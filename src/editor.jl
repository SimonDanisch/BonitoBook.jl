import PromptingTools as PT

const Monaco = ES6Module(joinpath(@__DIR__, "javascript", "Monaco.js"))
const CodeIcon = Asset("https://cdn.jsdelivr.net/npm/@vscode/codicons@latest/dist/codicon.min.css")

# TODO, this better not be a global, but rather part of `Book`
# Cant be `Observable("default")`, since for a global compiled into the
# Pkg image, it will always end up with ID 1, like any global observable from another Package -.-
const MONACO_THEME = Observable{String}[]

function get_monaco_theme()
    if isempty(MONACO_THEME)
        push!(MONACO_THEME, Observable("default"))
    end
    return MONACO_THEME[1]
end

function monaco_theme!(name::String)
    obs = get_monaco_theme()
    obs[] = name
end


struct MonacoEditor
    language::Observable{String}
    options::Dict{Symbol,Any}
    js_init_func::Base.RefValue{Bonito.JSCode}
    editor_classes::Vector{String}
    show_editor::Observable{Bool}
    hiding_direction::String
end

function MonacoEditor(source; js_init_func=nothing, show_editor=true, editor_classes=String[], language="julia", hiding_direction="vertical", options...)
    defaults = Dict{Symbol, Any}(
        :value => source,
        :language => language,
        :minimap => Dict(:enabled => false),
        :scrollBeyondLastLine => false,
        :scrollbar => Dict(:vertical => "hidden", :horizontal => "hidden", :verticalHasArrows => false),
        :overviewRulerBorder => false,
        :overviewRulerLanes => 0,
        :renderLineHighlight => "none",
        :lineDecorationsWidth => 0,
    )
    if js_init_func === nothing
        js_init_func = js"() => {}"
    end
    opts = merge!(defaults, Dict{Symbol,Any}(options))
    return MonacoEditor(
        Observable(language), opts, Base.RefValue(js_init_func), editor_classes, Observable(show_editor), hiding_direction
    )
end

function Bonito.jsrender(session::Session, editor::MonacoEditor)
    classes = copy(editor.editor_classes)
    push!(classes, "language-$(editor.language[])")
    if editor.show_editor[]
        push!(classes, "show-$(editor.hiding_direction)")
    else
        push!(classes, "hide-$(editor.hiding_direction)")
    end
    eclasses = join(classes, " ")
    editor_div = DOM.div(class="monaco-editor-div $(eclasses)")
    # needs a return statement to actually return a function
    return Bonito.jsrender(session, DOM.div(
        CodeIcon,
        editor_div,
        js"""
        $(Monaco).then(mod => {
            const init_func = $(editor.js_init_func[]);
            mod.setup_editor($(editor_div), $(editor.options),  $(editor.language), init_func, $(editor.show_editor), $(editor.hiding_direction), $(copy(get_monaco_theme())));
        })
        """
    ))
end

struct EvalEditor
    editor::MonacoEditor
    js_init_func::Bonito.JSCode
    container_classes::Vector{String}
    runner::Any

    source::Observable{String}
    set_source::Observable{String}
    get_source::Observable{Bool}

    output::Observable{Any}
    logging::Observable{String}
    logging_html::Observable{String}

    show_logging::Observable{Bool}
    show_output::Observable{Bool}
    show_editor::Observable{Bool}
    loading::Observable{Bool}
end


function EvalEditor(source, runner=nothing;
        language="julia",
        js_init_func=nothing,
        show_output=true,
        show_editor=true,
        show_logging=true,
        editor_classes=String[],
        container_classes=String[],
        options...
    )
    js_init_func = isnothing(js_init_func) ? js"() => {}" : js_init_func
    editor = MonacoEditor(source; language=language, show_editor=show_editor, editor_classes = editor_classes, options...)
    loading = Observable(false)
    show_output = Observable(show_output)
    show_editor = editor.show_editor
    result = Observable{Any}(nothing)
    src = Observable(source)
    set_src = Observable{String}("")
    on(set_src) do new_source
        src[] = new_source
    end
    get_source = Observable(false)
    logging = Observable("")
    logging_html = Observable("")
    on(logging) do str
        logging_html[] = logging_html[] * str
    end
    editor = EvalEditor(
        editor,
        js_init_func,
        container_classes,
        runner,

        src,
        set_src,
        get_source,

        result,
        logging,
        logging_html,
        Observable(show_logging),
        show_output,
        show_editor,
        loading,
    )
    on(src) do src
        if !isempty(src)
            set_result!(editor, result, runner, src)
        end
    end
    return editor
end

function render_editor(editor::EvalEditor)
    direction = editor.editor.hiding_direction
    hiding = "hide-$direction"
    showing = "show-$direction"
    output_class = editor.show_output[] ? showing : hiding
    logging_class = editor.show_logging[] ? showing : hiding
    output_div = DOM.div(ANSI_CSS, editor.output, class="cell-output $(output_class)")
    logging_html = Observable(HTML(""))
    on(editor.logging_html) do str
        logging_html[] = HTML("<pre>" * str * "</pre>")
    end
    logging_div = DOM.div(logging_html, class="logging-pre $(logging_class)")
    # Set the init func, which we can only do here where we have all divs
    editor.editor.js_init_func[] = js"""((editor, monaco, editor_div) => {
        const output_div = $(output_div);
        const logging_div = $(logging_div);
        return $(Monaco).then(mod => {
            mod.setup_cell_editor(
                editor, monaco, editor_div, output_div, logging_div,
                $(editor.source), $(editor.get_source), $(editor.set_source),
                $(editor.show_output), $(editor.show_logging), $(direction),
            );
            const callback = ($(editor.js_init_func));
            return callback(editor, monaco, editor_div);
        })
    })
    """
    return ( editor.editor, logging_div, output_div)
end

function Bonito.jsrender(session::Session, editor::EvalEditor)
    elems = render_editor(editor)
    return Bonito.jsrender(session, DOM.div(elems...))
end

struct CellEditor
    language::String
    chat::EvalEditor
    editor::EvalEditor
    show_output::Observable{Bool}
    show_editor::Observable{Bool}
    show_ai::Observable{Bool}
    uuid::String
    delete_self::Observable{Bool}
end


function CellEditor(content, language, runner; show_editor=true, show_logging=true, show_output=true, show_ai=false)
    runner = language == "markdown" ? MarkdownRunner() : runner
    uuid = string(UUIDs.uuid4())
    js_init_func = js"""
        (editor, monaco, editor_div) => {
            return $(Monaco).then(Monaco => {
                Monaco.register_editor(editor, monaco, $(uuid))
            })
        }
    """
    jleditor = EvalEditor(
        content, runner; js_init_func=js_init_func,
        show_editor=show_editor, show_logging=show_logging, language=language,
        show_output=show_output,
        tabCompletion = "on"
    )

    if language == "markdown"
        notify(jleditor.source)
    end
    airunner = MLRunner(jleditor)
    show_chat = Observable(show_ai)
    chat = EvalEditor(
        "", airunner;
        show_editor=show_ai, show_output=show_ai, show_logging=show_ai, language="markdown",
        lineNumbers="off", editor_classes=["chat"]
    )
    on(show_chat) do show
        chat.show_editor[] = show
        chat.show_output[] = show
        chat.show_logging[] = show
    end
    return CellEditor(
        language, chat, jleditor, jleditor.show_output,
        jleditor.show_editor, show_chat,
        uuid, Observable(false)
    )
end

function Bonito.jsrender(session::Session, editor::CellEditor)
    jleditor = editor.editor
    chat = editor.chat

    ai = SmallToggle(editor.show_ai; class="codicon codicon-sparkle-filled")
    out = SmallToggle(jleditor.show_output; class="codicon codicon-graph")
    show_editor = SmallToggle(jleditor.show_editor; class="codicon codicon-code")
    show_logging = SmallToggle(jleditor.show_logging; class="codicon codicon-terminal")
    delete_editor, click = SmallButton(class="codicon codicon-close", style="color: red;")
    on(session, click) do x
        editor.delete_self[] = true
    end
    hover_buttons = DOM.div(ai, show_editor, show_logging, out, delete_editor; class="hover-buttons")
    any_visible = map(|, editor.show_ai, jleditor.show_editor, jleditor.show_logging)
    jleditor_div, logging_div, output_div = render_editor(jleditor)
    class = any_visible[] ? "show-vertical" : "hide-vertical"
    card_content = DOM.div(
        chat, jleditor_div, logging_div;
        class="editor-content cell-editor $class",
    )
    cell = DOM.div(hover_buttons, card_content, DOM.div(output_div, tabindex=0), style=Styles("position" => "relative"))
    # Create a separate proximity area
    proximity_area = DOM.div(class="cell-menu-proximity-area")
    container = DOM.div(cell, proximity_area, style=Styles("position" => "relative"))
    any_loading = map(|, chat.loading, jleditor.loading)
    hide_on_focus_obs = Observable(editor.language == "markdown")
    setup_cell_interactions = js"""
    $(Monaco).then(mod => {
        mod.setup_cell_interactions(
            $hover_buttons, $container, $card_content, $any_loading, $any_visible,
            $(hide_on_focus_obs), $(jleditor.show_editor),
            $(jleditor.show_output), $(jleditor.get_source),
        );
    })
    """
    cell_div = DOM.div(CodeIcon, container, setup_cell_interactions, class="cell-editor-container", id=editor.uuid)
    return Bonito.jsrender(session, cell_div)
end

struct FileEditor
    files::Vector{String}
    editor::EvalEditor
    function FileEditor(filepath::Vector{String}, runner=nothing; language="julia", options...)
        source = read(filepath[1], String)
        opts = (
            minimap=Dict(:enabled => true, :autohide => true),
            scrollbar=Dict(),
            overviewRulerBorder=true,
            overviewRulerLanes=2,
            lineDecorationsWidth=10
        )
        js_init_func = js"""(editor, monaco, editor_div) => {
            return $(Monaco).then(Monaco => {
                Monaco.resize_to_lines(editor, monaco, editor_div)
            })
        }"""
        editor = EvalEditor(source, runner; js_init_func=js_init_func, editor_classes=["file-editor"], hiding_direction="horizontal", language=language, opts..., options...)
        return new(filepath, editor)
    end
end

function Bonito.jsrender(session::Session, editor::FileEditor)
    buttons = map(editor.files) do file
        button = Button(basename(file))
        on(session, button.value) do x
            editor.editor.set_source[] = read(file, String)
        end
        return button
    end
    name = DOM.div(buttons...; class="hide-horizontal file-editor-path")
    toggle_js = js"""
        const toggle_div = (show)=> {
            const elem = $(name);
              if (show) {
                elem.classList.remove(`hide-horizontal`);
                elem.classList.add(`show-horizontal`);
            } else {
                elem.classList.add(`hide-horizontal`);
                elem.classList.remove(`show-horizontal`);
            }
        }
        toggle_div($(editor.editor.show_editor[]));
        $(editor.editor.show_editor).on(toggle_div);
    """
    editor_div = DOM.div(editor.editor.editor, class="file-cell-editor")
    meditor, logging_div, output_div = render_editor(editor.editor)
    return Bonito.jsrender(session, DOM.div(
        name,
        editor_div,
        logging_div,
        toggle_js
    ))
end
