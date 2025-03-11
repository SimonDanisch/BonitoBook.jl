struct Cell
    language::Symbol
    source::Observable{String}
    parsed::Any
    output::Any
end

Cell(language, source, parsed) = Cell(Symbol(language), source, parsed, nothing)

struct Book
    cells::Vector{Cell}
end

function markdown2book(md)
    cells = Cell[]
    last_md = nothing
    for content in md.content
        if content isa Markdown.Code
            if !isnothing(last_md)
                parsed = Markdown.MD(last_md, md.meta)
                push!(cells, Cell("markdown", string(parsed), parsed))
                last_md = nothing
            end
            push!(cells, Cell(content.language, content.code, nothing))
        else
            isnothing(last_md) && (last_md = [])
            push!(last_md, content)
        end
    end
    return cells
end

function export_jl(file, cells)
    app = App() do s
        body = Centered(DOM.div(cells))
        document = DOM.div(DOM.div(body; style=Styles("width" => "210mm")))
        return DOM.div(Bonito.MarkdownCSS, BOOK_STYLE, document)
    end
    Bonito.export_static(file, app)
    return file
end

struct BookState
    folder::String
    history::Vector{Vector{Cell}}
    cells::Vector{Cell}
    commands::Observable{Dict{String, String}}
    runners::Dict{String, Any}
end

include("templates/style.jl")


function small_menu(elems...)


end

function saving_menu(session, cell_obs)
    save_jl, click_jl = SmallButton(; class="julia-dots")
    on(click_jl) do click
        Base.errormonitor(Threads.@async begin
            file = export_jl("book.html", cell_obs)
            evaljs(
                session,
                js"""
                    const a = document.createElement('a');
                    a.href = $(Bonito.url(session, Asset("book.html")));
                    a.download = 'book.html';
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                """
            )
        end)
    end
    save_md, click_md = SmallButton(; class="codicon codicon-markdown")
    save_pdf, click_pdf = SmallButton(; class="codicon codicon-file-pdf")
    return DOM.div(DOM.div(class="codicon codicon-save", save_jl, save_md, save_pdf);
        class="saving small-menu-bar"
    )
end


function setup_menu(runner)
    style_path = joinpath(@__DIR__, "templates/style.jl")
    style_fe = FileEditor(style_path, runner; editor_classes=["styling file-editor"], show_editor=false)
    notify(style_fe.editor.source)
    Bonito.wait_for(()-> !isnothing(style_fe.editor.output[]))
    style_fe_toggle = SmallToggle(style_fe.editor.show_editor; class="codicon codicon-paintcan")
    menu = DOM.div(DOM.div(class="codicon codicon-settings", style_fe_toggle);
        class="settings small-menu-bar"
    )
    return menu, style_fe
end

function book(session::Session, file)
    md = Markdown.parse_file(file)
    cells = markdown2book(md)
    runner = Bonito.ModuleRunner(Module())
    runner.mod.eval(runner.mod, :(using Bonito, Markdown, BonitoBook, WGLMakie))
    editors = map(cells) do cell
        editor = CellEditor(cell.source[], string(cell.language), runner)
        return editor
    end

    cell_obs = DOM.div(editors...; style=Styles("width" => "fit-content"))
    button_jl, add_jl = SmallButton(; class="julia-dots")
    button_md, add_md = SmallButton(; class="codicon codicon-markdown")
    button_chat, add_chat = SmallButton(; class="codicon codicon-sparkle-filled")

    on(add_jl) do click
        new_cell = CellEditor("", "julia", runner)
        Bonito.append_child(session, cell_obs, new_cell)
    end
    on(add_md) do click
        new_cell = CellEditor("", "markdown", runner)
        Bonito.append_child(session, cell_obs, new_cell)
    end
    on(add_chat) do click
        new_cell = CellEditor("", "chatgpt", runner)
        new_cell.show_ai[] = true
        new_cell.show_editor[] = false
        new_cell.show_output[] = false
        Bonito.append_child(session, cell_obs, new_cell)
    end
    add_div = DOM.div(DOM.div(class="codicon codicon-add"), button_jl, button_md, button_chat)

    save = saving_menu(session, cell_obs)
    _setup_menu, style_editor = setup_menu(runner)

    cell_obs = DOM.div(editors...; style=Styles("width" => "fit-content", "display" => "inline-block", "max-width" => "90ch"))
    content = DOM.div(cell_obs, style_editor;
        style=Styles(
            "display" => "flex",
            "width" => "fit-content",
            "flex-direction" => "row",  # Ensures elements are placed in a row
            "gap" => "10px"  # Adjust spacing between elements
        )
    )
    menu = DOM.div(save, _setup_menu; style=Styles(
        "display" => "flex",
        "width" => "fit-content",
        "flex-direction" => "row",  # Ensures elements are placed in a row
        "gap" => "10px"  # Adjust spacing between elements
    ))
    document = DOM.div(menu, content, add_div;
        style=Styles(
            "width" => "100%",
            "display" => "flex",
            "flex-direction" => "column",
            "justify-content" => "center",
            "align-items" => "center",  # If you also want vertical centering
            "gap" => "10px"  # Optional: spacing between elements
        )
    )

    return DOM.div(style_editor.editor.output, Bonito.MarkdownCSS, document)
end
