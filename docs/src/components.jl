# BonitoBook-style components for the documentation website

using BonitoBook
using BonitoBook: Styles, CSS, DOM

# Header component with BonitoBook styling
function Header(title::String)
    return DOM.header(
        DOM.div(
            DOM.h1(title, class="header-title"),
            class="header-content"
        ),
        class="bonitobook-header"
    )
end

# Navigation bar component
function NavBar(items::Vector{Pair{String,String}})
    nav_items = map(items) do (label, href)
        DOM.a(
            label,
            href=Bonito.Link(href),
            class="nav-item"
        )
    end

    return DOM.nav(
        nav_items...,
        class="bonitobook-navbar"
    )
end

# Card component for examples
function ExampleCard(title::AbstractString, description::AbstractString, route_prefix::AbstractString="")
    return DOM.div(
        DOM.h3(titlecase(title), class="example-title"),
        DOM.p(description, class="example-description"),
        DOM.a(
            "Open Example",
            href=Bonito.Link("$(route_prefix)/$(title)"),
            class="example-link"
        ),
        class="example-card"
    )
end

# Page wrapper with consistent layout
function Page(content, title::String="BonitoBook")
    header = Header("BonitoBook")
    navbar = NavBar([
        "Home" => "/",
        "Examples" => "/examples",
        "How-To" => "/howto",
        "Blog" => "/blog"
    ])

    return DOM.div(
        PageStyles,
        header,
        navbar,
        DOM.main(
            content,
            class="main-content"
        ),
        class="bonitobook-page"
    )
end

# Define page styles using BonitoBook's approach - directly matching style.jl
const PageStyles = Styles(
    # Website-specific variables
    CSS(
        ":root",
        "--header-height" => "80px",
        "--navbar-height" => "50px",
        "--content-padding" => "40px",
        "--card-gap" => "20px",
        "--max-content-width" => "1200px",
    ),

    # Light theme colors - matching BonitoBook exactly
    CSS(
        "@media (prefers-color-scheme: light)",
        CSS(
            ":root",
            "--site-bg-primary" => "#ffffff",
            "--site-text-primary" => "#24292e",
            "--site-text-secondary" => "#555555",
            "--site-border-primary" => "rgba(0, 0, 0, 0.1)",
            "--site-border-secondary" => "#ccc",
            "--site-shadow-soft" => "0 4px 8px rgba(0, 0, 51, 0.2)",
            "--site-shadow-button" => "0 2px 4px rgba(0, 0, 0, 0.2)",
            "--site-shadow-inset" => "inset 2px 2px 5px rgba(0, 0, 0, 0.5)",
            "--site-hover-bg" => "#ddd",
            "--site-menu-hover-bg" => "rgba(0, 0, 0, 0.05)",
            "--site-accent-blue" => "#0366d6",
            "--site-animation-glow" => "0 0 20px rgba(0, 150, 51, 0.8)",
            "--site-icon-color" => "#666666",
            "--site-icon-hover-color" => "#333333",
            "--site-icon-filter" => "none",
            "--site-icon-hover-filter" => "brightness(0.7)",
            "--site-scrollbar-track" => "#f1f1f1",
            "--site-scrollbar-thumb" => "#c1c1c1",
            "--site-scrollbar-thumb-hover" => "#a8a8a8",
        )
    ),

    # Dark theme colors - matching BonitoBook exactly
    CSS(
        "@media (prefers-color-scheme: dark)",
        CSS(
            ":root",
            "--site-bg-primary" => "#1e1e1e",
            "--site-text-primary" => "rgb(212, 212, 212)",
            "--site-text-secondary" => "rgb(212, 212, 212)",
            "--site-border-primary" => "rgba(255, 255, 255, 0.1)",
            "--site-border-secondary" => "rgba(255, 255, 255, 0.1)",
            "--site-shadow-soft" => "0 4px 8px rgba(255, 255, 255, 0.2)",
            "--site-shadow-button" => "0 2px 4px rgba(255, 255, 255, 0.2)",
            "--site-shadow-inset" => "inset 2px 2px 3px rgba(0, 0, 0, 0.5)",
            "--site-hover-bg" => "rgba(255, 255, 255, 0.1)",
            "--site-menu-hover-bg" => "rgba(255, 255, 255, 0.05)",
            "--site-accent-blue" => "#0366d6",
            "--site-animation-glow" => "0 0 20px rgba(10, 155, 55, 0.5)",
            "--site-icon-color" => "#cccccc",
            "--site-icon-hover-color" => "#ffffff",
            "--site-icon-filter" => "invert(1)",
            "--site-icon-hover-filter" => "invert(1) brightness(1.2)",
            "--site-scrollbar-track" => "#2d2d2d",
            "--site-scrollbar-thumb" => "#555555",
            "--site-scrollbar-thumb-hover" => "#777777",
        )
    ),
    # Global reset and base styles
    CSS(
        "*",
        "box-sizing" => "border-box"
    ),
    CSS(
        "html",
        "background-color" => "var(--site-bg-primary)",
        "color" => "var(--site-text-primary)"
    ),
    CSS(
        "body",
        "margin" => "0",
        "padding" => "0",
        "font-family" => "'Inter', 'Roboto', 'Arial', sans-serif",
        "background-color" => "var(--site-bg-primary)",
        "color" => "var(--site-text-primary)",
        "line-height" => "1.6"
    ),
    CSS(
        "*",
        "color" => "inherit"
    ),
    CSS(
        "a",
        "text-decoration" => "none",
        "color" => "inherit"
    ),

    # BonitoBook scrollbar styling
    CSS(
        "::-webkit-scrollbar",
        "width" => "12px"
    ),
    CSS(
        "::-webkit-scrollbar-track",
        "background" => "var(--site-scrollbar-track)"
    ),
    CSS(
        "::-webkit-scrollbar-thumb",
        "background-color" => "var(--site-scrollbar-thumb)",
        "border-radius" => "6px",
        "border" => "2px solid var(--site-scrollbar-track)"
    ),
    CSS(
        "::-webkit-scrollbar-thumb:hover",
        "background-color" => "var(--site-scrollbar-thumb-hover)"
    ),
    # Firefox scrollbar
    CSS(
        "*",
        "scrollbar-width" => "thin",
        "scrollbar-color" => "var(--site-scrollbar-thumb) var(--site-scrollbar-track)"
    ),

    # Header styles with gradient
    CSS(
        ".bonitobook-header",
        "background" => "linear-gradient(135deg, var(--site-bg-primary) 0%, var(--site-menu-hover-bg) 100%)",
        "border-bottom" => "1px solid var(--site-border-primary)",
        "height" => "var(--header-height)",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "box-shadow" => "var(--site-shadow-soft)",
        "backdrop-filter" => "blur(10px)",
        "position" => "relative"
    ),
    CSS(
        ".bonitobook-header::before",
        "content" => "''",
        "position" => "absolute",
        "top" => "0",
        "left" => "0",
        "right" => "0",
        "bottom" => "0",
        "background" => "var(--site-animation-glow)",
        "opacity" => "0.03",
        "pointer-events" => "none"
    ),
    CSS(
        ".header-content",
        "width" => "100%",
        "max-width" => "var(--max-content-width)",
        "padding" => "0 var(--content-padding)"
    ),
    CSS(
        ".header-title",
        "margin" => "0",
        "font-size" => "2.5rem",
        "font-weight" => "700",
        "color" => "var(--site-text-primary)"
    ),

    # Navigation styles
    CSS(
        ".bonitobook-navbar",
        "background-color" => "var(--site-bg-primary)",
        "border-bottom" => "1px solid var(--site-border-primary)",
        "padding" => "0 40px",
        "height" => "var(--navbar-height)",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "position" => "sticky",
        "top" => "0",
        "z-index" => "100",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.05)"
    ),
    CSS(
        ".nav-items",
        "display" => "flex",
        "width" => "100%",
    ),
    CSS(
        ".nav-item",
        "text-decoration" => "none",
        "color" => "var(--site-text-primary)",
        "font-weight" => "500",
        "padding" => "10px 16px",
        "border-radius" => "6px",
        "transition" => "all 0.2s ease",
        "white-space" => "nowrap"
    ),
    CSS(
        ".nav-item:hover",
        "background-color" => "var(--site-hover-bg)",
        "color" => "var(--site-accent-blue)"
    ),

    # Main content styles
    CSS(
        ".bonitobook-page",
        "min-height" => "100vh",
        "width" => "100%",
        "background-color" => "var(--site-bg-primary)",
        "color" => "var(--site-text-primary)"
    ),
    CSS(
        ".main-content",
        "margin" => "0 auto",
    ),

    # Hero section styles
    CSS(
        ".hero-section",
        "text-align" => "center",
        "padding" => "60px 0",
        "border-bottom" => "1px solid var(--site-border-primary)"
    ),
    CSS(
        ".hero-title",
        "font-size" => "3rem",
        "font-weight" => "700",
        "margin-bottom" => "20px",
        "color" => "var(--site-text-primary)"
    ),
    CSS(
        ".hero-subtitle",
        "font-size" => "1.25rem",
        "color" => "var(--site-text-secondary)",
        "max-width" => "600px",
        "margin" => "0 auto 40px"
    ),
    CSS(
        ".hero-buttons",
        "display" => "flex",
        "gap" => "20px",
        "justify-content" => "center"
    ),
    # BonitoBook-style buttons
    CSS(
        ".hero-button",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center",
        "background-color" => "var(--site-accent-blue)",
        "color" => "white",
        "padding" => "12px 24px",
        "border-radius" => "8px",
        "text-decoration" => "none",
        "font-weight" => "500",
        "transition" => "all 0.2s ease",
        "border" => "none",
        "cursor" => "pointer",
        "box-shadow" => "var(--site-shadow-button)",
        "font-size" => "16px",
        "font-family" => "inherit",
        "min-width" => "120px"
    ),
    CSS(
        ".hero-button:hover",
        "background-color" => "var(--site-hover-bg)",
        "color" => "var(--site-accent-blue)",
        "transform" => "translateY(-1px)",
        "box-shadow" => "0 4px 12px rgba(3, 102, 214, 0.3)"
    ),
    CSS(
        ".hero-button:active",
        "transform" => "translateY(0px)",
        "box-shadow" => "var(--site-shadow-inset)"
    ),
    CSS(
        ".hero-button-secondary",
        "background-color" => "var(--site-bg-primary)",
        "color" => "var(--site-text-primary)",
        "border" => "1px solid var(--site-border-secondary)",
        "box-shadow" => "var(--site-shadow-button)"
    ),
    CSS(
        ".hero-button-secondary:hover",
        "background-color" => "var(--site-hover-bg)",
        "border-color" => "var(--site-accent-blue)",
        "color" => "var(--site-accent-blue)",
        "transform" => "translateY(-1px)"
    ),

    # Example card styles
    CSS(
        ".examples-grid",
        "display" => "grid",
        "grid-template-columns" => "repeat(auto-fill, minmax(300px, 1fr))",
        "gap" => "var(--card-gap)",
        "margin-top" => "40px"
    ),
    CSS(".example-content",
        "max-width" => "1200px",
        "margin" => "0 auto",
        "padding" => "var(--content-padding)"
    ),
    CSS(
        ".example-card",
        "background-color" => "var(--site-bg-primary)",
        "border" => "1px solid var(--site-border-primary)",
        "border-radius" => "10px",
        "padding" => "24px",
        "transition" => "all 0.2s ease-out",
        "box-shadow" => "var(--site-shadow-soft)",
        "position" => "relative",
        "overflow" => "hidden",
        "width" => "fit-content",
        "max-width" => "400px",
    ),
    CSS(
        ".example-card:hover",
        "transform" => "translateY(-2px)",
        "box-shadow" => "var(--site-animation-glow)",
        "border-color" => "var(--site-accent-blue)"
    ),
    CSS(
        ".example-card::before",
        "content" => "''",
        "position" => "absolute",
        "top" => "0",
        "left" => "-100%",
        "width" => "100%",
        "height" => "2px",
        "background" => "linear-gradient(90deg, transparent, var(--site-accent-blue), transparent)",
        "transition" => "left 0.5s ease"
    ),
    CSS(
        ".example-card:hover::before",
        "left" => "100%"
    ),
    CSS(
        ".example-title",
        "margin" => "0 0 12px 0",
        "font-size" => "1.25rem",
        "font-weight" => "600",
        "color" => "var(--site-text-primary)"
    ),
    CSS(
        ".example-description",
        "margin" => "0 0 20px 0",
        "color" => "var(--site-text-secondary)",
        "line-height" => "1.6"
    ),
    CSS(
        ".example-link",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center",
        "background-color" => "var(--site-bg-primary)",
        "color" => "var(--site-accent-blue)",
        "text-decoration" => "none",
        "font-weight" => "500",
        "padding" => "8px 16px",
        "border" => "1px solid var(--site-accent-blue)",
        "border-radius" => "8px",
        "transition" => "all 0.2s ease",
        "box-shadow" => "var(--site-shadow-button)",
        "font-size" => "14px",
        "min-width" => "100px"
    ),
    CSS(
        ".example-link:hover",
        "background-color" => "var(--site-accent-blue)",
        "color" => "white",
        "transform" => "translateY(-1px)",
        "box-shadow" => "0 4px 12px rgba(3, 102, 214, 0.3)"
    ),
    CSS(
        ".example-link:active",
        "transform" => "translateY(0px)",
        "box-shadow" => "var(--site-shadow-inset)"
    ),

    # Blog styles
    CSS(
        ".blog-content",
        "max-width" => "800px",
        "margin" => "0 auto",
        "padding" => "var(--content-padding)",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center"
    ),
    CSS(
        ".blog-list",
        "width" => "100%",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "24px",
        "margin-top" => "40px"
    ),
    CSS(
        ".blog-card",
        "width" => "100%",
        "background-color" => "var(--site-bg-primary)",
        "border" => "1px solid var(--site-border-primary)",
        "border-radius" => "10px",
        "padding" => "24px",
        "transition" => "all 0.2s ease",
        "box-shadow" => "var(--site-shadow-soft)"
    ),
    CSS(
        ".blog-card:hover",
        "box-shadow" => "var(--site-animation-glow)",
        "border-color" => "var(--site-accent-blue)"
    ),

    # Section styles
    CSS(
        ".section",
        "margin" => "60px 0"
    ),
    CSS(
        ".section-title",
        "font-size" => "2rem",
        "font-weight" => "700",
        "margin-bottom" => "20px",
        "color" => "var(--site-text-primary)"
    ),
    CSS(
        ".section-content",
        "color" => "var(--site-text-secondary)",
        "line-height" => "1.8",
        "font-size" => "1.1rem"
    ), CSS(
        "code",
        "font-family" => "'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace",
        "font-size" => "0.9em",
        "background-color" => "var(--site-menu-hover-bg)",
        "padding" => "2px 6px",
        "border-radius" => "4px",
        "border" => "1px solid var(--site-border-primary)"
    ),
    CSS(
        "pre code",
        "background-color" => "transparent",
        "padding" => "0",
        "border" => "none"
    ),
    # Dark theme code adjustments
    CSS(
        "@media (prefers-color-scheme: dark)",
        CSS(
            "code",
            "background-color" => "var(--site-menu-hover-bg)",
            "color" => "var(--site-text-primary)"
        )
    ),

    # Getting Started InlineBook styling
    CSS(
        ".getting-started-inline",
        "background-color" => "var(--site-bg-primary)",
        "border" => "1px solid var(--site-border-primary)",
        "border-radius" => "10px",
        "padding" => "30px",
        "margin-top" => "20px",
        "box-shadow" => "var(--site-shadow-soft)"
    ),
    CSS(
        ".getting-started-inline .cell-editor-container",
        "margin-bottom" => "20px",
        "width" => "100% !important",
        "max-width" => "100% !important",
        "min-width" => "0 !important"
    ),
    CSS(
        ".getting-started-inline .cell-editor",
        "width" => "100% !important",
        "max-width" => "100% !important"
    ),
    CSS(
        ".getting-started-inline .book-cells-area .fit-content",
        "width" => "100% !important",
        "max-width" => "100% !important"
    ),
    CSS(
        ".getting-started-inline .cell-output",
        "background-color" => "var(--site-menu-hover-bg)",
        "border-radius" => "6px",
        "border" => "1px solid var(--site-border-primary)"
    ),
    CSS(
        ".getting-started-inline .hover-buttons",
        "display" => "none !important"
    ),
    CSS(
        ".getting-started-inline .new-cell-menu",
        "display" => "none !important"
    ),

    # Responsive design
    CSS(
        "@media (max-width: 768px)",
        CSS(".hero-title", "font-size" => "2rem !important"),
        CSS(".hero-subtitle", "font-size" => "1rem !important"),
        CSS(".hero-buttons", "flex-direction" => "column", "align-items" => "center"),
        CSS(".examples-grid", "grid-template-columns" => "1fr !important"),
        CSS(":root", "--content-padding" => "20px"),
        CSS(".getting-started-inline", "padding" => "20px"),
        # Force embedded books to use container width, not viewport width
        CSS(
            ".getting-started-inline .markdown-body",
            "max-width" => "100% !important",
            "overflow-wrap" => "break-word !important"
        ),
        CSS(
            ".getting-started-inline .markdown-body *",
            "max-width" => "100% !important"
        )
    ),
    CSS(
        "@media (max-width: 480px)",
        CSS(
            ".getting-started-inline .cell-editor",
            "padding" => "5px !important"
        ),
        CSS(
            ".getting-started-inline .book-cells-area",
            "padding" => "10px !important"
        )
    )
)
