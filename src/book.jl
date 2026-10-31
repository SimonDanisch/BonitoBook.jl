
abstract type AbstractBook end

"""
Valid values for `Book.logging_mode`. Each value controls only the
*visibility* of cell stdout/stderr; the runner always records every
chunk into `book.console_log` regardless of mode, so switching modes
never loses data.

  - `:respect_cell` — per-cell `editor.show_logging` decides whether
    the inline logging div is visible. Default.
  - `:hide_all` — never show inline logging anywhere. Per-cell toggles
    are ignored at the visibility layer.
  - `:show_all` — show every cell's logging inline regardless of its
    per-cell setting.
  - `:console` — hide all inline logging; the attributed console log
    in the bottom panel becomes the canonical place to read output.
"""
const LOGGING_MODES = (:respect_cell, :hide_all, :show_all, :console)

# `LogEntry`, `CONSOLE_LOG_BYTE_CAP`, and `push_console!` are defined in
# logging.jl (which loads before book.jl) because `ConsoleLogWidget`
# there needs to reference `LogEntry` too. Everything that touches
# `book.console_log` goes through them.

"Interactive book with code cells and execution runner."
mutable struct Book <: AbstractBook
    file::String
    folder::String
    cells::Vector{CellEditor}
    runner::Any
    progress::Observable{Tuple{Bool,Float64}}
    mcp_server::Any
    session::Union{Session,Nothing}
    widgets::Dict{String,Any}
    global_logging_widget::Any
    style_eval::EvalFileOnChange
    spinner::BookSpinner
    current_cell::Observable{Union{CellEditor,Nothing}}
    theme_preference::Observable{String}
    monaco_theme::Observable{String}
    cell_id_counter::Ref{Int}  # Counter for assigning unique cell IDs
    last_save_hash::Ref{UInt64}  # Hash of file after last save (prevents self-triggering)
    file_watcher::Union{Nothing, EvalFileOnChange}  # Watches markdown file for external changes
    logging_mode::Observable{Symbol}  # One of LOGGING_MODES; persisted in meta.toml
    # Attributed history of every stdout/stderr chunk a cell run produced
    # since the book was opened. Capped at `CONSOLE_LOG_BYTE_CAP` bytes
    # via `push_console!`. The console widget renders this; per-cell
    # inline `terminal_output` still gets the same chunks in parallel,
    # so the only thing `logging_mode` actually changes is visibility.
    console_log::Observable{Vector{LogEntry}}
end

# ── meta.toml helpers ────────────────────────────────────────────────────────
# Per-book settings (mode toggles, etc.) live in `<folder>/meta.toml`
# alongside the schema-version marker. We keep the file flat so a user
# can hand-edit it without breaking anything.

"Path to the per-book meta.toml. Doesn't create the file."
book_meta_path(folder::AbstractString) = joinpath(folder, "meta.toml")

"""
    read_book_meta(folder) -> Dict{String,Any}

Read `meta.toml` if it exists. Returns an empty dict if the file is
missing or unreadable so callers can `get(meta, key, default)` safely.
"""
function read_book_meta(folder::AbstractString)
    path = book_meta_path(folder)
    isfile(path) || return Dict{String,Any}()
    try
        return TOML.parsefile(path)
    catch e
        @warn "Failed to parse $(path); using defaults" exception=e
        return Dict{String,Any}()
    end
end

"""
    write_book_meta!(folder, updates::AbstractDict)

Merge `updates` into `meta.toml` (existing keys overwritten, missing
keys preserved). Creates the file if needed.
"""
function write_book_meta!(folder::AbstractString, updates::AbstractDict)
    path = book_meta_path(folder)
    base = read_book_meta(folder)
    merge!(base, updates)
    mkpath(folder)
    open(path, "w") do io
        TOML.print(io, base)
    end
    return path
end

"""
    load_logging_mode(folder) -> Symbol

Read the persisted logging mode from meta.toml, falling back to
`:respect_cell` if the file is missing or contains an unknown value.
"""
function load_logging_mode(folder::AbstractString)
    meta = read_book_meta(folder)
    raw = get(meta, "logging_mode", "respect_cell")
    sym = Symbol(raw)
    return sym in LOGGING_MODES ? sym : :respect_cell
end


# cp without preserving e.g. file permissions
function _cp(src, dest)
    bytes = read(src)
    write(dest, bytes)
end

# Include book structure management functions
include("book_structure.jl")

function import_bookfile(book_file, folder, replace_style, plugin_template=nothing, plugin_module_name=nothing)
    if !isfile(book_file)
        write(
            book_file,"""
            # New Book
            ```julia (editor=true, logging=false, output=true)
            ```
            """
        )
    end
    name, ext = splitext(book_file)
    if ext == ".zip"
        @info "Detected ZIP file, importing..."
        # Import the ZIP file and get the extracted book file path
        return import_zip(book_file)
    end

    # Set book.file to point to the .md file where content should be saved
    if ext == ".md" || ext == ".ipynb"
        if isnothing(folder)
            folder = create_book_structure(book_file; replace_style=replace_style)
            if !isnothing(plugin_module_name)
                wrapper_file = joinpath(folder, "book.jl")
                if !isfile(wrapper_file)
                    write(wrapper_file, """
                    module AutoPluginBook
                    using BonitoBook
                    using $(plugin_module_name)
                    create_book(book::BonitoBook.Book; kwargs...) = $(plugin_module_name).create_book(book; kwargs...)
                    end
                    """)
                end
            end
        elseif !isdir(folder)
            error("Provided folder $folder does not exist")
        else
            if !isnothing(plugin_module_name)
                wrapper_file = joinpath(folder, "book.jl")
                if !isfile(wrapper_file)
                    write(wrapper_file, """
                    module AutoPluginBook
                    using BonitoBook
                    using $(plugin_module_name)
                    create_book(book::BonitoBook.Book; kwargs...) = $(plugin_module_name).create_book(book; kwargs...)
                    end
                    """)
                end
            end
            # Detect if the provided folder is a plugin template (read-only).
            # If it contains a book.jl that references a plugin, create an
            # instance folder instead so we don't mutate the plugin.
            if is_plugin_template(folder)
                instance_folder = create_book_structure(book_file; replace_style=replace_style)
                # Copy the book.jl reference so the instance inherits the plugin
                plugin_book_jl = joinpath(folder, "book.jl")
                instance_book_jl = joinpath(instance_folder, "book.jl")
                if isfile(plugin_book_jl) && !isfile(instance_book_jl)
                    _cp(plugin_book_jl, instance_book_jl)
                end
                @info "Created instance folder $instance_folder (inheriting from plugin $folder)"
                folder = instance_folder
            end
        end
        return book_file, folder
    else
        error("File $book_file is not a markdown, zip or ipynb file: $(ext)")
    end
end

"""
    Book(file; replace_style=false, all_blocks_as_cell=false)

Create Book from .md or .ipynb file.

- `file::String`: Path to .md or .ipynb file
- `replace_style::Bool`: Replace style.jl with template
- `all_blocks_as_cell::Bool`: Treat all code blocks as cells
"""
function Book(user_file::String; folder=nothing, replace_style=false, all_blocks_as_cell=false, plugin_template=nothing, plugin_module_name=nothing)
    # Ensure we have a file path
    markdown_file, folder = import_bookfile(user_file, folder, replace_style, plugin_template, plugin_module_name)
    # Load the book content
    cells = load_book(markdown_file; all_blocks_as_cell=all_blocks_as_cell)
    global_logging_widget = LoggingWidget()
    # Attributed console history (cell_id, html, time per chunk).
    # Owned by the book, mirrored into the runner so the worker can
    # push directly without a back-reference to the Book.
    console_log = Observable(LogEntry[])
    logging_mode = Observable{Symbol}(load_logging_mode(folder))

    # The runner will cd into folder for code execution
    runner = AsyncRunner(folder;
        global_logger = global_logging_widget.logging,
        logging_mode = logging_mode,
        console_log = console_log,
    )
    monaco_theme = Observable{String}("default")
    editors = cells2editors(cells, runner, monaco_theme, folder)
    progress = Observable((false, 0.0))

    # Assign IDs to all cells and get the next counter value
    cell_id_counter = assign_cell_ids!(editors)

    # Activate the project in the parent directory (where Project.toml is)
    # Load required packages
    Core.eval(runner.mod, :(using BonitoBook, BonitoBook.Bonito, BonitoBook.Markdown))
    Core.eval(runner.mod, :(include(file) = BonitoBook.book_include(
        $(runner.mod),
        $(markdown_file),
        $(folder),
        file)
    ))
    include_file = joinpath(folder, "include.jl")
    if isfile(include_file)
        @eval runner.mod include($include_file)
    end
    # Set up style evaluation - use get_file_path to check custom then template
    style_path, is_custom = get_file_path(folder, "style.jl"; plugin_template=plugin_template)
    style_eval = EvalFileOnChange(style_path; module_context=runner.mod)
    # Load main styling implementation
    spinner = BookSpinner()
    current_cell = Observable{Union{CellEditor,Nothing}}(nothing)
    theme_preference = Observable{String}("auto")
    # Persist mode changes back to meta.toml so re-opening the book
    # restores the user's last-picked mode. We use `on` without a
    # session here because the observable is owned by the Book (it
    # lives across sessions).
    on(logging_mode) do new_mode
        new_mode in LOGGING_MODES || return
        try
            write_book_meta!(folder, Dict("logging_mode" => string(new_mode)))
        catch e
            @warn "Failed to persist logging_mode" exception = e
        end
    end
    book = Book(
        markdown_file, folder, editors, runner, progress, nothing, nothing, Dict{String,Any}(),
        global_logging_widget, style_eval, spinner, current_cell, theme_preference, monaco_theme,
        cell_id_counter, Ref(UInt64(0)), nothing, logging_mode, console_log,
    )
    for cell in book.cells
        cell.book = book  # Set back-reference to the parent book
    end
    Core.eval(runner.mod, :(current_book() = $(book)))
    # Add data string macro for convenient data folder access
    Core.eval(runner.mod, :(macro data_str(path)
        joinpath(current_book().folder, "data", path)
    end))
    notify(style_eval.file_watcher)
    export_md(markdown_file, book)
    return book
end

"""
    create_book(file; folder=nothing, replace_style=false, all_blocks_as_cell=false, plugin=nothing, plugin_kw_args...)

Create a Book instance from .md or .ipynb file. This is the entry point for the plugin system.
If a plugin exists, returns the plugin-specific book type. Otherwise returns a standard Book.

**Book Constructor Arguments:**
- `file::String`: Path to .md or .ipynb file
- `folder::Union{Nothing, String}`: Folder for .book-name-bbook structure (default: auto-create next to .md file)
- `replace_style::Bool`: Replace style.jl with template (default: false)
- `all_blocks_as_cell::Bool`: Treat all code blocks as cells (default: false)
- `plugin::Union{Nothing, Module}`: Plugin module to apply

**Plugin Arguments:**
- `plugin_kw_args...`: Additional keyword arguments passed to the plugin's create_book function
"""
function create_book(user_file::String; folder=nothing, replace_style=false, all_blocks_as_cell=false, plugin=nothing, plugin_kw_args...)
    plugin_template = nothing
    plugin_module_name = nothing
    if plugin !== nothing
        if !(plugin isa Module)
            error("`plugin` must be a Module, got $(typeof(plugin))")
        end
        plugin_template = plugin_template_path(plugin)
        plugin_module_name = plugin_fullname(plugin)
    end
    # Create basic Book instance with explicit Book constructor arguments
    book = Book(
        user_file;
        folder=folder,
        replace_style=replace_style,
        all_blocks_as_cell=all_blocks_as_cell,
        plugin_template=plugin_template,
        plugin_module_name=plugin_module_name
    )
    if plugin isa Module
        if !isdefined(plugin, :create_book)
            error("Plugin module $(plugin_fullname(plugin)) must define create_book(book::BonitoBook.Book; kwargs...)")
        end
        create_book_method = getfield(plugin, :create_book)
        if !hasmethod(create_book_method, (BonitoBook.Book,))
            error("Plugin module $(plugin_fullname(plugin)) create_book must accept BonitoBook.Book as first argument")
        end
        return Base.invokelatest(() -> create_book_method(book; plugin_kw_args...))
    end
    # Check for plugin extension
    extension = joinpath(book.folder, "book.jl")
    if isfile(extension)
        @info "Loading book extension: $extension"
        mod = Base._include(identity, book.runner.mod, extension)
        if !(mod isa Module)
            error("book.jl did not return a module")
        end
        return Base.invokelatest() do
            if !isdefined(mod, :create_book)
                error("The module in book.jl must define a create_book(book::Book; kwargs...) function")
            end
            create_book_method = getfield(mod, :create_book)
            if !hasmethod(create_book_method, (BonitoBook.Book,))
                error("The create_book function in book.jl must accept a BonitoBook.Book as first argument")
            end
            # Forward only plugin-specific kwargs to the plugin
            return create_book_method(book; plugin_kw_args...)
        end
    end
    # No plugin found, return basic Book
    return book
end

"Get the tabbed file editor widget."
function get_file_editor(book::Book)::TabbedFileEditor
    return book.widgets["file_editor"]
end
# New book-specific version
function monaco_theme!(book::Book, name::String)
    return book.monaco_theme[] = name
end

"Book cell with source code and display options."
struct Cell
    language::String
    source::String
    output::Any

    show_editor::Bool
    show_logging::Bool
    show_output::Bool

    id::Int
    metadata::Dict{Symbol, Any}
end


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
        class="saving small-menu-bar"
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
            x = Bonito.wait_for(() -> isempty(book.runner.task_queue))
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
        class="saving small-menu-bar"
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
            Base.delete!(book, editor)
        end
    end
    return
end

"""
    delete!(book::Book, editor::CellEditor)

Delete a cell editor from the book and clean up all associated resources.

- `book::Book`: Book instance
- `editor::CellEditor`: Cell editor to delete
"""
function Base.delete!(book::Book, editor::CellEditor)
    # Clear current cell if it's being deleted
    if book.current_cell[] === editor
        book.current_cell[] = nothing
    end

    # Clean up all observables using the editor's close method
    close(editor)

    # Remove from book cells list
    filter!(x -> x.uuid != editor.uuid, book.cells)

    # Remove from DOM
    evaljs(
        book.session, js"""
            $(Monaco).then(Monaco => {
                Monaco.BOOK.remove_editor($(editor.uuid));
            })
        """
    )

    # Save the notebook after cell deletion
    save(book)

    return nothing
end

"Save book with versioned backup."
function save(book::Book)
    if !isdir(joinpath(book.folder, ".versions"))
        mkpath(joinpath(book.folder, ".versions"))
    end
    version = Dates.format(Dates.now(), "yyyy-mm-dd_HHMMSS")
    # Create backup with original filename
    backup_name = "$(splitext(basename(book.file))[1])-$version.md"
    cp(book.file, joinpath(book.folder, ".versions", backup_name); force=true)
    result = export_md(book.file, book)
    # Record hash so file watcher can ignore our own saves
    book.last_save_hash[] = hash(read(book.file))
    return result
end

"""
    apply_file_changes!(book::Book)

Detect external changes to the markdown file and update the notebook.
Uses cell IDs to match old cells to new cells, preserving execution state
for unchanged cells.
"""
function apply_file_changes!(book::Book)
    # Skip if this is our own save
    file_hash = hash(read(book.file))
    file_hash == book.last_save_hash[] && return

    new_cells = load_book(book.file)

    # Build ID -> editor lookup for current cells
    old_by_id = Dict(c.uuid => c for c in book.cells)

    # Match new cells to old ones by ID
    new_editors = CellEditor[]
    matched_ids = Set{Int}()

    for cell in new_cells
        if haskey(old_by_id, cell.id)
            # Existing cell - update source if changed
            editor = old_by_id[cell.id]
            push!(matched_ids, cell.id)
            if editor.editor.source[] != cell.source
                # Source changed externally - update Julia-side observable
                editor.editor.source[] = cell.source
                # Also push to JS if session is active
                if !isnothing(book.session)
                    set_source!(editor.editor, cell.source)
                end
                # Re-run markdown cells immediately
                if cell.language == "markdown"
                    run_sync!(editor.editor)
                end
            end
            push!(new_editors, editor)
        else
            # New cell - create editor
            new_editor = CellEditor(
                cell.source, string(cell.language), book.runner;
                show_editor=cell.show_editor,
                show_logging=cell.show_logging,
                show_output=cell.show_output,
                theme=book.monaco_theme,
                metadata=cell.metadata,
                id=cell.id
            )
            new_editor.book = book
            push!(new_editors, new_editor)
        end
    end

    # Find deleted cells (old cells not in matched_ids)
    for editor in book.cells
        if !(editor.uuid in matched_ids)
            close(editor)
        end
    end

    # Update the book cells array
    book.cells = new_editors

    # Sync JS state if session is available
    if !isnothing(book.session)
        evaljs(book.session, js"""
            $(Monaco).then(Monaco => {
                Monaco.BOOK.update_order($(map(c -> c.uuid, book.cells)));
            })
        """)
    end

    # Record current state as our last known hash
    book.last_save_hash[] = file_hash
    return
end

"""
    start_file_watcher!(book::Book)

Start watching the book's markdown file for external changes.
Reuses the same FileWatching pattern as EvalFileOnChange.
"""
function start_file_watcher!(book::Book)
    !isnothing(book.file_watcher) && return
    watcher = Observable(mtime(book.file))
    current_output = Observable{Any}(nothing)
    last_valid_output = Observable{Any}(nothing)
    file_watcher_task = Ref{Task}()
    close_flag = Threads.Atomic{Bool}(false)
    efo = EvalFileOnChange(
        book.file, current_output, last_valid_output,
        watcher, file_watcher_task, close_flag
    )
    # Override the default eval behavior - instead of evaluating the file,
    # detect changes and diff
    Observables.clear(watcher)
    on(watcher) do _time
        try
            apply_file_changes!(book)
        catch e
            @warn "Error applying file changes" exception=(e, catch_backtrace())
        end
    end
    start_watch_loop!(efo)
    book.file_watcher = efo
    return
end

"""
    ensure_cell_id!(book, editor)

Assign the next available cell id when `editor.uuid == 0`. CellEditors
created at runtime (via the +-menu, plugins, or tests) default to
uuid=0, which collides with every other freshly-inserted cell — and
`delete!(book, editor)` uses uuid equality to identify the row to
remove, so a single delete on uuid=0 would purge every freshly-inserted
cell at once. Assigning a unique id at insert time prevents that.
"""
function ensure_cell_id!(book::Book, editor::CellEditor)
    if editor.uuid == 0
        editor.uuid = book.cell_id_counter[]
        book.cell_id_counter[] += 1
    end
    # Keep the EvalEditor's cell_id mirror in sync so the runner stamps
    # console-log entries with the assigned id, not the placeholder 0.
    editor.editor.cell_id[] = editor.uuid
    return editor.uuid
end

"""
    insert_editor!(book, editor, index::Int)

Insert editor at a specific 1-based index position.

- `book::Book`: Book instance
- `editor::CellEditor`: Cell editor to insert
- `index::Int`: 1-based index (1 = beginning, length(cells)+1 = end)
"""
function insert_editor!(book, editor, index::Int)
    # Set book reference
    editor.book = book
    ensure_cell_id!(book, editor)

    # Update book.cells array
    if index == 1
        pushfirst!(book.cells, editor)
    elseif index > length(book.cells)
        push!(book.cells, editor)
    else
        insert!(book.cells, index, editor)
    end
    # Save
    save(book)
    # Insert into DOM using dom_in_js which properly handles sub-session creation
    # This avoids the "double freeing session" bug that occurs when manually creating
    # a sub-session with Session(book.session) and using jsrender without proper initialization
    return Bonito.dom_in_js(
        book.session, editor, js"""(elem) => {
            $(Monaco).then(Monaco => {
                Monaco.insert_editor_at_index(elem, $(editor.uuid), $(index));
            })
        }"""
    )
end

"""
    move_cell!(book::Book, from_uuid::Int, to_index::Int)

Move a cell from its current position to a new 1-based index.
Updates both the Julia cells array and saves the markdown.
"""
function move_cell!(book::Book, from_uuid::Int, to_index::Int)
    from_idx = findfirst(x -> x.uuid == from_uuid, book.cells)
    isnothing(from_idx) && return
    to_index = clamp(to_index, 1, length(book.cells))
    from_idx == to_index && return

    editor = book.cells[from_idx]
    deleteat!(book.cells, from_idx)
    # Adjust target index after removal
    adjusted = from_idx < to_index ? to_index - 1 : to_index
    insert!(book.cells, adjusted, editor)
    save(book)
    return
end

function insert_editor_below!(book, editor, editor_above_uuid)
    if editor_above_uuid == "beginning"
        return insert_editor!(book, editor, 1)
    end
    idx = findfirst(x -> x.uuid == editor_above_uuid, book.cells)
    if isnothing(idx)
        # Append at end
        return insert_editor!(book, editor, length(book.cells) + 1)
    else
        return insert_editor!(book, editor, idx + 1)
    end
end


function insert_cell_at!(book::Book, editor::CellEditor, pos)
    if pos == :begin
        if isempty(book.cells)
            # If no cells exist, add directly and handle manually
            editor.book = book
            ensure_cell_id!(book, editor)
            push!(book.cells, editor)
            return Bonito.dom_in_js(
                book.session, editor, js"""(elem) => {
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
            return insert_cell_at!(book, editor, :begin)
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
            return insert_cell_at!(book, editor, :begin)
        elseif pos == length(book.cells) + 1
            # Insert at end
            return insert_cell_at!(book, editor, :end)
        else
            # Insert at specific position by using the editor above as reference
            editor_above_uuid = book.cells[pos-1].uuid
            return insert_editor_below!(book, editor, editor_above_uuid)
        end
    else
        error("Invalid position $pos. Must be :begin, :end, or an integer")
    end
end

"""
    insert_cell_at!(book, source, lang, pos)

Insert cell at position (:begin, :end, or index).

- `book::Book`: Book to modify
- `source::String`: Cell content
- `lang::String`: Language (julia, markdown, python)
- `pos`: Position (:begin, :end, or integer index)
"""
function insert_cell_at!(book::Book, source::String, lang::String, pos)
    # Create cell editor with appropriate settings
    editor = if lang == "markdown"
        CellEditor(source, lang, book.runner; show_editor=false, show_output=true, theme=book.monaco_theme)
    else
        CellEditor(source, lang, book.runner; theme=book.monaco_theme)
    end
    editor.book = book  # Set back-reference to the parent book

    # Handle different position types by finding the editor above

end

function new_cell_menu(book, editor_above_uuid, runner, above_cell_language="julia")
    buttons = []

    for (lang_name, lang) in ALL_LANGUAGES
        # Check if language has evaluator (always true for always_available languages)
        is_available = lang.always_available || (isa(runner, AsyncRunner) && haskey(runner.language_evaluators, lang_name))

        # Create button
        button, click = SmallButton(lang.icon; inactive=!is_available)

        # Add tooltip for inactive buttons with activation instructions
        if !is_available && !isempty(lang.activation_help)
            button_tooltip = Tooltip(button, lang.activation_help; position="top")
        else
            button_tooltip = Tooltip(button, "Add new $(lang_name) cell"; position="top")
        end

        push!(buttons, button_tooltip)

        # Always attach handler - inactive buttons won't trigger them
        on(click) do _
            if lang_name == "markdown"
                new_cell = CellEditor("", lang_name, runner; show_editor=true, show_output=false, theme=book.monaco_theme)
            else
                new_cell = CellEditor("", lang_name, runner; theme=book.monaco_theme)
            end
            insert_editor_below!(book, new_cell, editor_above_uuid)
        end
    end

    # Create the plus icon (just the icon, no button wrapper)
    plus_value = Observable(false)
    plus_tooltip = Tooltip(
        DOM.div("+"),
        "Add new $(above_cell_language) cell (same as above)";
        position="top"
    )
    plus_icon = DOM.div(
        plus_tooltip;
        class="new-cell-plus",
        onclick=js"event => $(plus_value).notify(true)"
    )

    # Add click handler to plus icon
    on(plus_value) do _
        if above_cell_language == "markdown"
            new_cell = CellEditor("", above_cell_language, runner; show_editor=true, show_output=false, theme=book.monaco_theme)
        else
            new_cell = CellEditor("", above_cell_language, runner; theme=book.monaco_theme)
        end
        insert_editor_below!(book, new_cell, editor_above_uuid)
    end

    # Create the language buttons container
    buttons_container = DOM.div(buttons...; class="new-cell-buttons")

    return DOM.div(
        plus_icon,
        buttons_container;
        class="new-cell-menu"
    )
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

"""
    logging_mode_option(book, mode, label, desc) -> DOM element

One clickable row in the logging-mode picker. Factored out so the
inner closures don't capture loop-bound variables from a `map do`
block (Hyperscript's `kw...` splat tripped over the closure-capture
mechanism in mysterious ways).
"""
function logging_mode_option(book::Book, mode::Symbol,
                              label::AbstractString, desc::AbstractString)
    cls = map(book.logging_mode) do current
        base = "logmode-option"
        current === mode ? base * " active" : base
    end
    return DOM.div(
        DOM.div(label; class = "logmode-option-label"),
        DOM.div(desc;  class = "logmode-option-desc");
        class = cls,
        onclick = js"() => $(book.logging_mode).notify($(string(mode)))",
    )
end

"""
    logging_mode_picker(book) -> DOM element

Build a 4-row radio-style picker for `book.logging_mode`. Each row
sets `book.logging_mode[]` when clicked; the corresponding
`meta.toml` write is wired in the Book constructor. The currently
active mode gets the `active` class so CSS can style it as selected.
"""
function logging_mode_picker(book::Book)
    options = [
        (:respect_cell, "Per-cell setting",
         "Follow each cell's own log toggle (default)."),
        (:show_all,     "Show all inline",
         "Always display every cell's log under it."),
        (:hide_all,     "Hide all",
         "Hide every cell's log. Output is still captured."),
        (:console,      "Send to console",
         "Hide inline; show attributed log in the bottom panel."),
    ]
    rows = [logging_mode_option(book, opt[1], opt[2], opt[3]) for opt in options]
    return DOM.div(
        DOM.div("Logging mode"; class = "logmode-picker-title"),
        rows...;
        class = "logmode-picker",
    )
end

function setup_menu(book::Book, tabbed_file_editor::TabbedFileEditor)
    # ── Style editor button (was the entire settings menu)
    style_setting_button, style_click = SmallButton("paintcan")
    on(style_click) do _click
        style_path = initialize_file_for_editing(
            book.folder, "style.jl";
            plugin_template = get_plugin_template_path(book.folder),
        )
        update_filepath!(book.style_eval, style_path)
        open_file!(tabbed_file_editor, style_path)
    end
    style_button_tooltip = Tooltip(
        style_setting_button, "Open style editor"; position = "bottom",
    )

    # ── Settings popup (gear icon → opens picker)
    settings_button, settings_click = SmallButton("settings")
    settings_popup = PopUp(logging_mode_picker(book); show = false)
    on(settings_click) do _click
        settings_popup.show[] = true
    end
    settings_button_tooltip = Tooltip(
        settings_button, "Settings"; position = "bottom",
    )

    return DOM.div(
        style_button_tooltip,
        settings_button_tooltip,
        settings_popup;
        class = "settings small-menu-bar",
    )
end

function setup_completions(session, cell_module)
    inbox = Observable{Any}([])
    outbox = Observable{Any}([])
    on(session, outbox) do (id, data)
        try
            text = data["text"]
            completions = get_completions(text, lastindex(text), cell_module)
            inbox[] = [id, completions]
        catch e
            @error "Error getting completions: $e"
            inbox[] = [id, []]
        end
        return
    end
    return js"""
        $(Monaco).then(Monaco => {
            Monaco.register_completions($inbox, $outbox);
        })
    """
end

function standard_setup!(session::Session, book::Book)
    book.session = session

    # Observable for receiving cell move messages from JS drag & drop
    move_cell_obs = Observable(Dict{String,Any}())
    on(session, move_cell_obs) do msg
        haskey(msg, "uuid") || return
        haskey(msg, "to_index") || return
        from_uuid = Int(msg["uuid"])
        to_index = Int(msg["to_index"])
        move_cell!(book, from_uuid, to_index)
    end

    register_book = js"""
        $(Monaco).then(Monaco => {
            Monaco.BOOK.update_order($(map(c-> c.uuid, book.cells)));
            Monaco.BOOK.setup_drag_drop($(move_cell_obs));
        })
    """

    completions = setup_completions(session, book.runner.mod)

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

    # Reactively project `book.logging_mode` onto a `logmode-<mode>`
    # class on `<body>`. CSS rules in style.jl key off this class to
    # show/hide inline logging divs and the bottom-panel console.
    # We keep one and only one `logmode-*` class on body at a time so
    # the rules don't have to disambiguate which mode is active.
    logmode_tracking = js"""
        const ALL_MODES = ['respect_cell', 'hide_all', 'show_all', 'console'];
        function apply_logmode(mode) {
            for (const m of ALL_MODES) {
                document.body.classList.remove('logmode-' + m);
            }
            // Default to respect_cell if the mode isn't one we know about.
            const safe = ALL_MODES.indexOf(mode) >= 0 ? mode : 'respect_cell';
            document.body.classList.add('logmode-' + safe);
        }
        apply_logmode($(book.logging_mode).value);
        $(book.logging_mode).on(apply_logmode);
    """
    on(session.on_close) do closed
        if closed
            close(book.runner)
            if !isnothing(book.file_watcher)
                book.file_watcher.close[] = true
            end
        end
        return
    end
    # Start watching the markdown file for external changes
    start_file_watcher!(book)
    style = book.style_eval.last_valid_output
    codicon = Styles(
        CSS(
            "@font-face",
            "font-family" => "codicon",
            "src" => assets("codicon.ttf"),
            "font-weight" => "normal",
            "font-style" => "normal"
        )
    )
    return [codicon, style, completions, register_book, theme_tracking, logmode_tracking]
end

function Bonito.jsrender(session::Session, book::Book)
    book.session = session
    session.metadata[:current_book] = book
    runner = book.runner
    add_julia_mpc_route!(book)

    # Cells render themselves with menu and callbacks via CellEditor.jsrender
    cells = book.cells

    # Create tabbed editor instead of separate file tabs
    tabbed_editor = TabbedFileEditor(String[])
    book.widgets["file_editor"] = tabbed_editor
    _setup_menu = setup_menu(book, tabbed_editor)
    save = saving_menu(session, book)
    player = play_menu(book)

    menu = DOM.div(save, player, _setup_menu; class="book-main-menu")

    # Wrap cells in scrollable area
    cells_area = DOM.div(DOM.div(cells; class="book-cells"); class="book-cells-area")
    # Create chat component with appropriate agent
    chat_agent = create_chat_agent(book)
    chat_component = ChatComponent(chat_agent; book=book)
    book.widgets["chat"] = chat_component

    # Create sidebar with widgets from book
    sidebar = Sidebar([
            ("file-editor", book.widgets["file_editor"], "File Editor", "file-code"),
            ("chat", book.widgets["chat"], "AI Chat", "chat-sparkle")
        ]; width="800px")

    # Create horizontal sidebar for global logging
    # The bottom panel is the user's view into `book.console_log` —
    # the attributed history of every chunk of cell stdout/stderr,
    # populated by the runner regardless of mode. CSS in style.jl
    # hides this whole panel unless `body.logmode-console` is on
    # (i.e. the user picked the console mode in the settings popup).
    console_widget = ConsoleLogWidget(book.console_log)
    global_logging_sidebar = Sidebar([
            ("console", console_widget, "Console", "terminal")
        ]; width="100vw", orientation="horizontal")

    # Create content area that includes both cells and sidebar
    content = DOM.div(cells_area, sidebar; class="book-content")

    # Create menu and spinner container to match width
    menu_and_spinner = DOM.div(book.spinner, menu; class="book-menu-container")

    # Create main content area (everything except the bottom global logging)
    main_content = DOM.div(menu_and_spinner, content; class="book-main-content")

    # Create document structure with main content and bottom global logging
    document = DOM.div(
        main_content,
        DOM.div(global_logging_sidebar; class="book-bottom-panel");
        class="book-document"
    )
    elements = standard_setup!(session, book)
    return Bonito.jsrender(session, DOM.div(elements, document; class="book-wrapper"))
end

"""
    current_cell(book::Book)

Get currently selected cell editor.

- `book::Book`: Book instance
"""
function current_cell(book::Book)::Union{CellEditor,Nothing}
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

const BOOK_SERVERS = Dict{Int,Bonito.Server}()

function get_server(url, port, proxy_url)
    server = get!(BOOK_SERVERS, port) do
        return Bonito.Server(url, port; proxy_url=proxy_url)
    end
    server.proxy_url = proxy_url
    return server
end


"""
    book(path; replace_style=false, all_blocks_as_cell=false, url="127.0.0.1", port=8773, proxy_url="", openbrowser=true, folder=nothing, plugin=nothing)

Launch a BonitoBook server for interactive notebook editing.

- `path::AbstractString`: Path to .md or .ipynb file
- `folder::Union{Nothing, AbstractString}`: Folder for .book-name-bbook structure (default: auto-create next to .md file)
- `plugin::Union{Nothing, Module}`: Plugin module to apply
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
    folder=nothing,
    plugin=nothing,
    port=8773,
    proxy_url="",
    openbrowser=true,
    plugin_args...
)
    name = splitext(basename(path))[1]
    app = App(title=name) do
        return create_book(path; replace_style=replace_style, all_blocks_as_cell=all_blocks_as_cell, folder=folder, plugin=plugin, plugin_args...)
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
