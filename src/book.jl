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
    style_dark_path = joinpath(folder, "styles", "style-dark.jl")
    files = [book, project, manifest, style_path, style_dark_path]
    for file in files
        if !isfile(file)
            error("File $file not found, not a BonitoBook?")
        end
    end
    Pkg.activate(folder; io=IOBuffer())
    return book, folder, [style_path, style_dark_path]
end

function from_file(book, folder)
    if isdir(folder)
        return from_folder(folder)
    end
    style_path_template = joinpath(@__DIR__, "templates/style.jl")
    style_dark_path_template = joinpath(@__DIR__, "templates/style-dark.jl")
    mkpath(joinpath(folder, "styles"))
    style_path = joinpath(folder, "styles", "style.jl")
    style_dark_path = joinpath(folder, "styles", "style-dark.jl")

    cp(style_path_template, style_path)
    cp(style_dark_path_template, style_dark_path)
    # Copy over project so mutations stay in the book
    project = Pkg.project().path
    cp(project, joinpath(folder, "Project.toml"))
    cp(joinpath(dirname(project), "Manifest.toml"), joinpath(folder, "Manifest.toml"))
    Pkg.activate(folder; io=IOBuffer())

    return book, folder, [style_path, style_dark_path]
end

function Book(file; folder=nothing, runner=AsyncRunner())
    runner.mod.eval(runner.mod, :(using Bonito, Markdown, BonitoBook, WGLMakie))
    if isfile(file)
        bookfile, folder, style_paths = from_file(file, folder, runner)
    elseif isdir(file)
        bookfile, folder, style_paths = from_folder(file, runner)
    else
        error("File $file isnt a file or folder")
    end
    cells = load_book(bookfile)
    editors = cells2editors(cells, runner)
    style_editor = FileEditor(style_paths..., runner; editor_classes=["styling file-editor"], show_editor=false)
    run!(style_editor.editor) # run the style editor to get the output Styles
    @assert style_editor.editor.output[] isa Styles
    progress = Observable((false, 0.0))
    book = Book(bookfile, folder, editors, style_editor, runner, progress)
    export_md(joinpath(folder, "book.md"), book)
    runner.callback[] = (cell, source, result) -> begin
        if cell.editor.source[] != source
            export_md(joinpath(folder, "book.md"), book)
        end
    end
end

struct Cell
    language::String
    source::String
    output::Any

    show_editor::Bool
    show_logging::Bool
    show_output::Bool
    show_chat::Bool
end

Cell(language, source) = Cell(language, source, nothing, false, false, true, false)

function trigger_js_download(session, file)
    evaljs(session, js"""
        const a = document.createElement('a');
        a.href = $(Bonito.url(session, Asset(file)));
        a.download = $(basename(file));
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    """)
end

function saving_menu(session, book)
    save_jl, click_jl = SmallButton(; class="julia-dots")
    on(click_jl) do click
        Base.errormonitor(Threads.@async begin
            file = export_jl(joinpath(book.folder, "book.html"), book)
            trigger_js_download(session, file)
        end)
    end
    save_md, click_md = SmallButton(; class="codicon codicon-markdown")
    on(click_md) do click
        Base.errormonitor(Threads.@async begin
            file = export_md(joinpath(book.folder, "book.md"), book)
            trigger_js_download(session, file)
        end)
    end
    save_pdf, click_pdf = SmallButton(; class="codicon codicon-file-pdf")
    return DOM.div(DOM.div(class="button-pad codicon codicon-save", save_jl, save_md, save_pdf);
        class="saving small-menu-bar"
    )
end

function play_menu(book)
    run_all_div, run_all_click = SmallButton(; class="codicon codicon-play")
    stop_all_div, stop_all_click = SmallButton(; class="codicon codicon-debug-stop")
    on(stop_all_click) do click
        println("Stopping all cells")
        # Base.errormonitor(interrupt!(runner))
    end
    on(run_all_click) do click
        task = @async for cell in book.cells
            # fetches source only if unsaved source is there
            # After that, runs cell
            cell.editor.loading[] = true
            run_from_newest!(cell.editor)
        end
        Base.errormonitor(task)
    end
    return DOM.div(DOM.div(run_all_div, stop_all_div);
        class="saving small-menu-bar"
    )
end

function new_cell_menu(session, book, editor_above_uuid, runner)
    new_jl, click_jl = SmallButton(; class="julia-dots")
    new_md, click_md = SmallButton(; class="codicon codicon-markdown")
    new_py, click_py = SmallButton(; class="python-logo")
    new_ai, click_ai = SmallButton(; class="codicon codicon-sparkle-filled")

    function insert_editor(editor)
        idx = findfirst(x-> x.uuid == editor_above_uuid, book.cells)
        insert!(book.cells, idx + 1, editor)
        add_cell_div = new_cell_menu(session, book, editor.uuid, runner)
        elem = DOM.div(editor, add_cell_div)
        Bonito.dom_in_js(session, elem, js"""(elem) => {
            $(Monaco).then(Monaco => {
                Monaco.add_editor_below($editor_above_uuid, elem, $(editor.uuid));
            })
        }""")
    end

    on(click_jl) do click
        new_cell = CellEditor("", "julia", runner)
        insert_editor(new_cell)
    end
    on(click_md) do click
        new_cell = CellEditor("", "markdown", runner)
        new_cell.show_editor[] = true
        new_cell.show_output[] = false
        insert_editor(new_cell)
    end
    on(click_ai) do click
        new_cell = CellEditor("", "chatgpt", runner)
        new_cell.show_chat[] = true
        new_cell.show_editor[] = false
        new_cell.show_output[] = false
        insert_editor(new_cell)
    end
    plus = DOM.div(class="codicon codicon-plus")
    menu_div = DOM.div(
        plus, new_jl, new_md, new_py, new_ai;
        class="saving small-menu-bar",
    )
    return DOM.div(Centered(menu_div); class="new-cell-menu")
end

function setup_menu(book)
    buttons_enabled = Observable(true)
    keep = Button("keep"; enabled=buttons_enabled)
    reset = Button("reset"; enabled=buttons_enabled)
    styling_popup_text = Observable(DOM.h3("Do you want to keep the styling changes?"))
    popup_content = DOM.div(
        styling_popup_text,
        DOM.div(keep, reset; class="flex-row gap-10"),
    )
    popup = PopUp(popup_content; show=false)
    style_fe = book.style_editor
    show_editor = Observable(false)
    on(show_editor) do show
        toggle!(style_fe.editor, editor=show)
    end
    style_fe_toggle = SmallToggle(show_editor; class="codicon codicon-paintcan")
    menu = DOM.div(DOM.div(class="codicon codicon-settings", style_fe_toggle);
        class="settings small-menu-bar"
    )
    last_style = Ref{Styles}(style_fe.editor.output[])
    last_source = Ref{String}(style_fe.editor.source[])
    output = Observable{Any}(last_style[])
    should_popup = Ref(false)
    on(style_fe.editor.output; update=true) do out
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
            output[] = out
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
            last_style[] = output[]
            last_source[] = style_fe.editor.source[]
        end
    end
    on(reset.value) do click
        popup.show[] = false
        should_popup[] = false
        style_fe.editor.set_source[] = last_source[]
    end
    return menu, style_fe, DOM.span(popup, output)
end

function setup_completions(session, cell_module)
    inbox = Observable{Any}(Dict{String,Any}())
    outbox = Observable{Any}(Dict{String,Any}())
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
        return DOM.div(editor, add_cell_div)
    end
    register_book = js"""
        $(Monaco).then(Monaco => {
            Monaco.BOOK.update_order($(map(c-> c.uuid, book.cells)));
        })
    """
    for editor in book.cells
        on(session, editor.delete_self) do delete
            if delete
                filter!(x -> x.uuid != editor.uuid, book.cells)
                evaljs(session, js"""
                    $(Monaco).then(Monaco => {
                        Monaco.BOOK.remove_editor($(editor.uuid));
                    })
                """)
            end
        end
    end
    cell_obs = DOM.div(cells...)
    _setup_menu, style_editor, style_output = setup_menu(book)
    save = saving_menu(session, book)
    player = play_menu(book)
    cell_obs = DOM.div(cells...; class="inline-block fit-content")
    content = DOM.div(cell_obs, style_editor; class="flex-row gap-10 fit-content")
    menu = DOM.div(save, player, _setup_menu; class="flex-row gap-10 fit-content")
    document = DOM.div(menu, content; class="flex-column center-content gap-10 full-width")
    completions = setup_completions(session, runner.mod)
    on(session.on_close) do close
        runner.open[] = false
    end
    return Bonito.jsrender(session, DOM.div(style_output, completions, register_book, document))
end
