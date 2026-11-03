# Generate base style with default settings

# Create plugin-specific styles for slideshow presentation
# Makie brand colors
MAKIE_PURPLE = "#6366F1"
MAKIE_BLUE = "#0EA5E9"
MAKIE_DARK = "#1E293B"
MAKIE_LIGHT = "#F8FAFC"

presentation_style = Styles(
    # Background and overall theming - higher specificity
    CSS(
        ".presentation-themed-slideshow .slideshow-container",
        "background" => "linear-gradient(135deg, $(MAKIE_LIGHT) 0%, #E2E8F0 100%)",
    ),
    CSS(
        ".presentation-themed-slideshow .slideshow-content",
        "background" => "linear-gradient(135deg, $(MAKIE_LIGHT) 0%, #E2E8F0 100%)",
    ),

    # Remove white backgrounds from markdown content - all possible classes
    CSS(
        ".presentation-themed-slideshow .slideshow-content .markdown-body",
        "background-color" => "transparent !important",
        "background" => "none !important",
        "border" => "none !important",
        "box-shadow" => "none !important",
        "padding" => "0 !important"
    ),

    # Target markdown cell containers
    CSS(
        ".presentation-themed-slideshow .slideshow-content .markdown-cell",
        "background-color" => "transparent !important",
        "background" => "none !important",
        "border" => "none !important",
        "box-shadow" => "none !important"
    ),

    # Target markdown display containers
    CSS(
        ".presentation-themed-slideshow .slideshow-content .markdown-display",
        "background-color" => "transparent !important",
        "background" => "none !important",
        "border" => "none !important",
        "box-shadow" => "none !important",
        "padding" => "0 !important"
    ),

    # Remove white backgrounds from any card containers
    CSS(
        ".presentation-themed-slideshow .slideshow-content .card",
        "background-color" => "transparent !important",
        "background" => "none !important",
        "border" => "none !important",
        "box-shadow" => "none !important"
    ),

    # Makie logo/branding area in top right - improved alignment and size
    CSS(
        ".presentation-themed-slideshow .slideshow-branding",
        "position" => "fixed",
        "top" => "24px",
        "right" => "32px",
        "z-index" => "1000",
        "color" => MAKIE_PURPLE,
        "font-family" => "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
        "font-weight" => "700",
        "font-size" => "20px",
        "opacity" => "0.9",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "8px"
    ),

    # Logo image styling
    CSS(
        ".presentation-themed-slideshow .slideshow-branding img",
        "height" => "28px !important",
        "width" => "auto !important",
        "margin" => "0 !important",
        "vertical-align" => "middle"
    ),

    # Headings with improved styling and higher specificity
    CSS(
        ".presentation-themed-slideshow .slideshow-content h1",
        "color" => MAKIE_DARK,
        "text-shadow" => "0 1px 3px rgba(0, 0, 0, 0.1)",
        "font-weight" => "800"
    ), CSS(
        ".presentation-themed-slideshow .slideshow-content h2",
        "color" => MAKIE_PURPLE,
        "border-bottom" => "3px solid $(MAKIE_PURPLE)",
        "padding-bottom" => "0.5rem",
        "font-weight" => "700",
        "text-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)"
    ), CSS(
        ".presentation-themed-slideshow .slideshow-content h3",
        "color" => MAKIE_BLUE,
        "font-weight" => "600"
    ),

    # Enhanced paragraph styling
    CSS(
        ".presentation-themed-slideshow .slideshow-content p",
        "color" => MAKIE_DARK,
        "line-height" => "1.7",
        "text-shadow" => "0 1px 1px rgba(0, 0, 0, 0.05)"
    ),

    # Remove white backgrounds from code containers without heavy styling
    CSS(
        ".presentation-themed-slideshow .slideshow-content .cell-editor-container",
        "background" => "transparent !important",
        "border" => "none !important",
        "box-shadow" => "none !important"
    ),
    # Code editor specific styling - minimal
    CSS(
        ".presentation-themed-slideshow .slideshow-content .cell-editor",
        "background" => "rgba(255, 255, 255, 0.85) !important",
        "border" => "1px solid rgba(99, 102, 241, 0.2) !important",
        "border-radius" => "6px !important",
        "box-shadow" => "0 2px 8px rgba(0, 0, 0, 0.1) !important"
    ),

    # Enhanced progress bar with Makie colors
    CSS(
        ".presentation-themed-slideshow .progress-bar",
        "background" => "linear-gradient(90deg, $(MAKIE_PURPLE), $(MAKIE_BLUE))",
        "box-shadow" => "0 2px 4px rgba(99, 102, 241, 0.3)",
        "border-radius" => "2px 2px 0 0"
    ),

    # Progress container hover effect
    CSS(
        ".presentation-themed-slideshow .progress-container:hover .progress-bar",
        "box-shadow" => "0 4px 8px rgba(99, 102, 241, 0.4)"
    ),

    # Enhanced footer styling
    CSS(
        ".presentation-themed-slideshow .slideshow-footer",
        "position" => "fixed",
        "bottom" => "32px",
        "left" => "32px",
        "z-index" => "1000",
        "color" => MAKIE_DARK,
        "font-family" => "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
        "font-size" => "14px",
        "font-weight" => "500",
        "opacity" => "0.7",
        "background" => "rgba(255, 255, 255, 0.8)",
        "padding" => "8px 12px",
        "border-radius" => "6px",
        "backdrop-filter" => "blur(5px)",
        "border" => "1px solid rgba(99, 102, 241, 0.1)"
    ),

    # List styling improvements
    CSS(
        ".presentation-themed-slideshow .slideshow-content ul, .presentation-themed-slideshow .slideshow-content ol",
        "color" => MAKIE_DARK,
        "line-height" => "1.8"
    ), CSS(
        ".presentation-themed-slideshow .slideshow-content li",
        "margin-bottom" => "0.5rem",
        "color" => MAKIE_DARK
    ),

    # Code inline styling
    CSS(
        ".presentation-themed-slideshow .slideshow-content code:not(.monaco-editor code)",
        "background" => "rgba(99, 102, 241, 0.1) !important",
        "color" => MAKIE_PURPLE,
        "padding" => "2px 6px !important",
        "border-radius" => "4px !important",
        "font-weight" => "600"
    )
)


slideshow_styles = Styles(
    # Main slideshow container
    CSS(
        ":where(.slideshow-container)",
        "position" => "relative",
        "width" => "100%",
        "min-height" => "100vh",
        "overflow" => "visible"
    ),

    # Content container - optimized for presentation (only apply within slideshow-container)
    CSS(
        ":where(.slideshow-container .slideshow-content)",
        "padding" => "80px 120px calc(100vh - 200px) 120px", # Bottom padding ensures last slide can scroll to top
        "scroll-behavior" => "smooth",
        "line-height" => "1.6",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center", # Center content horizontally
    ),

    # HR elements create large gaps to separate slides
    CSS(
        ".slideshow-container .slideshow-content hr",
        "margin" => "100vh 0", # Full viewport height margins
        "border" => "none",
        "height" => "2px",
        "opacity" => "0.3"
    ),

    # Progress bar with hover area
    CSS(
        ":where(.progress-bar)",
        "position" => "fixed",
        "bottom" => "0",
        "left" => "0",
        "height" => "6px",
        "background-color" => "var(--accent-blue)",
        "transition" => "width 0.5s ease, height 0.2s ease",
        "z-index" => "1000",
        "cursor" => "pointer"
    ),

    # Progress bar container for tooltip
    CSS(
        ".progress-container",
        "position" => "fixed",
        "bottom" => "0",
        "left" => "0",
        "right" => "0",
        "height" => "20px",
        "background-color" => "rgba(0,0,0,0.1)",
        "z-index" => "999",
        "cursor" => "pointer"
    ),

    CSS(
        ".progress-container:hover .progress-bar",
        "height" => "10px"
    ),

    # Presentation-optimized content styling
    CSS(
        ":where(.slideshow-content :is(h1, h2, h3, h4, h5, h6))",
        "color" => "var(--text-primary)",
        "font-weight" => "600",
        "text-align" => "center",
        "width" => "100%"
    ),

    CSS(
        ":where(.slideshow-content h1)",
        "font-size" => "3.5rem",
        "font-weight" => "700",
        "margin" => "1rem 0 2rem 0",
        "line-height" => "1.2"
    ),

    CSS(
        ":where(.slideshow-content h2)",
        "font-size" => "2.8rem",
        "margin" => "1rem 0",
        "line-height" => "1.3"
    ),

    CSS(
        ":where(.slideshow-content h3)",
        "font-size" => "2.2rem",
        "margin" => "0.8rem 0",
        "line-height" => "1.3"
    ),

    CSS(
        ":where(.slideshow-content :is(h4, h5, h6))",
        "font-size" => "1.6rem",
        "margin" => "0.8rem 0 1rem 0"
    ),

    CSS(
        ".slideshow-content :is(p, li)",
        "color" => "var(--text-primary)",
        "font-size" => "1.3rem",
        "line-height" => "1.6"
    ),

    # Code blocks - optimized for presentation, override base width constraints
    CSS(
        ".slideshow-content > div",
        "width" => "95%",
        "max-width" => "1000px"
    ),
    CSS(
        ":where(.slideshow-content .cell-editor-container)",
        "width" => "95%",
        "max-width" => "1000px",
    ),
    # Keep markdown content width aligned with code cell width
    CSS(
        ".slideshow-content .cell-output-markdown, .slideshow-content .cell-output-markdown .markdown-body",
        "width" => "95%",
        "max-width" => "1000px",
        "margin-left" => "auto",
        "margin-right" => "auto"
    ),

    # Markdown headings - apply to any markdown content
    CSS(
        ".slideshow-content h1",
        "font-size" => "3.5rem"
    ),

    CSS(
        ".slideshow-content h2",
        "font-size" => "2.8rem"
    ),

    CSS(
        ".slideshow-content h3",
        "font-size" => "2.2rem"
    ),

    CSS(
        ".slideshow-content p",
        "font-size" => "1.3rem",
        "margin-bottom" => "1.5rem"
    ),

    # Hide hover menu in presentation mode
    CSS(
        ".presentation-themed-slideshow .hover-buttons",
        "display" => "none !important"
    ),
    CSS(
        ".presentation-themed-slideshow .new-cell-menu, .presentation-themed-slideshow .new-cell-plus",
        "display" => "none !important"
    ),

    # Center and fix cell output to fit content
    CSS(
        ".slideshow-content .cell-output:not(.cell-output-markdown)",
        "width" => "fit-content",
        "max-width" => "95%",
        "margin-left" => "auto",
        "margin-right" => "auto"
    ),

    # Center cell editor
    CSS(
        ".slideshow-content .cell-editor",
        "margin-left" => "auto !important",
        "margin-right" => "auto !important"
    ),

    # Large screen optimizations for presentations
    CSS(
        "@media (min-width: 1600px)",
        CSS(
            ".slideshow-content h1",
            "font-size" => "4.5rem"
        ),
        CSS(
            ".slideshow-content h2",
            "font-size" => "3.5rem"
        ),
        CSS(
            ".slideshow-content h3",
            "font-size" => "2.8rem"
        ),
        CSS(
            ".slideshow-content :is(p, li)",
            "font-size" => "1.6rem",
            "line-height" => "1.8"
        ),
        CSS(
            ".slideshow-content > div",
            "width" => "95%",
            "max-width" => "1600px"
        ),
        CSS(
            ".slideshow-content .cell-editor-container",
            "width" => "95%",
            "max-width" => "1600px"
        ),
        CSS(
            ".slideshow-content .cell-output",
            "max-width" => "1600px"
        ),
        CSS(
            ".slideshow-content .cell-output-markdown, .slideshow-content .cell-output-markdown .markdown-body",
            "max-width" => "1600px"
        ),
        # Larger code font for presentations
        CSS(
            ".slideshow-content .monaco-editor, .slideshow-content .cell-editor",
            "font-size" => "16px !important"
        ),
        CSS(
            ".slideshow-content .view-lines",
            "font-size" => "16px !important"
        ),
        # NDViewer widget scaling for large screens
        CSS(
            ".slideshow-content .ndviewer-widgets",
            "padding" => "8px 16px",
            "gap" => "4px 20px"
        ),
        CSS(
            ".slideshow-content .ndviewer-lbl",
            "font-size" => "16px"
        ),
        CSS(
            ".slideshow-content .ndviewer-val",
            "font-size" => "15px"
        ),
        CSS(
            ".slideshow-content .ndviewer-play-btn",
            "width" => "32px",
            "height" => "32px",
            "font-size" => "14px"
        ),
        CSS(
            ".slideshow-content .ndviewer-slider-wrap",
            "min-width" => "160px"
        ),
    ),

    # Extra large screens (4K, projectors)
    CSS(
        "@media (min-width: 2400px)",
        CSS(
            ".slideshow-content h1",
            "font-size" => "5.5rem"
        ),
        CSS(
            ".slideshow-content h2",
            "font-size" => "4.2rem"
        ),
        CSS(
            ".slideshow-content h3",
            "font-size" => "3.2rem"
        ),
        CSS(
            ".slideshow-content :is(p, li)",
            "font-size" => "2rem",
            "line-height" => "1.9"
        ),
        CSS(
            ".slideshow-content > div",
            "width" => "90%",
            "max-width" => "2200px"
        ),
        CSS(
            ".slideshow-content .cell-editor-container",
            "width" => "90%",
            "max-width" => "2200px"
        ),
        CSS(
            ".slideshow-content .cell-output",
            "max-width" => "2200px"
        ),
        CSS(
            ".slideshow-content .cell-output-markdown, .slideshow-content .cell-output-markdown .markdown-body",
            "max-width" => "2200px"
        ),
        # Even larger code font for 4K
        CSS(
            ".slideshow-content .monaco-editor, .slideshow-content .cell-editor",
            "font-size" => "20px !important"
        ),
        CSS(
            ".slideshow-content .view-lines",
            "font-size" => "20px !important"
        ),
        # NDViewer widget scaling for extra large screens
        CSS(
            ".slideshow-content .ndviewer-widgets",
            "padding" => "12px 24px",
            "gap" => "6px 28px"
        ),
        CSS(
            ".slideshow-content .ndviewer-lbl",
            "font-size" => "20px"
        ),
        CSS(
            ".slideshow-content .ndviewer-val",
            "font-size" => "18px"
        ),
        CSS(
            ".slideshow-content .ndviewer-play-btn",
            "width" => "40px",
            "height" => "40px",
            "font-size" => "18px"
        ),
        CSS(
            ".slideshow-content .ndviewer-slider-wrap",
            "min-width" => "200px"
        ),
    ),

    # Images and figures - exclude button icons
    CSS(
        ".slideshow-content :is(img, svg):not(.small-button *):not(.codicon svg)",
        "max-width" => "100%",
        "height" => "auto",
        "margin" => "1rem 0",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 8px rgba(0, 0, 0, 0.1)"
    ),

)

"""
    generate_style(book; kwargs...)

Generate slideshow styles by composing BonitoBook base styles with slideshow-specific styling.
"""
function generate_style(book; kwargs...)
    base_style = BonitoBook.generate_style(book;
        light_theme=true,
        editor_width="80vw",
        editor_max_width="1600px",
        kwargs...
    )

    # Override base styles to be scoped to slideshow when embedded
    slideshow_scoped_style = Styles(
        # Scope body styles to slideshow container instead of global body
        CSS(
            ".presentation-themed-slideshow",
            "font-family" => "'Inter', 'Roboto', 'Arial', sans-serif",
            "background-color" => "var(--bg-primary)",
            "color" => "var(--text-primary)",
            "margin" => "0"
        ),
        # Scope pre styles to slideshow container
        CSS(
            ".presentation-themed-slideshow pre",
            "margin-block" => "5px 0px",
            "font-family" => "'Consolas', 'Monaco', 'Courier New', monospace"
        ),
    )

    return Styles(base_style, slideshow_scoped_style, slideshow_styles, presentation_style)
end
