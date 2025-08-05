"Interactive book with code cells and execution runner."
mutable struct Book
    file::String
    folder::String
    cells::Vector{CellEditor}
    runner::Any
    progress::Observable{Tuple{Bool, Float64}}
    mcp_server::Any
    session::Union{Session, Nothing}
    widgets::Dict{String, Any}
    global_logging_widget::Any
    style_eval::EvalFileOnChange
    spinner::BookSpinner
    current_cell::Observable{Union{CellEditor, Nothing}}
    theme_preference::Observable{String}
end

function create_book_structure(bookfile; replace_style=false)
    # Always create .book-name-bbook folder structure
    book_file = normpath(abspath(bookfile))
    name, ext = splitext(book_file)
    if !(ext in (".md", ".ipynb"))
        error("File $bookfile is not a markdown or ipynb file: $(ext)")
    end

    # Create hidden folder structure: .book-name-bbook
    book_dir = dirname(book_file)
    book_basename = basename(name)
    folder = joinpath(book_dir, ".$(book_basename)-bbook")

    # Create the folder structure if it doesn't exist
    if !isdir(folder)
        mkpath(folder)

        # Create styles folder and copy template
        mkpath(joinpath(folder, "styles"))
        style_path_template = joinpath(@__DIR__, "templates/style.jl")
        style_path = joinpath(folder, "styles", "style.jl")
        cp(style_path_template, style_path)

        # Create AI folder with configuration and system prompt
        ai_folder = joinpath(folder, "ai")
        mkpath(ai_folder)

        # Copy AI configuration template
        ai_config_template = joinpath(@__DIR__, "templates/ai/config.toml")
        ai_config_path = joinpath(ai_folder, "config.toml")
        cp(ai_config_template, ai_config_path)

        # Copy system prompt template
        system_prompt_template = joinpath(@__DIR__, "templates/ai/system-prompt.md")
        system_prompt_path = joinpath(ai_folder, "system-prompt.md")
        cp(system_prompt_template, system_prompt_path)
    else
        # Handle style file replacement for existing folders
        style_path = joinpath(folder, "styles", "style.jl")
        if replace_style || !isfile(style_path)
            style_path_template = joinpath(@__DIR__, "templates", "style.jl")
            mkpath(joinpath(folder, "styles"))
            cp(style_path_template, style_path; force=true)
        end
    end

    return folder
end

"""
    Book(file; replace_style=false, all_blocks_as_cell=false)

Create Book from .md or .ipynb file.

- `file::String`: Path to .md or .ipynb file
- `replace_style::Bool`: Replace style.jl with template
- `all_blocks_as_cell::Bool`: Treat all code blocks as cells
"""
function Book(file; replace_style = false, all_blocks_as_cell = false)
    # Ensure we have a file path
    if !isfile(file)
        error("File $file not found")
    end

    # Handle ZIP files by importing them first
    original_file = normpath(abspath(file))
    name, ext = splitext(original_file)

    if ext == ".zip"
        @info "Detected ZIP file, importing..."
        # Import the ZIP file and get the extracted book file path
        book_file_path = import_zip(original_file)
        file = book_file_path
        @info "Imported ZIP to: $book_file_path"
    end

    # Determine the correct file paths
    original_file = normpath(abspath(file))
    name, ext = splitext(original_file)
    original_basename = basename(name)

    # Set book.file to point to the .md file where content should be saved
    if ext == ".md"
        # For .md files, book.file points to the original file
        book_file = original_file
        load_file = original_file
        # Create folder structure based on the .md file
        folder = create_book_structure(book_file; replace_style=replace_style)
    elseif ext == ".ipynb"
        # For .ipynb files, create/use .md file in the same directory as the .ipynb
        book_file = "$(name).md"  # Same directory, same basename, .md extension
        # Try to load from the converted .md first, fallback to original .ipynb
        load_file = isfile(book_file) ? book_file : original_file
        # Create folder structure based on the converted .md file path
        folder = create_book_structure(book_file; replace_style=replace_style)
    else
        error("File $file is not a markdown or ipynb file: $(ext)")
    end

    # Load the book content
    cells = load_book(load_file; all_blocks_as_cell=all_blocks_as_cell)
    global_logging_widget = LoggingWidget()

    # Set up directories
    project_dir = dirname(file)  # Directory containing the .md file and Project.toml
    execution_dir = folder       # The .book-name-bbook folder for execution

    # The runner will cd into execution_dir for code execution
    runner = AsyncRunner(execution_dir; global_logger=global_logging_widget.logging)
    editors = cells2editors(cells, runner)
    progress = Observable((false, 0.0))

    # Activate the project in the parent directory (where Project.toml is)
    # Load required packages
    Core.eval(runner.mod, :(using BonitoBook, BonitoBook.Bonito, BonitoBook.Markdown, BonitoBook.WGLMakie))

    # Set up style evaluation with single style path
    style_path = joinpath(folder, "styles", "style.jl")
    style_eval = EvalFileOnChange(style_path; module_context = runner.mod)
    spinner = BookSpinner()
    current_cell = Observable{Union{CellEditor, Nothing}}(nothing)
    theme_preference = Observable{String}("auto")

    book = Book(
        book_file, folder, editors, runner, progress, nothing, nothing, Dict{String, Any}(),
        global_logging_widget, style_eval, spinner, current_cell, theme_preference
    )
    Core.eval(runner.mod, :(macro Book(); $(book); end))
    notify(style_eval.file_watcher)
    export_md(book_file, book)
    return book
end

"Get the tabbed file editor widget."
function get_file_editor(book::Book)::TabbedFileEditor
    return book.widgets["file_editor"]
end

"Book cell with source code and display options."
struct Cell
    language::String
    source::String
    output::Any

    show_editor::Bool
    show_logging::Bool
    show_output::Bool
end

Cell(language, source) = Cell(language, source, nothing, false, false, true)

function download_file_js(session, file)
    return js"""
    const a = document.createElement('a');
    a.href = $(Bonito.url(session, Asset(file)));
    a.download = $(basename(file));
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    """
end

function trigger_js_download(session, file)
    return evaljs(
        session, download_file_js(session, file)
    )
end

function saving_menu(session, book)
    save_html, click_html = SmallButton("html-file")
    on(click_html) do click
        task = spawnat(1) do
            file = export_html(joinpath(book.folder, "book.html"), book)
            trigger_js_download(session, file)
        end
        show_spinner!(book.spinner, task; message="Exporting to HTML...")
        Base.errormonitor(task)
    end
    save_md, click_md = SmallButton("markdown")
    on(click_md) do click
        task = Threads.@async begin
            file = export_md(book.file, book)
            trigger_js_download(session, file)
        end
        show_spinner!(book.spinner, task; message="Exporting to Markdown...")
        Base.errormonitor(task)
    end
    save_pdf, click_pdf = SmallButton("file-pdf")
    pdf_js = js"""
    $(click_pdf).on(click => {
        window.print();
    });
    """
    evaljs(session, pdf_js)

    # Add Quarto export
    save_quarto, click_quarto = SmallButton("quarto.png")
    on(click_quarto) do click
        task = Threads.@async begin
            file = export_quarto(joinpath(book.folder, "book.qmd"), book)
            trigger_js_download(session, file)
        end
        show_spinner!(book.spinner, task; message="Exporting to Quarto...")
        Base.errormonitor(task)
    end

    # Add Jupyter notebook export
    save_ipynb, click_ipynb = SmallButton("notebook")
    on(click_ipynb) do click
        task = Threads.@async begin
            file = export_ipynb(joinpath(book.folder, "book.ipynb"), book)
            trigger_js_download(session, file)
        end
        show_spinner!(book.spinner, task; message="Exporting to Jupyter Notebook...")
        Base.errormonitor(task)
    end

    # Add ZIP export
    save_zip, click_zip = SmallButton("archive")
    on(click_zip) do click
        task = Threads.@async begin
            book_name = splitext(basename(book.file))[1]
            zip_file = joinpath(book.folder, "$(book_name).zip")
            file = export_zip(book, zip_file)
            trigger_js_download(session, file)
        end
        show_spinner!(book.spinner, task; message="Exporting to ZIP archive...")
        Base.errormonitor(task)
    end

    save_html_tooltip = Tooltip(
        save_html,
        "Export the book to HTML"; position="bottom"
    )
    save_md_tooltip = Tooltip(
        save_md,
        "Export the book to Markdown"; position="bottom"
    )
    save_pdf_tooltip = Tooltip(
        save_pdf,
        "Print or save as PDF"; position="bottom"
    )
    save_quarto_tooltip = Tooltip(
        save_quarto,
        "Export the book to Quarto format"; position="bottom"
    )
    save_ipynb_tooltip = Tooltip(
        save_ipynb,
        "Export the book to Jupyter Notebook"; position="bottom"
    )
    save_zip_tooltip = Tooltip(
        save_zip,
        "Export the book project as ZIP archive (includes dependencies)"; position="bottom"
    )
    return DOM.div(
        icon("save"), save_html_tooltip, save_md_tooltip, save_pdf_tooltip, save_quarto_tooltip, save_ipynb_tooltip, save_zip_tooltip;
        class = "saving small-menu-bar"
    )
end

function play_menu(book)
    run_all_div, run_all_click = SmallButton("play")
    stop_all_div, stop_all_click = SmallButton("debug-stop")
    on(stop_all_click) do click
        println("Stopping all cells")
        if isa(book.runner, AsyncRunner)
            Base.errormonitor(interrupt!(book.runner))
        end
    end
    on(run_all_click) do click
        task = @async begin
            for cell in book.cells
                # fetches source only if unsaved source is there
                # After that, runs cell
                run_from_newest!(cell.editor)
            end
            sleep(0.5)
            x = Bonito.wait_for(()-> isempty(book.runner.task_queue))
        end
        show_spinner!(book.spinner, task; message="Running all cells...")
    end
    run_all_tooltip = Tooltip(
        run_all_div,
        "Run all cells in sequence"; position="bottom"
    )
    stop_all_tooltip = Tooltip(
        stop_all_div,
        "Stop all running cells"; position="bottom"
    )
    return DOM.div(
        run_all_tooltip, stop_all_tooltip;
        class = "saving small-menu-bar"
    )
end

using Dates

function setup_editor_callbacks!(book, editor)
    on(book.session, editor.editor.source) do new_source
        save(book)
    end

    # Use the editor's focused observable to track current cell
    on(book.session, editor.focused) do focused
        if focused
            # When this editor gains focus, set it as current cell
            book.current_cell[] = editor
        end
    end

    on(book.session, editor.delete_self) do delete
        if delete
            # Clear current cell if it's being deleted
            if book.current_cell[] === editor
                book.current_cell[] = nothing
            end
            filter!(x -> x.uuid != editor.uuid, book.cells)
            evaljs(
                book.session, js"""
                    $(Monaco).then(Monaco => {
                        Monaco.BOOK.remove_editor($(editor.uuid));
                    })
                """
            )
            save(book)  # Save the notebook after cell deletion
        end
    end
    return
end

"Save book with versioned backup."
function WGLMakie.save(book::Book)
    if !isdir(joinpath(book.folder, ".versions"))
        mkpath(joinpath(book.folder, ".versions"))
    end
    version = Dates.format(Dates.now(), "yyyy-mm-dd_HHMMSS")
    # Create backup with original filename
    backup_name = "$(splitext(basename(book.file))[1])-$version.md"
    cp(book.file, joinpath(book.folder, ".versions", backup_name))
    return export_md(book.file, book)
end

function insert_editor_below!(book, editor, editor_above_uuid)
    # Handle special case for inserting at beginning
    if editor_above_uuid == "beginning"
        pushfirst!(book.cells, editor)
        add_cell_div = new_cell_menu(book, editor.uuid, book.runner)
        setup_editor_callbacks!(book, editor)
        elem = DOM.div(editor, add_cell_div)
        save(book)  # Save the notebook after cell insertion
        return Bonito.dom_in_js(
            book.session, elem, js"""(elem) => {
                $(Monaco).then(Monaco => {
                    Monaco.add_editor_at_beginning(elem, $(editor.uuid));
                })
            }"""
        )
    end

    # Normal case - find the editor above and insert below it
    idx = findfirst(x -> x.uuid == editor_above_uuid, book.cells)
    if isnothing(idx)
        push!(book.cells, editor)
    else
        insert!(book.cells, idx + 1, editor)
    end
    add_cell_div = new_cell_menu(book, editor.uuid, book.runner)
    setup_editor_callbacks!(book, editor)
    elem = DOM.div(editor, add_cell_div)
    save(book)  # Save the notebook after cell insertion
    return Bonito.dom_in_js(
        book.session, elem, js"""(elem) => {
            $(Monaco).then(Monaco => {
                Monaco.add_editor_below($editor_above_uuid, elem, $(editor.uuid));
            })
        }"""
    )
end

"""
    insert_cell_at!(book, source, lang, pos)

Insert cell at position (:begin, :end, or index).

- `book::Book`: Book to modify
- `source::String`: Cell content
- `lang::String`: Language (julia, markdown, python)
- `pos`: Position (:begin, :end, or integer index)
"""
function insert_cell_at!(book, source::String, lang::String, pos)
    # Create cell editor with appropriate settings
    editor = if lang == "markdown"
        CellEditor(source, lang, book.runner; show_editor=true, show_output=false)
    else
        CellEditor(source, lang, book.runner)
    end

    # Handle different position types by finding the editor above
    if pos == :begin
        if isempty(book.cells)
            # If no cells exist, add directly and handle manually
            push!(book.cells, editor)
            add_cell_div = new_cell_menu(book, editor.uuid, book.runner)
            setup_editor_callbacks!(book, editor)
            elem = DOM.div(editor, add_cell_div)
            return Bonito.dom_in_js(
                book.session, elem, js"""(elem) => {
                    $(Monaco).then(Monaco => {
                        Monaco.add_editor_at_beginning(elem, $(editor.uuid));
                    })
                }"""
            )
        else
            # Insert at beginning by using insert_editor_below! with a special "beginning" UUID
            return insert_editor_below!(book, editor, "beginning")
        end
    elseif pos == :end
        if isempty(book.cells)
            # If no cells exist, treat as beginning
            return insert_cell_at!(book, source, lang, :begin)
        else
            # Insert at end by using the last cell as reference
            last_editor_uuid = book.cells[end].uuid
            return insert_editor_below!(book, editor, last_editor_uuid)
        end
    elseif pos isa Integer
        if pos < 1 || pos > length(book.cells) + 1
            error("Position $pos is out of bounds. Must be between 1 and $(length(book.cells) + 1)")
        end

        if pos == 1
            # Insert at beginning
            return insert_cell_at!(book, source, lang, :begin)
        elseif pos == length(book.cells) + 1
            # Insert at end
            return insert_cell_at!(book, source, lang, :end)
        else
            # Insert at specific position by using the editor above as reference
            editor_above_uuid = book.cells[pos - 1].uuid
            return insert_editor_below!(book, editor, editor_above_uuid)
        end
    else
        error("Invalid position $pos. Must be :begin, :end, or an integer")
    end
end

function new_cell_menu(book, editor_above_uuid, runner)
    new_jl, click_jl = SmallButton("julia-logo")
    new_md, click_md = SmallButton("markdown")
    new_py, click_py = SmallButton("python-logo")
    on(click_py) do click
        new_cell = CellEditor("", "python", runner)
        insert_editor_below!(book, new_cell, editor_above_uuid)
    end
    on(click_jl) do click
        new_cell = CellEditor("", "julia", runner)
        insert_editor_below!(book, new_cell, editor_above_uuid)
    end
    on(click_md) do click
        new_cell = CellEditor("", "markdown", runner; show_editor = true, show_output = false)
        insert_editor_below!(book, new_cell, editor_above_uuid)
    end
    menu_div = DOM.div(
        icon("add"), new_jl, new_md, new_py;
        class = "saving small-menu-bar",
    )
    return DOM.div(Centered(menu_div); class = "new-cell-menu")
end

prompt(agent, question) = nothing
create_claude_agent(book) = nothing
create_prompting_tools_agent(book) = nothing

"Create chat agent for the book."
function create_chat_agent(book::Book)
    # Use Claude agent with local CLI (no API key needed)
    agent = create_claude_agent(book)
    isnothing(agent) || return agent
    # Fallback to PromtingTools agent if Claude is not available
    return create_prompting_tools_agent(book)
end

function setup_menu(book::Book, tabbed_file_editor::TabbedFileEditor)
    style_path = joinpath(book.folder, "styles", "style.jl")

    # Create EvalFileOnChange component for the style file
    style_eval = book.style_eval
    style_setting_button, click = SmallButton("paintcan")
    on(click) do _click
        # Toggle style editor visibility
        open_file!(tabbed_file_editor, style_path)
    end
    # Settings menu button
    style_button_tooltip = Tooltip(
        style_setting_button,
        "Open style editor"; position="bottom"
    )
    menu = DOM.div(
        icon("settings"), style_button_tooltip;
        class = "settings small-menu-bar"
    )

    return menu, style_eval, style_eval.last_valid_output
end

function setup_completions(session, cell_module)
    inbox = Observable{Any}([])
    outbox = Observable{Any}([])
    on(session, outbox) do (id, data)
        completions = get_completions(data["text"], Int(data["column"]) - 1, cell_module)
        inbox[] = [id, completions]
        return
    end
    return js"""
        $(Monaco).then(Monaco => {
            Monaco.register_completions($inbox, $outbox);
        })
    """
end

function Bonito.jsrender(session::Session, book::Book)
    book.session = session
    runner = book.runner
    add_julia_mpc_route!(book)
    cells = map(book.cells) do editor
        add_cell_div = new_cell_menu(book, editor.uuid, runner)
        DOM.div(editor, add_cell_div)
    end
    register_book = js"""
        $(Monaco).then(Monaco => {
            Monaco.BOOK.update_order($(map(c-> c.uuid, book.cells)));
        })
    """
    for editor in book.cells
        setup_editor_callbacks!(book, editor)
    end

    # Create tabbed editor instead of separate file tabs
    tabbed_editor = TabbedFileEditor(String[])
    book.widgets["file_editor"] = tabbed_editor
    _setup_menu, style_eval, style_output = setup_menu(book, tabbed_editor)
    save = saving_menu(session, book)
    player = play_menu(book)


    menu = DOM.div(save, player, _setup_menu; class = "book-main-menu")

    cell_obs = DOM.div(cells...; class = "inline-block fit-content")

    # Wrap cells in scrollable area
    cells_area = DOM.div(cell_obs; class = "book-cells-area")
    # Create chat component with appropriate agent
    chat_agent = create_chat_agent(book)
    chat_component = ChatComponent(chat_agent; book=book)
    book.widgets["chat"] = chat_component

    # Create sidebar with widgets from book
    sidebar = Sidebar([
        ("file-editor", book.widgets["file_editor"], "File Editor", "file-code"),
        ("chat", book.widgets["chat"], "AI Chat", "chat-sparkle")
    ]; width = "800px")

    # Create horizontal sidebar for global logging
    global_logging_sidebar = Sidebar([
        ("global-logging", book.global_logging_widget, "Global Output", "terminal")
    ]; width = "100vw", orientation = "horizontal")

    # Create content area that includes both cells and sidebar
    content = DOM.div(cells_area, sidebar; class = "book-content")

    # Create menu and spinner container to match width
    menu_and_spinner = DOM.div(book.spinner, menu; class = "book-menu-container")

    # Create main content area (everything except the bottom global logging)
    main_content = DOM.div(menu_and_spinner, content; class = "book-main-content")

    # Create document structure with main content and bottom global logging
    document = DOM.div(
        main_content,
        DOM.div(global_logging_sidebar; class = "book-bottom-panel");
        class = "book-document"
    )

    completions = setup_completions(session, runner.mod)

    # Set up theme preference tracking
    theme_tracking = js"""
        // Function to get current theme preference
        function get_current_theme() {
            if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
                return 'dark';
            } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
                return 'light';
            } else {
                return 'auto';
            }
        }
        // Set initial theme
        $(book.theme_preference).notify(get_current_theme());
        // Listen for theme changes
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
            $(book.theme_preference).notify(get_current_theme());
        });
        window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e) => {
            $(book.theme_preference).notify(get_current_theme());
        });
    """
    evaljs(session, theme_tracking)

    on(session.on_close) do close
        runner.open[] = false
        return
    end
    codicon = Styles(
        CSS(
            "@font-face",
            "font-family" => "codicon",
            "src" => assets("codicon.ttf"),
            "font-weight" => "normal",
            "font-style" => "normal"
        )
    )

    return Bonito.jsrender(session, DOM.div(codicon, style_eval, style_output, completions, register_book, document; class = "book-wrapper"))
end

"""
    current_cell(book::Book)

Get currently selected cell editor.

- `book::Book`: Book instance
"""
function current_cell(book::Book)::Union{CellEditor, Nothing}
    return book.current_cell[]
end

"""
    theme_preference(book::Book)

Get browser theme preference (light/dark/auto).

- `book::Book`: Book instance
"""
function theme_preference(book::Book)::String
    return book.theme_preference[]
end

const BOOK_SERVERS = Dict{Int, Bonito.Server}()

function get_server(url, port, proxy_url)
    server = get!(BOOK_SERVERS, port) do
        return Bonito.Server(url, port; proxy_url=proxy_url)
    end
    server.proxy_url = proxy_url
    return server
end


"""
    book(path; replace_style=false, all_blocks_as_cell=false, url="127.0.0.1", port=8773, proxy_url="", openbrowser=true)

Launch a BonitoBook server for interactive notebook editing.

- `path::AbstractString`: Path to .md or .ipynb file
- `replace_style::Bool`: Replace style.jl with template
- `all_blocks_as_cell::Bool`: Treat all code blocks as cells (and not just ```julia (editor=true, logging=false, output=true)`)
- `url::String`: Server URL
- `port::Int`: Server port
- `proxy_url::String`: Proxy URL
- `openbrowser::Bool`: Open browser automatically
"""
function book(path::AbstractString;
        replace_style=false,
        all_blocks_as_cell=false,
        url="127.0.0.1",
        port=8773,
        proxy_url="",
        openbrowser=true
    )
    name = splitext(basename(path))[1]
    app = App(title=name) do
        return Book(path; replace_style=replace_style, all_blocks_as_cell=all_blocks_as_cell)
    end
    server = get_server(url, port, proxy_url)
    route!(server, "/$(name)" => app)
    if openbrowser
        Bonito.HTTPServer.openurl(Bonito.online_url(server, "/$(name)"))
    else
        println("Book server running at: $(Bonito.online_url(server, "/$(name)"))")
    end
    return server
end
