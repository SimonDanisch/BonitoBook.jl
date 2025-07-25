using Bonito
using Dates
using Base64

"""
    ChatAgent

Abstract type for chat agents that can respond to prompts.
Implement `prompt(agent::YourChatAgent, question::String)` to create a custom chat agent.
"""
abstract type ChatAgent end

"""
    settings_menu(agent::ChatAgent)

Returns a Bonito widget for configuring agent settings.
Default implementation returns a simple text widget.
Override this method for custom agents to provide specific settings UI.
"""
function settings_menu(agent::ChatAgent)
    return DOM.div("No settings available for this agent type.")
end


"""
    ChatMessage

Represents a single message in the chat.

# Fields
- `content::Union{String, Any}`: The message content (can be text or parsed Markdown)
- `is_user::Bool`: Whether this message is from the user (true) or agent (false)
- `timestamp::Dates.DateTime`: When the message was sent
- `attachments::Vector{String}`: File paths to attached images or files
"""
struct ChatMessage
    content::Any
    is_user::Bool
    timestamp::DateTime
    attachments::Vector{String}
end

# Convenience constructor for backward compatibility
ChatMessage(content, is_user, timestamp) = ChatMessage(content, is_user, timestamp, String[])

"""
    ChatComponent

A chat component for AI-powered conversations.

# Fields
- `chat_agent::ChatAgent`: The chat agent that will respond to prompts
- `messages::Observable{Vector{ChatMessage}}`: Observable list of chat messages
- `input_text::Observable{String}`: Current input text
- `is_processing::Observable{Bool}`: Whether the agent is currently processing
- `book::Union{Any, Nothing}`: Optional book context for code execution via MCP server
"""
struct ChatComponent
    chat_agent::ChatAgent
    messages::Observable{Vector{ChatMessage}}
    input_text::Observable{String}
    is_processing::Observable{Bool}
    book::Union{Any, Nothing}
    current_task::Base.RefValue{Union{Task, Nothing}}
    pending_attachments::Observable{Vector{String}}
end

"""
    ChatComponent(chat_agent::ChatAgent; book=nothing)

Create a new chat component with the given chat agent.
"""
function ChatComponent(chat_agent::ChatAgent; book=nothing)
    return ChatComponent(
        chat_agent,
        @D(Observable(ChatMessage[])),
        @D(Observable("")),
        @D(Observable(false)),
        book,
        Ref{Union{Task, Nothing}}(nothing),
        @D(Observable(String[]))
    )
end

# Utility function to ensure data/tmp directory exists
function ensure_tmp_directory()
    tmp_dir = joinpath("data", "tmp")
    if !isdir(tmp_dir)
        mkpath(tmp_dir)
    end
    return tmp_dir
end

# Function to save pasted image data to tmp directory
function save_pasted_image(image_data_base64::String, filename::String)
    tmp_dir = ensure_tmp_directory()

    # Decode base64 image data
    # Remove data:image/png;base64, prefix if present
    if startswith(image_data_base64, "data:")
        image_data_base64 = split(image_data_base64, ",")[2]
    end

    # Decode base64 to bytes
    image_bytes = base64decode(image_data_base64)

    # Generate unique filename with timestamp
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    file_path = joinpath(tmp_dir, "$(timestamp)_$(filename)")

    # Write image to file
    open(file_path, "w") do f
        write(f, image_bytes)
    end

    return file_path
end


function send_message!(chat::ChatComponent, message::String)
    if isempty(strip(message)) || chat.is_processing[]
        return
    end
    # Get current attachments and clear them
    attachments = copy(chat.pending_attachments[])
    chat.pending_attachments[] = String[]

    # Add user message with attachments
    user_msg = ChatMessage(message, true, Dates.now(), attachments)
    push!(chat.messages[], user_msg)
    notify(chat.messages)
    # Set processing state
    chat.is_processing[] = true
    agent_msg = try
        # For Claude Code, we need to format the message with attachments
        formatted_message = if !isempty(attachments)
            attachment_text = join(["Image: $path" for path in attachments], "\n")
            "$message\n\n$attachment_text"
        else
            message
        end

        response_channel = prompt(chat.chat_agent, formatted_message)
        dom = @D Observable(DOM.div())
        task = Threads.@spawn begin
            try
                for msg in response_channel
                    push!(Bonito.Hyperscript.children(dom[]), msg)
                    notify(dom)
                end
            catch e
                if isa(e, InterruptException)
                    # Add interrupted message
                    push!(Bonito.Hyperscript.children(dom[]), DOM.div("[Response interrupted]", style="color: orange; font-style: italic;"))
                    notify(dom)
                else
                    rethrow(e)
                end
            finally
                chat.is_processing[] = false
                chat.current_task[] = nothing
            end
        end
        chat.current_task[] = task
        ChatMessage(dom, false, Dates.now())
    catch e
        chat.is_processing[] = false
        chat.current_task[] = nothing
        ChatMessage(e, false, Dates.now())
    finally
    end
    push!(chat.messages[], agent_msg)
    notify(chat.messages)
end

function stop_streaming!(chat::ChatComponent)
    if chat.current_task[] !== nothing
        # Interrupt the current streaming task
        Base.schedule(chat.current_task[], InterruptException(); error=true)
        chat.current_task[] = nothing
        chat.is_processing[] = false
    end
end

function Bonito.jsrender(session::Session, message::ChatMessage)
    # Render a single chat message
    user = message.is_user ? "user" : "agent"
    content_display = DOM.div(message.content, class = "chat-message-content")

    # Add attachment previews if present
    attachment_elements = []
    if !isempty(message.attachments)
        for attachment in message.attachments
            if isfile(attachment)
                # Create image preview
                img_element = DOM.img(
                    src = Asset(attachment),
                    style = "max-width: 200px; max-height: 200px; border-radius: 8px; margin: 4px 0;",
                    alt = "Attached image"
                )
                push!(attachment_elements, img_element)
            else
                # Show placeholder for missing files
                placeholder = DOM.div(
                    "📎 $(basename(attachment))",
                    style = "color: #666; font-style: italic; margin: 4px 0;"
                )
                push!(attachment_elements, placeholder)
            end
        end
    end

    message_content = if !isempty(attachment_elements)
        DOM.div(content_display, attachment_elements...)
    else
        content_display
    end

    return Bonito.jsrender(session, DOM.div(
        message_content,
        DOM.div(Dates.format(message.timestamp, "HH:MM"), class = "chat-message-time"),
        class = "chat-message chat-$user"
    ))
end

function Bonito.jsrender(session::Session, chat::ChatComponent)
    # Create the messages display
    messages_display = map(chat.messages) do messages
        return DOM.div(messages...; class = "chat-messages-container")
    end

    # Create the input area
    input_field = DOM.textarea(
        placeholder = "Type your message... (Press Enter to send, Shift+Enter for new line)",
        class = "chat-input",
        value = chat.input_text[],
        disabled = chat.is_processing,
        rows = "1",
        style = "resize: none; overflow-y: hidden; min-height: 40px;"
    )

    # Send button with icon
    send_button, send_clicked = SmallButton("send"; disabled = chat.is_processing)

    # Stop button with icon
    stop_button, stop_clicked = SmallButton("debug-stop"; disabled = map(!, chat.is_processing))

    # Settings button with icon
    settings_button, settings_clicked = SmallButton("settings"; disabled = false)

    # Handle send button click
    on(send_clicked) do _
        if !isempty(strip(chat.input_text[]))
            send_message!(chat, chat.input_text[])
        end
    end

    # Handle stop button click
    on(stop_clicked) do _
        stop_streaming!(chat)
    end

    # Create settings popup
    settings_popup = PopUp(settings_menu(chat.chat_agent); show = false)

    # Handle settings button click
    on(settings_clicked) do _
        settings_popup.show[] = true
    end

    # Handle image paste events
    paste_data = Observable{Dict}(Dict())
    on(paste_data) do attachment_data
        if haskey(attachment_data, "type") && attachment_data["type"] == "image"
            # Save the pasted image
            file_path = save_pasted_image(attachment_data["data"], attachment_data["filename"])
            # Add to pending attachments list
            current_attachments = copy(chat.pending_attachments[])
            push!(current_attachments, file_path)
            chat.pending_attachments[] = current_attachments
        end
    end

    # Handle enter key send
    on(chat.input_text) do text
        # Check if this is a send trigger (we'll use a special marker)
        send_message!(chat, text)
    end

    # Processing indicator
    processing_indicator = map(chat.is_processing) do processing
        if processing
            DOM.div("AI is thinking...", class = "chat-processing")
        else
            DOM.div()
        end
    end

    # Attachment indicator
    attachment_indicator = map(chat.pending_attachments) do attachments
        if !isempty(attachments)
            DOM.div(
                "📎 $(length(attachments)) file(s) attached",
                class = "chat-attachment-indicator",
                style = "padding: 4px 8px; background: #e3f2fd; border-radius: 4px; font-size: 12px; color: #1976d2; margin: 4px 0;"
            )
        else
            DOM.div()
        end
    end

    # Combine all elements
    chat_container = DOM.div(
        ChatStyles,
        DOM.div(
            messages_display,
            processing_indicator,
            class = "chat-messages-wrapper"
        ),
        attachment_indicator,
        DOM.div(
            input_field,
            settings_button,
            send_button,
            stop_button,
            class = "chat-input-area"
        ),
        class = "chat-container"
    )

    # Auto-scroll to bottom when new messages arrive and maintain focus
    scroll_script = js"""
        const container = $(chat_container).querySelector('.chat-messages-wrapper');
        const input = $(input_field);

        // Auto-resize textarea
        function resizeTextarea() {
            input.style.height = 'auto';
            input.style.height = Math.min(input.scrollHeight, 120) + 'px';
        }

        input.addEventListener('input', resizeTextarea);

        // Enhanced enter key handling for multiline
        input.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                const message = input.value.trim();
                if (message && !$(chat.is_processing).value) {
                    $(chat.input_text).notify(message);
                    $(chat.input_text).notify(""); // Clear input after sending
                    input.value = ""; // Clear input field
                    resizeTextarea(); // Reset height after clearing
                }
            }
        });

        // Handle paste events for images
        input.addEventListener('paste', (event) => {
            const items = event.clipboardData.items;
            for (let i = 0; i < items.length; i++) {
                const item = items[i];
                if (item.type.indexOf('image') !== -1) {
                    event.preventDefault();
                    const file = item.getAsFile();
                    const reader = new FileReader();
                    reader.onload = function(e) {
                        // Send image data to Julia for processing
                        $(paste_data).notify({
                            type: 'image',
                            data: e.target.result,
                            filename: file.name || 'pasted_image.png'
                        });
                    };
                    reader.readAsDataURL(file);
                }
            }
        });

        // Also refocus when processing completes
        $(chat.is_processing).on((processing) => {
            if (!processing) {
                container.scrollTop = container.scrollHeight;
                // Refocus the input after message is sent
                input.focus();
            }
        });
    """

    return Bonito.jsrender(session, DOM.div(chat_container, scroll_script, settings_popup))
end

# Chat-specific styles
const ChatStyles = Styles(
    CSS(
        ".chat-container",
        "display" => "flex",
        "flex-direction" => "column",
        "height" => "800px",
        "max-width" => "800px",
        "max-height" => "80vh",
        "min-width" => "600px",
        "background-color" => "var(--bg-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "10px",
        "overflow" => "hidden",
        "position" => "relative",
    ),
    CSS(
        ".chat-messages-wrapper",
        "flex" => "1 1 auto",
        "overflow-y" => "auto",
        "padding" => "16px",
        "background-color" => "var(--bg-primary)",
        "min-height" => "0"
    ),
    CSS(
        ".chat-messages-container",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "12px"
    ),
    CSS(
        ".chat-message",
        "display" => "flex",
        "flex-direction" => "column",
        "max-width" => "70%",
        "word-wrap" => "break-word"
    ),
    CSS(
        ".chat-user",
        "align-self" => "flex-end",
        "align-items" => "flex-end"
    ),
    CSS(
        ".chat-agent",
        "align-self" => "flex-start",
        "align-items" => "flex-start"
    ),
    CSS(
        ".chat-message-content",
        "padding" => "10px 14px",
        "border-radius" => "8px",
        "font-size" => "14px",
        "line-height" => "1.5"
    ),
    CSS(
        ".chat-user .chat-message-content",
        "background-color" => "var(--accent-blue)",
        "color" => "white"
    ),
    CSS(
        ".chat-agent .chat-message-content",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".chat-message-time",
        "font-size" => "11px",
        "color" => "var(--text-secondary)",
        "margin-top" => "4px",
        "padding" => "0 4px"
    ),
    CSS(
        ".chat-input-area",
        "display" => "flex",
        "align-items" => "center",
        "padding" => "12px",
        "border-top" => "1px solid var(--border-primary)",
        "background-color" => "var(--bg-primary)",
        "gap" => "8px",
        "flex-shrink" => "0"
    ),
    CSS(
        ".chat-input",
        "flex" => "1",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "12px",
        "padding" => "8px 16px",
        "font-size" => "14px",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "outline" => "none",
        "transition" => "border-color 0.2s",
        "font-family" => "inherit",
        "line-height" => "1.4",
        "max-height" => "120px"
    ),
    CSS(
        ".chat-input:focus",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".chat-input:disabled",
        "opacity" => "0.6",
        "cursor" => "not-allowed"
    ),
    CSS(
        ".chat-processing",
        "text-align" => "center",
        "color" => "var(--text-secondary)",
        "font-size" => "14px",
        "font-style" => "italic",
        "padding" => "8px",
        "animation" => "pulse 1.5s ease-in-out infinite"
    ),
    CSS(
        "@keyframes pulse",
        CSS("0%, 100%", "opacity" => "0.6"),
        CSS("50%", "opacity" => "1")
    ),
)
