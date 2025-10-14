"""
Styles for the LLM Chat plugin.
"""

const ChatStyles = Styles(
    # Chat container - fills viewport
    CSS(
        ".llm-chat-container",
        "display" => "flex",
        "flex-direction" => "column",
        "height" => "100vh",
        "overflow" => "hidden",
        "background-color" => "var(--bg-primary)",
        "position" => "relative"
    ),

    # Messages area - scrollable with hidden scrollbar
    CSS(
        ".llm-chat-messages",
        "flex" => "1 1 auto",
        "overflow-y" => "auto",
        "padding" => "12px",
        "padding-bottom" => "90px",  # Space for flexible input height
        "scroll-behavior" => "smooth",
        "scrollbar-width" => "none"
    ),

    CSS(
        ".llm-chat-messages::-webkit-scrollbar",
        "display" => "none"
    ),

    # User cell styling - message bubbles on the right
    CSS(
        ".cell-from-user",
        "display" => "flex",
        "justify-content" => "flex-end",
        "margin-left" => "auto",
        "margin-right" => "0",
        "max-width" => "75%",
        "margin-bottom" => "8px",
        "animation" => "slideInRight 0.2s ease-out"
    ),

    CSS(
        ".cell-from-user .cell-output",
        "background" => "var(--accent-blue)",
        "color" => "white",
        "border-radius" => "4px",
        "padding" => "8px 12px",
        "margin" => "0",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)",
        "word-wrap" => "break-word",
        "line-height" => "1.5",
        "text-align" => "left"
    ),

    # Agent cell styling - message bubbles on the left
    CSS(
        ".cell-from-agent",
        "margin-left" => "0",
        "margin-right" => "auto",
        "max-width" => "75%",
        "margin-bottom" => "8px",
        "animation" => "slideInLeft 0.2s ease-out"
    ),

    CSS(
        ".cell-from-agent .cell-output",
        "background-color" => "var(--hover-bg)",
        "border-radius" => "4px",
        "padding" => "8px 12px",
        "margin" => "0",
        "border-left" => "2px solid var(--border-secondary)",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.05)",
        "word-wrap" => "break-word",
        "line-height" => "1.5"
    ),

    # Fixed chat input at bottom - improved design
    CSS(
        ".llm-chat-input-container",
        "position" => "fixed",
        "bottom" => "0",
        "left" => "0",
        "right" => "0",
        "background" => "var(--bg-primary)",
        "border-top" => "1px solid var(--border-secondary)",
        "padding" => "8px 12px 12px",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "6px",
        "z-index" => "1000",
        "box-shadow" => "0 -1px 3px rgba(0, 0, 0, 0.03)"
    ),

    # Container for input field and buttons
    CSS(
        ".llm-chat-input-row",
        "display" => "flex",
        "align-items" => "flex-end",
        "gap" => "6px",
        "width" => "100%"
    ),

    CSS(
        ".llm-chat-input",
        "flex" => "1",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "4px",
        "padding" => "8px 12px",
        "font-size" => "14px",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "outline" => "none",
        "resize" => "none",
        "min-height" => "36px",
        "max-height" => "120px",
        "overflow-y" => "auto !important",
        "overflow-x" => "hidden",
        "font-family" => "inherit",
        "line-height" => "1.4",
        "transition" => "border-color 0.15s, box-shadow 0.15s",
        "box-sizing" => "border-box",
        "scrollbar-width" => "none"
    ),

    CSS(
        ".llm-chat-input::-webkit-scrollbar",
        "display" => "none"
    ),

    CSS(
        ".llm-chat-input:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(33, 150, 243, 0.08)"
    ),

    CSS(
        ".llm-chat-input:disabled",
        "opacity" => "0.5",
        "cursor" => "not-allowed",
        "background-color" => "var(--hover-bg)"
    ),

    CSS(
        ".llm-chat-input::placeholder",
        "color" => "var(--text-secondary)",
        "opacity" => "0.6"
    ),

    # Send button - improved with icon support
    CSS(
        ".llm-chat-send-button",
        "background" => "var(--accent-blue)",
        "color" => "white",
        "border" => "none",
        "border-radius" => "4px",
        "width" => "36px",
        "height" => "36px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "cursor" => "pointer",
        "transition" => "all 0.15s ease",
        "flex-shrink" => "0",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)",
        "font-size" => "16px"
    ),

    CSS(
        ".llm-chat-send-button:hover:not(:disabled)",
        "opacity" => "0.9",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.15)"
    ),

    CSS(
        ".llm-chat-send-button:active:not(:disabled)",
        "transform" => "scale(0.98)"
    ),

    CSS(
        ".llm-chat-send-button:disabled",
        "opacity" => "0.3",
        "cursor" => "not-allowed",
        "transform" => "none",
        "box-shadow" => "none"
    ),

    # Stop button - warning style
    CSS(
        ".llm-chat-stop-button",
        "background" => "#f44336",
        "color" => "white",
        "border" => "none",
        "border-radius" => "4px",
        "width" => "36px",
        "height" => "36px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "cursor" => "pointer",
        "transition" => "all 0.15s ease",
        "flex-shrink" => "0",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)",
        "font-size" => "16px"
    ),

    CSS(
        ".llm-chat-stop-button:hover:not(:disabled)",
        "opacity" => "0.9",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.15)"
    ),

    CSS(
        ".llm-chat-stop-button:active:not(:disabled)",
        "transform" => "scale(0.98)"
    ),

    CSS(
        ".llm-chat-stop-button:disabled",
        "opacity" => "0.3",
        "cursor" => "not-allowed"
    ),

    # Streaming indicator - improved animation
    CSS(
        ".llm-chat-streaming",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "6px",
        "color" => "var(--text-secondary)",
        "font-size" => "12px",
        "padding" => "6px 10px",
        "margin" => "4px 0 6px 0",
        "background-color" => "var(--hover-bg)",
        "border-radius" => "4px",
        "width" => "fit-content"
    ),

    CSS(
        ".llm-chat-streaming-dot",
        "width" => "8px",
        "height" => "8px",
        "border-radius" => "50%",
        "background-color" => "var(--accent-blue)",
        "animation" => "pulse 1.4s ease-in-out infinite"
    ),

    CSS(
        ".llm-chat-streaming-dot:nth-child(1)",
        "animation-delay" => "0s"
    ),

    CSS(
        ".llm-chat-streaming-dot:nth-child(2)",
        "animation-delay" => "0.2s"
    ),

    CSS(
        ".llm-chat-streaming-dot:nth-child(3)",
        "animation-delay" => "0.4s"
    ),

    # Tool result highlighting - improved colors
    CSS(
        ".tool-result-success",
        "border-left" => "4px solid #4caf50",
        "background-color" => "rgba(76, 175, 80, 0.05)"
    ),

    CSS(
        ".tool-result-error",
        "border-left" => "4px solid #f44336",
        "background-color" => "rgba(244, 67, 54, 0.05)"
    ),

    # Code blocks in messages
    CSS(
        ".cell-output pre",
        "background-color" => "rgba(0, 0, 0, 0.05)",
        "border-radius" => "4px",
        "padding" => "8px 10px",
        "overflow-x" => "auto",
        "margin" => "6px 0",
        "font-size" => "14px"
    ),

    CSS(
        ".cell-output code",
        "font-family" => "monospace",
        "font-size" => "14px"
    ),

    # Scroll to bottom hint - improved design
    CSS(
        ".llm-chat-scroll-hint",
        "position" => "fixed",
        "bottom" => "80px",
        "right" => "20px",
        "background" => "var(--accent-blue)",
        "color" => "white",
        "border-radius" => "4px",
        "padding" => "8px 14px",
        "font-size" => "13px",
        "font-weight" => "500",
        "cursor" => "pointer",
        "box-shadow" => "0 2px 8px rgba(33, 150, 243, 0.3)",
        "transition" => "all 0.3s ease",
        "z-index" => "999",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "6px"
    ),

    CSS(
        ".llm-chat-scroll-hint:hover",
        "transform" => "translateY(-3px)",
        "box-shadow" => "0 6px 20px rgba(33, 150, 243, 0.4)"
    ),

    CSS(
        ".llm-chat-scroll-hint.hidden",
        "opacity" => "0",
        "transform" => "translateY(10px)",
        "pointer-events" => "none"
    ),

    # Animations
    CSS(
        "@keyframes pulse",
        "0%, 100%" => Dict("opacity" => "0.3", "transform" => "scale(0.8)"),
        "50%" => Dict("opacity" => "1", "transform" => "scale(1)")
    ),

    CSS(
        "@keyframes slideInRight",
        "from" => Dict("opacity" => "0", "transform" => "translateX(20px)"),
        "to" => Dict("opacity" => "1", "transform" => "translateX(0)")
    ),

    CSS(
        "@keyframes slideInLeft",
        "from" => Dict("opacity" => "0", "transform" => "translateX(-20px)"),
        "to" => Dict("opacity" => "1", "transform" => "translateX(0)")
    ),

    # Tool cell styling
    CSS(
        ".cell-from-tool",
        "margin-left" => "0",
        "margin-right" => "auto",
        "max-width" => "85%",
        "margin-bottom" => "12px"
    ),

    # Tool rendering styles
    CSS(
        ".tool-container",
        "margin" => "6px 0"
    ),

    CSS(
        ".tool-header",
        "display" => "flex",
        "align-items" => "center",
        "margin-bottom" => "6px",
        "gap" => "6px"
    ),

    CSS(
        ".tool-icon",
        "font-size" => "16px"
    ),

    CSS(
        ".tool-path",
        "background" => "var(--hover-bg)",
        "padding" => "2px 6px",
        "border-radius" => "3px",
        "font-size" => "0.9em",
        "color" => "var(--accent-blue)",
        "font-family" => "monospace",
        "word-break" => "break-all"
    ),

    CSS(
        ".tool-command",
        "background" => "var(--hover-bg)",
        "padding" => "2px 6px",
        "border-radius" => "3px",
        "font-size" => "0.9em",
        "font-family" => "monospace"
    ),

    CSS(
        ".tool-url",
        "color" => "var(--accent-blue)",
        "text-decoration" => "none",
        "font-size" => "0.9em"
    ),

    CSS(
        ".tool-url:hover",
        "text-decoration" => "underline"
    ),

    CSS(
        ".tool-output",
        "background-color" => "var(--hover-bg)",
        "padding" => "6px 8px",
        "border-radius" => "4px",
        "font-family" => "'Fira Code', 'Consolas', monospace",
        "font-size" => "11px",
        "margin" => "0",
        "overflow-x" => "auto",
        "max-height" => "250px",
        "overflow-y" => "auto",
        "white-space" => "pre-wrap",
        "word-wrap" => "break-word",
        "line-height" => "1.3"
    ),

    CSS(
        ".tool-output-success",
        "border-left" => "3px solid var(--accent-blue)",
        "color" => "var(--text-primary)"
    ),

    CSS(
        ".tool-output-error",
        "border-left" => "3px solid #d32f2f",
        "color" => "#d32f2f"
    ),

    CSS(
        ".tool-info",
        "color" => "#4caf50",
        "font-size" => "0.9em",
        "margin-top" => "4px"
    ),

    CSS(
        ".tool-error",
        "color" => "#d32f2f",
        "font-size" => "0.9em"
    ),

    CSS(
        ".tool-status",
        "font-size" => "0.85em",
        "color" => "var(--text-secondary)",
        "margin-bottom" => "8px"
    ),

    CSS(
        ".tool-executing",
        "color" => "var(--text-secondary)",
        "font-size" => "0.9em",
        "font-style" => "italic"
    ),

    CSS(
        ".todo-container",
        "background-color" => "var(--hover-bg)",
        "padding" => "6px 8px",
        "border-radius" => "4px",
        "border-left" => "3px solid var(--accent-blue)",
        "margin" => "6px 0"
    ),

    CSS(
        ".todo-title",
        "font-weight" => "600",
        "color" => "var(--accent-blue)",
        "margin-bottom" => "6px",
        "font-size" => "13px",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "6px"
    ),

    CSS(
        ".todo-items",
        "margin-left" => "12px"
    ),

    CSS(
        ".todo-item",
        "display" => "flex",
        "align-items" => "start",
        "margin-bottom" => "6px",
        "padding" => "4px",
        "gap" => "8px"
    ),

    CSS(
        ".todo-checkbox",
        "color" => "var(--text-secondary)"
    ),

    CSS(
        ".todo-text",
        "color" => "var(--text-primary)"
    ),

    # Spinner container styling - horizontal row, centered
    CSS(
        ".llm-chat-spinners",
        "display" => "flex",
        "flex-direction" => "row",
        "gap" => "12px",
        "align-items" => "center",
        "justify-content" => "center",
        "min-height" => "20px",
        "padding" => "4px 0"
    ),

    # Responsive adjustments for mobile
    CSS(
        "@media (max-width: 768px)",
        CSS(
            ".cell-from-user, .cell-from-agent",
            "max-width" => "90%"
        ),
        CSS(
            ".cell-from-tool",
            "max-width" => "95%"
        ),
        CSS(
            ".llm-chat-messages",
            "padding" => "16px",
            "padding-bottom" => "140px"
        ),
        CSS(
            ".llm-chat-input-container",
            "padding" => "12px 16px 16px"
        ),
        CSS(
            ".llm-chat-send-button, .llm-chat-stop-button",
            "width" => "44px",
            "height" => "44px",
            "font-size" => "18px"
        ),
        CSS(
            ".llm-chat-input",
            "font-size" => "14px",
            "padding" => "10px 16px",
            "max-height" => "150px"
        ),
        CSS(
            ".tool-output",
            "font-size" => "10px",
            "max-height" => "300px"
        )
    )
)
