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
function NavBar(items::Vector{Pair{String, String}})
    nav_items = map(items) do (label, href)
        DOM.a(
            label,
            href=href,
            class="nav-item"
        )
    end

    return DOM.nav(
        DOM.div(nav_items..., class="nav-items"),
        class="bonitobook-navbar"
    )
end

# Card component for examples
function ExampleCard(title::AbstractString, description::AbstractString)
    return DOM.div(
        DOM.h3(title, class="example-title"),
        DOM.p(description, class="example-description"),
        DOM.a(
            "Open Example",
            href="/$(title)",
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
        "Examples" => "/examples"
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
        "@media (prefers-color-scheme: light), (prefers-color-scheme: no-preference)",
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

    # Dark theme colors - matching BonitoBook exactly
    CSS(
        "@media (prefers-color-scheme: dark)",
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
    # Global reset and base styles
    CSS(
        "*",
        "box-sizing" => "border-box"
    ),
    CSS(
        "html",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        "body",
        "margin" => "0",
        "padding" => "0",
        "font-family" => "'Inter', 'Roboto', 'Arial', sans-serif",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
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

    # Header styles with gradient
    CSS(
        ".bonitobook-header",
        "background" => "linear-gradient(135deg, var(--bg-primary) 0%, var(--menu-hover-bg) 100%)",
        "border-bottom" => "1px solid var(--border-primary)",
        "height" => "var(--header-height)",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "box-shadow" => "var(--shadow-soft)",
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
        "background" => "var(--animation-glow)",
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
        "color" => "var(--text-primary)"
    ),

    # Navigation styles
    CSS(
        ".bonitobook-navbar",
        "background-color" => "var(--bg-primary)",
        "border-bottom" => "1px solid var(--border-primary)",
        "height" => "var(--navbar-height)",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "position" => "sticky",
        "top" => "0",
        "z-index" => "100"
    ),
    CSS(
        ".nav-items",
        "display" => "flex",
        "gap" => "30px",
        "width" => "100%",
        "max-width" => "var(--max-content-width)",
        "padding" => "0 var(--content-padding)"
    ),
    CSS(
        ".nav-item",
        "text-decoration" => "none",
        "color" => "var(--text-primary)",
        "font-weight" => "500",
        "padding" => "8px 16px",
        "border-radius" => "6px",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".nav-item:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--accent-blue)"
    ),

    # Main content styles
    CSS(
        ".bonitobook-page",
        "min-height" => "100vh",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".main-content",
        "max-width" => "var(--max-content-width)",
        "margin" => "0 auto",
        "padding" => "var(--content-padding)"
    ),

    # Hero section styles
    CSS(
        ".hero-section",
        "text-align" => "center",
        "padding" => "60px 0",
        "border-bottom" => "1px solid var(--border-primary)"
    ),
    CSS(
        ".hero-title",
        "font-size" => "3rem",
        "font-weight" => "700",
        "margin-bottom" => "20px",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".hero-subtitle",
        "font-size" => "1.25rem",
        "color" => "var(--text-secondary)",
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
        "background-color" => "var(--accent-blue)",
        "color" => "white",
        "padding" => "12px 24px",
        "border-radius" => "8px",
        "text-decoration" => "none",
        "font-weight" => "500",
        "transition" => "all 0.2s ease",
        "border" => "none",
        "cursor" => "pointer",
        "box-shadow" => "var(--shadow-button)",
        "font-size" => "16px",
        "font-family" => "inherit",
        "min-width" => "120px"
    ),
    CSS(
        ".hero-button:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--accent-blue)",
        "transform" => "translateY(-1px)",
        "box-shadow" => "0 4px 12px rgba(3, 102, 214, 0.3)"
    ),
    CSS(
        ".hero-button:active",
        "transform" => "translateY(0px)",
        "box-shadow" => "var(--shadow-inset)"
    ),
    CSS(
        ".hero-button-secondary",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "box-shadow" => "var(--shadow-button)"
    ),
    CSS(
        ".hero-button-secondary:hover",
        "background-color" => "var(--hover-bg)",
        "border-color" => "var(--accent-blue)",
        "color" => "var(--accent-blue)",
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
    CSS(
        ".example-card",
        "background-color" => "var(--bg-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "10px",
        "padding" => "24px",
        "transition" => "all 0.2s ease-out",
        "box-shadow" => "var(--shadow-soft)",
        "position" => "relative",
        "overflow" => "hidden"
    ),
    CSS(
        ".example-card:hover",
        "transform" => "translateY(-2px)",
        "box-shadow" => "var(--animation-glow)",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".example-card::before",
        "content" => "''",
        "position" => "absolute",
        "top" => "0",
        "left" => "-100%",
        "width" => "100%",
        "height" => "2px",
        "background" => "linear-gradient(90deg, transparent, var(--accent-blue), transparent)",
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
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".example-description",
        "margin" => "0 0 20px 0",
        "color" => "var(--text-secondary)",
        "line-height" => "1.6"
    ),
    CSS(
        ".example-link",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--accent-blue)",
        "text-decoration" => "none",
        "font-weight" => "500",
        "padding" => "8px 16px",
        "border" => "1px solid var(--accent-blue)",
        "border-radius" => "8px",
        "transition" => "all 0.2s ease",
        "box-shadow" => "var(--shadow-button)",
        "font-size" => "14px",
        "min-width" => "100px"
    ),
    CSS(
        ".example-link:hover",
        "background-color" => "var(--accent-blue)",
        "color" => "white",
        "transform" => "translateY(-1px)",
        "box-shadow" => "0 4px 12px rgba(3, 102, 214, 0.3)"
    ),
    CSS(
        ".example-link:active",
        "transform" => "translateY(0px)",
        "box-shadow" => "var(--shadow-inset)"
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
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".section-content",
        "color" => "var(--text-secondary)",
        "line-height" => "1.8",
        "font-size" => "1.1rem"
    ),

    # Code block styles - matching BonitoBook monaco editor
    CSS(
        "pre",
        "background-color" => "var(--bg-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "10px",
        "padding" => "16px",
        "overflow-x" => "auto",
        "margin" => "16px 0",
        "box-shadow" => "var(--shadow-soft)",
        "position" => "relative"
    ),
    CSS(
        "code",
        "font-family" => "'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace",
        "font-size" => "0.9em",
        "background-color" => "var(--menu-hover-bg)",
        "padding" => "2px 6px",
        "border-radius" => "4px",
        "border" => "1px solid var(--border-primary)"
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
            "background-color" => "var(--menu-hover-bg)",
            "color" => "var(--text-primary)"
        )
    ),

    # Getting Started InlineBook styling
    CSS(
        ".getting-started-inline",
        "background-color" => "var(--bg-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "10px",
        "padding" => "30px",
        "margin-top" => "20px",
        "box-shadow" => "var(--shadow-soft)"
    ),
    CSS(
        ".getting-started-inline .cell-editor-container",
        "margin-bottom" => "20px",
        "max-width" => "100%"
    ),
    CSS(
        ".getting-started-inline .cell-output",
        "background-color" => "var(--menu-hover-bg)",
        "border-radius" => "6px",
        "border" => "1px solid var(--border-primary)"
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
        CSS(".getting-started-inline", "padding" => "20px")
    )
)
