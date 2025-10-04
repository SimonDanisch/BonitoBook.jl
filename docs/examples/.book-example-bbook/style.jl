

# Scientific Academic Book Styling - using proper BonitoBook CSS variables
realbook_styles = Styles(
    # Academic Book Container - clean, professional appearance
    CSS(
        ".real-book-container",
        "display" => "flex",
        "position" => "relative",
        "width" => "auto",
        "max-width" => "1400px",
        "margin" => "20px auto",
        "overflow" => "visible",
        "background-color" => "var(--bg-primary)",
        "border-radius" => "12px",
        "box-shadow" => "0 4px 20px rgba(0,0,0,0.08)",
        "border" => "1px solid var(--border-primary)"
    ),

    # Enhanced TOC Sidebar - scientific paper style
    CSS(
        ".book-toc-sidebar",
        "width" => "280px",
        "position" => "relative",
        "flex-shrink" => "0",
        "overflow-y" => "auto",
        "background" => "linear-gradient(180deg, var(--bg-primary) 0%, rgba(249,250,251,0.6) 100%)",
        "border-right" => "2px solid var(--border-primary)",
        "padding" => "20px",
        "align-self" => "stretch",
        "border-top-left-radius" => "12px",
        "border-bottom-left-radius" => "12px"
    ),

    # TOC Header - academic styling
    CSS(
        ".toc-header",
        "color" => "var(--text-primary)",
        "margin" => "0 0 24px 0",
        "font-size" => "1.1em",
        "font-weight" => "700",
        "letter-spacing" => "0.025em",
        "text-transform" => "uppercase",
        "border-bottom" => "3px solid var(--accent-blue)",
        "padding-bottom" => "8px",
        "position" => "relative"
    ),

    # TOC header accent line
    CSS(
        ".toc-header::after",
        "content" => "''",
        "position" => "absolute",
        "bottom" => "-2px",
        "left" => "0",
        "width" => "30%",
        "height" => "2px",
        "background" => "linear-gradient(90deg, var(--accent-blue), transparent)"
    ),

    # TOC Links - refined typography
    CSS(
        ".toc-link",
        "text-decoration" => "none",
        "color" => "var(--text-primary)",
        "transition" => "all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1)",
        "display" => "block",
        "padding" => "8px 12px",
        "border-radius" => "6px",
        "font-weight" => "400",
        "line-height" => "1.4",
        "border-left" => "3px solid transparent"
    ),

    # Level-specific styling
    CSS(
        ".toc-link.level-1",
        "font-size" => "1.0em",
        "font-weight" => "600",
        "margin-top" => "16px",
        "color" => "var(--accent-blue)"
    ),

    CSS(
        ".toc-link.level-2",
        "font-size" => "0.95em",
        "font-weight" => "500",
        "margin-top" => "8px"
    ),

    CSS(
        ".toc-link.level-3, .toc-link.level-4, .toc-link.level-5, .toc-link.level-6",
        "font-size" => "0.9em",
        "font-weight" => "400",
        "opacity" => "0.85"
    ),

    # Enhanced hover effects
    CSS(
        ".toc-link:hover",
        "background-color" => "rgba(59, 130, 246, 0.08)",
        "border-left-color" => "var(--accent-blue)",
        "color" => "var(--accent-blue)",
        "transform" => "translateX(4px)"
    ),

    # TOC Items
    CSS(
        ".toc-item",
        "margin-bottom" => "4px"
    ),

    # No headings message
    CSS(
        ".toc-no-headings",
        "font-style" => "italic",
        "color" => "var(--text-secondary)",
        "text-align" => "center",
        "padding" => "20px"
    ),

    # Main content area - academic layout
    CSS(
        ".academic-content",
        "width" => "100%",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "background-color" => "var(--bg-primary)"
    ),

    CSS(
        ".book-main-area",
        "flex" => "1",
        "padding" => "40px 60px",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center",
        "justify-content" => "flex-start",
        "min-width" => "0",
        "overflow" => "visible",
        "background-color" => "var(--bg-primary)"
    ),

    # Academic Footer - professional styling
    CSS(
        ".book-footer",
        "margin-top" => "60px",
        "padding" => "30px 0",
        "border-top" => "2px solid var(--border-primary)",
        "color" => "var(--text-secondary)",
        "font-size" => "0.85em",
        "text-align" => "center",
        "background" => "linear-gradient(0deg, rgba(249,250,251,0.3) 0%, var(--bg-primary) 100%)"
    ),

    CSS(
        ".book-footer p:first-child",
        "margin-bottom" => "8px",
        "font-weight" => "500"
    ),

    CSS(
        ".book-footer p:last-child",
        "font-style" => "italic",
        "opacity" => "0.8"
    ),

    # Responsive design for TOC
    CSS(
        "@media (max-width: 900px)",
        CSS(".book-toc-sidebar", "width" => "220px !important"),
        CSS(".book-main-area", "padding" => "20px 30px !important")
    ),

    # Dark theme adjustments
    CSS(
        "@media (prefers-color-scheme: dark)",
        CSS(
            ".book-toc-sidebar",
            "background" => "linear-gradient(180deg, var(--bg-primary) 0%, rgba(30,30,30,0.6) 100%)"
        ),
        CSS(
            ".book-footer",
            "background" => "linear-gradient(0deg, rgba(30,30,30,0.3) 0%, var(--bg-primary) 100%)"
        )
    )
)
# Generate base style with default settings
style = BonitoBook.generate_style(current_book(); light_theme=true)
# Combine with main BonitoBook styles
Styles(style, realbook_styles)
