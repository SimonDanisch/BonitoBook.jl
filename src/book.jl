"""
    Book

Represents an interactive book with code cells, style editor, and execution runner.

# Fields
- `file::String`: Path to the main book file
- `folder::String`: Directory containing the book files
- `cells::Vector{CellEditor}`: Collection of editable code/markdown cells
- `style_editor::FileEditor`: Editor for styling the book
- `runner::Any`: Code execution runner (typically AsyncRunner)
- `progress::Observable{Tuple{Bool, Float64}}`: Progress tracking for operations
"""
struct Book
    file::String
    folder::String
    cells::Vector{CellEditor}
    style_editor::FileEditor
    runner::Any
    progress::Observable{Tuple{Bool, Float64}}
end

function from_folder(folder)
    project = joinpath(folder, "Project.toml")
    manifest = joinpath(folder, "Manifest.toml")
    book = joinpath(folder, "book.md")
    style_path = joinpath(folder, "styles", "style.jl")
    files = [book, project, manifest, style_path]
    for file in files
        if !isfile(file)
            error("File $file not found, not a BonitoBook?")
        end
    end
    return book, folder, [style_path]
end

function from_file(book, folder)
    if isnothing(folder)
        book_file = normpath(abspath(book))
        name, ext = splitext(book)
        if !(ext in (".md", ".ipynb"))
            error("File $book is not a markdown or ipynb file: $(ext)")
        end
        folder = joinpath(dirname(book_file), basename(name))
        if isdir(folder)
            return from_folder(folder)
        else
            mkpath(folder)
        end
    end
    style_path_template = joinpath(@__DIR__, "templates/style.jl")
    mkpath(joinpath(folder, "styles"))
    style_path = joinpath(folder, "styles", "style.jl")

    cp(style_path_template, style_path)
    # Copy over project so mutations stay in the book
    project = Pkg.project().path
    cp(project, joinpath(folder, "Project.toml"))
    cp(joinpath(dirname(project), "Manifest.toml"), joinpath(folder, "Manifest.toml"))
    return book, folder, [style_path]
end

"""
    Book(file; folder=nothing, runner=AsyncRunner())

Create a new Book from a file or folder.

# Arguments
- `file`: Path to a markdown file (.md), Jupyter notebook (.ipynb), or folder containing book files
- `folder`: Optional target folder for book files (if not provided, auto-generated)
- `runner`: Code execution runner (defaults to AsyncRunner())

# Returns
A `Book` instance ready for interactive editing and execution.

# Examples
```julia
# Create from markdown file
book = Book("mybook.md")

# Create from existing book folder
book = Book("/path/to/book/folder")
```
"""
function Book(file; folder = nothing, runner = AsyncRunner())
    if !isa(runner, MarkdownRunner)
        runner.mod.eval(runner.mod, :(using BonitoBook, BonitoBook.Bonito, BonitoBook.Markdown, BonitoBook.WGLMakie))
    end
    if isfile(file)
        bookfile, folder, style_paths = from_file(file, folder)
    elseif isdir(file)
        bookfile, folder, style_paths = from_folder(file)
    else
        error("File $file isnt a file or folder")
    end
    cells = load_book(bookfile)
    editors = cells2editors(cells, runner)
    style_editor = FileEditor("", nothing; editor_classes = ["styling file-editor"], show_editor = true)
    progress = Observable((false, 0.0))
    book = Book(bookfile, folder, editors, style_editor, runner, progress)
    export_md(joinpath(folder, "book.md"), book)
    return book
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
    save_jl, click_jl = icon_button("julia-logo")
    on(click_jl) do click
        Base.errormonitor(
            Threads.@async begin
                file = export_jl(joinpath(book.folder, "book.html"), book)
                trigger_js_download(session, file)
            end
        )
    end
    save_md, click_md = icon_button("markdown")
    on(click_md) do click
        Base.errormonitor(
            Threads.@async begin
                file = export_md(joinpath(book.folder, "book.md"), book)
                trigger_js_download(session, file)
            end
        )
    end
    save_pdf, click_pdf = icon_button("file-pdf")
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
    run_all_div, run_all_click = icon_button("play")
    stop_all_div, stop_all_click = icon_button("debug-stop")
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

function setup_editor_callbacks!(session, book, editor)
    on(session, editor.editor.source) do new_source
        save(book)
    end
    return on(session, editor.delete_self) do delete
        if delete
            filter!(x -> x.uuid != editor.uuid, book.cells)
            evaljs(
                session, js"""
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

function insert_editor_below!(book, session, editor, editor_above_uuid)
    idx = findfirst(x -> x.uuid == editor_above_uuid, book.cells)
    if isnothing(idx)
        push!(book.cells, editor)
    else
        insert!(book.cells, idx + 1, editor)
    end
    add_cell_div = new_cell_menu(session, book, editor.uuid, book.runner)
    setup_editor_callbacks!(session, book, editor)
    elem = DOM.div(editor, add_cell_div)
    return Bonito.dom_in_js(
        session, elem, js"""(elem) => {
            $(Monaco).then(Monaco => {
                Monaco.add_editor_below($editor_above_uuid, elem, $(editor.uuid));
            })
        }"""
    )
end

function new_cell_menu(session, book, editor_above_uuid, runner)

    new_jl, click_jl = icon_button("julia-logo")
    new_md, click_md = icon_button("markdown")
    new_py, click_py = icon_button("python-logo")
    on(click_py) do click
        new_cell = CellEditor("", "python", runner)
        insert_editor_below!(book, session, new_cell, editor_above_uuid)
    end

    on(click_jl) do click
        new_cell = CellEditor("", "julia", runner)
        insert_editor_below!(book, session, new_cell, editor_above_uuid)
    end
    on(click_md) do click
        new_cell = CellEditor("", "markdown", runner; show_editor = true, show_output = false)
        insert_editor_below!(book, session, new_cell, editor_above_uuid)
    end
    plus, click_plus = icon_button("add")
    menu_div = DOM.div(
        plus, new_jl, new_md, new_py;
        class = "saving small-menu-bar",
    )
    return DOM.div(Centered(menu_div); class = "new-cell-menu")
end

function setup_file_tabs(session, book)
    # Create FileTabs component for the file editor
    file_tabs = FileTabs([book.style_editor.current_file[]])

    # Connect FileTabs to the style_editor
    on(session, file_tabs.current_file) do filepath
        # Only open file if it's different from current file to prevent circular updates
        if !isempty(filepath) && filepath != book.style_editor.current_file[]
            open_file!(book.style_editor, filepath)
        end
    end

    return file_tabs
end

function setup_menu(book::Book)
    buttons_enabled = Observable(true)
    keep = Button("keep"; enabled = buttons_enabled)
    reset = Button("reset"; enabled = buttons_enabled)
    styling_popup_text = Observable(DOM.h3("Do you want to keep the styling changes?"))
    popup_content = DOM.div(
        styling_popup_text,
        DOM.div(keep, reset; class = "flex-row gap-10"),
    )
    popup = PopUp(popup_content; show = false)
    style_fe = book.style_editor
    style_path = joinpath(book.folder, "styles", "style.jl")
    # Remove the toggle button from the menu since sidebar handles it
    menu = DOM.div(
        icon("settings");
        class = "settings small-menu-bar"
    )
    style_source = Observable(read(style_path, String))
    onany(style_fe.current_file, style_fe.editor.source) do file, src
        if file == style_path && !isempty(src)
            style_source[] = src
        end
        return
    end
    style_file_eval = map(style_source) do src
        try
            return include_string(BonitoBook, src)
        catch e
            return e
        end
    end
    last_style = Ref{Styles}(style_file_eval[])
    last_source = Ref{String}(style_source[])
    should_popup = Ref(false)
    book_style = Observable(style_file_eval[])

    on(style_file_eval; update = true) do out
        if should_popup[]
            popup.show[] = true
        end
        if (out isa Styles)
            if should_popup[]
                buttons_enabled[] = true
                styling_popup_text[] = DOM.div(
                    DOM.h3("Want to keep changes?"),
                )
            end
            book_style[] = out
        else
            buttons_enabled[] = false
            styling_popup_text[] = DOM.div(
                DOM.h3("Error in styling document!"),
                out
            )
        end
        if !should_popup[]
            should_popup[] = true
        end
        return
    end
    on(keep.value) do click
        popup.show[] = false
        if buttons_enabled[]
            last_style[] = book_style[]
            last_source[] = style_source[]
        end
    end
    on(reset.value) do click
        popup.show[] = false
        should_popup[] = false
        style_fe.editor.set_source[] = last_source[]
    end
    return menu, style_fe, DOM.span(popup, book_style)
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
    runner = book.runner
    cells = map(book.cells) do editor
        add_cell_div = new_cell_menu(session, book, editor.uuid, runner)
        DOM.div(editor, add_cell_div)
    end
    register_book = js"""
        $(Monaco).then(Monaco => {
            Monaco.BOOK.update_order($(map(c-> c.uuid, book.cells)));
        })
    """
    for editor in book.cells
        setup_editor_callbacks!(session, book, editor)
    end
    _setup_menu, style_editor, style_output = setup_menu(book)
    save = saving_menu(session, book)
    player = play_menu(book)
    file_tabs = setup_file_tabs(session, book)

    menu = DOM.div(save, player, _setup_menu; class = "book-main-menu")

    cell_obs = DOM.div(cells...; class = "inline-block fit-content")

    # Wrap cells in scrollable area
    cells_area = DOM.div(cell_obs; class = "book-cells-area")
    # Create chat component
    chat_agent = MockChatAgent()
    chat_component = ChatComponent(chat_agent)

    # Create sidebar with FileEditor and Chat as widgets
    style_editor.editor.show_editor[] = true
    sidebar = Sidebar([
        ("file-editor", style_editor, "File Editor", "file-code"),
        ("chat", chat_component, "AI Chat", "chat-sparkle")
    ]; width = "50vw")

    # Create content area that includes both cells and sidebar
    content = DOM.div(cells_area, sidebar; class = "book-content")

    document = DOM.div(menu, file_tabs, content; class = "book-document")

    completions = setup_completions(session, runner.mod)

    on(session.on_close) do close
        runner.open[] = false
        return
    end

    return Bonito.jsrender(session, DOM.div(style_output, completions, register_book, document; class = "book-wrapper"))
end
