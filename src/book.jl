"""
    Book

Represents an interactive book with code cells and execution runner.

# Fields
- `file::String`: Path to the main book file
- `folder::String`: Directory containing the book files
- `cells::Vector{CellEditor}`: Collection of editable code/markdown cells
- `runner::Any`: Code execution runner (typically AsyncRunner)
- `progress::Observable{Tuple{Bool, Float64}}`: Progress tracking for operations
- `mcp_server::Union{MCPJuliaServer, Nothing}`: MCP server for Claude Code integration
- `widgets::Dict{String, Any}`: Dictionary of UI widgets (file editor, chat, etc.)
- `global_logging_widget::Any`: Global logging output widget
"""
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
end

function from_folder(folder; replace_style=false)
    project = joinpath(folder, "Project.toml")
    manifest = joinpath(folder, "Manifest.toml")
    book = joinpath(folder, "book.md")
    style_path = joinpath(folder, "styles", "style.jl")
    ai_config_path = joinpath(folder, "ai", "config.toml")
    ai_prompt_path = joinpath(folder, "ai", "system-prompt.md")

    # Check required files (exclude style_path from the check initially)
    required_files = [book, project, manifest, ai_config_path, ai_prompt_path]
    for file in required_files
        if !isfile(file)
            error("File $file not found, not a BonitoBook?")
        end
    end

    # Handle style file replacement
    if replace_style || !isfile(style_path)
        style_path_template = joinpath(@__DIR__, "templates", "style.jl")
        cp(style_path_template, style_path; force=true)
    end

    return book, folder, [style_path]
end

function from_file(book, folder; replace_style=false)
    if isnothing(folder)
        book_file = normpath(abspath(book))
        name, ext = splitext(book)
        if !(ext in (".md", ".ipynb"))
            error("File $book is not a markdown or ipynb file: $(ext)")
        end
        folder = joinpath(dirname(book_file), basename(name))
        if isdir(folder)
            return from_folder(folder; replace_style=replace_style)
        else
            mkpath(folder)
        end
    end
    style_path_template = joinpath(@__DIR__, "templates/style.jl")
    mkpath(joinpath(folder, "styles"))
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
    # Copy over project so mutations stay in the book
    project = Pkg.project().path
    cp(project, joinpath(folder, "Project.toml"))
    cp(joinpath(dirname(project), "Manifest.toml"), joinpath(folder, "Manifest.toml"))
    return book, folder, [style_path]
end

"""
    Book(file; folder=nothing, replace_style=false, all_blocks_as_cell=false)

Create a new Book from a file or folder.

# Arguments
- `file`: Path to a markdown file (.md), Jupyter notebook (.ipynb), or folder containing book files
- `folder`: Optional target folder for book files (if not provided, auto-generated)
- `replace_style`: When loading from an existing book folder, replace style.jl with latest template (default: false)
- `all_blocks_as_cell`: Whether to treat all code blocks as executable cells (default: false)

# Returns
A `Book` instance ready for interactive editing and execution.

# Examples
```julia
# Create from markdown file
book = Book("mybook.md")

# Create from existing book folder, preserving custom styles
book = Book("/path/to/book/folder")

# Update existing book folder with latest style template
book = Book("/path/to/book/folder"; replace_style=true)
```
"""
function Book(file; folder = nothing, replace_style = false, all_blocks_as_cell = false)
    if isfile(file)
        bookfile, folder, style_paths = from_file(file, folder; replace_style=replace_style)
    elseif isdir(file)
        bookfile, folder, style_paths = from_folder(file; replace_style=replace_style)
    else
        error("File $file isnt a file or folder")
    end
    cells = load_book(bookfile; all_blocks_as_cell=all_blocks_as_cell)
    global_logging_widget = LoggingWidget()
    runner = AsyncRunner(folder; global_logger=global_logging_widget.logging)
    editors = cells2editors(cells, runner)
    progress = @D Observable((false, 0.0))
    Core.eval(runner.mod, :(using BonitoBook, BonitoBook.Bonito, BonitoBook.Markdown, BonitoBook.WGLMakie))
    style_eval = EvalFileOnChange(style_paths[1]; module_context = BonitoBook)
    book = Book(bookfile, folder, editors, runner, progress, nothing, nothing, Dict{String, Any}(), global_logging_widget, style_eval)
    Core.eval(runner.mod, :(macro Book(); $(book); end))
    export_md(joinpath(folder, "book.md"), book)
    return book
end

"""
    get_file_editor(book::Book)::TabbedFileEditor

Get the tabbed file editor from the book's widgets dictionary.
"""
function get_file_editor(book::Book)::TabbedFileEditor
    return book.widgets["file_editor"]
end

"""
    Cell

Represents a single cell in a book with source code and display options.

# Fields
- `language::String`: Programming language ("julia", "markdown", "python", etc.)
- `source::String`: Source code or markdown content
- `output::Any`: Computed output from executing the cell
- `show_editor::Bool`: Whether to show the code editor
- `show_logging::Bool`: Whether to show execution logs
- `show_output::Bool`: Whether to show execution output
- `show_chat::Bool`: Whether to show AI chat interface
"""
struct Cell
    language::String
    source::String
    output::Any

    show_editor::Bool
    show_logging::Bool
    show_output::Bool
end

Cell(language, source) = Cell(language, source, nothing, false, false, true)

function trigger_js_download(session, file)
    return evaljs(
        session, js"""
            const a = document.createElement('a');
            a.href = $(Bonito.url(session, Asset(file)));
            a.download = $(basename(file));
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
        """
    )
end

function saving_menu(session, book)
    save_jl, click_jl = SmallButton("julia-logo")
    on(click_jl) do click
        Base.errormonitor(
            Threads.@spawn begin
                file = export_jl(joinpath(book.folder, "book.html"), book)
                trigger_js_download(session, file)
            end
        )
    end
    save_md, click_md = SmallButton("markdown")
    on(click_md) do click
        Base.errormonitor(
            Threads.@async begin
                file = export_md(joinpath(book.folder, "book.md"), book)
                trigger_js_download(session, file)
            end
        )
    end
    save_pdf, click_pdf = SmallButton("file-pdf")
    on(click_pdf) do click
        Base.errormonitor(
            Threads.@async begin
                println("PDF export not yet implemented")
            end
        )
    end
    return DOM.div(
        icon("save"), save_jl, save_md, save_pdf;
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
        task = @async for cell in book.cells
            # fetches source only if unsaved source is there
            # After that, runs cell
            run_from_newest!(cell.editor)
        end
        Base.errormonitor(task)
    end
    return DOM.div(
        DOM.div(run_all_div, stop_all_div);
        class = "saving small-menu-bar"
    )
end

using Dates

function setup_editor_callbacks!(book, editor)
    on(book.session, editor.editor.source) do new_source
        save(book)
    end
    return on(book.session, editor.delete_self) do delete
        if delete
            filter!(x -> x.uuid != editor.uuid, book.cells)
            evaljs(
                book.session, js"""
                    $(Monaco).then(Monaco => {
                        Monaco.BOOK.remove_editor($(editor.uuid));
                    })
                """
            )
        end
    end
end

"""
    save(book::Book)

Save the book to disk, creating a versioned backup and exporting to markdown.

Creates a timestamped backup in the `.versions` folder and updates the main `book.md` file.
"""
function WGLMakie.save(book::Book)
    if !isdir(joinpath(book.folder, ".versions"))
        mkpath(joinpath(book.folder, ".versions"))
    end
    version = Dates.format(Dates.now(), "yyyy-mm-dd_HHMMSS")
    cp(book.file, joinpath(book.folder, ".versions", "book-$version.md"))
    return export_md(joinpath(book.folder, "book.md"), book)
end

function insert_editor_below!(book, editor, editor_above_uuid)
    # Handle special case for inserting at beginning
    if editor_above_uuid == "beginning"
        pushfirst!(book.cells, editor)
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
    return Bonito.dom_in_js(
        book.session, elem, js"""(elem) => {
            $(Monaco).then(Monaco => {
                Monaco.add_editor_below($editor_above_uuid, elem, $(editor.uuid));
            })
        }"""
    )
end

"""
    insert_cell_at!(book, source::String, lang::String, pos)

Insert a new cell at the specified position in the book.

# Arguments
- `book::Book`: The book to modify
- `source::String`: Initial source code or content for the cell
- `lang::String`: Language for the cell ("julia", "markdown", "python", etc.)
- `pos`: Position where to insert the cell
  - `:begin` - Insert at the beginning of the book
  - `:end` - Insert at the end of the book
  - `Integer` - Insert at the specified index (1-based)

# Returns
The DOM element for the inserted cell.

# Examples
```julia
# Add Julia cell at beginning
insert_cell_at!(book, "println(\"Hello\")", "julia", :begin)

# Add Markdown cell at end
insert_cell_at!(book, "# My Title", "markdown", :end)

# Add cell at specific position
insert_cell_at!(book, "x = 42", "julia", 3)
```
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

"""
    create_chat_agent(book::Book)

Create the appropriate chat agent based on environment configuration.
If ANTHROPIC_API_KEY is set, creates a ClaudeAgent, otherwise falls back to MockChatAgent.
"""
function create_chat_agent(book::Book)
    # Use Claude agent with local CLI (no API key needed)
    @info "Using ClaudeAgent with local CLI, tools enabled: true"
    return ClaudeAgent(book)
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
    menu = DOM.div(
        icon("settings"), style_setting_button;
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
    tabbed_editor = TabbedFileEditor(String[];)
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
    ]; width = "50vw")

    # Create horizontal sidebar for global logging
    global_logging_sidebar = Sidebar([
        ("global-logging", book.global_logging_widget, "Global Output", "terminal")
    ]; width = "100vw", orientation = "horizontal")

    # Create content area that includes both cells and sidebar
    content = DOM.div(cells_area, sidebar; class = "book-content")

    # Create main content area (everything except the bottom global logging)
    main_content = DOM.div(menu, content; class = "book-main-content")

    # Create document structure with main content and bottom global logging
    document = DOM.div(
        main_content,
        DOM.div(global_logging_sidebar; class = "book-bottom-panel");
        class = "book-document"
    )

    completions = setup_completions(session, runner.mod)

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
