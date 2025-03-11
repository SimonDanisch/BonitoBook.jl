Styles(
    # Fix for Markdown list
    CSS("li p", "display" => "inline"),
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
        "max-height" => "60vh !important",
        # Enables scrolling for long lists
        "overflow-y" => "auto !important"
    ),


    # The editor div
    CSS(
        ".editor-container",
        "width" => "80ch",
        "position" => "relative",
        "display" => "inline-block",
        "padding" => "10px",
        "margin" => "10px",
        "border-radius" => "10px",
        "box-shadow" => "0 4px 8px rgba(0.0, 0.0, 51.0, 0.2)",
    ),
    CSS(
        ".monaco-editor-div",
        "background-color" => "transparent",
        "padding" => "0px",
        "margin" => "0px",
    ),
    # AI
    CSS(".chat.monaco-editor-div",
        "border-radius" => "1px",
        "border" => "1px solid #ccc",
        "padding" => "2px",
    ),
    # The logging output (io/stdout/etc)
    CSS(
        ".logging-pre",
        "opacity" => "0",
        "max-height" => "0",
        "overflow" => "hidden",
        "margin" => "0",
        "padding" => "0",
        # Avoid invisible whitespace
        "line-height" => "0",
        "transition" => "opacity 2s ease, max-height 2s ease",
        "display" => "none"
    ),
    # The logging output (io/stdout/etc) when shown
    CSS(
        ".logging-pre.show",
        "opacity" => "1",
        "max-height" => "500px",
        "line-height" => "inherit",
        "display" => "block"
    ),

    CSS(".hover-buttons",
        "position" => "absolute",
        "right" => "10px",
        "top" => "0px",
        "z-index" => 1000,
        "opacity" => 0.0,
        # Prevent flickering when hovering over buttons
        "pointer-events" => "none",
    ),

    CSS(".cell-output",
        "padding" => "10px 0px 0px 10px",
    ),

    CSS(".cell-output",
        "width" => "100%",
    ),

    # Menu at top
    CSS(".small-menu-bar",
        "border" => "1px solid rgba(0, 0, 0, 0.1)",  # Soft outline
        "border-radius" => "8px",  # Rounded corners for a smoother look
        "box-shadow" => "0px 4px 10px rgba(0, 0, 0, 0.15)",  # Soft shadow
        "padding" => "5px",  # Adds spacing inside
        "background" => "white"  # Ensures it's visible on different backgrounds
    ),

    CSS(".hide-vertical",
        "opacity" => "0",
        "padding" => "0px",
        "margin" => "0px",
        "height" => "0px",  # Start collapsed horizontally
        "max-height" => "0",  # Start collapsed
        "overflow" => "hidden",  # Hide overflow content
        "transition" => "max-height 0.1s ease-out"  # Transition for max-height
    ),
    CSS(".show-vertical",
        "max-height" => "1000px",  # Or any large value larger than the element's height
        "transition" => "max-height 0.1s ease-in"  # Transition for max-height
    ),
    CSS(".hide-horizontal",
        "opacity" => "0",
        "padding" => "0px",
        "margin" => "0px",
        "width" => "0px",  # Start collapsed horizontally
        "max-width" => "0px",  # Start collapsed horizontally
        "overflow" => "hidden",  # Hide overflow content
        "transition" => "max-width 0.1s ease-out",  # Transition for max-width
        "border-radius" => "0px",
    ),
    CSS(".show-horizontal",
        "max-width" => "1000px",  # Or any large value larger than the element's width
        "transition" => "max-width 0.1s ease-in"  # Transition for max-width
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
    CSS(".julia-dots",
        "background-image" => BonitoBook.assets("julia-dots.svg"),
        "background-size" => "60% auto",
        "background-repeat" => "no-repeat",
        "background-position" => "center",
        "padding-top" => "0.1rem",
        "padding-bottom" => "0.1rem",
        "width" => "1.2rem",
        "height" => "1.2rem",
    ),
    CSS(".small-button",
        "font-weight" => 600,
        "background-color" => "transparent",
        "font-size" => "1rem",
        "min-width" => "1.5rem",
        "padding-left" => "0.3rem",
        "padding-right" => "0.3rem",
        "padding-top" => "0.1rem",
        "padding-bottom" => "0.1rem",
        "border" => "none",
        "border-radius" => "100px",
        "color" => "#777",
        "cursor" => "pointer",
        "margin" => "0.25rem",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.2)",
        "transition" => "background-color 0.2s",
    ),
    CSS(
        ".small-button:hover",
        "background-color" => "#ddd",
    ),
    CSS(".toggled",
        "color" => "#000",
        "border" => "none",
        "filter" => "grayscale(100%)",
        "opacity" => "0.5",
        "box-shadow" => "inset 2px 2px 5px rgba(0, 0, 0, 0.5)",
    ),
    CSS(".file-editor-path",
        "font-family" => "'Inter', 'Roboto', 'Arial', sans-serif",  # Clean, modern font
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
    CSS(".file-editor",
        "padding" => "0px",
        "margin" => "0px",
        "width" => "90ch",
        "max-height" => "80vh",
    ),
)
