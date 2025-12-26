module LLMChatBooks

using Bonito
using BonitoBook
using Observables
using JSON3
using Bonito.HTTP

# Include all components
include("tools.jl")
include("rendering.jl")
include("agent.jl")
include("spinner.jl")       # Must come before http_agent.jl and agent_loop.jl (defines TaskSpinner)
include("sanitizer.jl")     # Must come before agent_loop.jl (defines SanitizerConfig)
include("http_agent.jl")
include("message_history.jl")  # Message history: cells_to_messages, deduplication, compacting
include("agent_loop.jl")
include("styles.jl")

# Export main types
export LLMChatBook, create_book

"""
    LLMChatBook <: AbstractBook

An interactive LLM chat notebook where cells represent the conversation history.

# Fields
- `book::Book`: The underlying book
- `agent::HTTPAgent`: The HTTP agent for LLM communication (contains all config and state)
- `is_streaming::Observable{Bool}`: Whether agent is currently streaming
- `current_task::Base.RefValue{Union{Task, Nothing}}`: Current streaming task
- `task_spinner::TaskSpinner`: Unified spinner for all operations
- `file_editor::BonitoBook.TabbedFileEditor`: File editor widget for opening files from tools
- `sanitizer_config::SanitizerConfig`: Code execution sanitizer configuration
"""
mutable struct LLMChatBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    agent::HTTPAgent
    is_streaming::Observable{Bool}
    current_task::Base.RefValue{Union{Task, Nothing}}
    task_spinner::TaskSpinner
    file_editor::BonitoBook.TabbedFileEditor
    sanitizer_config::SanitizerConfig
end

"""
    create_book(book::Book; agent=nothing, file_editor=nothing, sanitizer_config=nothing, kwargs...)

Create an LLM Chat book from a regular book.

# Arguments
- `book::Book`: The underlying book
- `agent::Union{HTTPAgent, Nothing}`: Optional agent (loaded from config if not provided)
- `file_editor::Union{BonitoBook.TabbedFileEditor, Nothing}`: Optional file editor instance (created if not provided)
- `sanitizer_config::Union{SanitizerConfig, Nothing}`: Code execution sanitizer config (default: restrictive)
"""
function create_book(book::BonitoBook.Book; agent=nothing, file_editor=nothing, sanitizer_config=nothing, kwargs...)
    # Load or create agent
    if agent === nothing
        agent = load_agent_config(book.folder)
    end

    # Create file editor if not provided
    if file_editor === nothing
        file_editor = BonitoBook.TabbedFileEditor(String[])
    end

    # Register file editor in book widgets for tool access
    book.widgets["file_editor"] = file_editor

    # Create default sanitizer config if not provided
    if sanitizer_config === nothing
        sanitizer_config = SanitizerConfig(
            allow_pkg_operations=false,
            allow_file_operations=false,  # Force use of tools
            allow_include=false,
            max_output_lines=1000
        )
    end

    Core.eval(book.runner.mod,quote
        using BonitoBook.LLMChatBooks
        using JSON3
    end)

    # Run all tools, otherwise it looks weird with empty tool result cells
    for cell in book.cells
        #AddCell might be a long to execute cell, so skip running it here
        if get(cell.metadata, :tool, :notool) != "add_cell"
            BonitoBook.run_sync!(cell.editor)
        end
    end

    # Create LLM chat book with TaskSpinner
    return LLMChatBook(
        book,
        agent,
        Observable(false),
        Ref{Union{Task, Nothing}}(nothing),
        TaskSpinner(),
        file_editor,
        sanitizer_config
    )
end


"""
    send_message!(chat_book::LLMChatBook, message::String)

Send a message to the LLM and stream the response with TaskSpinner.
"""
function send_message!(chat_book::LLMChatBook, message::String)
    if isempty(strip(message)) ||
            chat_book.is_streaming[] ||
            (chat_book.current_task[] !== nothing && !istaskdone(chat_book.current_task[]))
        return
    end

    if chat_book.agent === nothing
        @warn "Failed to create LLM agent. Check API keys (ANTHROPIC_API_KEY, OPENAI_API_KEY) or Ollama installation."
        return
    end

    # Reset stop flag and set streaming state
    chat_book.task_spinner.stop[] = false
    chat_book.is_streaming[] = true

    # Create streaming display task
    chat_book.current_task[] = @async begin
        try
            run_agent_loop!(
                chat_book.book,
                chat_book.agent,
                message,
                chat_book.task_spinner,
                chat_book.sanitizer_config,
                chat_book.file_editor
            )
        catch e
            if !isa(e, InterruptException)
                @error "Streaming error" exception=(e, catch_backtrace())
            end
        finally
            @info "Agent loop completed, resetting streaming state"
            chat_book.is_streaming[] = false
            chat_book.current_task[] = nothing
            # Clear spinner text
            chat_book.task_spinner.text[] = ""
        end
    end

    return
end

"""
    stop_streaming!(chat_book::LLMChatBook)

Stop the current streaming response immediately at any level.
"""
function stop_streaming!(chat_book::LLMChatBook)
    # Set atomic stop flag (checked at all levels)
    chat_book.task_spinner.stop[] = true

    # Clear spinner text immediately
    chat_book.task_spinner.text[] = ""

    # Reset state
    chat_book.is_streaming[] = false
    chat_book.current_task[] = nothing
end


function Bonito.jsrender(session::Session, chat_book::LLMChatBook)
    # Standard book setup
    book = chat_book.book
    elements = BonitoBook.standard_setup!(session, book)

    # Render all cells directly (CellEditor.jsrender handles menu and callbacks)
    cells_container = DOM.div(book.cells, class="llm-chat-messages", id="chat-messages")
    # Chat input and stop control
    input_text = Observable("")
    stop_requested = Observable(false)

    input_field = DOM.textarea(
        placeholder="Type your message... (Press Enter to send, Shift+Enter for new line)",
        class="llm-chat-input",
        value=input_text[],
        disabled=chat_book.is_streaming,
        rows="1"
    )

    # Send button
    send_button = DOM.button(
        BonitoBook.icon("send"),
        class="llm-chat-send-button",
        disabled=chat_book.is_streaming
    )

    # Stop button
    stop_button = DOM.button(
        BonitoBook.icon("debug-stop"),
        class="llm-chat-stop-button",
        disabled=map(!, chat_book.is_streaming)
    )

    # Single spinner with dynamic text
    task_spinner_component = LLMChatSpinner(chat_book.task_spinner.text)
    spinner_container = DOM.div(
        task_spinner_component,
        class="llm-chat-spinners"
    )

    # Input row with field and buttons
    input_row = DOM.div(
        input_field,
        send_button,
        stop_button,
        class="llm-chat-input-row"
    )

    # Input container
    input_container = DOM.div(
        spinner_container,
        input_row,
        class="llm-chat-input-container"
    )

    # Main container
    chat_container = DOM.div(
        cells_container,
        input_container,
        class="llm-chat-container"
    )

    # JavaScript for input handling
    input_script = js"""
        const input = $(input_field);
        const sendBtn = $(send_button);
        const stopBtn = $(stop_button);
        const container = $(chat_container);

        // Auto-resize textarea with better sizing
        function resizeTextarea() {
            input.style.height = '36px'; // Reset to min height
            const scrollHeight = input.scrollHeight;
            const newHeight = Math.min(Math.max(scrollHeight, 36), 120);
            input.style.height = newHeight + 'px';
        }

        input.addEventListener('input', resizeTextarea);

        // Initial resize
        resizeTextarea();

        // Handle Enter key for sending
        input.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                const message = input.value.trim();
                if (message && !$(chat_book.is_streaming).value) {
                    $(input_text).notify(message);
                    input.value = '';
                    resizeTextarea();
                }
            }
        });

        // Send button click
        sendBtn.addEventListener('click', () => {
            const message = input.value.trim();
            if (message && !$(chat_book.is_streaming).value) {
                $(input_text).notify(message);
                input.value = '';
                resizeTextarea();
            }
        });

        // Stop button click - calls stop_streaming! directly
        stopBtn.addEventListener('click', () => {
            if ($(chat_book.is_streaming).value) {
                // Trigger stop via a notification that we'll handle in Julia
                $(stop_requested).notify(true);
            }
        });

        // ESC key to stop streaming
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && $(chat_book.is_streaming).value) {
                event.preventDefault();
                $(stop_requested).notify(true);
            }
        });

        // Auto-scroll to bottom when new messages arrive
        let lastScrollHeight = container.scrollHeight;
        let isUserScrolling = false;
        let scrollTimeout = null;

        function scrollToBottom() {
            requestAnimationFrame(() => {
                container.scrollTop = container.scrollHeight;
                lastScrollHeight = container.scrollHeight;
            });
        }

        // Check if user is near bottom (within 150px)
        function isNearBottom() {
            return container.scrollHeight - container.scrollTop - container.clientHeight < 150;
        }

        // Track user scrolling
        container.addEventListener('scroll', () => {
            isUserScrolling = !isNearBottom();
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(() => {
                isUserScrolling = false;
            }, 1000);
        });

        // Observe ALL changes in container (new cells AND cell content updates)
        const observer = new MutationObserver((mutations) => {
            // Throttle scroll updates
            requestAnimationFrame(() => {
                const hasNewContent = container.scrollHeight > lastScrollHeight;
                // Auto-scroll if user is near bottom or not manually scrolling
                if (hasNewContent && (!isUserScrolling || isNearBottom())) {
                    scrollToBottom();
                }
                lastScrollHeight = container.scrollHeight;
            });
        });
        // Watch for all changes including subtree (cell content updates)
        observer.observe(container, {
            childList: true,
            subtree: true,
            characterData: true,
            attributes: true
        });

        // Auto-focus input and scroll when not streaming
        $(chat_book.is_streaming).on((streaming) => {
            if (!streaming) {
                setTimeout(() => {
                    input.focus();
                    scrollToBottom();
                }, 100);
            }
        });

        // Initial setup
        setTimeout(() => {
            input.focus();
            scrollToBottom();
        }, 100);
    """

    # Handle input text changes
    on(input_text) do text
        if !isempty(strip(text))
            send_message!(chat_book, text)
            input_text[] = ""  # Clear after sending
        end
    end

    # Handle stop requests from UI
    on(stop_requested) do _
        if chat_book.is_streaming[]
            @info "Stop requested from UI"
            stop_streaming!(chat_book)
        end
    end

    # Create layout with file editor
    file_editor_widget = chat_book.file_editor

    # File editor visibility toggle
    editor_visible = Observable(true)

    # Collapse/expand button at panel border
    collapse_btn = DOM.div("◀", class="file-editor-collapse-btn", title="Toggle File Editor")

    # JavaScript for collapse/expand functionality
    collapse_script = js"""
        const collapseBtn = $(collapse_btn);
        const rightPanel = document.querySelector('.llm-chat-right-panel');
        const editorVisible = $(editor_visible);

        collapseBtn.addEventListener('click', () => {
            const isVisible = !editorVisible.value;
            editorVisible.notify(isVisible);

            if (isVisible) {
                rightPanel.style.display = 'flex';
                collapseBtn.textContent = '◀';
                collapseBtn.title = 'Hide File Editor';
                collapseBtn.style.right = 'calc(40% - 10px)';
                collapseBtn.style.borderRadius = '4px 0 0 4px';
            } else {
                rightPanel.style.display = 'none';
                collapseBtn.textContent = '▶';
                collapseBtn.title = 'Show File Editor';
                collapseBtn.style.right = '0';
                collapseBtn.style.borderRadius = '4px 0 0 4px';
            }
        });

        // Initial state
        rightPanel.style.display = editorVisible.value ? 'flex' : 'none';
        collapseBtn.textContent = editorVisible.value ? '◀' : '▶';
        collapseBtn.style.right = editorVisible.value ? 'calc(40% - 10px)' : '0';
    """

    # Split layout: chat on left, file editor on right with collapse button
    layout = DOM.div(
        DOM.div(
            elements,
            chat_container,
            input_script,
            class="llm-chat-left-panel"
        ),
        collapse_btn,
        DOM.div(
            file_editor_widget,
            class="llm-chat-right-panel"
        ),
        collapse_script,
        class="llm-chat-split-layout"
    )

    # Return combined view
    return Bonito.jsrender(session, layout)
end

end # module LLMChatBooks
