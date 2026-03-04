"""
Styles for the LLM Chat plugin.
"""

"""
    generate_style(book; kwargs...)

Generate complete styles for LLM Chat books, merging base BonitoBook styles with chat-specific styles.

This function calls `BonitoBook.generate_style` and adds LLM chat-specific styling on top.
All BonitoBook style parameters can be passed through.

# Example
```julia
style = LLMChatBooks.generate_style(current_book(),
    light_theme = nothing,  # Auto-detect theme
    editor_width = "90ch"   # Any BonitoBook style parameter
)
```
"""
function generate_style(book; kwargs...)
    # Get base BonitoBook styles with all customizations
    base_styles = BonitoBook.generate_style(book; kwargs...)

    # Merge with chat-specific styles (spinner styles + chat styles)
    return Bonito.Styles(base_styles, LLMSpinnerStyles, ChatStyles)
end

# Spinner styles with CSS animation using proper nested CSS() pattern
const LLMSpinnerStyles = Bonito.Styles(
    Bonito.CSS(
        ".llm-spinner-hidden",
        "display" => "none"
    ),
    Bonito.CSS(
        ".llm-spinner-active",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "6px",
        "animation" => "fadeIn 0.3s ease-in",
        "opacity" => "1"
    ),
    Bonito.CSS(
        ".llm-spinner-dot",
        "width" => "8px",
        "height" => "8px",
        "border-radius" => "50%",
        "background-color" => "var(--accent-blue, #0366d6)",
        "animation" => "spinnerPulse 1.4s ease-in-out infinite",
        "will-change" => "opacity, transform"
    ),
    Bonito.CSS(
        ".llm-spinner-dot:nth-child(1)",
        "animation-delay" => "0s"
    ),
    Bonito.CSS(
        ".llm-spinner-dot:nth-child(2)",
        "animation-delay" => "0.2s"
    ),
    Bonito.CSS(
        ".llm-spinner-dot:nth-child(3)",
        "animation-delay" => "0.4s"
    ),
    Bonito.CSS(
        ".llm-spinner-text",
        "margin-left" => "6px",
        "font-size" => "13px",
        "color" => "var(--text-secondary)",
        "font-weight" => "500"
    ),
    # Keyframe animations using proper nested CSS() pattern
    Bonito.CSS(
        "@keyframes spinnerPulse",
        Bonito.CSS("0%, 100%", "opacity" => "0.3", "transform" => "scale(0.8)"),
        Bonito.CSS("50%", "opacity" => "1", "transform" => "scale(1.3)")
    ),
    Bonito.CSS(
        "@keyframes fadeIn",
        Bonito.CSS("from", "opacity" => "0"),
        Bonito.CSS("to", "opacity" => "1")
    )
)

const ChatStyles = Bonito.Styles(
    # Split layout styles
    CSS(
        ".llm-chat-split-layout",
        "display" => "flex",
        "flex-direction" => "row",
        "height" => "100vh",
        "width" => "100%",
        "overflow" => "hidden"
    ),

    CSS(
        ".llm-chat-left-panel",
        "flex" => "1 1 auto",
        "min-width" => "0",
        "display" => "flex",
        "flex-direction" => "column",
        "overflow" => "hidden"
    ),

    CSS(
        ".llm-chat-right-panel",
        "flex" => "0 0 40%",
        "min-width" => "300px",
        "border-left" => "1px solid var(--border-secondary)",
        "overflow" => "hidden",
        "display" => "flex",
        "flex-direction" => "column"
    ),

    # File editor collapse button at panel border
    CSS(
        ".file-editor-collapse-btn",
        "position" => "fixed",
        "right" => "calc(40% - 10px)",  # Positioned at the border between panels (40% panel width - half button)
        "top" => "50vh",
        "transform" => "translateY(-50%)",
        "z-index" => "100",
        "width" => "20px",
        "height" => "60px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "background" => "var(--bg-secondary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "4px 0 0 4px",
        "border-right" => "none",
        "cursor" => "pointer",
        "font-size" => "0.9rem",
        "color" => "var(--text-secondary)",
        "transition" => "all 0.2s ease",
        "user-select" => "none",
        "box-shadow" => "-2px 0 4px rgba(0,0,0,0.1)"
    ),

    CSS(
        ".file-editor-collapse-btn:hover",
        "background" => "var(--bg-tertiary)",
        "color" => "var(--text-primary)",
        "width" => "24px",
        "box-shadow" => "-3px 0 6px rgba(0,0,0,0.15)"
    ),

    # Tool open button
    CSS(
        ".tool-open-btn",
        "padding" => "4px 8px",
        "margin-left" => "8px",
        "background" => "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
        "color" => "white",
        "border" => "none",
        "border-radius" => "4px",
        "cursor" => "pointer",
        "font-size" => "0.85rem",
        "transition" => "all 0.2s ease"
    ),

    CSS(
        ".tool-open-btn:hover",
        "transform" => "translateY(-1px)",
        "box-shadow" => "0 2px 4px rgba(0,0,0,0.2)"
    ),

    # Chat container - fills viewport and handles scrolling
    CSS(
        ".llm-chat-container",
        "display" => "flex",
        "flex-direction" => "column",
        "height" => "100vh",
        "overflow-y" => "auto",
        "overflow-x" => "hidden",
        "background-color" => "var(--bg-primary)",
        "position" => "relative",
        "scroll-behavior" => "smooth",
        "scrollbar-width" => "thin",
        "scrollbar-color" => "rgba(0, 0, 0, 0.2) transparent"
    ),

    # Webkit scrollbar styling for container
    CSS(
        ".llm-chat-container::-webkit-scrollbar",
        "width" => "8px"
    ),

    CSS(
        ".llm-chat-container::-webkit-scrollbar-track",
        "background" => "transparent"
    ),

    CSS(
        ".llm-chat-container::-webkit-scrollbar-thumb",
        "background-color" => "rgba(0, 0, 0, 0.2)",
        "border-radius" => "4px",
        "transition" => "background-color 0.2s ease"
    ),

    CSS(
        ".llm-chat-container::-webkit-scrollbar-thumb:hover",
        "background-color" => "rgba(0, 0, 0, 0.3)"
    ),

    # Messages area - centered layout (no scrolling here)
    CSS(
        ".llm-chat-messages",
        "flex" => "0 0 auto",
        "padding" => "2rem 1rem",
        "padding-bottom" => "1rem",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "stretch",
        "width" => "100%",
        "max-width" => "1400px",  # increased max width to render messages wider on large screens
        "margin" => "0 auto",
        "gap" => "0.75rem",
        "box-sizing" => "border-box"
    ),

    # User cell styling - message bubbles on the right
    CSS(
        ".cell-from-user",
        "display" => "flex",
        "justify-content" => "flex-end",
        "width" => "100%",
        "margin-bottom" => "0",
        "animation" => "slideInRight 0.3s ease-out"
    ),

    CSS(
        ".cell-from-user .cell-output",
        "background" => "var(--accent-blue)",
        "color" => "white",
        "border-radius" => "12px 12px 2px 12px",
        "padding" => "8px 14px",
        "margin" => "0",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)",
        "word-wrap" => "break-word",
        "overflow-wrap" => "anywhere",
        "line-height" => "1.5",
        "text-align" => "left",
        "max-width" => "85%",
        "font-size" => "14px",
        "transition" => "box-shadow 0.2s ease",
        "max-height" => "60vh",
        "overflow" => "auto",
        "position" => "relative",
        "z-index" => "1"
    ),

    CSS(
        ".cell-from-user .cell-output:hover",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.15)"
    ),

    # Agent cell styling - clean text bubbles on the left
    CSS(
        ".cell-from-agent",
        "display" => "flex",
        "justify-content" => "flex-start",
        "width" => "100%",
        "margin-bottom" => "0",
        "animation" => "slideInLeft 0.3s ease-out"
    ),

    CSS(
        ".cell-from-agent .cell-output",
        "border-radius" => "5px 5px 5px 1px",
        "margin" => "0",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.05)",
        "word-wrap" => "break-word",
        "overflow-wrap" => "anywhere",
        "line-height" => "1.5",
        "max-width" => "85%",
        "font-size" => "14px",
        "transition" => "box-shadow 0.2s ease",
        "overflow" => "auto",
        "position" => "relative",
        "z-index" => "1"
    ),

    CSS(
        ".cell-from-agent .cell-output:hover",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.08)"
    ),

    # Ensure proper spacing for visible editors in chat cells
    CSS(
        ".llm-chat-messages .cell-editor",
        "margin-top" => "0.5rem"
    ),

    # Fixed chat input at bottom - improved design
    CSS(
        ".llm-chat-input-container",
        "position" => "sticky",
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
        "box-shadow" => "0 -1px 3px rgba(0, 0, 0, 0.03)",
        "margin-top" => "auto"
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
        "font-size" => "14px",
        "max-height" => "50vh",
        "overflow" => "auto",
        "box-shadow" => "inset 0 1px 0 rgba(0,0,0,0.02)"
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

    # Animations using proper nested CSS() pattern
    CSS(
        "@keyframes pulse",
        CSS("0%, 100%", "opacity" => "0.3", "transform" => "scale(0.8)"),
        CSS("50%", "opacity" => "1", "transform" => "scale(1)")
    ),

    CSS(
        "@keyframes slideInRight",
        CSS("from", "opacity" => "0", "transform" => "translateX(20px)"),
        CSS("to", "opacity" => "1", "transform" => "translateX(0)")
    ),

    CSS(
        "@keyframes slideInLeft",
        CSS("from", "opacity" => "0", "transform" => "translateX(-20px)"),
        CSS("to", "opacity" => "1", "transform" => "translateX(0)")
    ),

    # Tool cell styling - gray cards with blue left stroke
    CSS(
        ".cell-from-tool",
        "display" => "flex",
        "justify-content" => "flex-start",
        "width" => "100%",
        "margin-bottom" => "0"
    ),

    CSS(
        ".cell-from-tool .cell-output",
        "max-width" => "90%",
        "font-size" => "13px",
        "background-color" => "var(--hover-bg)",
        "border-left" => "3px solid var(--accent-blue)",
        "border-radius" => "4px",
        "padding" => "6px 10px",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.05)"
    ),

    # Hide new-cell-menu in chat interface
    CSS(
        ".llm-chat-messages .new-cell-menu",
        "display" => "none"
    ),

    # Ensure cell output doesn't overflow
    CSS(
        ".llm-chat-messages .cell-output",
        "position" => "relative",
        "overflow" => "visible"
    ),

    # Tool rendering styles
    CSS(
        ".tool-container",
        "margin" => "8px 0",
        "background" => "var(--hover-bg)",
        "border-radius" => "8px",
        "padding" => "10px 12px",
        "border" => "1px solid var(--border-secondary)",
        "box-shadow" => "0 1px 3px rgba(0, 0, 0, 0.05)"
    ),

    CSS(
        ".tool-header",
        "display" => "flex",
        "align-items" => "center",
        "margin-bottom" => "8px",
        "gap" => "8px",
        "flex-wrap" => "wrap"
    ),

    CSS(
        ".tool-name",
        "font-weight" => "600",
        "color" => "var(--accent-blue)",
        "font-size" => "13px",
        "text-transform" => "uppercase",
        "letter-spacing" => "0.5px"
    ),

    CSS(
        ".tool-args",
        "background" => "rgba(0, 0, 0, 0.05)",
        "padding" => "3px 8px",
        "border-radius" => "4px",
        "font-size" => "12px",
        "font-family" => "'Fira Code', 'Consolas', monospace",
        "word-break" => "break-all",
        "flex" => "1",
        "min-width" => "0"
    ),

    CSS(
        ".tool-info",
        "color" => "var(--text-secondary)",
        "font-size" => "12px",
        "margin-left" => "auto",
        "white-space" => "nowrap"
    ),

    CSS(
        ".tool-icon",
        "font-size" => "16px"
    ),

    CSS(
        ".tool-path",
        "background" => "rgba(0, 0, 0, 0.05)",
        "padding" => "3px 8px",
        "border-radius" => "4px",
        "font-size" => "12px",
        "color" => "var(--accent-blue)",
        "font-family" => "'Fira Code', 'Consolas', monospace",
        "word-break" => "break-all"
    ),

    CSS(
        ".tool-command",
        "background" => "rgba(0, 0, 0, 0.05)",
        "padding" => "3px 8px",
        "border-radius" => "4px",
        "font-size" => "12px",
        "font-family" => "'Fira Code', 'Consolas', monospace"
    ),

    CSS(
        ".tool-url",
        "color" => "var(--accent-blue)",
        "text-decoration" => "none",
        "font-size" => "12px",
        "transition" => "color 0.2s ease"
    ),

    CSS(
        ".tool-url:hover",
        "text-decoration" => "underline",
        "color" => "#024a99"
    ),

    CSS(
        ".tool-output",
        "background-color" => "rgba(0, 0, 0, 0.03)",
        "padding" => "10px 12px",
        "border-radius" => "6px",
        "font-family" => "'Fira Code', 'Consolas', 'Monaco', monospace",
        "font-size" => "12px",
        "margin" => "0",
        "overflow-x" => "auto",
        "max-height" => "300px",
        "overflow-y" => "auto",
        "white-space" => "pre-wrap",
        "word-wrap" => "break-word",
        "line-height" => "1.5",
        "border" => "1px solid var(--border-secondary)"
    ),

    CSS(
        ".tool-output-success",
        "border-left" => "3px solid #4caf50",
        "color" => "var(--text-primary)"
    ),

    CSS(
        ".tool-output-error",
        "border-left" => "3px solid #ef5350",
        "color" => "#d32f2f"
    ),

    CSS(
        ".tool-error",
        "color" => "#ef5350",
        "font-size" => "13px",
        "padding" => "8px 12px",
        "background" => "rgba(239, 83, 80, 0.1)",
        "border-radius" => "6px",
        "margin-top" => "6px",
        "font-family" => "monospace"
    ),

    CSS(
        ".tool-error-container",
        "border-left" => "3px solid #ef5350"
    ),

    CSS(
        ".tool-status",
        "font-size" => "12px",
        "color" => "var(--text-secondary)",
        "margin-bottom" => "6px",
        "font-style" => "italic"
    ),

    CSS(
        ".tool-executing",
        "color" => "var(--text-secondary)",
        "font-size" => "13px",
        "font-style" => "italic",
        "padding" => "6px 0"
    ),

    # Summarized tool execution styles
    CSS(
        ".tool-summarized-container",
        "border-left" => "3px solid #ff9800"
    ),

    CSS(
        ".tool-summary-badge",
        "background" => "linear-gradient(135deg, #ff9800 0%, #f57c00 100%)",
        "color" => "white",
        "padding" => "3px 8px",
        "border-radius" => "4px",
        "font-size" => "11px",
        "font-weight" => "600",
        "margin-left" => "auto",
        "white-space" => "nowrap"
    ),

    CSS(
        ".tool-summary-content",
        "max-height" => "200px",
        "border-left" => "2px solid #ff9800"
    ),

    CSS(
        ".tool-summary-toggle-container",
        "text-align" => "center",
        "margin-top" => "8px"
    ),

    CSS(
        ".tool-summary-toggle",
        "background" => "var(--accent-blue)",
        "color" => "white",
        "border" => "none",
        "padding" => "6px 16px",
        "border-radius" => "6px",
        "font-size" => "12px",
        "font-weight" => "600",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "box-shadow" => "0 2px 4px rgba(3, 102, 214, 0.2)"
    ),

    CSS(
        ".tool-summary-toggle:hover",
        "background" => "#024a99",
        "box-shadow" => "0 4px 8px rgba(3, 102, 214, 0.3)",
        "transform" => "translateY(-1px)"
    ),

    CSS(
        ".tool-summary-toggle:active",
        "transform" => "translateY(0)",
        "box-shadow" => "0 2px 4px rgba(3, 102, 214, 0.2)"
    ),

    CSS(
        ".tool-full-container",
        "margin-top" => "8px"
    ),

    CSS(
        ".tool-full-content",
        "border" => "2px solid var(--accent-blue)",
        "border-radius" => "6px",
        "max-height" => "500px"
    ),

    # File list styling
    CSS(
        ".file-list",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "4px",
        "margin-top" => "6px"
    ),

    CSS(
        ".file-item",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "8px",
        "padding" => "6px 8px",
        "background" => "rgba(0, 0, 0, 0.02)",
        "border-radius" => "4px",
        "font-family" => "'Fira Code', 'Consolas', monospace",
        "font-size" => "12px",
        "transition" => "background 0.2s ease"
    ),

    CSS(
        ".file-item:hover",
        "background" => "rgba(0, 0, 0, 0.05)"
    ),

    CSS(
        ".file-type",
        "color" => "var(--accent-blue)",
        "font-weight" => "600",
        "min-width" => "24px"
    ),

    CSS(
        ".file-name",
        "color" => "var(--text-primary)",
        "flex" => "1",
        "word-break" => "break-all"
    ),

    CSS(
        ".file-size",
        "color" => "var(--text-secondary)",
        "font-size" => "11px",
        "white-space" => "nowrap"
    ),

    CSS(
        ".file-more",
        "color" => "var(--text-secondary)",
        "font-size" => "12px",
        "padding" => "6px 8px",
        "text-align" => "center",
        "font-style" => "italic"
    ),

    # File open button styles
    CSS(
        ".file-open-container",
        "display" => "inline-block",
        "margin-left" => "auto"
    ),

    CSS(
        ".file-open-button",
        "background" => "linear-gradient(135deg, #4caf50 0%, #45a049 100%)",
        "color" => "white",
        "border" => "none",
        "padding" => "4px 10px",
        "border-radius" => "4px",
        "font-size" => "11px",
        "font-weight" => "600",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "box-shadow" => "0 2px 4px rgba(76, 175, 80, 0.2)",
        "white-space" => "nowrap"
    ),

    CSS(
        ".file-open-button:hover",
        "background" => "linear-gradient(135deg, #45a049 0%, #3d8b40 100%)",
        "box-shadow" => "0 4px 8px rgba(76, 175, 80, 0.3)",
        "transform" => "translateY(-1px)"
    ),

    CSS(
        ".file-open-button:active",
        "transform" => "translateY(0)",
        "box-shadow" => "0 2px 4px rgba(76, 175, 80, 0.2)"
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

    # Responsive adjustments for large screens
    CSS(
        "@media (min-width: 1200px)",
        CSS(
            ".cell-from-user .cell-output, .cell-from-agent .cell-output",
            "font-size" => "15px",
            "line-height" => "1.6",
            "padding" => "10px 16px"
        ),
        CSS(
            ".cell-from-tool .cell-output",
            "font-size" => "14px"
        ),
        CSS(
            ".llm-chat-input",
            "font-size" => "15px"
        ),
        CSS(
            ".tool-output",
            "font-size" => "13px"
        ),
        CSS(
            ".llm-chat-messages",
            "padding" => "2rem 1.5rem",
            "gap" => "1rem"
        )
    ),

    # Responsive adjustments for mobile
    CSS(
        "@media (max-width: 768px)",
        CSS(
            ".cell-from-user .cell-output, .cell-from-agent .cell-output",
            "max-width" => "85%",
            "font-size" => "14px",
            "padding" => "7px 12px"
        ),
        CSS(
            ".cell-from-tool .cell-output",
            "max-width" => "95%"
        ),
        CSS(
            ".llm-chat-messages",
            "padding" => "1rem 0.5rem",
            "gap" => "0.5rem"
        ),
        CSS(
            ".llm-chat-input-container",
            "padding" => "8px 12px 12px"
        ),
        CSS(
            ".llm-chat-send-button, .llm-chat-stop-button",
            "width" => "40px",
            "height" => "40px",
            "font-size" => "16px"
        ),
        CSS(
            ".llm-chat-input",
            "font-size" => "14px",
            "padding" => "10px 14px",
            "max-height" => "120px"
        ),
        CSS(
            ".tool-output",
            "font-size" => "11px",
            "max-height" => "200px"
        )
    )
)
