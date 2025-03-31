# Define reusable variables
editor_width = "90ch"
max_height_large = "80vh"
max_height_medium = "60vh"
border_radius_small = "3px"
border_radius_large = "10px"
box_shadow_soft = "0 4px 8px rgba(0.0, 0.0, 51.0, 0.2)"
transition_fast = "0.1s ease-out"
transition_slow = "0.2s ease-in"
font_family_clean = "'Inter', 'Roboto', 'Arial', sans-serif"

Makie.set_theme!(size = (650, 450))
BonitoBook.monaco_theme!("default")
editor_width = "90ch"
Styles(
    # Fix for Markdown list
    CSS("li p", "display" => "inline"),
    CSS(
        "mjx-container[jax='CHTML'][display='true']",
        "display" => "inline"
    ),
    CSS(
        "@media print",
        CSS(
            "*",
            "-webkit-print-color-adjust" => "exact !important",
            "print-color-adjust" => "exact !important",
            "color-adjust" => "exact !important",
            "filter" => "none !important"
        )
    ),
    # Monaco Widgets (find/command palette)
    CSS(
        ".quick-input-widget",
        "position" => "fixed !important",
        "top" => "10px !important",
    ),
    CSS(
        ".find-widget",
        "position" => "fixed !important",
        "top" => "10px !important",
    ),
    CSS(
        ".monaco-list",
        # Prevents list from being cut off
        "max-height" => max_height_medium,
        # Enables scrolling for long lists
        "overflow-y" => "auto !important"
    ),
    # The editor div
    CSS(
        ".cell-editor-container",
        "width" => editor_width,
        "position" => "relative"
    ),
    CSS(
        ".cell-menu-proximity-area",
        "position" => "absolute",
        "top" => "-20px", # span an area of 20px above the cell
        "left" => "0px",
        "height" => "20px",
        "width" => "100%",
        "background-color" => "transparent",  # Invisible
        "pointer-events" => "auto",  # Ensure it can detect mouse events
        "z-index" => "-1" # don't cover e.g. editor
    ),
    CSS(
        ".cell-editor",
        "width" => editor_width,
        "position" => "relative",
        "display" => "inline-block",
        "padding" => "5px 5px 10px 10px",
        "border-radius" => border_radius_large,
        "box-shadow" => box_shadow_soft,
    ),
    CSS(
        ".monaco-editor-div",
        "background-color" => "transparent",
        "padding" => "0px",
        "margin" => "0px",
    ),
    # AI
    CSS(
        ".chat.monaco-editor-div",
        "border-radius" => border_radius_small,
        "border" => "1px solid #ccc",
        "padding" => "5px",
        "margin" => "5px",
        "overflow" => "hidden",
    ),
    # The logging output (io/stdout/etc)
    CSS(
        ".cell-logging",
        "max-height" => "500px",
        "max-width" => editor_width,
        "overflow-y" => "auto",
        "margin" => "0",
        "padding" => "0",
    ),

    CSS(
        ".hover-buttons",
        "position" => "absolute",
        "right" => "-10px",
        "top" => "-23px",
        "z-index" => 1000,
        "opacity" => 0.0,
        # Prevent flickering when hovering over buttons
        "pointer-events" => "auto",
    ),

    CSS(
        ".cell-output",
        "width" => "100%",
        "margin" => "5px",
        "max-height" => "700px",
        "overflow-y" => "auto",
        "overflow-x" => "visible",
    ),

    CSS(
        ".hide-vertical",
        "display" => "none",
    ),
    CSS(
        ".show-vertical",
        "display" => "block",
    ),
    CSS(
        ".hide-horizontal",
        "display" => "none"
    ),
    CSS(
        ".show-horizontal",
        "display" => "block",
    ),
    CSS(
        ".loading-cell",
        "background" => "rgba(255, 255, 255, 1)",
        "box-shadow" => "0 0 5px rgba(0, 0, 0, 0.1)",
        "animation" => "background-fade 1.5s ease-in-out infinite, shadow-pulse 1.5s ease-in-out infinite",
    ),
    CSS(
        "@keyframes background-fade",
        CSS("0%", "background" => "rgba(255, 255, 255, 1)"),
        CSS("100%", "background" => "rgba(250, 250, 250, 1)"),
    ),
    CSS(
        "@keyframes shadow-pulse",
        CSS("0%", "box-shadow" => "0 0 5px rgba(0, 0, 0, 0.1)"),
        CSS("50%", "box-shadow" => "0 0 15px rgba(0, 0, 0, 0.3)"),
        CSS("100%", "box-shadow" => "0 0 5px rgba(0, 0, 0, 0.1)"),
    ),
    CSS(
        ".julia-dots",
        "background-image" => BonitoBook.assets("julia-dots.svg"),
        "background-size" => "60% auto",
        "background-repeat" => "no-repeat",
        "background-position" => "center",
        "width" => "1.2rem",
        "height" => "1.2rem",
    ),
    CSS(
        ".python-logo",
        "background-image" => BonitoBook.assets("python.svg"),
        "background-size" => "60% auto",
        "background-repeat" => "no-repeat",
        "background-position" => "center",
        "width" => "1.2rem",
        "height" => "1.2rem",
    ),
    # Menu and Buttons

    CSS(
        ".small-menu-bar",
        "z-index" => "1001",
        "background-color" => "white",
        "border" => "1px solid rgba(0, 0, 0, 0.1)",  # Soft outline
        "border-radius" => "8px",  # Rounded corners for a smoother look
        "box-shadow" => "0px 4px 10px rgba(0, 0, 0, 0.15)",  # Soft shadow
        "padding" => "4px",  # Adds spacing inside
    ),
    CSS(
        ".small-button.toggled",
        "color" => "#000",
        "border" => "none",
        "filter" => "grayscale(100%)",
        "opacity" => "0.5",
        "box-shadow" => "inset 2px 2px 5px rgba(0, 0, 0, 0.5)",
    ),
    CSS(
        ".small-button",
        "background-color" => "transparent",
        "border" => "none",
        "border-radius" => "100px",
        "color" => "#555",
        "cursor" => "pointer",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.2)",
        "transition" => "background-color 0.2s",
    ),
    CSS(
        ".small-button:hover",
        "background-color" => "#ddd",
    ),

    CSS(
        ".file-editor-path",
        "font-family" => font_family_clean,  # Clean, modern font
        "font-size" => "14px",  # Slightly smaller for paths
        "font-weight" => "500",  # Medium weight
        "color" => "#555",  # Softer than blackmonaco-editor-div
        "letter-spacing" => "0.3px",  # Subtle spacing
        "padding" => "5px 10px",  # Adds space around text
        "margin" => "1px",
        "width" => "fit-content",
        "border-radius" => "6px",  # Soft rounded corners
        "border" => "1px solid rgba(0, 0, 0, 0.1)",  # Light border
        "box-shadow" => "0px 2px 5px rgba(0, 0, 0, 0.1)",  # Soft shadow
        "white-space" => "nowrap",  # Prevents wrapping
        "overflow" => "hidden",  # Hides overflow
        "text-overflow" => "ellipsis",  # Adds "..." if the path is too long
    ),
    CSS(
        ".file-editor",
        "padding" => "0px",
        "margin" => "0px",
        "width" => editor_width,
        "max-height" => max_height_large,
    ),
    # Utility
    CSS(
        ".flex-row",
        "display" => "flex",
        "flex-direction" => "row"
    ),
    CSS(
        ".flex-column",
        "display" => "flex",
        "flex-direction" => "column"
    ),
    CSS(
        ".center-content",
        "justify-content" => "center",
        "align-items" => "center"
    ),
    CSS(
        ".inline-block",
        "display" => "inline-block"
    ),
    CSS(
        ".fit-content",
        "width" => "fit-content"
    ),
    CSS(
        ".max-width-90ch",
        "max-width" => "90ch"
    ),
    CSS(
        ".gap-10",
        "gap" => "10px"
    ),
    CSS(
        ".full-width",
        "width" => "100%"
    ),
    # Markdown
    CSS(
        ".markdown-body",
        "-ms-text-size-adjust" => "100%",
        "-webkit-text-size-adjust" => "100%",
        "color" => "#24292e",
        "line-height" => "1.5",
        "font-family" => "-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol",
        "font-size" => "16px",
        "word-wrap" => "break-word"
    ),
    CSS(
        ".markdown-body .octicon",
        "display" => "inline-block",
        "fill" => "currentColor",
        "vertical-align" => "text-bottom"
    ),
    CSS(
        ".markdown-body .anchor",
        "float" => "left",
        "line-height" => "1",
        "margin-left" => "-20px",
        "padding-right" => "4px"
    ),
    CSS(".markdown-body .anchor:focus", "outline" => "none"),
    CSS(
        ".markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6",
        "margin-bottom" => "0", "margin-top" => "0"
    ),
    CSS(".markdown-body h1", "font-size" => "32px", "font-weight" => "600"),
    CSS(".markdown-body h2", "font-size" => "24px", "font-weight" => "600"),
    CSS(".markdown-body h3", "font-size" => "20px", "font-weight" => "600"),
    CSS(".markdown-body h4", "font-size" => "16px", "font-weight" => "600"),
    CSS(".markdown-body h5", "font-size" => "14px", "font-weight" => "600"),
    CSS(".markdown-body h6", "font-size" => "12px", "font-weight" => "600"),
    CSS(".markdown-body a", "color" => "#0366d6", "text-decoration" => "none"),
    CSS(".markdown-body a:hover", "text-decoration" => "underline"),
    CSS(".markdown-body strong", "font-weight" => "600"),
    CSS(
        ".markdown-body hr",
        "background" => "transparent",
        "border" => "0",
        "border-bottom" => "1px solid #dfe2e5",
        "height" => "0",
        "margin" => "15px 0",
        "overflow" => "hidden"
    ),
    CSS(
        ".markdown-body table",
        "border-collapse" => "collapse",
        "border-spacing" => "0"
    ),
    CSS(".markdown-body td, .markdown-body th", "padding" => "0"),
    CSS(
        ".markdown-body blockquote",
        "border-left" => ".25em solid #dfe2e5",
        "color" => "#6a737d",
        "padding" => "0 1em"
    ),
    CSS(
        ".markdown-body code, .markdown-body pre",
        "font-family" => "SFMono-Regular,Consolas,Liberation Mono,Menlo,Courier,monospace",
        "font-size" => "12px"
    ),
    CSS(".markdown-body pre", "margin-bottom" => "0", "margin-top" => "0"),
    CSS(".markdown-body img", "border-style" => "none"),
    CSS(".markdown-body input", "font" => "inherit", "overflow" => "visible"),
    CSS(".markdown-body *", "box-sizing" => "border-box"),
    # New Cell Menu
    CSS(
        ".new-cell-menu",
        "width" => "100%",
        "overflow" => "hidden",
        "height" => "1.3rem",
        "background-color" => "transparent",  # Initial background color
        "transition" => "height 0.2s",
    ),
    CSS(
        ".new-cell-menu:hover",
        "height" => "2.5rem",  # Expand to fit buttons
        "transition-delay" => "0.5s",
        "background-color" => "#f0f0f0",  # Or any color you want
    ),
    CSS(
        ".new-cell-menu > *",  # Target direct children
        "opacity" => "0",
        "transition" => "opacity 0.2s",
    ),
    CSS(
        ".new-cell-menu:hover > *",  # Target direct children on hover
        "opacity" => "1",
        "transition-delay" => "0.5s",
    )
)
