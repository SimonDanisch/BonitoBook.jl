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
include("http_agent.jl")
include("agent_loop.jl")
include("spinner.jl")
include("styles.jl")

# Export main types
export LLMChatBook, create_book

"""
    LLMChatBook <: AbstractBook

An interactive LLM chat notebook where cells represent the conversation history.

# Fields
- `book::Book`: The underlying book
- `agent::Union{LLMChatAgent, Nothing}`: The LLM agent (if available)
- `config::AgentConfig`: Agent configuration
- `is_streaming::Observable{Bool}`: Whether agent is currently streaming
- `current_task::Base.RefValue{Union{Task, Nothing}}`: Current streaming task
- `http_spinner::LLMChatSpinner`: Spinner for HTTP requests
- `channel_spinner::LLMChatSpinner`: Spinner for channel processing
- `loop_spinner::LLMChatSpinner`: Spinner for agent loop iterations
"""
mutable struct LLMChatBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    agent::Any
    config::AgentConfig
    is_streaming::Observable{Bool}
    current_task::Base.RefValue{Union{Task, Nothing}}
    stop_flag::Threads.Atomic{Bool}
    http_spinner::LLMChatSpinner
    channel_spinner::LLMChatSpinner
    loop_spinner::LLMChatSpinner
end

"""
    create_book(book::Book; agent=nothing, config=nothing, kwargs...)

Create an LLM Chat book from a regular book.

# Arguments
- `book::Book`: The underlying book
- `agent::Union{LLMChatAgent, Nothing}`: Optional agent (auto-detected if not provided)
- `config::Union{AgentConfig, Nothing}`: Optional config (loaded from file if not provided)
"""
function create_book(book::BonitoBook.Book; agent=nothing, config=nothing, kwargs...)
    # Load or create config
    if config === nothing
        config = load_agent_config(book.folder)
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

    # Create LLM chat book with custom spinners
    return LLMChatBook(
        book,
        agent,
        config,
        Observable(false),
        Ref{Union{Task, Nothing}}(nothing),
        Threads.Atomic{Bool}(false),
        LLMChatSpinner("requesting"),    # http_spinner
        LLMChatSpinner("processing"),    # channel_spinner
        LLMChatSpinner("thinking")       # loop_spinner
    )
end

"""
    send_message!(chat_book::LLMChatBook, message::String)

Send a message to the LLM and stream the response with multi-level spinners.
"""
function send_message!(chat_book::LLMChatBook, message::String)
    if isempty(strip(message)) || chat_book.is_streaming[]
        return
    end

    if chat_book.agent === nothing
        @warn "Failed to create LLM agent. Check API keys (ANTHROPIC_API_KEY, OPENAI_API_KEY) or Ollama installation."
        return
    end

    # Reset stop flag and set streaming state
    chat_book.stop_flag[] = false
    chat_book.is_streaming[] = true

    # Run agent loop with spinners
    response_channel = run_agent_loop!(
        chat_book.book,
        chat_book.agent,
        message,
        chat_book.config,
        chat_book.stop_flag;
        http_spinner=chat_book.http_spinner,
        channel_spinner=chat_book.channel_spinner,
        loop_spinner=chat_book.loop_spinner
    )

    # Create streaming display task
    task = @async begin
        try
            for item in response_channel
                # Check stop flag while consuming output
                if chat_book.stop_flag[]
                    break
                end
                # Items are already being added to cells by agent_loop
                # This is just for any additional UI updates
            end
        catch e
            if !isa(e, InterruptException)
                @error "Streaming error" exception=(e, catch_backtrace())
            end
        finally
            @info "Agent loop completed, resetting streaming state"
            chat_book.is_streaming[] = false
            chat_book.current_task[] = nothing
            # Ensure all spinners are hidden
            chat_book.http_spinner.visible[] = false
            chat_book.channel_spinner.visible[] = false
            chat_book.loop_spinner.visible[] = false
        end
    end

    chat_book.current_task[] = task

    # Ensure task is running
    yield()

    return
end

"""
    stop_streaming!(chat_book::LLMChatBook)

Stop the current streaming response immediately at any level.
"""
function stop_streaming!(chat_book::LLMChatBook)
    # Set atomic stop flag (checked at all levels)
    chat_book.stop_flag[] = true

    # Hide all spinners immediately
    chat_book.http_spinner.visible[] = false
    chat_book.channel_spinner.visible[] = false
    chat_book.loop_spinner.visible[] = false
    # Reset state
    chat_book.is_streaming[] = false
    chat_book.current_task[] = nothing
end


function Bonito.jsrender(session::Session, chat_book::LLMChatBook)
    # Standard book setup
    book = chat_book.book
    elements = BonitoBook.standard_setup!(session, book)
    BonitoBook.add_julia_mpc_route!(book)
    # Create agent if not provided
    if chat_book.agent === nothing
        chat_book.agent = create_llm_chat_agent(book)
    end
    # Render all cells
    cells = map(book.cells) do cell
        from = get(cell.metadata, :from, :user)
        cell_class = "cell-from-$from"
        return DOM.div(cell, class=cell_class)
    end
    cells_container = DOM.div(cells, class="llm-chat-messages", id="chat-messages")
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

    # Spinner indicators with individual classes for colors
    http_spinner_div = DOM.div(chat_book.http_spinner, class="llm-spinner-http")
    channel_spinner_div = DOM.div(chat_book.channel_spinner, class="llm-spinner-channel")
    loop_spinner_div = DOM.div(chat_book.loop_spinner, class="llm-spinner-loop")

    spinner_container = DOM.div(
        http_spinner_div,
        channel_spinner_div,
        loop_spinner_div,
        class="llm-chat-spinners"
    )

    # Input container
    input_container = DOM.div(
        spinner_container,
        input_field,
        send_button,
        stop_button,
        class="llm-chat-input-container"
    )

    # Main container
    chat_container = DOM.div(
        LLMSpinnerStyles,
        ChatStyles,
        cells_container,
        input_container,
        class="llm-chat-container"
    )

    # JavaScript for input handling
    input_script = js"""
        const input = $(input_field);
        const sendBtn = $(send_button);
        const stopBtn = $(stop_button);
        const container = $(chat_container).querySelector('.llm-chat-messages');

        // Auto-resize textarea
        function resizeTextarea() {
            input.style.height = 'auto';
            input.style.height = Math.min(input.scrollHeight, 120) + 'px';
        }

        input.addEventListener('input', resizeTextarea);

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
        function scrollToBottom() {
            container.scrollTop = container.scrollHeight;
        }

        // Observe cells changes for auto-scroll
        const observer = new MutationObserver(scrollToBottom);
        observer.observe(container, { childList: true, subtree: true });

        // Auto-focus input when not streaming
        $(chat_book.is_streaming).on((streaming) => {
            if (!streaming) {
                input.focus();
                scrollToBottom();
            }
        });

        // Initial focus
        input.focus();
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


    # Return combined view
    return Bonito.jsrender(session, DOM.div(elements, chat_container, input_script))
end

end # module LLMChatBooks
