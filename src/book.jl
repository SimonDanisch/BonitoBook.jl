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
    history::Vector{Vector{Cell}}
    cells::Vector{Cell}
    commands::Observable{Dict{String, String}}
    runners::Dict{String, Any}
end

include("templates/style.jl")

function book(session::Session, file)
    md = Markdown.parse_file(file)
    cells = markdown2book(md)
    runner = Bonito.ModuleRunner(Module())
    runner.mod.eval(runner.mod, :(using Bonito, Markdown, WGLMakie))
    editors = map(cells) do cell
        editor = CellEditor(cell.source[], string(cell.language), runner)
        return editor
    end
    style_path = joinpath(@__DIR__, "templates/style.jl")
    style_editor = FileEditor(style_path, runner; editor_classes=["file-editor"])

    cell_obs = DOM.div(editors...)
    button_jl, add_jl = SmallButton(; style=JL_ICON_STYLE)
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

    save_jl, click_jl = SmallButton(; style=JL_ICON_STYLE)
    on(click_jl) do click
        Base.errormonitor(Threads.@async begin
            file = export_jl("book.html", cell_obs)
            evaljs(session, js"""
                const a = document.createElement('a');
                a.href = $(Bonito.url(session, Asset("book.html")));
                a.download = 'book.html';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
            """)
        end)
    end
    save_md, click_md = SmallButton(; class="codicon codicon-markdown")
    save_pdf, click_pdf = SmallButton(; class="codicon codicon-file-pdf")
    save = DOM.div(DOM.div(class="codicon codicon-save", save_jl, save_md, save_pdf))
    add_div = Centered(DOM.div(DOM.div(class="codicon codicon-add"), button_jl, button_md, button_chat))
    body = Centered(DOM.div(
        Centered(save),
        cell_obs,
        add_div)
    )
    content = DOM.div(body, style_editor; style=Styles("display" => "flex", "flex-direction" => "row", "width" => "100%"))
    document = DOM.div(DOM.div(content; style=Styles("width" => "100%")))

    return DOM.div(BOOK_STYLE, Bonito.MarkdownCSS, document)
end
