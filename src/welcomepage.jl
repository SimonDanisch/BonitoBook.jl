# Welcome page for BonitoBook
# Displays available example books and allows creating new books

# Styles for the welcome page
const WelcomePageStyles = Styles(
    # CSS variables for theming
    CSS(
        ":root",
        "--welcome-max-width" => "1200px",
        "--welcome-padding" => "40px",
        "--welcome-card-gap" => "24px"
    ),

    # Light theme colors
    CSS(
        "@media (prefers-color-scheme: light), (prefers-color-scheme: no-preference)",
        CSS(
            ":root",
            "--welcome-bg" => "#ffffff",
            "--welcome-text" => "#24292e",
            "--welcome-text-secondary" => "#555555",
            "--welcome-border" => "rgba(0, 0, 0, 0.1)",
            "--welcome-border-hover" => "#0366d6",
            "--welcome-shadow" => "0 4px 8px rgba(0, 0, 51, 0.2)",
            "--welcome-shadow-hover" => "0 8px 16px rgba(3, 102, 214, 0.3)",
            "--welcome-accent" => "#0366d6",
            "--welcome-accent-hover" => "#0256c7",
            "--welcome-card-bg" => "#ffffff",
            "--welcome-button-bg" => "#0366d6",
            "--welcome-button-text" => "#ffffff",
            "--welcome-button-hover" => "#0256c7",
            "--welcome-code-bg" => "#f6f8fa",
            "--welcome-code-border" => "#d0d7de"
        )
    ),

    # Dark theme colors
    CSS(
        "@media (prefers-color-scheme: dark)",
        CSS(
            ":root",
            "--welcome-bg" => "#1e1e1e",
            "--welcome-text" => "rgb(212, 212, 212)",
            "--welcome-text-secondary" => "rgb(170, 170, 170)",
            "--welcome-border" => "rgba(255, 255, 255, 0.1)",
            "--welcome-border-hover" => "#58a6ff",
            "--welcome-shadow" => "0 4px 8px rgba(0, 0, 0, 0.4)",
            "--welcome-shadow-hover" => "0 8px 16px rgba(88, 166, 255, 0.3)",
            "--welcome-accent" => "#58a6ff",
            "--welcome-accent-hover" => "#79b8ff",
            "--welcome-card-bg" => "#2d2d2d",
            "--welcome-button-bg" => "#238636",
            "--welcome-button-text" => "#ffffff",
            "--welcome-button-hover" => "#2ea043",
            "--welcome-code-bg" => "#161b22",
            "--welcome-code-border" => "#30363d"
        )
    ),

    # Global body/html styling to prevent white background
    CSS(
        "html",
        "background-color" => "var(--welcome-bg)",
        "margin" => "0",
        "padding" => "0"
    ),
    CSS(
        "body",
        "background-color" => "var(--welcome-bg)",
        "color" => "var(--welcome-text)",
        "margin" => "0",
        "padding" => "0",
        "font-family" => "system-ui, -apple-system, sans-serif"
    ),

    # Page container
    CSS(
        ".welcome-page-container",
        "min-height" => "100vh",
        "background-color" => "var(--welcome-bg)",
        "color" => "var(--welcome-text)"
    ),

    # Navbar styles
    CSS(
        ".welcome-page-navbar",
        "background-color" => "var(--welcome-bg)",
        "border-bottom" => "1px solid var(--welcome-border)",
        "padding" => "0 var(--welcome-padding)",
        "display" => "flex",
        "gap" => "20px",
        "position" => "sticky",
        "top" => "0",
        "z-index" => "100",
        "box-shadow" => "0 2px 4px rgba(0, 0, 0, 0.05)"
    ),
    CSS(
        ".welcome-page-nav-item",
        "display" => "inline-block",
        "padding" => "12px 16px",
        "text-decoration" => "none",
        "color" => "var(--welcome-text)",
        "font-weight" => "500",
        "border-radius" => "6px",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".welcome-page-nav-item:hover",
        "background-color" => "var(--welcome-card-bg)",
        "color" => "var(--welcome-accent)"
    ),

    # Main content
    CSS(
        ".welcome-page-main",
        "max-width" => "var(--welcome-max-width)",
        "margin" => "0 auto",
        "padding" => "var(--welcome-padding)"
    ),
    # When displaying a book, use full width
    CSS(
        ".welcome-page-main.book-page",
        "max-width" => "100%",
        "padding" => "0"
    ),

    # When embedding a Book inside WelcomePage, remove double scrollbars and fix layout
    CSS(
        ".welcome-page-main .book-wrapper",
        "width" => "100%",
        "height" => "auto",
        "max-width" => "100%",
        "overflow" => "visible"
    ),
    CSS(
        ".welcome-page-main .book-document",
        "height" => "auto",
        "min-height" => "auto",
        "overflow" => "visible"
    ),
    CSS(
        ".welcome-page-main .book-main-content",
        "height" => "auto",
        "overflow" => "visible"
    ),
    CSS(
        ".welcome-page-main .book-content",
        "height" => "auto",
        "overflow" => "visible"
    ),
    CSS(
        ".welcome-page-main .book-cells-area",
        "height" => "auto",
        "max-height" => "none",
        "overflow" => "visible"
    ),
    CSS(
        ".welcome-page-main .book-cells",
        "overflow" => "visible"
    ),
    # Ensure cell outputs are fully visible
    CSS(
        ".welcome-page-main .cell-output",
        "max-height" => "none",
        "overflow" => "visible"
    ),
    CSS(
        ".welcome-page-main .cell-logging",
        "max-height" => "none",
        "overflow-y" => "visible"
    ),
    # Hide the book's menu bar since we have our own navbar
    CSS(
        ".welcome-page-main .book-menu-container",
        "position" => "static",
        "width" => "100%"
    ),
    # Adjust sidebar to work within the embedded context
    CSS(
        ".welcome-page-main .book-bottom-panel",
        "position" => "relative"
    ),

    # Welcome content
    CSS(
        ".welcome-content",
        "width" => "100%"
    ),

    # Hero section
    CSS(
        ".welcome-hero",
        "text-align" => "center",
        "padding" => "60px 0",
        "margin-bottom" => "60px"
    ),
    CSS(
        ".welcome-hero-title",
        "font-size" => "3.5rem",
        "font-weight" => "700",
        "margin" => "0 0 20px 0",
        "color" => "var(--welcome-text)"
    ),
    CSS(
        ".welcome-hero-subtitle",
        "font-size" => "1.5rem",
        "color" => "var(--welcome-text-secondary)",
        "margin" => "0"
    ),

    # Sections
    CSS(
        ".welcome-section",
        "margin-bottom" => "60px"
    ),
    CSS(
        ".welcome-section-title",
        "font-size" => "2.5rem",
        "font-weight" => "700",
        "margin" => "0 0 30px 0",
        "color" => "var(--welcome-text)"
    ),

    # Grid layout for cards
    CSS(
        ".welcome-grid",
        "display" => "grid",
        "grid-template-columns" => "repeat(auto-fill, minmax(300px, 1fr))",
        "gap" => "var(--welcome-card-gap)"
    ),

    # Card styles
    CSS(
        ".welcome-card",
        "background-color" => "var(--welcome-card-bg)",
        "border" => "2px solid var(--welcome-border)",
        "border-radius" => "12px",
        "padding" => "24px",
        "transition" => "all 0.3s ease",
        "box-shadow" => "var(--welcome-shadow)"
    ),
    CSS(
        ".welcome-card:hover",
        "transform" => "translateY(-4px)",
        "box-shadow" => "var(--welcome-shadow-hover)",
        "border-color" => "var(--welcome-border-hover)"
    ),
    CSS(
        ".welcome-card-title",
        "font-size" => "1.5rem",
        "font-weight" => "600",
        "margin" => "0 0 12px 0",
        "color" => "var(--welcome-text)"
    ),
    CSS(
        ".welcome-card-description",
        "color" => "var(--welcome-text-secondary)",
        "margin" => "0 0 20px 0",
        "line-height" => "1.6"
    ),
    CSS(
        ".welcome-card-link",
        "display" => "inline-block",
        "padding" => "10px 20px",
        "background-color" => "var(--welcome-button-bg)",
        "color" => "var(--welcome-button-text)",
        "text-decoration" => "none",
        "border-radius" => "8px",
        "font-weight" => "500",
        "transition" => "all 0.2s ease",
        "border" => "none",
        "cursor" => "pointer"
    ),
    CSS(
        ".welcome-card-link:hover",
        "background-color" => "var(--welcome-button-hover)",
        "transform" => "translateY(-1px)"
    ),

    # Create button (inside input container)
    CSS(
        ".welcome-create-button",
        "display" => "inline-flex",
        "align-items" => "center",
        "gap" => "8px",
        "padding" => "12px 24px",
        "background-color" => "var(--welcome-button-bg)",
        "color" => "var(--welcome-button-text)",
        "border" => "none",
        "border-radius" => "8px",
        "font-size" => "1.1rem",
        "font-weight" => "600",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "box-shadow" => "var(--welcome-shadow)",
        "width" => "100%"
    ),
    CSS(
        ".welcome-create-button:hover",
        "background-color" => "var(--welcome-button-hover)",
        "transform" => "translateY(-2px)",
        "box-shadow" => "var(--welcome-shadow-hover)"
    ),
    CSS(
        ".welcome-create-button:active",
        "transform" => "translateY(0px)"
    ),
    # Loading state for create button
    CSS(
        ".welcome-create-button.loading",
        "cursor" => "not-allowed",
        "opacity" => "0.8",
        "animation" => "button-pulse 1.5s ease-in-out infinite"
    ),
    CSS(
        "@keyframes button-pulse",
        CSS("0%", "box-shadow" => "var(--welcome-shadow)"),
        CSS("50%", "box-shadow" => "var(--welcome-shadow-hover)"),
        CSS("100%", "box-shadow" => "var(--welcome-shadow)")
    ),

    # Input container
    CSS(
        ".welcome-input-container",
        "margin" => "20px 0",
        "padding" => "24px",
        "background-color" => "var(--welcome-card-bg)",
        "border" => "2px solid var(--welcome-border)",
        "border-radius" => "12px",
        "box-shadow" => "var(--welcome-shadow)"
    ),
    CSS(
        ".welcome-input-label",
        "margin" => "0 0 12px 0",
        "font-weight" => "500",
        "font-size" => "1.1rem"
    ),
    CSS(
        ".welcome-filename-input",
        "width" => "100%",
        "padding" => "12px",
        "font-size" => "1rem",
        "border" => "2px solid var(--welcome-border)",
        "border-radius" => "8px",
        "background-color" => "var(--welcome-bg)",
        "color" => "var(--welcome-text)",
        "margin-bottom" => "12px",
        "transition" => "border-color 0.2s ease"
    ),
    CSS(
        ".welcome-filename-input:focus",
        "outline" => "none",
        "border-color" => "var(--welcome-accent)"
    ),

    # New book info
    CSS(
        ".welcome-new-book-info",
        "margin-top" => "20px"
    ),
    CSS(
        ".welcome-new-book-info p",
        "margin" => "0 0 10px 0",
        "line-height" => "1.6"
    ),
    CSS(
        ".welcome-code-block",
        "background-color" => "var(--welcome-code-bg)",
        "border" => "1px solid var(--welcome-code-border)",
        "border-radius" => "6px",
        "padding" => "15px",
        "margin" => "10px 0",
        "overflow-x" => "auto"
    ),
    CSS(
        ".welcome-code-block code",
        "font-family" => "'Monaco', 'Menlo', 'Consolas', monospace",
        "font-size" => "0.9em",
        "color" => "var(--welcome-text)"
    ),

    # Loading overlay to prevent interaction while creating book
    CSS(
        ".welcome-loading-overlay",
        "position" => "fixed",
        "top" => "0",
        "left" => "0",
        "right" => "0",
        "bottom" => "0",
        "background-color" => "rgba(0, 0, 0, 0.5)",
        "z-index" => "9999",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "backdrop-filter" => "blur(2px)"
    ),
    CSS(
        ".welcome-loading-overlay.hidden",
        "display" => "none"
    ),
    CSS(
        ".welcome-loading-message",
        "background-color" => "var(--welcome-card-bg)",
        "padding" => "30px 40px",
        "border-radius" => "12px",
        "box-shadow" => "var(--welcome-shadow-hover)",
        "text-align" => "center",
        "animation" => "overlay-pulse 1.5s ease-in-out infinite"
    ),
    CSS(
        "@keyframes overlay-pulse",
        CSS("0%", "transform" => "scale(1)"),
        CSS("50%", "transform" => "scale(1.05)"),
        CSS("100%", "transform" => "scale(1)")
    ),
    CSS(
        ".welcome-loading-message h3",
        "margin" => "0 0 10px 0",
        "font-size" => "1.5rem",
        "color" => "var(--welcome-text)"
    ),
    CSS(
        ".welcome-loading-message p",
        "margin" => "0",
        "color" => "var(--welcome-text-secondary)"
    ),

    # Responsive design
    CSS(
        "@media (max-width: 768px)",
        CSS(".welcome-hero-title", "font-size" => "2.5rem"),
        CSS(".welcome-hero-subtitle", "font-size" => "1.2rem"),
        CSS(".welcome-section-title", "font-size" => "2rem"),
        CSS(".welcome-grid", "grid-template-columns" => "1fr"),
        CSS(":root", "--welcome-padding" => "20px")
    )
)

"""
    WelcomePage(folder::String; navbar_items::Vector{Pair{String,String}}=[])

Create a page wrapper with navigation for the welcome/book pages.

# Arguments
- `content`: The main content to display
- `title::String`: Page title (default: "BonitoBook")
- `navbar_items::Vector{Pair{String,String}}`: Navigation items (default: just Home)
"""
function WelcomePage(content, title::String="BonitoBook"; navbar_items::Vector{Pair{String,String}}=["Home" => "/"])
    # Navigation bar
    nav_links = map(navbar_items) do (label, href)
        DOM.a(
            label,
            href=Bonito.Link(href),
            class="welcome-page-nav-item"
        )
    end

    navbar = DOM.nav(
        nav_links...,
        class="welcome-page-navbar"
    )

    # Check if content is a Book to add special class
    is_book = isa(content, AbstractBook)
    main_class = is_book ? "welcome-page-main book-page" : "welcome-page-main"

    return DOM.div(
        WelcomePageStyles,
        navbar,
        DOM.main(
            content,
            class=main_class
        ),
        class="welcome-page-container"
    )
end

"""
    Welcome

A welcome page component that lists all markdown books in a folder.
Displays example books with links to open them, and provides option to create new books.

# Fields
- `folder::String`: Path to folder containing example books (.md files)
- `server::Bonito.Server`: The server instance to add new book routes to
"""
struct Welcome
    folder::String
    server::Bonito.Server
end

function Bonito.jsrender(session::Session, welcome::Welcome)
    # Find all .md files in the folder
    folder = welcome.folder
    server = welcome.server
    md_files = filter(f -> endswith(f, ".md"), readdir(folder))

    # Create hero section
    hero = DOM.section(
        DOM.h1("Welcome to BonitoBook!", class="welcome-hero-title"),
        DOM.p("Interactive Julia notebooks with live code execution", class="welcome-hero-subtitle");
        class="welcome-hero"
    )

    # Create examples section with cards
    examples_title = DOM.h2("Example Books", class="welcome-section-title")

    # Shared loading state for all interactions
    is_loading = Observable(false)
    loading_message = Observable("Loading...")

    example_cards = map(md_files) do file
        name = splitext(file)[1]
        display_name = titlecase(replace(name, "-" => " ", "_" => " "))

        # Create a click observable for this example
        example_click = Observable(false)

        # Create link as a button with click handler
        link = DOM.a(
            "Open Example",
            href=Bonito.Link("/$name"),
            class="welcome-card-link",
            onclick=js"""event => {
                event.preventDefault();
                $(example_click).notify(true);
            }"""
        )

        # Handle click - show loading and navigate
        on(session, example_click) do _
            # Ignore if already loading
            is_loading[] && return

            is_loading[] = true
            loading_message[] = "Opening $display_name..."

            # Navigate after a brief moment to ensure overlay shows
            @async try
                book_url = Bonito.url(session, Bonito.Link("/$name"))
                evaljs(session, js"window.location.href = $book_url")
            catch e
                @error "Failed to open example book: $e" exception=(e, catch_backtrace())
                # Reset loading state on error
                is_loading[] = false
                loading_message[] = "Loading..."
            end
        end

        DOM.div(
            DOM.h3(display_name, class="welcome-card-title"),
            DOM.p("Click to open this example notebook", class="welcome-card-description"),
            link,
            class="welcome-card"
        )
    end

    examples_section = DOM.div(
        examples_title,
        DOM.div(example_cards...; class="welcome-grid");
        class="welcome-section"
    )

    # Create new book section with button
    new_book_title = DOM.h2("Create New Book", class="welcome-section-title")

    # Input field for filename
    filename_input = Observable("")
    create_button_click = Observable(false)

    # Create the input field
    input_field = DOM.input(
        type="text",
        placeholder="mybook.md",
        class="welcome-filename-input",
        oninput=js"event => $(filename_input).notify(event.target.value)"
    )

    # Create button with dynamic class based on loading state
    button_class = map(is_loading) do loading
        loading ? "welcome-create-button loading" : "welcome-create-button"
    end

    create_button = DOM.button(
        icon("new-file"),
        DOM.span(" Create New Book"),
        class=button_class,
        onclick=js"event => $(create_button_click).notify(true)"
    )

    # Handle create button click
    on(session, create_button_click) do _
        # Ignore clicks while loading
        is_loading[] && return

        @async try
            filename = filename_input[]
            if isempty(filename)
                @warn "Please enter a filename"
                return
            end

            # Ensure .md extension
            if !endswith(filename, ".md")
                filename = filename * ".md"
            end

            # Create the book file in the folder
            book_path = joinpath(folder, filename)
            name = splitext(basename(filename))[1]
            display_name = titlecase(replace(name, "-" => " ", "_" => " "))

            # Set loading state
            is_loading[] = true
            loading_message[] = "Creating $display_name...\nThis may take a moment on first run"

            @info "Creating new book: $book_path"

            # Add route for the new book
            book_app = App(title=name) do
                book = create_book(book_path; replace_style=false, all_blocks_as_cell=false)
                # Wrap the book in WelcomePage with navigation back to home
                return WelcomePage(book, name; navbar_items=["Home" => "/"])
            end

            route!(server, "/$name" => book_app)

            @info "Created new book and added route /$name"

            # Navigate to the new book
            sleep(0.1)  # Small delay to ensure UI updates
            book_url = Bonito.url(session, Bonito.Link("/$name"))
            evaljs(session, js"window.location.href = $book_url")

            # Note: loading state will persist until page navigates away
        catch e
            @error "Failed to create book: $e" exception=(e, catch_backtrace())
            # Reset loading state on error
            is_loading[] = false
            loading_message[] = "Loading..."
        end
    end

    # Input container
    input_container = DOM.div(
        DOM.p("Enter the filename for your new book:", class="welcome-input-label"),
        input_field,
        create_button,
        class="welcome-input-container"
    )


    new_book_section = DOM.div(
        new_book_title,
        input_container;
        class="welcome-section"
    )

    # Create loading overlay with dynamic message
    overlay_class = map(is_loading) do loading
        loading ? "welcome-loading-overlay" : "welcome-loading-overlay hidden"
    end

    # Parse the loading message for title and subtitle
    message_content = map(loading_message) do msg
        lines = split(msg, '\n')
        if length(lines) > 1
            (title=lines[1], subtitle=join(lines[2:end], '\n'))
        else
            (title=msg, subtitle="")
        end
    end

    loading_overlay = map(message_content) do content
        DOM.div(
            DOM.div(
                DOM.h3(content.title),
                isempty(content.subtitle) ? DOM.div() : DOM.p(content.subtitle);
                class="welcome-loading-message"
            );
            class=overlay_class[]
        )
    end

    # Create main content
    content = DOM.div(
        hero,
        examples_section,
        new_book_section;
        class="welcome-content"
    )

    # Wrap in page with navigation and add overlay
    page = WelcomePage(content, "BonitoBook")

    # Add the loading overlay to the page
    return Bonito.jsrender(session, DOM.div(page, loading_overlay))
end

"""
    serve_welcome(folder::String; url="127.0.0.1", port=8773, proxy_url="")::Bonito.Server

Create and start a Bonito server with the welcome page and all books in the folder.

# Arguments
- `folder::String`: Path to folder containing example books (.md files)
- `url::String`: Server URL (default: "127.0.0.1")
- `port::Int`: Server port (default: 8773)
- `proxy_url::String`: Proxy URL (default: "")

# Returns
`Bonito.Server`: The running Bonito server instance

# Example
```julia
server = serve_welcome("./docs/examples")
```
"""
function serve_welcome(folder::String; url="127.0.0.1", port=8773, proxy_url="")::Bonito.Server
    # Ensure folder exists
    if !isdir(folder)
        error("Folder does not exist: $folder")
    end

    # Create server
    server = Bonito.Server(url, port; proxy_url=proxy_url, verbose=-1)

    # Add welcome page at root
    welcome_app = App(title="BonitoBook") do
        return Welcome(folder, server)
    end
    route!(server, "/" => welcome_app)

    # Find all .md files and create routes for them
    md_files = filter(f -> endswith(f, ".md"), readdir(folder))

    for md_file in md_files
        name = splitext(md_file)[1]
        book_path = joinpath(folder, md_file)

        # Create app for each book, wrapped in page with navbar
        book_app = App(title=name) do
            book = create_book(book_path; replace_style=false, all_blocks_as_cell=false)
            # Wrap the book in WelcomePage with navigation back to home
            return WelcomePage(book, name; navbar_items=["Home" => "/"])
        end

        route!(server, "/$name" => book_app)
    end

    return server
end
