"""
Compact spinner component specifically for LLMChat status indicators.
Shows small animated dots next to the chat input field.
"""

struct LLMChatSpinner
    visible::Observable{Bool}
    message::Observable{String}
end

function LLMChatSpinner(message::String="")
    return LLMChatSpinner(Observable(false), Observable(message))
end

function Bonito.jsrender(session::Session, spinner::LLMChatSpinner)
    # Create spinner with animated dots
    spinner_content = map(spinner.visible, spinner.message) do visible, msg
        if visible
            DOM.div(
                DOM.span(class="llm-spinner-dot"),
                DOM.span(class="llm-spinner-dot"),
                DOM.span(class="llm-spinner-dot"),
                DOM.span(isempty(msg) ? "" : msg, class="llm-spinner-text"),
                class="llm-spinner-active"
            )
        else
            DOM.div(class="llm-spinner-hidden")
        end
    end

    return Bonito.jsrender(session, spinner_content)
end

# Spinner styles with CSS animation
const LLMSpinnerStyles = DOM.style("""
.llm-chat-spinners {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 4px 8px;
    font-size: 12px;
    color: var(--vscode-descriptionForeground);
    min-height: 20px;
}

.llm-spinner-hidden {
    display: none;
}

.llm-spinner-active {
    display: flex;
    align-items: center;
    gap: 4px;
    animation: fadeIn 0.2s ease-in;
}

.llm-spinner-dot {
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background-color: var(--vscode-progressBar-background);
    animation: pulse 1.4s ease-in-out infinite;
}

.llm-spinner-dot:nth-child(1) {
    animation-delay: 0s;
}

.llm-spinner-dot:nth-child(2) {
    animation-delay: 0.2s;
}

.llm-spinner-dot:nth-child(3) {
    animation-delay: 0.4s;
}

.llm-spinner-text {
    margin-left: 4px;
    font-size: 11px;
    color: var(--vscode-descriptionForeground);
    opacity: 0.8;
}

@keyframes pulse {
    0%, 100% {
        opacity: 0.3;
        transform: scale(0.8);
    }
    50% {
        opacity: 1;
        transform: scale(1.2);
    }
}

@keyframes fadeIn {
    from {
        opacity: 0;
        transform: translateY(-2px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

/* Different colors for different spinner types */
.llm-spinner-http .llm-spinner-dot {
    background-color: #4a9eff; /* Blue for HTTP */
}

.llm-spinner-channel .llm-spinner-dot {
    background-color: #89d185; /* Green for channel processing */
}

.llm-spinner-loop .llm-spinner-dot {
    background-color: #f0ad4e; /* Orange for loop iterations */
}
""")
