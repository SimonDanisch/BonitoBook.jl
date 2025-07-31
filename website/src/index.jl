# Main index page for BonitoBook documentation

function index()
    hero = DOM.section(
        DOM.h1("BonitoBook", class="hero-title"),
        DOM.p(
            "Create interactive Julia notebooks with live code execution, AI assistance, and beautiful exports.",
            class="hero-subtitle"
        ),
        DOM.div(
            DOM.a(
                "Get Started",
                href="/examples",
                class="hero-button"
            ),
            DOM.a(
                "View on GitHub",
                href="https://github.com/SimonDanisch/BonitoBook.jl",
                class="hero-button hero-button-secondary"
            ),
            class="hero-buttons"
        ),
        class="hero-section"
    )
    
    features = DOM.section(
        DOM.h2("Features", class="section-title"),
        DOM.div(
            feature_list(),
            class="section-content"
        ),
        class="section"
    )
    
    getting_started = DOM.section(
        DOM.h2("Getting Started", class="section-title"),
        DOM.div(
            DOM.p("Install BonitoBook with:"),
            DOM.pre(
                DOM.code("""
                using Pkg
                Pkg.add("BonitoBook")
                """, class="language-julia")
            ),
            DOM.p("Create your first book:"),
            DOM.pre(
                DOM.code("""
                using BonitoBook
                
                # Create a new book from a markdown file
                book = Book("mybook.md")
                
                # Or load an existing book folder
                book = Book("/path/to/book/folder")
                """, class="language-julia")
            ),
            class="section-content"
        ),
        class="section"
    )
    
    content = DOM.div(
        hero,
        features,
        getting_started
    )
    
    return Page(content, "BonitoBook - Interactive Julia Notebooks")
end

function feature_list()
    features = [
        ("📝", "Live Code Editing", "Edit Julia, Python, and Markdown cells with syntax highlighting and auto-completion"),
        ("🚀", "Interactive Execution", "Run code cells individually or all at once with real-time output"),
        ("🤖", "AI Integration", "Built-in AI assistant powered by Claude for code help and explanations"),
        ("🎨", "Customizable Styling", "Theme your notebooks with custom CSS using live style editing"),
        ("📤", "Multiple Export Formats", "Export to HTML, Markdown, or PDF for sharing and publishing"),
        ("🔧", "Extensible", "Add custom widgets and components using the Bonito framework")
    ]
    
    feature_items = map(features) do (icon, title, desc)
        DOM.div(
            DOM.span(icon, style=Styles("font-size" => "2rem", "margin-bottom" => "10px", "display" => "block")),
            DOM.h3(title, style=Styles("margin" => "10px 0", "font-weight" => "600")),
            DOM.p(desc, style=Styles("margin" => "0", "color" => "var(--text-secondary)")),
            style=Styles(
                "text-align" => "center",
                "padding" => "20px",
                "flex" => "1 1 300px"
            )
        )
    end
    
    return DOM.div(
        feature_items...,
        style=Styles(
            "display" => "flex",
            "flex-wrap" => "wrap",
            "gap" => "30px",
            "margin-top" => "30px"
        )
    )
end