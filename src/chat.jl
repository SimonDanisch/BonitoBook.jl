using Bonito
using Dates

"""
    ChatAgent

Abstract type for chat agents that can respond to prompts.
Implement `prompt(agent::YourChatAgent, question::String)` to create a custom chat agent.
"""
abstract type ChatAgent end


"""
    ChatMessage

Represents a single message in the chat.

# Fields
- `content::Union{String, Any}`: The message content (can be text or parsed Markdown)
- `is_user::Bool`: Whether this message is from the user (true) or agent (false)
- `timestamp::Dates.DateTime`: When the message was sent
"""
struct ChatMessage
    content::Any
    is_user::Bool
    timestamp::DateTime
end

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
end

"""
    ChatComponent(chat_agent::ChatAgent; book=nothing)

Create a new chat component with the given chat agent.
"""
function ChatComponent(chat_agent::ChatAgent; book=nothing)
    return ChatComponent(
        chat_agent,
        Observable(ChatMessage[]),
        Observable(""),
        Observable(false),
        book
    )
end


function send_message!(chat::ChatComponent, message::String)
    if isempty(strip(message)) || chat.is_processing[]
        return
    end
    # Add user message
    user_msg = ChatMessage(message, true, Dates.now())
    push!(chat.messages[], user_msg)
    notify(chat.messages)
    # Set processing state
    chat.is_processing[] = true
    agent_msg = try
        response_channel = prompt(chat.chat_agent, message)
        dom = Observable(DOM.div())
        Threads.@spawn begin
            for msg in response_channel
                push!(Bonito.Hyperscript.children(dom[]), msg)
                notify(dom)
            end
            chat.is_processing[] = false
        end
        ChatMessage(dom, false, Dates.now())
    catch e
        ChatMessage(e, false, Dates.now())
    finally
    end
    push!(chat.messages[], agent_msg)
    notify(chat.messages)
end

function Bonito.jsrender(session::Session, message::ChatMessage)
    # Render a single chat message
    user = message.is_user ? "user" : "agent"
    content_display = DOM.div(message.content, class = "chat-message-content")
    return Bonito.jsrender(session, DOM.div(
        content_display,
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

    # Handle send button click
    on(send_clicked) do _
        if !isempty(strip(chat.input_text[]))
            send_message!(chat, chat.input_text[])
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

    # Combine all elements
    chat_container = DOM.div(
        ChatStyles,
        DOM.div(
            messages_display,
            processing_indicator,
            class = "chat-messages-wrapper"
        ),
        DOM.div(
            input_field,
            send_button,
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

        // Also refocus when processing completes
        $(chat.is_processing).on((processing) => {
            if (!processing) {
                container.scrollTop = container.scrollHeight;
                // Refocus the input after message is sent
                input.focus();
            }
        });
    """

    return Bonito.jsrender(session, DOM.div(chat_container, scroll_script))
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
