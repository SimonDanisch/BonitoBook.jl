# Theme control: true = light, false = dark, nothing = auto (browser preference)
light_theme = nothing

# Define reusable variables for dimensions and transitions
editor_width = "90ch"
max_height_large = "80vh"
max_height_medium = "60vh"
border_radius_small = "3px"
border_radius_large = "10px"
transition_fast = "0.1s ease-out"
transition_slow = "0.2s ease-in"
font_family_clean = "'Inter', 'Roboto', 'Arial', sans-serif"

# Set Makie theme and Monaco editor based on system preference
Makie.set_theme!(size = (650, 450))

# Define theme media queries based on light_theme setting
light_media_query = if light_theme === nothing
    BonitoBook.monaco_theme!("default")  # Auto-detect in JS
    "@media (prefers-color-scheme: light), (prefers-color-scheme: no-preference)"
elseif light_theme === true
    BonitoBook.monaco_theme!("vs")  # Force light Monaco theme
    ""  # No media query = always apply
else
    BonitoBook.monaco_theme!("vs-dark")  # Force dark Monaco theme
    "@media (max-width: 0px)"  # Never apply
end

dark_media_query = if light_theme === nothing
    "@media (prefers-color-scheme: dark)"
elseif light_theme === false
    ""  # No media query = always apply
else
    "@media (max-width: 0px)"  # Never apply
end

Styles(
    # Light theme colors
    CSS(
        light_media_query,
        CSS(
            ":root",
            "--bg-primary" => "#ffffff",
            "--text-primary" => "#24292e",
            "--text-secondary" => "#555555",
            "--border-primary" => "rgba(0, 0, 0, 0.1)",
            "--border-secondary" => "#ccc",
            "--shadow-soft" => "0 4px 8px rgba(0, 0, 51, 0.2)",
            "--shadow-button" => "0 2px 4px rgba(0, 0, 0, 0.2)",
            "--shadow-inset" => "inset 2px 2px 5px rgba(0, 0, 0, 0.5)",
            "--hover-bg" => "#ddd",
            "--menu-hover-bg" => "rgba(0, 0, 0, 0.05)",
            "--accent-blue" => "#0366d6",
            "--animation-glow" => "0 0 20px rgba(0, 150, 51, 0.8)",
            "--icon-color" => "#666666",
            "--icon-hover-color" => "#333333",
            "--icon-filter" => "none",
            "--icon-hover-filter" => "brightness(0.7)",
        )
    ),

    # Dark theme colors
    CSS(
        dark_media_query,
        CSS(
            ":root",
            "--bg-primary" => "#1e1e1e",
            "--text-primary" => "rgb(212, 212, 212)",
            "--text-secondary" => "rgb(212, 212, 212)",
            "--border-primary" => "rgba(255, 255, 255, 0.1)",
            "--border-secondary" => "rgba(255, 255, 255, 0.1)",
            "--shadow-soft" => "0 4px 8px rgba(255, 255, 255, 0.2)",
            "--shadow-button" => "0 2px 4px rgba(255, 255, 255, 0.2)",
            "--shadow-inset" => "inset 2px 2px 5px rgba(255, 255, 255, 0.2)",
            "--hover-bg" => "rgba(255, 255, 255, 0.1)",
            "--menu-hover-bg" => "rgba(255, 255, 255, 0.05)",
            "--accent-blue" => "#0366d6",
            "--animation-glow" => "0 0 15px rgba(255, 255, 255, 0.3)",
            "--icon-color" => "#cccccc",
            "--icon-hover-color" => "#ffffff",
            "--icon-filter" => "invert(1)",
            "--icon-hover-filter" => "invert(1) brightness(1.2)",
        )
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
    # Global styling for all elements
    CSS(
        "html",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        "body",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        "*",
        "color" => "inherit"
    ),
    # Fix for Markdown list
    CSS("li p", "display" => "inline"),
    CSS(
        "mjx-container[jax='CHTML'][display='true']",
        "display" => "inline"
    ),

    # Monaco Widgets (find/command palette)
    CSS(
        ".quick-input-widget",
        "position" => "fixed !important",
        "top" => "10px !important",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".find-widget",
        "position" => "fixed !important",
        "top" => "10px !important",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".monaco-list",
        "max-height" => max_height_medium,
        "overflow-y" => "auto !important",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    # Editor containers
    CSS(
        ".cell-editor-container",
        "width" => editor_width,
        "max-width" => "95vw",
        "position" => "relative",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".cell-menu-proximity-area",
        "position" => "absolute",
        "top" => "-20px",
        "left" => "0px",
        "height" => "20px",
        "width" => "100%",
        "background-color" => "transparent",
        "pointer-events" => "auto",
        "z-index" => "-1"
    ),
    CSS(
        ".cell-editor",
        "width" => editor_width,
        "max-width" => "95vw",
        "position" => "relative",
        "display" => "inline-block",
        "padding" => "5px 5px 10px 10px",
        "border-radius" => border_radius_large,
        "box-shadow" => "var(--shadow-soft)",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".monaco-editor-div",
        "background-color" => "var(--bg-primary)",
        "padding" => "0px",
        "margin" => "0px",
        "color" => "var(--text-primary)"
    ),

    # AI Chat
    CSS(
        ".chat.monaco-editor-div",
        "border-radius" => border_radius_small,
        "border" => "1px solid var(--border-secondary)",
        "padding" => "5px",
        "margin" => "5px",
        "overflow" => "hidden",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    # Logging output
    CSS(
        ".cell-logging",
        "max-height" => "500px",
        "max-width" => editor_width,
        "overflow-y" => "auto",
        "margin" => "0",
        "padding" => "0",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    # Hover buttons
    CSS(
        ".hover-buttons",
        "position" => "absolute",
        "right" => "-10px",
        "top" => "-23px",
        "z-index" => 1000,
        "opacity" => 0.0,
        "pointer-events" => "auto",
    ),

    # Cell output
    CSS(
        ".cell-output",
        "width" => "100%",
        "margin" => "5px",
        "max-height" => "700px",
        "overflow-y" => "auto",
        "overflow-x" => "visible",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    # Visibility controls
    CSS(".hide-vertical", "display" => "none"),
    CSS(".show-vertical", "display" => "block"),
    CSS(
        ".hide-horizontal",
        "display" => "none"
    ),
    CSS(
        ".show-horizontal",
        "display" => "block",
    ),

    # Loading animation
    CSS(
        ".loading-cell",
        "box-shadow" => "var(--shadow-soft)",
        "animation" => "shadow-pulse 1.5s ease-in-out infinite",
    ),
    CSS(
        "@keyframes shadow-pulse",
        CSS("0%", "box-shadow" => "var(--shadow-soft)"),
        CSS("50%", "box-shadow" => "var(--animation-glow)"),
        CSS("100%", "box-shadow" => "var(--shadow-soft)")
    ),

    # Language icon
    CSS(
        ".small-language-icon",
        "position" => "absolute",
        "bottom" => "4px",
        "right" => "8px",
        "opacity"=> "0.8",
        "pointer-events" => "none",
        "color" => "var(--icon-color)",
        "filter" => "var(--icon-filter)"
    ),

    # Codicon system
    CSS(
        ".codicon",
        "display" => "inline-block",
        "text-decoration" => "none",
        "text-rendering" => "auto",
        "text-align" => "center",
        "text-transform" => "none",
        "-webkit-font-smoothing" => "antialiased",
        "-moz-osx-font-smoothing" => "grayscale",
        "user-select" => "none",
        "-webkit-user-select" => "none",
        "flex-shrink" => "0",
        "color" => "var(--icon-color)",
        "filter" => "var(--icon-filter)"
    ),
    CSS(
        ".codicon svg",
        "display" => "block",
        "fill" => "currentColor"
    ),
    CSS(
        ".codicon:hover",
        "color" => "var(--icon-hover-color)",
        "filter" => "var(--icon-hover-filter)"
    ),

    # SVG icons (excluding colored icons identified by filename)
    CSS(
        "img:not([src*='python-logo']):not([src*='julia-logo']), svg",
        "filter" => "var(--icon-filter)"
    ),
    CSS(
        ".small-button img:not([src*='python-logo']):not([src*='julia-logo']), .small-button svg",
        "filter" => "var(--icon-filter)"
    ),
    CSS(
        ".small-button:hover img:not([src*='python-logo']):not([src*='julia-logo']), .small-button:hover svg",
        "filter" => "var(--icon-hover-filter)"
    ),

    # Colored icons - handle separately for dark theme
    CSS(
        dark_media_query,
        CSS(
            "img[src*='python-logo'], img[src*='julia-logo']",
            "filter" => "brightness(1.3) contrast(1.1)"
        )
    ),

    # Menu and Buttons
    CSS(
        ".small-menu-bar",
        "z-index" => "1001",
        "background-color" => "var(--bg-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "8px",
        "box-shadow" => "var(--shadow-soft)",
        "padding" => "6px",
        "display" => "flex",
        "gap" => "4px",
        "align-items" => "center"
    ),
    CSS(
        ".small-button.toggled",
        "color" => "var(--text-primary)",
        "border" => "none",
        "filter" => "grayscale(100%)",
        "opacity" => "0.5",
        "box-shadow" => "var(--shadow-inset)",
    ),
    CSS(
        ".small-button",
        "background-color" => "transparent",
        "border" => "none",
        "border-radius" => "8px",
        "color" => "var(--text-secondary)",
        "cursor" => "pointer",
        "box-shadow" => "var(--shadow-button)",
        "transition" => "background-color 0.2s",
        "padding" => "8px",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center"
    ),
    CSS(
        ".small-button:hover",
        "background-color" => "var(--hover-bg)",
    ),

    # File editor path
    CSS(
        ".file-editor-path",
        "font-family" => font_family_clean,
        "font-size" => "14px",
        "font-weight" => "500",
        "color" => "var(--text-secondary)",
        "letter-spacing" => "0.3px",
        "padding" => "5px 10px",
        "margin" => "1px",
        "width" => "fit-content",
        "border-radius" => "6px",
        "border" => "1px solid var(--border-primary)",
        "box-shadow" => "var(--shadow-soft)",
        "white-space" => "nowrap",
        "overflow" => "hidden",
        "text-overflow" => "ellipsis",
    ),
    CSS(
        ".file-editor",
        "padding" => "0px",
        "margin" => "0px",
        "width" => editor_width,
        "max-height" => max_height_large,
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    # Utility classes
    CSS(".flex-row", "display" => "flex", "flex-direction" => "row"),
    CSS(".flex-column", "display" => "flex", "flex-direction" => "column"),
    CSS(".center-content", "justify-content" => "center", "align-items" => "center"),
    CSS(".inline-block", "display" => "inline-block"),
    CSS(".fit-content", "width" => "fit-content"),
    CSS(".max-width-90ch", "max-width" => "90ch"),
    CSS(".gap-10", "gap" => "10px"),
    CSS(".full-width", "width" => "100%"),

    # Markdown styling
    CSS(
        ".markdown-body",
        "-ms-text-size-adjust" => "100%",
        "-webkit-text-size-adjust" => "100%",
        "color" => "var(--text-primary)",
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
    CSS(".markdown-body a", "color" => "var(--accent-blue)", "text-decoration" => "none"),
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
        "background-color" => "transparent",
        "transition" => "height 0.2s",
    ),
    CSS(
        ".new-cell-menu:hover",
        "height" => "2.5rem",
        "transition-delay" => "0.1s",
        "background-color" => "var(--menu-hover-bg)",
    ),
    CSS(
        ".new-cell-menu > *",
        "opacity" => "0",
        "transition" => "opacity 0.15s",
    ),
    CSS(
        ".new-cell-menu:hover > *",
        "opacity" => "1",
        "transition-delay" => "0.1s",
    ),
)
