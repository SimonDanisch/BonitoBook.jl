# Presentation Style - Makie Documentation Theme
# This file defines presentation-specific styling that gets applied on top of the base slideshow styles

using BonitoBook.Bonito: Styles, CSS

# Makie brand colors
MAKIE_PURPLE = "#6366F1"
MAKIE_BLUE = "#0EA5E9"
MAKIE_DARK = "#1E293B"
MAKIE_LIGHT = "#F8FAFC"

Styles(
    # Background and overall theming - higher specificity
    CSS(
        ".presentation-themed-slideshow .slideshow-container",
        "background" => "linear-gradient(135deg, $(MAKIE_LIGHT) 0%, #E2E8F0 100%)",
    ),
    CSS(
        ".presentation-themed-slideshow .slideshow-content",
        "background" => "linear-gradient(135deg, $(MAKIE_LIGHT) 0%, #E2E8F0 100%)",
    ),

    # Remove white backgrounds from markdown content
    CSS(
        ".presentation-themed-slideshow .slideshow-content .markdown-body",
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
    ),

    CSS(
        ".presentation-themed-slideshow .slideshow-content h2",
        "color" => MAKIE_PURPLE,
        "border-bottom" => "3px solid $(MAKIE_PURPLE)",
        "padding-bottom" => "0.5rem",
        "font-weight" => "700",
        "text-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)"
    ),

    CSS(
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
    ),

    CSS(
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
