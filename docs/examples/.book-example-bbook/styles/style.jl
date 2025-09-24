

# Create plugin-specific styles for RealBook academic layout
realbook_styles = Styles(
    # RealBook Academic Layout Styles - uses global CSS variables
    CSS(
        ".real-book-container",
        "display" => "flex",
        "position" => "relative",
        "width" => "auto",
        "max-width" => "1200px",
        "margin" => "20px auto",
        "overflow" => "visible",
        "background-color" => "var(--bg-color)",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 12px rgba(0,0,0,0.1)"
    ),
    CSS(
        ".book-toc-sidebar",
        "width" => "200px",
        "position" => "relative",
        "flex-shrink" => "0",
        "overflow-y" => "auto",
        "background-color" => "var(--sidebar-bg)",
        "border-right" => "1px solid var(--border-color)",
        "padding" => "12px",
        "align-self" => "stretch"
    ),
    CSS(
        ".academic-content",
        "width" => "100%",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center"
    ),
    CSS(
        ".book-main-area",
        "flex" => "1",
        "padding" => "20px",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "justify-content" => "flex-start",
        "min-width" => "0",
        "overflow" => "visible"
    ),
    CSS(
        ".toc-link",
        "text-decoration" => "none",
        "color" => "var(--primary-color)",
        "transition" => "all 0.2s",
        "display" => "block",
        "padding" => "4px 8px",
        "border-radius" => "4px"
    ),
    CSS(
        ".toc-link.level-1, .toc-link.level-2",
        "font-size" => "0.95em",
        "font-weight" => "500"
    ),
    CSS(
        ".toc-link.level-3, .toc-link.level-4, .toc-link.level-5, .toc-link.level-6",
        "font-size" => "0.9em",
        "font-weight" => "normal"
    ),
    CSS(
        ".toc-link:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--primary-hover)"
    ),
    CSS(
        ".toc-item",
        "margin-bottom" => "2px"
    ),
    CSS(
        ".toc-no-headings",
        "font-style" => "italic",
        "color" => "var(--muted-text)",
        "text-align" => "center"
    ),
    CSS(
        ".toc-header",
        "color" => "var(--text-color)",
        "margin-bottom" => "1.5em",
        "font-size" => "1.2em",
        "font-weight" => "bold",
        "border-bottom" => "2px solid var(--primary-color)",
        "padding-bottom" => "0.5em"
    ),
    CSS(
        ".book-footer",
        "margin-top" => "4em",
        "padding" => "2em",
        "border-top" => "1px solid var(--border-color)",
        "color" => "var(--muted-text)",
        "font-size" => "0.9em",
        "text-align" => "center"
    ),
    CSS(
        ".book-footer p:first-child",
        "margin-bottom" => "0.5em"
    ),
    CSS(
        ".book-footer p:last-child",
        "font-style" => "italic"
    ),
)
# Generate base style with default settings
style = BonitoBook.generate_style(current_book(); light_theme=true)
# Combine with main BonitoBook styles
Styles(style, realbook_styles)
