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
    return obs[] = name
end


"""
    MonacoEditor

Wrapper for the Monaco Code Editor with customizable options and themes.

# Fields
- `options::Dict{Symbol, Any}`: Monaco editor configuration options
- `js_init_func::Base.RefValue{Bonito.JSCode}`: JavaScript initialization function
- `editor_classes::Vector{String}`: CSS classes to apply
- `theme::String`: Editor theme name
- `hiding_direction::String`: Direction for show/hide animations
- `init_visible::Bool`: Whether editor is initially visible
"""
struct MonacoEditor
    options::Dict{Symbol, Any}
    js_init_func::Base.RefValue{Bonito.JSCode}
    editor_classes::Vector{String}
    theme::String
    hiding_direction::String
    init_visible::Bool
end

function MonacoEditor(
        source;
        js_init_func = nothing, theme = "default", hiding_direction = "horizontal",
        show_editor = true, editor_classes = String[], options...
    )
    defaults = Dict{Symbol, Any}(
        :value => source,
        :language => "julia",
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
    opts = merge!(defaults, Dict{Symbol, Any}(options))
    return MonacoEditor(
        opts, Base.RefValue(js_init_func), editor_classes, theme, hiding_direction, show_editor
    )
end

function Bonito.jsrender(session::Session, editor::MonacoEditor)
    visible = editor.init_visible
    classes = copy(editor.editor_classes)
    direction = editor.hiding_direction
    lang = get(editor.options, :language, "julia")
    push!(classes, "language-$(lang)")
    if !visible
        push!(classes, "hide-$(direction)")
    end
    eclasses = join(classes, " ")
    editor_div = DOM.div(class = "monaco-editor-div $(eclasses)")
    # needs a return statement to actually return a function
    return Bonito.jsrender(
        session, DOM.div(
            CodeIcon,
            editor_div,
            js"""
            $(Monaco).then(mod => {
                const init_func = $(editor.js_init_func[]);
                const editor = new mod.MonacoEditor($(editor_div), $(editor.options), init_func, $(direction), $(visible), $(editor.theme));
                if ($(visible)) {
                    // return promise tho wait for the editor to be ready
                    return editor.editor;
                }
                // if invisible, editor doesn't get initialized, so we dont wait on it
            })
            """
        )
    )
end

"""
    EvalEditor

Interactive code editor with execution capabilities and bidirectional JavaScript communication.

# Fields
- `editor::MonacoEditor`: Monaco code editor instance
- `js_init_func::Base.RefValue{Bonito.JSCode}`: JavaScript initialization function
- `container_classes::Vector{String}`: CSS classes for the container
- `runner::Any`: Code execution runner
- `js_to_julia::Observable{Dict{String, Any}}`: Messages from JavaScript to Julia
- `julia_to_js::Observable{Dict{String, Any}}`: Messages from Julia to JavaScript
- `source::Observable{String}`: Current source code
- `output::Observable{Any}`: Execution output
- `logging::Observable{String}`: Execution logs
- `logging_html::Observable{String}`: HTML-formatted logs
- `show_logging::Observable{Bool}`: Whether to show logs
- `show_output::Observable{Bool}`: Whether to show output
- `show_editor::Observable{Bool}`: Whether to show editor
- `loading::Observable{Bool}`: Whether execution is in progress
"""
struct EvalEditor
    editor::MonacoEditor
    js_init_func::Base.RefValue{Bonito.JSCode}
    container_classes::Vector{String}
    runner::Any

    js_to_julia::Observable{Dict{String, Any}}
    julia_to_js::Observable{Dict{String, Any}}

    source::Observable{String}

    output::Observable{Any}
    logging::Observable{String}
    logging_html::Observable{String}

    show_logging::Observable{Bool}
    show_output::Observable{Bool}
    show_editor::Observable{Bool}

    loading::Observable{Bool}
end

function process_message(editor::EvalEditor, message::Dict)
    if message["type"] == "new-source"
        if editor.source[] != message["data"]
            editor.source[] = message["data"]
        end
    elseif message["type"] == "run"
        eval_source!(editor, editor.source[])
    elseif message["type"] == "toggle-editor"
        editor.show_editor[] = message["data"]
    elseif message["type"] == "toggle-logging"
        editor.show_logging[] = message["data"]
    elseif message["type"] == "toggle-output"
        editor.show_output[] = message["data"]
    elseif message["type"] === "multi"
        foreach(msg -> process_message(editor, msg), message["data"])
    else
        error("Unknown message type: $(message["type"])")
    end
    return
end

function send(editor::EvalEditor; msg...)
    editor.julia_to_js[] = Dict{String, Any}((string(k) => v for (k, v) in pairs(msg)))
    return
end

function run_from_newest!(editor::EvalEditor)
    cell.editor.loading[] = true
    send(editor; type = "run-from-newest")
    return
end

function toggle!(ee::EvalEditor; editor = nothing, output = nothing, logging = nothing)
    values = (:editor => editor, :output => output, :logging => logging)
    messages = []
    for (key, v) in values
        if !isnothing(v)
            field = Symbol("show_$(key)")
            ref = getfield(ee, field)
            if ref[] != v
                ref[] = v
                push!(messages, Dict{String, Any}("type" => "toggle-$key", "data" => ref[]))
            end
        end
    end
    send(ee; type = "multi", data = messages)
    return
end

function EvalEditor(
        source, runner = nothing;
        language = "julia",
        js_init_func = nothing,
        show_output = true,
        show_editor = true,
        show_logging = true,
        editor_classes = String[],
        container_classes = String[],
        options...
    )
    js_init_func = isnothing(js_init_func) ? js"() => {}" : js_init_func
    editor = MonacoEditor(source; language = language, show_editor = show_editor, editor_classes = editor_classes, options...)
    loading = Observable(false)
    js_to_julia = Observable(Dict{String, Any}())
    julia_to_js = Observable(Dict{String, Any}())
    show_output = Observable(show_output)
    show_editor_obs = Observable(show_editor)

    result = Observable{Any}(nothing)
    src = Observable(source)
    logging = Observable("")
    logging_html = Observable("")
    on(logging) do str
        logging_html[] = logging_html[] * str
    end
    editor = EvalEditor(
        editor,
        Base.RefValue(js_init_func),
        container_classes,
        runner,
        js_to_julia,
        julia_to_js,

        src,
        result,
        logging,
        logging_html,

        Observable(show_logging),
        show_output,
        show_editor_obs,
        loading,
    )

    on(js_to_julia) do message
        process_message(editor, message)
    end

    return editor
end

function render_editor(editor::EvalEditor)
    direction = editor.editor.hiding_direction
    hiding = "hide-$direction"
    showing = "show-$direction"
    output_class = editor.show_output[] ? showing : hiding
    logging_class = editor.show_logging[] ? showing : hiding
    output_div = DOM.div(ANSI_CSS, editor.output, class = "cell-output $(output_class)")
    logging_html = Observable(HTML(""))
    on(editor.logging_html) do str
        logging_html[] = HTML("<pre>" * str * "</pre>")
    end
    logging_div = DOM.div(logging_html, class = "cell-logging $(logging_class)")
    # Set the init func, which we can only do here where we have all divs
    editor.editor.js_init_func[] = js"""((editor) => {
        const output_div = $(output_div);
        const logging_div = $(logging_div);
        return $(Monaco).then(mod => {
            const ee = new mod.EvalEditor(
                editor, output_div, logging_div, $(direction),
                $(editor.js_to_julia), $(editor.julia_to_js), $(editor.source),
                $(editor.show_output), $(editor.show_logging),
            );
            const callback = ($(editor.js_init_func[]));
            return callback(ee);
        })
    })
    """
    return (editor.editor, logging_div, output_div)
end

function Bonito.jsrender(session::Session, editor::EvalEditor)
    elems = render_editor(editor)
    return Bonito.jsrender(session, DOM.div(elems...))
end

"""
    CellEditor

Interactive cell combining code editor and AI chat capabilities.

# Fields
- `language::String`: Programming language ("julia", "markdown", "python", etc.)
- `chat::EvalEditor`: AI chat interface editor
- `editor::EvalEditor`: Main code editor
- `uuid::String`: Unique identifier for the cell
- `show_chat::Observable{Bool}`: Whether to show chat interface
- `delete_self::Observable{Bool}`: Signal for cell deletion
"""
struct CellEditor
    language::String
    chat::EvalEditor
    editor::EvalEditor
    uuid::String
    show_chat::Observable{Bool}
    delete_self::Observable{Bool}
end


"""
    CellEditor(content, language, runner; show_editor=true, show_logging=true, show_output=true, show_chat=false)

Create an interactive cell editor with code execution and AI chat capabilities.

# Arguments
- `content`: Initial source code or content
- `language`: Programming language ("julia", "markdown", "python", etc.)
- `runner`: Code execution runner
- `show_editor`: Whether to show the code editor initially
- `show_logging`: Whether to show execution logs initially
- `show_output`: Whether to show execution output initially
- `show_chat`: Whether to show AI chat interface initially

# Returns
Configured `CellEditor` instance ready for interactive use.
"""
function CellEditor(content, language, runner; show_editor = true, show_logging = true, show_output = true, show_chat = false)
    runner = language == "markdown" ? MarkdownRunner() : runner
    uuid = string(UUIDs.uuid4())

    jleditor = EvalEditor(
        content, runner;
        show_editor = show_editor, show_logging = show_logging, language = language,
        show_output = show_output,
        tabCompletion = "on"
    )

    if language == "markdown"
        # run immediately, since we only show output
        run!(jleditor)
    end
    airunner = MLRunner(jleditor)
    show_chat_obs = Observable(show_chat)
    chat = EvalEditor(
        "", airunner;
        show_editor = show_chat, show_output = show_chat, show_logging = show_chat, language = "markdown",
        lineNumbers = "off", editor_classes = ["chat"]
    )
    for (key, obs) in (:editor => jleditor.show_editor, :logging => jleditor.show_logging, :output => jleditor.show_output)
        on(obs) do show
            toggle!(jleditor; (key => show,)...)
        end
    end
    on(show_chat_obs) do show
        toggle!(chat; editor = show, output = show, logging = show)
    end
    return CellEditor(
        language, chat, jleditor,
        uuid, show_chat_obs, Observable(false)
    )
end

function Bonito.jsrender(session::Session, editor::CellEditor)
    jleditor = editor.editor
    chat = editor.chat

    ai = SmallToggle(editor.show_chat; class = "codicon codicon-sparkle-filled")
    show_output = Observable(jleditor.show_output[])
    on(x -> toggle!(jleditor; output = !jleditor.show_output[]), show_output)
    out = SmallToggle(show_output; class = "codicon codicon-graph")
    show_editor_obs = Observable(jleditor.show_editor[])
    on(x -> toggle!(jleditor; editor = !jleditor.show_editor[]), show_editor_obs)
    show_editor = SmallToggle(show_editor_obs; class = "codicon codicon-code")
    show_logging_obs = Observable(jleditor.show_logging[])
    on(x -> toggle!(jleditor; logging = !jleditor.show_logging[]), show_logging_obs)
    show_logging = SmallToggle(show_logging_obs; class = "codicon codicon-terminal")
    delete_editor, click = SmallButton(class = "codicon codicon-close", style = "color: red;")
    on(session, click) do x
        editor.delete_self[] = true
    end
    hover_id = "$(editor.uuid)-hover"
    container_id = "$(editor.uuid)-container"
    card_content_id = "$(editor.uuid)-card-content"
    any_loading = map(|, chat.loading, jleditor.loading)
    hide_on_focus_obs = Observable(editor.language == "markdown")
    any_visible = map(|, editor.chat.show_editor, jleditor.show_editor, jleditor.show_logging)

    editor.editor.js_init_func[] = js"""
        (editor) => {
            return $(Monaco).then(Monaco => {
                Monaco.register_cell_editor(editor, $(editor.uuid))
                Monaco.setup_cell_editor(
                    editor,
                    $hover_id, $container_id, $card_content_id,
                    $any_loading, $any_visible,
                    $(hide_on_focus_obs),
                );
            })
        }
    """
    hover_buttons = DOM.div(ai, show_editor, show_logging, out, delete_editor; class = "hover-buttons", id=hover_id)

    jleditor_div, logging_div, output_div = render_editor(jleditor)
    class = any_visible[] ? "show-vertical" : "hide-vertical"
    card_content = DOM.div(
        chat, jleditor_div, logging_div;
        class = "cell-editor $class", id=card_content_id,
    )
    cell = DOM.div(hover_buttons, card_content, DOM.div(output_div, tabindex = 0), style = Styles("position" => "relative"))
    # Create a separate proximity area
    proximity_area = DOM.div(class = "cell-menu-proximity-area")
    container = DOM.div(cell, proximity_area, style = Styles("position" => "relative"), id=container_id, tabindex = 0)

    cell_div = DOM.div(CodeIcon, container, class = "cell-editor-container", id = editor.uuid)
    return Bonito.jsrender(session, cell_div)
end

struct FileEditor
    files::Vector{String}
    editor::EvalEditor
    current_file::Observable{String}
    function FileEditor(filepath::Vector{String}, runner = nothing; language = "julia", options...)
        source = read(filepath[1], String)
        opts = (
            minimap = Dict(:enabled => true, :autohide => true),
            scrollbar = Dict(),
            overviewRulerBorder = true,
            overviewRulerLanes = 2,
            lineDecorationsWidth = 10,
        )
        js_init_func = js"""(editor, monaco, editor_div) => {
            return $(Monaco).then(Monaco => {
                Monaco.resize_to_lines(editor, monaco, editor_div)
            })
        }"""
        editor = EvalEditor(
            source, runner;
            js_init_func = js_init_func,
            editor_classes = ["file-editor"],
            hiding_direction = "horizontal",
            language = language, show_logging = false,
            opts..., options...
        )
        current_file = Observable(filepath[1])

        # Set up auto-save when source changes
        on(editor.source) do new_source
            write(current_file[], new_source)
        end

        return new(filepath, editor, current_file)
    end
end

function Bonito.jsrender(session::Session, editor::FileEditor)
    buttons = map(editor.files) do file
        button = Button(basename(file))
        on(session, button.value) do x
            # Save current file before switching
            write(editor.current_file[], editor.editor.source[])
            # Switch to new file
            editor.current_file[] = file
            editor.editor.source[] = read(file, String)
        end
        return button
    end
    name = DOM.div(buttons...; class = "hide-horizontal file-editor-path")

    editor_div = DOM.div(editor.editor.editor, class = "file-cell-editor")
    meditor, logging_div, output_div = render_editor(editor.editor)
    return Bonito.jsrender(
        session, DOM.div(
            name,
            editor_div,
        )
    )
end
