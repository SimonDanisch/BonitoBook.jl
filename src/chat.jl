using Bonito
using Dates

"""
    ChatAgent

Abstract type for chat agents that can respond to prompts.
Implement `prompt(agent::YourChatAgent, question::String)` to create a custom chat agent.
"""
abstract type ChatAgent end

"""
    MockChatAgent

A simple mock chat agent for testing purposes.
"""
struct MockChatAgent <: ChatAgent end

function prompt(agent::MockChatAgent, question::String)
    return "Mock response to: $question"
end

"""
    ChatMessage

Represents a single message in the chat.

# Fields
- `content::String`: The message content
- `is_user::Bool`: Whether this message is from the user (true) or agent (false)
- `timestamp::DateTime`: When the message was sent
"""
struct ChatMessage
    content::String
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
"""
struct ChatComponent
    chat_agent::ChatAgent
    messages::Observable{Vector{ChatMessage}}
    input_text::Observable{String}
    is_processing::Observable{Bool}
end

"""
    ChatComponent(chat_agent::ChatAgent)

Create a new chat component with the given chat agent.
"""
function ChatComponent(chat_agent::ChatAgent)
    return ChatComponent(
        chat_agent,
        Observable(ChatMessage[]),
        Observable(""),
        Observable(false)
    )
end

function send_message!(chat::ChatComponent, message::String)
    if isempty(strip(message)) || chat.is_processing[]
        return
    end

    # Add user message
    user_msg = ChatMessage(message, true, now())
    push!(chat.messages[], user_msg)
    notify(chat.messages)

    # Clear input
    chat.input_text[] = ""

    # Set processing state
    chat.is_processing[] = true

    # Get response from agent (in a real implementation, this might be async)
    try
        response = prompt(chat.chat_agent, message)
        agent_msg = ChatMessage(response, false, now())
        push!(chat.messages[], agent_msg)
        notify(chat.messages)
    catch e
        error_msg = ChatMessage("Error: $(string(e))", false, now())
        push!(chat.messages[], error_msg)
        notify(chat.messages)
    finally
        chat.is_processing[] = false
    end
end

function Bonito.jsrender(session::Session, chat::ChatComponent)
    # Create the messages display
    messages_display = map(chat.messages) do messages
        message_elements = []

        for msg in messages
            msg_class = msg.is_user ? "chat-message chat-user" : "chat-message chat-agent"

            message_div = DOM.div(
                DOM.div(msg.content, class = "chat-message-content"),
                DOM.div(Dates.format(msg.timestamp, "HH:MM"), class = "chat-message-time"),
                class = msg_class
            )
            push!(message_elements, message_div)
        end

        return DOM.div(
            message_elements...,
            class = "chat-messages-container"
        )
    end

    # Create the input area
    input_field = DOM.input(
        type = "text",
        placeholder = "Type your message...",
        class = "chat-input",
        value = chat.input_text,
        disabled = chat.is_processing,
        oninput = js"event => $(chat.input_text).notify(event.target.value)",
        onkeydown = js"""event => {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                const message = event.target.value.trim();
                if (message) {
                    // Trigger send via Julia
                    $(chat.input_text).notify(message);
                    // We'll handle the actual send in Julia
                }
            }
        }"""
    )

    # Send button with icon
    send_clicked = Observable(false)
    send_icon = BonitoBook.icon("send")
    send_button = DOM.button(
        send_icon;
        onclick = js"event=> $(send_clicked).notify(true);",
        class = "small-button",
        disabled = chat.is_processing
    )

    # Handle send button click
    on(send_clicked) do _
        if !isempty(strip(chat.input_text[]))
            send_message!(chat, chat.input_text[])
        end
    end

    # Handle enter key send
    on(chat.input_text) do text
        # Check if this is a send trigger (we'll use a special marker)
        if endswith(text, "\n<send>")
            actual_text = replace(text, "\n<send>" => "")
            send_message!(chat, actual_text)
        end
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
        
        $(chat.messages).on(() => {
            setTimeout(() => {
                if (container) {
                    container.scrollTop = container.scrollHeight;
                }
                // Refocus the input after message is sent
                if (!$(chat.is_processing).value) {
                    input.focus();
                }
            }, 50);
        });

        // Enhanced enter key handling
        input.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                const message = input.value.trim();
                if (message && !$(chat.is_processing).value) {
                    $(chat.input_text).notify(message + '\n<send>');
                }
            }
        });
        
        // Also refocus when processing completes
        $(chat.is_processing).on((processing) => {
            if (!processing) {
                setTimeout(() => input.focus(), 50);
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
        "height" => "500px",
        "max-height" => "80vh",
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
        "border-radius" => "20px",
        "padding" => "8px 16px",
        "font-size" => "14px",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "outline" => "none",
        "transition" => "border-color 0.2s"
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
