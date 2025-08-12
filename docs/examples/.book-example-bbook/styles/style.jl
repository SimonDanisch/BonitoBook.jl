# Embeddable Book Styling
# Optimized for embedding in other webpages with complete style isolation
# All styles are scoped to .bonito-book-embedded and .real-book-container classes
# to prevent conflicts with parent webpage styles

# Theme control: true = light (better for embedding), false = dark, nothing = auto
light_theme = true  # Force light theme for maximum compatibility

# Define academic book variables (using relative units for better embedding)
content_width = "min(800px, 90vw)"  # Responsive content width
line_height = 1.6
font_size_base = "1rem"
font_size_small = "0.875rem"
font_size_large = "1.25rem"
font_family_serif = "Georgia, 'Times New Roman', Times, serif"
font_family_sans = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
font_family_mono = "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, monospace"

# Academic color palette
color_primary = "#2c3e50"      # Dark blue-gray for headings
color_secondary = "#34495e"     # Medium gray for text
color_accent = "#3498db"       # Blue for links and accents
color_highlight = "#e74c3c"    # Red for emphasis
color_code_bg = "#f8f9fa"     # Light gray for code backgrounds
color_table_border = "#dee2e6" # Light gray for table borders

# Set Makie theme for academic figures
Makie.set_theme!(
    size = (600, 400),
    fontsize = 12,
    font = "DejaVu Sans",
    backgroundcolor = :white,
    figure_padding = 20,
    Axis = (
        backgroundcolor = :white,
        leftspinevisible = true,
        rightspinevisible = false,
        topspinevisible = false,
        bottomspinevisible = true,
        xgridcolor = :lightgray,
        ygridcolor = :lightgray,
        xgridwidth = 0.5,
        ygridwidth = 0.5,
    )
)

# Set Monaco theme to light
BonitoBook.monaco_theme!("vs")

Styles(
    # CSS reset for embedded container to prevent inheritance from parent page
    CSS(
        ".bonito-book-embedded *, .real-book-container *",
        "box-sizing" => "border-box"
    ),

    CSS(
        ".bonito-book-embedded, .real-book-container",
        "font-family" => font_family_serif,
        "font-size" => font_size_base,
        "line-height" => line_height,
        "color" => color_secondary,
        "background-color" => "#ffffff",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 12px rgba(0,0,0,0.1)",
        "overflow" => "visible",
        "position" => "relative",
        "display" => "block",
        "width" => "auto",
        "max-width" => "1200px",
        "margin" => "20px auto",
        "padding" => "0"
    ),

    # Embedded container wrapper styling
    CSS(
        ".bonito-book-embedded",
        "isolation" => "isolate"      # Create new stacking context
    ),

    # Academic heading hierarchy (scoped to container)
    CSS(
        ".bonito-book-embedded h1, .real-book-container h1, .bonito-book-embedded .book-title, .real-book-container .book-title",
        "font-family" => font_family_sans,
        "font-size" => "2.2em",
        "font-weight" => "700",
        "color" => color_primary,
        "margin" => "1.5em 0 1em 0",
        "text-align" => "center",
        "border-bottom" => "3px solid $(color_accent)",
        "padding-bottom" => "0.5em"
    ),

    CSS(
        ".bonito-book-embedded h2, .real-book-container h2",
        "font-family" => font_family_sans,
        "font-size" => "1.6em",
        "font-weight" => "600",
        "color" => color_primary,
        "margin" => "1.8em 0 1em 0",
        "border-left" => "4px solid $(color_accent)",
        "padding-left" => "1em"
    ),

    CSS(
        ".bonito-book-embedded h3, .real-book-container h3",
        "font-family" => font_family_sans,
        "font-size" => "1.3em",
        "font-weight" => "600",
        "color" => color_primary,
        "margin" => "1.4em 0 0.8em 0"
    ),

    CSS(
        ".bonito-book-embedded h4, .real-book-container h4",
        "font-family" => font_family_sans,
        "font-size" => "1.1em",
        "font-weight" => "600",
        "color" => color_secondary,
        "margin" => "1.2em 0 0.6em 0"
    ),

    # Academic paragraph styling (scoped to container)
    CSS(
        ".bonito-book-embedded p, .real-book-container p",
        "margin" => "1em 0",
        "text-align" => "justify",
        "text-indent" => "1.5em",
        "hyphens" => "auto"
    ),

    # First paragraph after headings shouldn't be indented (scoped)
    CSS(
        ".bonito-book-embedded h1 + p, .bonito-book-embedded h2 + p, .bonito-book-embedded h3 + p, .bonito-book-embedded h4 + p, .bonito-book-embedded h5 + p, .bonito-book-embedded h6 + p, .real-book-container h1 + p, .real-book-container h2 + p, .real-book-container h3 + p, .real-book-container h4 + p, .real-book-container h5 + p, .real-book-container h6 + p",
        "text-indent" => "0"
    ),

    # Academic links (scoped)
    CSS(
        ".bonito-book-embedded a, .real-book-container a",
        "color" => color_accent,
        "text-decoration" => "none",
        "border-bottom" => "1px solid transparent",
        "transition" => "border-bottom 0.2s ease"
    ),

    CSS(
        ".bonito-book-embedded a:hover, .real-book-container a:hover",
        "border-bottom" => "1px solid $(color_accent)"
    ),

    # Academic code styling (scoped)
    CSS(
        ".bonito-book-embedded code:not(.hljs), .real-book-container code:not(.hljs)",
        "font-family" => font_family_mono,
        "font-size" => "0.9em",
        "background-color" => color_code_bg,
        "padding" => "0.2em 0.4em",
        "border-radius" => "3px",
        "border" => "1px solid #e9ecef"
    ),

    CSS(
        ".bonito-book-embedded pre, .real-book-container pre",
        "font-family" => font_family_mono,
        "font-size" => font_size_small,
        "background-color" => color_code_bg,
        "padding" => "1em",
        "border-radius" => "8px",
        "border" => "1px solid #e9ecef",
        "overflow-x" => "auto",
        "margin" => "1.5em 0",
        "line-height" => "1.4"
    ),

    # Academic table styling (scoped)
    CSS(
        ".bonito-book-embedded table, .real-book-container table",
        "width" => "100%",
        "border-collapse" => "collapse",
        "margin" => "2em 0",
        "font-size" => font_size_small,
        "background-color" => "#ffffff"
    ),

    CSS(
        ".bonito-book-embedded th, .real-book-container th",
        "background-color" => color_primary,
        "color" => "#ffffff",
        "padding" => "12px",
        "text-align" => "left",
        "font-family" => font_family_sans,
        "font-weight" => "600",
        "border" => "1px solid $(color_table_border)"
    ),

    CSS(
        ".bonito-book-embedded td, .real-book-container td",
        "padding" => "10px 12px",
        "border" => "1px solid $(color_table_border)",
        "vertical-align" => "top"
    ),

    CSS(
        ".bonito-book-embedded tr:nth-child(even), .real-book-container tr:nth-child(even)",
        "background-color" => "#f8f9fa"
    ),

    # Academic figure and table captions (scoped)
    CSS(
        ".bonito-book-embedded .figure-caption, .bonito-book-embedded .table-caption, .real-book-container .figure-caption, .real-book-container .table-caption",
        "font-family" => font_family_sans,
        "font-size" => font_size_small,
        "font-style" => "italic",
        "color" => color_secondary,
        "text-align" => "center",
        "margin" => "0.5em 0 1.5em 0",
        "font-weight" => "500"
    ),

    # Blockquotes for theorems, definitions, etc. (scoped)
    CSS(
        ".bonito-book-embedded blockquote, .real-book-container blockquote",
        "border-left" => "4px solid $(color_accent)",
        "background-color" => "#f8f9fa",
        "padding" => "1em 1.5em",
        "margin" => "1.5em 0",
        "font-style" => "italic",
        "position" => "relative"
    ),

    # Academic definition boxes (scoped)
    CSS(
        ".bonito-book-embedded .definition, .bonito-book-embedded .theorem, .bonito-book-embedded .lemma, .bonito-book-embedded .proof, .real-book-container .definition, .real-book-container .theorem, .real-book-container .lemma, .real-book-container .proof",
        "border" => "1px solid $(color_accent)",
        "background-color" => "#f0f8ff",
        "padding" => "1em",
        "margin" => "1.5em 0",
        "border-radius" => "8px",
        "position" => "relative"
    ),

    CSS(
        ".bonito-book-embedded .definition::before, .real-book-container .definition::before",
        "content" => "\"Definition: \"",
        "font-weight" => "bold",
        "color" => color_primary
    ),

    CSS(
        ".bonito-book-embedded .theorem::before, .real-book-container .theorem::before",
        "content" => "\"Theorem: \"",
        "font-weight" => "bold",
        "color" => color_highlight
    ),

    # Academic footnotes (scoped)
    CSS(
        ".bonito-book-embedded sup, .real-book-container sup",
        "font-size" => "0.8em",
        "vertical-align" => "super",
        "line-height" => "0"
    ),

    # Bibliography styling (scoped)
    CSS(
        ".bonito-book-embedded .bibliography ol, .real-book-container .bibliography ol",
        "counter-reset" => "bib-counter",
        "list-style" => "none",
        "padding-left" => "0"
    ),

    CSS(
        ".bonito-book-embedded .bibliography li, .real-book-container .bibliography li",
        "counter-increment" => "bib-counter",
        "margin" => "1em 0",
        "padding-left" => "2em",
        "text-indent" => "-2em",
        "font-size" => font_size_small
    ),

    CSS(
        ".bonito-book-embedded .bibliography li::before, .real-book-container .bibliography li::before",
        "content" => "\"[\" counter(bib-counter) \"] \"",
        "font-weight" => "bold",
        "color" => color_primary
    ),

    # Table of contents styling (scoped)
    CSS(
        ".bonito-book-embedded .toc, .real-book-container .toc",
        "background-color" => "#f8f9fa",
        "border" => "1px solid #dee2e6",
        "border-radius" => "8px",
        "padding" => "1.5em",
        "margin" => "2em 0"
    ),

    CSS(
        ".bonito-book-embedded .toc ul, .real-book-container .toc ul",
        "list-style" => "none",
        "padding-left" => "0"
    ),

    CSS(
        ".bonito-book-embedded .toc li, .real-book-container .toc li",
        "margin" => "0.5em 0",
        "padding-left" => "1em",
        "text-indent" => "-1em"
    ),

    # Book-specific editor styling (scoped)
    CSS(
        ".bonito-book-embedded .cell-editor, .real-book-container .cell-editor",
        "max-width" => content_width,
        "margin" => "2em auto",
        "background-color" => "#ffffff",
        "border" => "1px solid #e9ecef",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 8px rgba(0,0,0,0.1)"
    ),

    # Academic page layout (scoped)
    CSS(
        ".bonito-book-embedded .book-content, .real-book-container .book-content",
        "max-width" => content_width,
        "margin" => "0 auto",
        "padding" => "2em",
        "background-color" => "#ffffff"
    ),

    # Print-specific styles for academic publication
    CSS(
        "@media print",
        CSS("*", "-webkit-print-color-adjust" => "exact !important"),
        CSS("@page", "margin" => "2.5cm", "size" => "A4"),

        # Hide interactive elements (scoped)
        CSS(
            ".bonito-book-embedded .hover-buttons, .bonito-book-embedded .cell-menu-proximity-area, .bonito-book-embedded .sidebar-main-container, .bonito-book-embedded .book-bottom-panel, .real-book-container .hover-buttons, .real-book-container .cell-menu-proximity-area, .real-book-container .sidebar-main-container, .real-book-container .book-bottom-panel",
            "display" => "none !important"
        ),

        # Ensure proper page breaks (scoped)
        CSS(
            ".bonito-book-embedded h1, .bonito-book-embedded h2, .real-book-container h1, .real-book-container h2",
            "page-break-after" => "avoid"
        ),

        CSS(
            ".bonito-book-embedded .cell-editor, .real-book-container .cell-editor",
            "page-break-inside" => "avoid",
            "border" => "none",
            "box-shadow" => "none",
            "background-color" => "transparent"
        ),

        # Adjust colors for print (scoped)
        CSS(
            ".bonito-book-embedded, .real-book-container",
            "background-color" => "#ffffff !important",
            "color" => "#000000 !important"
        )
    ),

    # Chapter numbering (scoped to container)
    CSS(
        ".bonito-book-embedded, .real-book-container",
        "counter-reset" => "chapter section subsection"
    ),

    CSS(
        ".bonito-book-embedded h1, .real-book-container h1",
        "counter-increment" => "chapter",
        "counter-reset" => "section subsection"
    ),

    CSS(
        ".bonito-book-embedded h2, .real-book-container h2",
        "counter-increment" => "section",
        "counter-reset" => "subsection"
    ),

    CSS(
        ".bonito-book-embedded h3, .real-book-container h3",
        "counter-increment" => "subsection"
    ),

    CSS(
        ".bonito-book-embedded h1::before, .real-book-container h1::before",
        "content" => "\"Chapter \" counter(chapter) \": \"",
        "display" => "block",
        "font-size" => "0.6em",
        "font-weight" => "normal",
        "color" => color_accent,
        "margin-bottom" => "0.5em"
    ),

    CSS(
        ".bonito-book-embedded h2::before, .real-book-container h2::before",
        "content" => "counter(chapter) \".\" counter(section) \" \""
    ),

    CSS(
        ".bonito-book-embedded h3::before, .real-book-container h3::before",
        "content" => "counter(chapter) \".\" counter(section) \".\" counter(subsection) \" \""
    ),

    # BonitoBook Interactive Elements Styling
    # ==============================================

    # Book layout structure (scoped)
    CSS(
        ".bonito-book-embedded .book-wrapper, .real-book-container .book-wrapper",
        "display" => "flex",
        "flex-direction" => "column",
        "min-height" => "100%",
        "overflow" => "visible",
        "background-color" => "#ffffff"
    ),

    CSS(
        ".bonito-book-embedded .book-document, .real-book-container .book-document",
        "display" => "flex",
        "flex-direction" => "column",
        "width" => "100%"
    ),

    CSS(
        ".bonito-book-embedded .book-content, .real-book-container .book-content",
        "display" => "flex",
        "flex-direction" => "row",
        "flex" => "1",
        "overflow" => "visible",
        "width" => "100%"
    ),

    CSS(
        ".bonito-book-embedded .book-cells-area, .real-book-container .book-cells-area",
        "flex" => "1",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "overflow-y" => "visible",
        "overflow-x" => "hidden",
        "padding" => "20px"
    ),

    # Cell editors with academic styling (scoped)
    CSS(
        ".bonito-book-embedded .cell-editor-container, .real-book-container .cell-editor-container",
        "width" => content_width,
        "max-width" => "95%",
        "position" => "relative",
        "margin" => "1em auto"
    ),

    CSS(
        ".bonito-book-embedded .cell-editor, .real-book-container .cell-editor",
        "background-color" => "#ffffff",
        "border" => "1px solid #e9ecef",
        "border-radius" => "8px",
        "padding" => "1em",
        "margin" => "0.5em 0",
        "box-shadow" => "0 2px 8px rgba(0,0,0,0.1)",
        "position" => "relative",
        "transition" => "box-shadow 0.2s ease"
    ),

    CSS(
        ".bonito-book-embedded .cell-editor:hover, .real-book-container .cell-editor:hover",
        "box-shadow" => "0 4px 12px rgba(0,0,0,0.15)"
    ),

    CSS(
        ".bonito-book-embedded .cell-editor.focused, .real-book-container .cell-editor.focused",
        "box-shadow" => "0 4px 12px rgba(3, 102, 214, 0.3)",
        "border-color" => color_accent
    ),

    # Monaco editor styling (scoped)
    CSS(
        ".bonito-book-embedded .monaco-editor-div, .real-book-container .monaco-editor-div",
        "background-color" => "#ffffff",
        "border-radius" => "6px",
        "border" => "1px solid #e9ecef",
        "font-family" => font_family_mono
    ),

    # Cell output styling (scoped)
    CSS(
        ".bonito-book-embedded .cell-output, .real-book-container .cell-output",
        "margin-top" => "1em",
        "padding" => "0.5em 0",
        "border-top" => "1px solid #f0f0f0",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "text-align" => "center"
    ),

    # Override centering for headings and text elements in cell output (scoped)
    CSS(
        ".bonito-book-embedded .cell-output h1, .bonito-book-embedded .cell-output h2, .bonito-book-embedded .cell-output h3, .bonito-book-embedded .cell-output h4, .bonito-book-embedded .cell-output h5, .bonito-book-embedded .cell-output h6, .real-book-container .cell-output h1, .real-book-container .cell-output h2, .real-book-container .cell-output h3, .real-book-container .cell-output h4, .real-book-container .cell-output h5, .real-book-container .cell-output h6",
        "text-align" => "left",
        "align-self" => "flex-start",
        "width" => "100%"
    ),

    CSS(
        ".bonito-book-embedded .cell-output p, .real-book-container .cell-output p",
        "text-align" => "justify",
        "align-self" => "stretch",
        "width" => "100%"
    ),

    # Hover buttons for academic book - follow BonitoBook default behavior (scoped)
    CSS(
        ".bonito-book-embedded .hover-buttons, .real-book-container .hover-buttons",
        "position" => "absolute",
        "right" => "-10px",
        "top" => "-23px",
        "z-index" => "50",
        "opacity" => "0.0",
        "pointer-events" => "auto",
        "background-color" => "#ffffff",
        "border" => "1px solid #e9ecef",
        "border-radius" => "6px",
        "padding" => "4px",
        "box-shadow" => "0 2px 8px rgba(0,0,0,0.1)"
    ),

    # Note: Hover visibility is controlled by JavaScript, not CSS
    # The JavaScript sets opacity to 1.0 on mouseover of the container

    # Small buttons academic styling - following BonitoBook structure (scoped)
    CSS(
        ".bonito-book-embedded .small-button, .real-book-container .small-button",
        "background-color" => "#ffffff",
        "border" => "none",
        "border-radius" => "8px",
        "color" => color_secondary,
        "cursor" => "pointer",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.2)",
        "transition" => "background-color 0.2s",
        "padding" => "8px",
        "margin-right" => "5px",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center",
        "font-size" => "12px"
    ),

    CSS(
        ".bonito-book-embedded .small-button:hover, .real-book-container .small-button:hover",
        "background-color" => "#ddd"
    ),

    # Cell menu proximity area - follow BonitoBook default behavior (scoped)
    CSS(
        ".bonito-book-embedded .cell-menu-proximity-area, .real-book-container .cell-menu-proximity-area",
        "position" => "absolute",
        "top" => "-20px",
        "left" => "0px",
        "height" => "20px",
        "width" => "100%",
        "background-color" => "transparent",
        "pointer-events" => "auto",
        "z-index" => "-1"
    ),

    # Collapsed editor proximity area behavior (scoped)
    CSS(
        ".bonito-book-embedded .cell-editor-container.editor-collapsed .cell-menu-proximity-area, .real-book-container .cell-editor-container.editor-collapsed .cell-menu-proximity-area",
        "position" => "absolute",
        "top" => "0px",
        "left" => "0px",
        "height" => "6px",
        "width" => "100%",
        "background-color" => "transparent",
        "border" => "none",
        "border-radius" => "2px",
        "pointer-events" => "auto",
        "z-index" => "1",
        "transition" => "all 0.2s ease",
        "opacity" => "0"
    ),

    CSS(
        ".bonito-book-embedded .cell-editor-container.editor-collapsed .cell-menu-proximity-area:hover, .real-book-container .cell-editor-container.editor-collapsed .cell-menu-proximity-area:hover",
        "background-color" => "#ddd",
        "border-style" => "solid",
        "opacity" => "1",
        "transform" => "scaleY(1.2)"
    ),

    # New cell menu academic styling (scoped)
    CSS(
        ".bonito-book-embedded .new-cell-menu, .real-book-container .new-cell-menu",
        "width" => "100%",
        "height" => "2px",
        "background-color" => "transparent",
        "border-top" => "1px dashed #dee2e6",
        "margin" => "1em 0",
        "position" => "relative",
        "transition" => "all 0.3s ease"
    ),

    CSS(
        ".bonito-book-embedded .new-cell-menu:hover, .real-book-container .new-cell-menu:hover",
        "height" => "40px",
        "background-color" => "rgba(3, 102, 214, 0.05)",
        "border-radius" => "6px",
        "border-top" => "1px solid " * color_accent
    ),

    CSS(
        ".bonito-book-embedded .new-cell-menu > *, .real-book-container .new-cell-menu > *",
        "opacity" => "0",
        "transition" => "opacity 0.2s ease"
    ),

    CSS(
        ".bonito-book-embedded .new-cell-menu:hover > *, .real-book-container .new-cell-menu:hover > *",
        "opacity" => "1"
    ),

    # Hide/show classes - critical for BonitoBook functionality (scoped)
    CSS(
        ".bonito-book-embedded .hide-horizontal, .real-book-container .hide-horizontal",
        "height" => "6px",
        "overflow" => "hidden",
        "position" => "relative"
    ),

    CSS(
        ".bonito-book-embedded .hide-vertical, .real-book-container .hide-vertical",
        "display" => "none"
    ),

    CSS(
        ".bonito-book-embedded .show-horizontal, .real-book-container .show-horizontal",
        "display" => "block"
    ),

    CSS(
        ".bonito-book-embedded .show-vertical, .real-book-container .show-vertical",
        "display" => "block"
    ),

    # Fix specificity issue - ensure hide-vertical works even with cell-editor class (scoped)
    CSS(
        ".bonito-book-embedded .cell-editor.hide-vertical, .real-book-container .cell-editor.hide-vertical",
        "display" => "none !important"
    ),

    # Logging widgets academic styling - with proper visibility controls (scoped)
    CSS(
        ".bonito-book-embedded .cell-logging, .real-book-container .cell-logging",
        "background-color" => "#f8f9fa",
        "border" => "1px solid #e9ecef",
        "border-radius" => "6px",
        "padding" => "8px",
        "margin-top" => "8px",
        "font-family" => font_family_mono,
        "font-size" => "11px",
        "max-height" => "500px",
        "max-width" => "90ch",
        "overflow-y" => "auto"
    ),

    # Critical: Hide logging when it has hide classes or is empty (scoped)
    CSS(
        ".bonito-book-embedded .cell-logging.hide-horizontal, .bonito-book-embedded .cell-logging.hide-vertical, .real-book-container .cell-logging.hide-horizontal, .real-book-container .cell-logging.hide-vertical",
        "height" => "0",
        "min-height" => "0",
        "padding" => "0",
        "margin" => "0",
        "overflow" => "hidden"
    ),

    CSS(
        ".bonito-book-embedded .cell-logging:empty, .real-book-container .cell-logging:empty",
        "height" => "0",
        "min-height" => "0",
        "padding" => "0",
        "margin" => "0"
    ),

    CSS(
        ".bonito-book-embedded .logging-widget, .real-book-container .logging-widget",
        "background-color" => "#f8f9fa",
        "color" => color_secondary,
        "font-family" => font_family_mono,
        "font-size" => "11px",
        "line-height" => "1.4"
    ),

    # Sidebar styling for academic book (scoped - but only for embedded use when container is present)
    CSS(
        ".bonito-book-embedded .sidebar-main-container, .real-book-container .sidebar-main-container",
        "position" => "relative",
        "right" => "auto",
        "top" => "auto",
        "transform" => "none",
        "z-index" => "auto",
        "display" => "none", # Hide sidebar in embedded mode
        "flex-direction" => "row-reverse",
        "pointer-events" => "none"
    ),

    CSS(
        ".bonito-book-embedded .sidebar-content-container, .real-book-container .sidebar-content-container",
        "background-color" => "#ffffff",
        "border" => "1px solid #e9ecef",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 8px rgba(0,0,0,0.1)",
        "max-width" => "100%",
        "max-height" => "none",
        "overflow" => "visible",
        "transition" => "none",
        "pointer-events" => "auto"
    ),

    CSS(
        ".bonito-book-embedded .sidebar-tabs, .real-book-container .sidebar-tabs",
        "background-color" => "#ffffff",
        "border" => "1px solid #e9ecef",
        "border-radius" => "8px",
        "padding" => "8px 4px",
        "display" => "flex",
        "flex-direction" => "row",
        "gap" => "4px",
        "pointer-events" => "auto"
    ),

    # File tabs academic styling (scoped)
    CSS(
        ".bonito-book-embedded .file-tabs-container, .real-book-container .file-tabs-container",
        "background-color" => "#f8f9fa",
        "border-bottom" => "1px solid #e9ecef",
        "padding" => "8px 16px",
        "display" => "flex",
        "gap" => "8px",
        "overflow-x" => "auto"
    ),

    CSS(
        ".bonito-book-embedded .file-tab, .real-book-container .file-tab",
        "background-color" => "#ffffff",
        "border" => "1px solid #dee2e6",
        "border-radius" => "6px",
        "padding" => "6px 12px",
        "cursor" => "pointer",
        "font-size" => "13px",
        "color" => color_secondary,
        "transition" => "all 0.2s ease",
        "white-space" => "nowrap"
    ),

    CSS(
        ".bonito-book-embedded .file-tab:hover, .real-book-container .file-tab:hover",
        "background-color" => "#f8f9fa",
        "border-color" => color_accent
    ),

    CSS(
        ".bonito-book-embedded .file-tab.active, .real-book-container .file-tab.active",
        "background-color" => color_accent,
        "border-color" => color_accent,
        "color" => "#ffffff",
        "font-weight" => "500"
    ),

    # Menu bar academic styling (scoped)
    CSS(
        ".bonito-book-embedded .book-main-menu, .real-book-container .book-main-menu",
        "background-color" => "#ffffff",
        "border-bottom" => "1px solid #e9ecef",
        "padding" => "8px 16px",
        "display" => "flex",
        "justify-content" => "center",
        "align-items" => "center",
        "gap" => "16px"
    ),

    CSS(
        ".bonito-book-embedded .small-menu-bar, .real-book-container .small-menu-bar",
        "background-color" => "#ffffff",
        "border" => "1px solid #e9ecef",
        "border-radius" => "6px",
        "padding" => "4px 8px",
        "display" => "flex",
        "gap" => "4px",
        "align-items" => "center",
        "box-shadow" => "0 2px 4px rgba(0,0,0,0.1)"
    ),

    # Toggle buttons (scoped)
    CSS(
        ".bonito-book-embedded .toggle-button, .real-book-container .toggle-button",
        "border" => "1px solid #dee2e6",
        "background-color" => "#ffffff"
    ),

    CSS(
        ".bonito-book-embedded .toggle-button.active, .real-book-container .toggle-button.active",
        "background-color" => color_accent,
        "color" => "#ffffff",
        "border-color" => color_accent
    ),

    CSS(
        ".bonito-book-embedded .small-button.toggled, .real-book-container .small-button.toggled",
        "background-color" => "#f8f9fa",
        "color" => color_secondary,
        "opacity" => "0.7"
    )
)
