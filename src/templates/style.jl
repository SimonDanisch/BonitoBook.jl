const BOOK_STYLE = Styles(
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
        "max-height" => "60vh !important",  # Prevents list from being cut off
        "overflow-y" => "auto !important"  # Enables scrolling for long lists
    ),
    # The editor div
    CSS(
        ".monaco-editor-div",
        "width" => "100%",
        "max-width" => "90ch",
        "overflow" => "hidden",
        "padding" => "0px",
        "margin" => "0px"
    ),
    # The outside div around the editor_div
    CSS(".monaco-container",
        "width" => "100%",
        "max-width" => "90ch",
        "overflow" => "hidden",
        "padding" => "0px",
        "margin" => "0px",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)",
        "border-radius" => "2px",
        "padding" => "2px"
    ),
    CSS(".chat.monaco-editor-div",
        "border-radius" => "2px",
        "border" => "1px solid #ccc",
        "padding" => "2px",
    ),
    # The logging output (io/stdout/etc)
    CSS(
        ".logging-pre",
        "opacity" => "0",
        "max-height" => "0",
        "overflow" => "hidden",
        "margin" => "0",         # Remove margins that take up space
        "padding" => "0",        # Remove padding
        "line-height" => "0",    # Avoid invisible whitespace
        "transition" => "opacity 2s ease, max-height 2s ease",
        "display" => "none"
    ),
    # The logging output (io/stdout/etc) when shown
    CSS(
        ".logging-pre.show",
        "opacity" => "1",
        "max-height" => "500px", # Adjust based on content height
        "line-height" => "inherit",
        "display" => "block"
    ),
    CSS(".hover-container",
        "position" => "relative",  # Contains both buttons and card
        "display" => "inline-block",
    ),
    CSS(".hover-buttons",
        "position" => "absolute",
        "right" => "10px",
        "top" => "10px",
        "z-index" => 1000,
        "opacity" => 0.0,
        "pointer-events" => "none",  # Prevent flickering
    ),
    CSS(".editor-content",
        "overflow" => "hidden",
        "min-height" => "1ch",
        "width" => "80ch",
        "padding" => "10px",
        "margin" => "10px",
        "border-radius" => "10px",
        "box-shadow" => "0 4px 8px rgba(0.0, 0.0, 51.0, 0.2)",
    ),
    CSS(".editor-container",
        "width" => "fit-content",
        "position" => "relative",
    ),
    CSS(".cell-output",
        "padding" => "10px 0px 0px 10px",
    ),
    CSS(".file-editor",
        "width" => "80ch",
        "height" => "800px",
        "overflow" => "hidden",
        "padding" => "0px",
        "margin" => "0px",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)",
        "border-radius" => "2px",
        "padding" => "2px"
    ),
)
