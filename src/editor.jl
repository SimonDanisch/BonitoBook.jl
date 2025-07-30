const Monaco = ES6Module(joinpath(@__DIR__, "javascript", "Monaco.js"))

# TODO, this better not be a global, but rather part of `Book`
# Cant be `Observable("default")`, since for a global compiled into the
# Pkg image, it will always end up with ID 1, like any global observable from another Package -.-
const MONACO_THEME = Observable{String}[]

function get_monaco_theme()
    if isempty(MONACO_THEME)
        push!(MONACO_THEME, @D Observable("default"))
    end
    return MONACO_THEME[1]
end

function monaco_theme!(name::String)
    obs = get_monaco_theme()
    return obs[] = name
end

"""
    ToggleButton(icon_name::String, obs_to_toggle::Observable{Bool})

Create a toggle button with dark/light friendly styling that toggles a boolean observable.

# Arguments
- `icon_name::String`: Name of the icon to display
- `obs_to_toggle::Observable{Bool}`: Observable boolean to toggle

# Returns
A DOM button element with toggle functionality and appropriate styling.
"""
function ToggleButton(icon_name::String, obs_to_toggle::Observable{Bool})
    button_icon = icon(icon_name)
    # Set initial class based on observable value
    initial_class = obs_to_toggle[] ? "small-button toggle-button active" : "small-button toggle-button"

    return DOM.button(
        button_icon;
        class = initial_class,
        onclick = js"""event=> {
            const button = event.target.closest('button');
            const newValue = !$(obs_to_toggle).value;
            $(obs_to_toggle).notify(newValue);

            // Toggle the active class based on new value
            if (newValue) {
                button.classList.add('active');
            } else {
                button.classList.remove('active');
            }
        }"""
    )
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
        :automaticLayout => true,
        :renderLineHighlight => "none",
        :lineDecorationsWidth => 0,
        :disableLayerHinting => true,
        :scrollBeyondLastColumn => 0,
        :hideCursorInOverviewRuler => true,
        :mouseWheelScrollSensitivity => 0,
        :fastScrollSensitivity => 0,
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
    theme = copy(get_monaco_theme())
    return Bonito.jsrender(
        session, DOM.div(
            editor_div,
            js"""
            $(Monaco).then(mod => {
                const init_func = $(editor.js_init_func[]);
                const editor = new mod.MonacoEditor($(editor_div), $(editor.options), init_func, $(direction), $(visible), $(theme));
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
    language::String
    resize_to_lines::Bool
end

function process_message(editor::EvalEditor, message::Dict)
    if message["type"] == "new-source"
        if editor.source[] != message["data"]
            editor.source[] = message["data"]
        end
    elseif message["type"] == "run"
        run!(editor)
    elseif message["type"] == "get-source"
        # Send current source to JavaScript editor
        send(editor; type = "set-source", data = editor.source[])
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
    editor.loading[] = true
    send(editor; type = "run-from-newest")
    return
end

function set_source!(editor::EvalEditor, source::String)
    send(editor; type = "set-source", data = source)
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
        show_logging = false,
        editor_classes = String[],
        container_classes = String[],
        resize_to_lines = true,
        options...
    )
    js_init_func = isnothing(js_init_func) ? js"() => {}" : js_init_func
    editor = MonacoEditor(source; language = language, show_editor = show_editor, editor_classes = editor_classes, options...)
    loading = @D Observable(false)
    js_to_julia = @D Observable(Dict{String, Any}())
    julia_to_js = @D Observable(Dict{String, Any}())
    show_output = @D Observable(show_output)
    show_editor_obs = @D Observable(show_editor)

    result = Observable{Any}(nothing)
    src = @D Observable(source)
    logging = @D Observable("")
    logging_html = @D Observable("")
    on(logging) do str
        if !isempty(str)
            # Append the new HTML content (already formatted by ANSIColoredPrinters)
            logging_html[] = logging_html[] * str
        end
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

        @D(Observable(show_logging)),
        show_output,
        show_editor_obs,
        loading,
        language,
        resize_to_lines
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
    output_class = map(editor.show_output) do show
        show ? showing : hiding
    end
    logging_class = map(editor.show_logging) do show
        show ? showing : hiding
    end
    output_div = DOM.div(editor.output, class = map(c -> "cell-output $(c)", output_class))
    logging_html = @D Observable(HTML(""))
    on(editor.logging_html) do str
        # Don't wrap in <pre> since ANSIColoredPrinters already provides formatted HTML
        logging_html[] = HTML(str)
    end
    logging_div = DOM.div(ANSI_CSS, logging_html, class = map(c -> "cell-logging $(c)", logging_class))
    # Set the init func, which we can only do here where we have all divs
    editor.editor.js_init_func[] = js"""((editor) => {
        const output_div = $(output_div);
        const logging_div = $(logging_div);
        return $(Monaco).then(mod => {
            const ee = new mod.EvalEditor(
                editor, output_div, logging_div, $(direction),
                $(editor.js_to_julia), $(editor.julia_to_js), $(editor.source),
                $(editor.show_output), $(editor.show_logging), $(editor.resize_to_lines)
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

Interactive cell for code editing and execution.

# Fields
- `language::String`: Programming language ("julia", "markdown", "python", etc.)
- `editor::EvalEditor`: Main code editor
- `uuid::String`: Unique identifier for the cell
- `delete_self::Observable{Bool}`: Signal for cell deletion
"""
struct CellEditor
    language::String
    editor::EvalEditor
    uuid::String
    delete_self::Observable{Bool}
end


"""
    CellEditor(content, language, runner; show_editor=true, show_logging=false, show_output=true)

Create an interactive cell editor with code execution capabilities.

# Arguments
- `content`: Initial source code or content
- `language`: Programming language ("julia", "markdown", "python", etc.)
- `runner`: Code execution runner
- `show_editor`: Whether to show the code editor initially
- `show_logging`: Whether to show execution logs initially
- `show_output`: Whether to show execution output initially

# Returns
Configured `CellEditor` instance ready for interactive use.
"""
function CellEditor(content, language, runner; show_editor = true, show_logging = false, show_output = true)
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
    for (key, obs) in (:editor => jleditor.show_editor, :logging => jleditor.show_logging, :output => jleditor.show_output)
        on(obs) do show
            toggle!(jleditor; (key => show,)...)
        end
    end
    return CellEditor(
        language, jleditor,
        uuid, @D Observable(false)
    )
end

function Bonito.jsrender(session::Session, editor::CellEditor)
    jleditor = editor.editor

    show_output = @D Observable(jleditor.show_output[])
    on(x -> toggle!(jleditor; output = !jleditor.show_output[]), show_output)
    out = ToggleButton("graph", show_output)
    show_editor_obs = @D Observable(jleditor.show_editor[])
    on(x -> toggle!(jleditor; editor = !jleditor.show_editor[]), show_editor_obs)
    show_editor = ToggleButton("code", show_editor_obs)
    show_logging_obs = @D Observable(jleditor.show_logging[])
    on(x -> toggle!(jleditor; logging = !jleditor.show_logging[]), show_logging_obs)
    show_logging = ToggleButton("terminal", show_logging_obs)
    delete_icon = icon("close", style = Styles("color" => "red"))
    click = @D Observable(false)
    delete_editor = DOM.button(delete_icon; class = "small-button", onclick = js"event=> $(click).notify(true)")
    on(session, click) do x
        editor.delete_self[] = true
    end

    hover_id = "$(editor.uuid)-hover"
    container_id = "$(editor.uuid)-container"
    card_content_id = "$(editor.uuid)-card-content"
    any_loading = jleditor.loading
    hide_on_focus_obs = @D Observable(editor.language == "markdown")
    any_visible = map(|, jleditor.show_editor, jleditor.show_logging)

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
    hover_buttons = DOM.div(show_editor, show_logging, out, delete_editor; class = "hover-buttons", id = hover_id)

    # Create small always-visible language indicator positioned in bottom right
    names = Dict(
        "julia" => "julia-logo",
        "markdown" => "markdown",
        "python" => "python-logo",
    )
    name = get(names, editor.language, "file-code")
    small_language_indicator = icon(name, size = "10px", class = "small-language-icon")

    jleditor_div, logging_div, output_div = render_editor(jleditor)
    class = any_visible[] ? "show-vertical" : "hide-vertical"
    card_content = DOM.div(
        jleditor_div, logging_div, small_language_indicator;
        class = "cell-editor $class", id = card_content_id, style = "position: relative;"
    )
    cell = DOM.div(hover_buttons, card_content, DOM.div(output_div, tabindex = 0), style = Styles("position" => "relative"))
    # Create a separate proximity area
    proximity_area = DOM.div(class = "cell-menu-proximity-area")
    container = DOM.div(cell, proximity_area, style = Styles("position" => "relative"), id = container_id, tabindex = 0)

    cell_div = DOM.div(container, class = "cell-editor-container", id = editor.uuid)
    return Bonito.jsrender(session, cell_div)
end

struct FileEditor
    editor::EvalEditor
    current_file::Observable{String}

    function FileEditor(filepath::String="", runner = nothing; language = "julia", show_editor = true, options...)
        source = isempty(filepath) ? "" : read(filepath, String)
        opts = (
            minimap = Dict(:enabled => true, :autohide => true),
            scrollbar = Dict(),
            overviewRulerBorder = true,
            overviewRulerLanes = 2,
            lineDecorationsWidth = 10,
        )

        editor = EvalEditor(
            source, runner;
            editor_classes = ["file-editor"],
            hiding_direction = "horizontal",
            language = language,
            show_editor = show_editor,
            show_logging = false,
            resize_to_lines = false,
            opts..., options...
        )
        current_file = @D Observable(filepath)

        return new(editor, current_file)
    end
end

function open_file!(editor::FileEditor, filepath::String; line::Union{Int, Nothing} = nothing)
    if isfile(filepath)
        # Switch to new file
        @info "Opening file in editor: $filepath" * (isnothing(line) ? "" : " at line $line")
        editor.current_file[] = filepath
        set_source!(editor.editor, read(filepath, String))
        
        # Jump to line if specified
        if !isnothing(line) && line > 0
            send(editor.editor; type = "goto-line", line = line)
        end
        
        toggle!(editor.editor; editor = true)
    else
        @warn "Could not find file: $filepath"
    end
end


# Forward toggle! calls to the underlying EvalEditor for compatibility
function toggle!(editor::FileEditor; kwargs...)
    toggle!(editor.editor; kwargs...)
end

function Bonito.jsrender(session::Session, editor::FileEditor)
    # Editor container that fills remaining height
    meditor, _, _ = render_editor(editor.editor)
    return Bonito.jsrender(session, meditor)
end
