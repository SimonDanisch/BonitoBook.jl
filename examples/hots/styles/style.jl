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

# Define theme media queries based on light_theme setting
light_media_query = if light_theme === nothing
    BonitoBook.monaco_theme!("default")  # Auto-detect in JS
    Makie.set_theme!(size = (650, 450))
    "@media (prefers-color-scheme: light), (prefers-color-scheme: no-preference)"
elseif light_theme === true
    BonitoBook.monaco_theme!("vs")  # Force light Monaco theme
    Makie.set_theme!(size = (650, 450))
    "@media screen"  # Apply directly to root
else
    Makie.set_theme!(Makie.theme_dark(), size = (650, 450))
    BonitoBook.monaco_theme!("vs-dark")  # Force dark Monaco theme
    "@media (max-width: 0px)"  # Never apply
end

dark_media_query = if light_theme === nothing
    "@media (prefers-color-scheme: dark)"
elseif light_theme === false
    "@media screen" # Apply directly to root
else
    "@media (max-width: 0px)"  # Never apply
end

Styles(
    CSS(
        "body",
        "margin" => "0px",
    ),
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
            "--scrollbar-track" => "#f1f1f1",
            "--scrollbar-thumb" => "#c1c1c1",
            "--scrollbar-thumb-hover" => "#a8a8a8",
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
            "--shadow-inset" => "inset 2px 2px 3px rgba(0, 0, 0, 0.5)",
            "--hover-bg" => "rgba(255, 255, 255, 0.1)",
            "--menu-hover-bg" => "rgba(255, 255, 255, 0.05)",
            "--accent-blue" => "#0366d6",
            "--animation-glow" => "0 0 20px rgba(10, 155, 55, 0.5)",
            "--icon-color" => "#cccccc",
            "--icon-hover-color" => "#ffffff",
            "--icon-filter" => "invert(1)",
            "--icon-hover-filter" => "invert(1) brightness(1.2)",
            "--scrollbar-track" => "#2d2d2d",
            "--scrollbar-thumb" => "#555555",
            "--scrollbar-thumb-hover" => "#777777",
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
        "min-width" => "400px",  # Don't squeeze too much
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
    CSS(
        ".logging-widget",
        "max-height" => "100%",
        "width" => "100%",
        "overflow-y" => "auto",
        "margin" => "0",
        "padding" => "8px",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "font-family" => "monospace",
        "font-size" => "12px",
        "line-height" => "1.4"
    ),
    CSS(
        ".logging-widget pre",
        "margin" => "0",
        "padding" => "0",
        "background-color" => "transparent",
        "color" => "inherit",
        "font-family" => "inherit",
        "font-size" => "inherit",
        "line-height" => "inherit",
        "white-space" => "pre-wrap",
        "word-wrap" => "break-word"
    ),

    # Hover buttons
    CSS(
        ".hover-buttons",
        "position" => "absolute",
        "right" => "-10px",
        "top" => "-23px",
        "z-index" => 50,
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
        "opacity" => "0.8",
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

    # Scrollbar styling
    CSS(
        "::-webkit-scrollbar",
        "width" => "12px"
    ),
    CSS(
        "::-webkit-scrollbar-track",
        "background" => "var(--scrollbar-track)"
    ),
    CSS(
        "::-webkit-scrollbar-thumb",
        "background-color" => "var(--scrollbar-thumb)",
        "border-radius" => "6px",
        "border" => "2px solid var(--scrollbar-track)"
    ),
    CSS(
        "::-webkit-scrollbar-thumb:hover",
        "background-color" => "var(--scrollbar-thumb-hover)"
    ),
    # Firefox scrollbar
    CSS(
        "*",
        "scrollbar-width" => "thin",
        "scrollbar-color" => "var(--scrollbar-thumb) var(--scrollbar-track)"
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
        ".toggle-button.active",
        "box-shadow" => "var(--shadow-inset)",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".small-button:hover",
        "background-color" => "var(--hover-bg)",
    ),
    CSS(
        ".small-button.has-new-content",
        "animation" => "blink-notification 1.5s ease-in-out infinite",
    ),
    CSS(
        "@keyframes blink-notification",
        CSS("0%", "opacity" => "1"),
        CSS("50%", "opacity" => "0.5"),
        CSS("100%", "opacity" => "1")
    ),

    CSS(
        ".file-tabs-container",
        "display" => "flex",
        "background-color" => "var(--bg-primary)",
        "border-bottom" => "1px solid var(--border-primary)",
        "overflow-x" => "auto",
        "flex-shrink" => "0",
    ),
    CSS(
        ".file-tab",
        "display" => "flex",
        "align-items" => "center",
        "padding" => "8px 4px",
        "border-bottom" => "2px solid transparent",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-secondary)",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "border-radius" => "6px 6px 0 0",
        "margin-right" => "2px",
        "user-select" => "none",
    ),
    CSS(
        ".file-tab:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".file-tab.active",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border-bottom-color" => "var(--accent-blue)",
        "font-weight" => "500",
    ),
    CSS(
        ".file-tab-content",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "6px",
    ),
    CSS(
        ".file-tab-name",
        "font-size" => "13px",
        "max-width" => "150px",
        "overflow" => "hidden",
        "text-overflow" => "ellipsis",
        "white-space" => "nowrap",
    ),
    CSS(
        ".file-tab-close",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "width" => "16px",
        "height" => "16px",
        "border-radius" => "50%",
        "background-color" => "transparent",
        "border" => "none",
        "color" => "var(--text-secondary)",
        "cursor" => "pointer",
        "font-size" => "12px",
        "line-height" => "1",
        "transition" => "all 0.2s ease",
    ),
    CSS(
        ".file-tab-close:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".file-tab-add",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "padding" => "8px 12px",
        "background-color" => "transparent",
        "border" => "none",
        "color" => "var(--text-secondary)",
        "cursor" => "pointer",
        "font-size" => "16px",
        "line-height" => "1",
        "transition" => "all 0.2s ease",
        "border-radius" => "6px",
    ),
    CSS(
        ".file-tab-add:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-primary)",
    ),

    CSS(
        ".file-editor",
        "padding" => "0px",
        "margin" => "0px",
        "width" => "100%",
        "min-width" => editor_width,
        "height" => "calc(100vh - 20px)",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    CSS(
        ".sidebar-widget-content .monaco-editor-div.hide-horizontal",
        "display" => "block !important",
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

    # Popup styling for file dialogs
    CSS(
        ".popup-overlay",
        "position" => "fixed",
        "top" => "0",
        "left" => "0",
        "width" => "100vw",
        "height" => "100vh",
        "background-color" => "rgba(0, 0, 0, 0.5)",
        "z-index" => "2000",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
    ),
    CSS(
        ".popup-content",
        "position" => "relative",
        "background-color" => "var(--bg-primary)",
        "border-radius" => border_radius_large,
        "box-shadow" => "var(--shadow-soft)",
        "border" => "1px solid var(--border-primary)",
        "max-width" => "90vw",
        "max-height" => "90vh",
        "overflow" => "auto",
        "color" => "var(--text-primary)",
        "padding" => "16px",
        "margin" => "20px",
        "width" => "fit-content",
        "height" => "fit-content",
    ),
    CSS(
        ".popup-close-button",
        "position" => "absolute",
        "top" => "4px",
        "right" => "4px",
        "background" => "none",
        "border" => "none",
        "font-size" => "18px",
        "color" => "var(--text-secondary)",
        "cursor" => "pointer",
        "padding" => "2px",
        "border-radius" => "50%",
        "width" => "20px",
        "height" => "20px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "transition" => "all 0.2s ease",
        "z-index" => "2001",
        "line-height" => "1",
    ),
    CSS(
        ".popup-close-button:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-primary)",
    ),

    # Book layout classes
    CSS(
        ".book-main-menu",
        "position" => "relative",
        "display" => "flex",
        "flex-direction" => "row",
        "width" => "100%",
        "justify-content" => "center",
        "background-color" => "var(--bg-primary)"
    ),
    CSS(
        ".book-main-menu .file-tabs-container",
        "justify-content" => "center",
        "border-bottom" => "none" # Remove border from tabs in menu
    ),
    CSS(
        ".book-content",
        "display" => "flex",
        "flex-direction" => "row",
        "flex" => "1",
        "padding-top" => "20px", # to have some space for overlay menu
        "overflow" => "hidden", # Prevent the container from scrolling
        "width" => "100%",
        "height" => "calc(100vh - 20px)" # Full height minus menu space
    ),
    CSS(
        ".book-cells-area",
        "flex" => "1 1 auto",
        "min-width" => "0", # Allow shrinking
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "overflow-y" => "auto",
        "overflow-x" => "hidden",
        "padding" => "15px 10px",
    ),
    CSS(
        ".book-document",
        "display" => "flex",
        "flex-direction" => "column",
        "width" => "100%",
        "height" => "100vh",
        "overflow" => "hidden"
    ),
    CSS(
        ".book-wrapper",
        "overflow" => "hidden",
        "height" => "100vh"
    ),
    CSS(
        ".book-bottom-panel",
        "position" => "fixed",
        "bottom" => "0",
        "left" => "0",
        "right" => "0",
        "z-index" => "1000",
        "background-color" => "var(--bg-primary)",
    ),
    CSS(
        ".book-main-content",
        "padding-bottom" => "50px", # Add padding to avoid overlap with horizontal sidebar
        "flex" => "1",
        "display" => "flex",
        "flex-direction" => "column",
        "overflow" => "hidden",
    ),

    # Sidebar styles
    CSS(
        ".sidebar-main-container",
        "position" => "absolute",
        "right" => "0",
        "top" => "0",
        "bottom" => "0",
        "display" => "flex",
        "flex-direction" => "row-reverse",  # Icon bar on the right
        "align-items" => "center",
        "z-index" => "100",
        "pointer-events" => "none",
    ),
    CSS(
        ".sidebar-content-container",
        "background-color" => "var(--bg-primary)",
        "border-left" => "1px solid var(--border-primary)",
        "transition" => "width 0.3s ease, opacity 0.3s ease",
        "border-radius" => "8px 0 0 8px",
        "box-shadow" => "-4px 0 8px rgba(0, 0, 0, 0.1)",
        "overflow" => "hidden",
        "height" => "fit-content",
        "max-height" => "90vh",
        "pointer-events" => "auto",
    ),
    CSS(
        ".sidebar-content-container.collapsed",
        "width" => "0",
        "opacity" => "0",
        "visibility" => "hidden",
    ),
    CSS(
        ".sidebar-content-container.expanded",
        "opacity" => "1",
        "visibility" => "visible",
    ),
    # Horizontal sidebar styles
    CSS(
        ".sidebar-content-container.horizontal.expanded",
        "opacity" => "1",
        "visibility" => "visible",
        "height" => "var(--sidebar-height, 300px)",
    ),
    CSS(
        ".sidebar-content-container.horizontal",
        "background-color" => "var(--bg-primary)",
        "border-top" => "1px solid var(--border-primary)",
        "transition" => "height 0.3s ease, opacity 0.3s ease",
        "overflow" => "hidden",
        "width" => "100%",
        "opacity" => "1",
        "visibility" => "visible",
    ),
    CSS(
        ".sidebar-content-container.horizontal.collapsed",
        "height" => "0px",
        "opacity" => "0",
        "visibility" => "hidden",
    ),
    CSS(
        ".sidebar-main-container.horizontal",
        "position" => "relative",
        "width" => "100%",
        "display" => "flex",
        "flex-direction" => "column-reverse",
        "height" => "auto",
    ),
    CSS(
        ".sidebar-tabs.horizontal",
        "display" => "flex",
        "flex-direction" => "row",
        "justify-content" => "center",
        "background-color" => "var(--bg-primary)",
        "border-top" => "1px solid var(--border-primary)",
        "padding" => "4px",
        "width" => "100%",
        "height" => "auto",
    ),
    CSS(
        ".sidebar-tabs",
        "width" => "48px",
        "background-color" => "var(--bg-primary)",
        "border-left" => "1px solid var(--border-primary)",
        "border-radius" => "0 8px 8px 0",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "padding-top" => "10px",
        "gap" => "4px",
        "flex-shrink" => "0",
        "height" => "fit-content",
        "pointer-events" => "auto",
    ),
    CSS(
        ".sidebar-tab",
        "position" => "relative",
    ),
    CSS(
        ".sidebar-tab.active::before",
        "content" => "''",
        "position" => "absolute",
        "left" => "0",
        "top" => "50%",
        "transform" => "translateY(-50%)",
        "width" => "3px",
        "height" => "18px",
        "background-color" => "var(--accent-blue)",
        "border-radius" => "0 3px 3px 0",
    ),
    CSS(
        ".sidebar-toggle-button",
        "width" => "36px",
        "height" => "36px",
        "border" => "none",
        "background-color" => "transparent",
        "color" => "var(--icon-color)",
        "cursor" => "pointer",
        "border-radius" => "6px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "transition" => "all 0.2s ease",
        "margin-top" => "auto",
        "margin-bottom" => "10px",
    ),
    CSS(
        ".sidebar-toggle-button:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--icon-hover-color)",
    ),
    CSS(
        ".sidebar-toggle-button.hidden",
        "display" => "none",
    ),
    CSS(
        ".sidebar-content",
        "overflow-y" => "auto",
        "overflow-x" => "hidden",
        "padding" => "0",
        "width" => "100%",
        "background-color" => "var(--bg-primary)",
        "position" => "relative",
        "height" => "fit-content",
    ),
    CSS(
        ".sidebar-widget-content",
        "width" => "100%",
        "height" => "fit-content",
    ),
    CSS(
        ".sidebar-widget-content.hide",
        "display" => "none",
    ),
    CSS(
        ".sidebar-widget-content.show",
        "display" => "block",
    ),

    # Resize handle
    CSS(
        ".sidebar-resize-handle",
        "position" => "absolute",
        "left" => "0",
        "top" => "0",
        "bottom" => "0",
        "width" => "4px",
        "cursor" => "ew-resize",
        "background-color" => "transparent",
        "z-index" => "10",
    ),
    CSS(
        ".sidebar-resize-handle:hover",
        "background-color" => "var(--accent-blue)",
        "opacity" => "0.5",
    ),

    # Adjust book content to account for sidebar
    CSS(
        ".book-content",
        "display" => "flex",
        "flex-direction" => "row",
        "width" => "100%",
        "height" => "100%",
        "overflow" => "hidden",
        "position" => "relative",
    ),

    # BonitoBook Components Styling
    CSS(
        ".bonitobook-button",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 16px",
        "font-size" => "14px",
        "font-weight" => "500",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "box-shadow" => "0 1px 3px rgba(0, 0, 0, 0.1)",
        "min-width" => "80px",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center",
        "font-family" => "inherit"
    ),
    CSS(
        ".bonitobook-button:hover",
        "background-color" => "var(--hover-bg)",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 2px 6px rgba(0, 0, 0, 0.15)"
    ),
    CSS(
        ".bonitobook-button:focus",
        "outline" => "none",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-button:active",
        "transform" => "translateY(1px)",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)"
    ),

    # Input field styling
    CSS(
        ".bonitobook-input",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 12px",
        "font-size" => "14px",
        "font-family" => "inherit",
        "transition" => "all 0.2s ease",
        "outline" => "none",
        "width" => "100%",
        "box-sizing" => "border-box"
    ),
    CSS(
        ".bonitobook-input:hover",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-input:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-input:disabled",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-secondary)",
        "cursor" => "not-allowed"
    ),

    # Checkbox styling
    CSS(
        ".bonitobook-checkbox",
        "width" => "16px",
        "height" => "16px",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "3px",
        "background-color" => "var(--bg-primary)",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "position" => "relative",
        "margin" => "0 8px 0 0",
        "flex-shrink" => "0"
    ),
    CSS(
        ".bonitobook-checkbox:hover",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-checkbox:focus",
        "outline" => "none",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-checkbox:checked",
        "background-color" => "var(--accent-blue)",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-checkbox:checked::after",
        "content" => "\"✓\"",
        "position" => "absolute",
        "top" => "50%",
        "left" => "50%",
        "transform" => "translate(-50%, -50%)",
        "color" => "white",
        "font-size" => "12px",
        "line-height" => "1"
    ),

    # Dropdown styling
    CSS(
        ".bonitobook-dropdown",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 12px",
        "font-size" => "14px",
        "font-family" => "inherit",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "outline" => "none",
        "width" => "100%",
        "box-sizing" => "border-box",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "background-repeat" => "no-repeat",
        "background-position" => "right 12px center",
        "background-size" => "12px",
        "padding-right" => "36px"
    ),
    CSS(
        ".bonitobook-dropdown:hover",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-dropdown:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-dropdown option",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),

    # Light theme dropdown arrow
    CSS(
        light_media_query,
        CSS(
            ".bonitobook-dropdown",
            "background-image" => "url('data:image/svg+xml;charset=US-ASCII,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 5\"><path fill=\"%23666\" d=\"M2 0L0 2h4zm0 5L0 3h4z\"/></svg>')"
        )
    ),

    # Dark theme dropdown arrow
    CSS(
        dark_media_query,
        CSS(
            ".bonitobook-dropdown",
            "background-image" => "url('data:image/svg+xml;charset=US-ASCII,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 5\"><path fill=\"%23ccc\" d=\"M2 0L0 2h4zm0 5L0 3h4z\"/></svg>')"
        )
    ),

    # Slider styling
    CSS(
        ".bonitobook-slider",
        "width" => "100%",
        "height" => "6px",
        "border-radius" => "3px",
        "background" => "var(--border-secondary)",
        "outline" => "none",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".bonitobook-slider::-webkit-slider-thumb",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "width" => "20px",
        "height" => "20px",
        "border-radius" => "50%",
        "background" => "var(--accent-blue)",
        "cursor" => "pointer",
        "border" => "2px solid var(--bg-primary)",
        "box-shadow" => "0 2px 6px rgba(0, 0, 0, 0.2)",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".bonitobook-slider::-webkit-slider-thumb:hover",
        "transform" => "scale(1.1)",
        "box-shadow" => "0 3px 8px rgba(0, 0, 0, 0.3)"
    ),
    CSS(
        ".bonitobook-slider::-moz-range-thumb",
        "width" => "20px",
        "height" => "20px",
        "border-radius" => "50%",
        "background" => "var(--accent-blue)",
        "cursor" => "pointer",
        "border" => "2px solid var(--bg-primary)",
        "box-shadow" => "0 2px 6px rgba(0, 0, 0, 0.2)",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".bonitobook-slider::-moz-range-track",
        "width" => "100%",
        "height" => "6px",
        "border-radius" => "3px",
        "background" => "var(--border-secondary)",
        "border" => "none"
    ),
    CSS(
        ".bonitobook-slider:focus",
        "outline" => "none"
    ),
    CSS(
        ".bonitobook-slider:focus::-webkit-slider-thumb",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2), 0 2px 6px rgba(0, 0, 0, 0.2)"
    ),

    # Manipulate widget styling
    CSS(
        ".manipulate-container",
        "background-color" => "var(--bg-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "8px",
        "padding" => "16px",
        "margin" => "16px 0",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "16px"
    ),
    CSS(
        ".manipulate-controls",
        "background-color" => "var(--hover-bg)",
        "border-radius" => "6px",
        "padding" => "12px",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "12px"
    ),
    CSS(
        ".manipulate-control-row",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "12px"
    ),
    CSS(
        ".manipulate-label",
        "font-size" => "13px",
        "font-weight" => "500",
        "color" => "var(--text-secondary)",
        "min-width" => "120px",
        "text-align" => "left",
        "flex-shrink" => "0"
    ),
    CSS(
        ".manipulate-widget",
        "flex" => "1",
        "min-width" => "0"
    ),
    CSS(
        ".manipulate-output",
        "background-color" => "var(--bg-primary)",
        "border-radius" => "6px",
        "padding" => "12px",
        "min-height" => "100px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center"
    ),
)
