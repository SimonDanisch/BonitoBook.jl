import BonitoMLTools as BMLT
import PromptingTools as PT

const Monaco = ES6Module(joinpath(@__DIR__, "javascript", "Monaco.js"))
const CodeIcon = Asset("https://cdn.jsdelivr.net/npm/@vscode/codicons@0.0.36/dist/codicon.min.css")

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
    eclasses = join(editor.editor_classes, " ")
    editor_div = DOM.div(class="monaco-editor-div $(eclasses)")
    # We somehow have to hide the container, since hiding the editor div destroys the editor
    container = DOM.div(editor_div, class="monaco-editor-container $(eclasses)")
    # needs a return statement to actually return a function
    return Bonito.jsrender(session, DOM.div(
        CodeIcon,
        container,
        js"""
        $(Monaco).then(mod => {
            const init_func = $(editor.js_init_func[]);
            mod.setup_editor($(editor_div), $(container), $(editor.options),  $(editor.language), init_func, $(editor.show_editor), $(editor.hiding_direction));
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
        Observable(true),
        show_output,
        show_editor,
        loading
    )
    on(src) do src
        if !isempty(src)
            set_result!(editor, result, runner, src)
        end
    end
    return editor
end


function render_editor(editor::EvalEditor)
    output_div = DOM.div(editor.output, class="cell-output")
    logging_html = Observable(HTML(""))
    on(editor.logging_html) do str
        logging_html[] = HTML("<pre>" * str * "</pre>")
    end
    logging_div = DOM.div(logging_html, class="logging-pre")
    # Set the init func, which we can only do here where we have all divs
    editor.editor.js_init_func[] = js"""((editor, monaco, editor_div) => {
        const output_div = $(output_div);
        const logging_div = $(logging_div);
        $(Monaco).then(mod => {
            mod.setup_cell_editor(
                editor, monaco, editor_div, output_div, logging_div,
                $(editor.source), $(editor.get_source), $(editor.set_source),
                $(editor.show_output), $(editor.show_logging)
            );
            const callback = ($(editor.js_init_func));
            callback(editor, monaco, editor_div);
        })
    })
    """
    return (ANSI_CSS, editor.editor, logging_div, output_div)
end

function Bonito.jsrender(session::Session, editor::EvalEditor)
    elems = render_editor(editor)
    return Bonito.jsrender(session, DOM.div(elems...;))
end

struct MarkdownRunner
end

function parse_source(runner::Bonito.ModuleRunner, source)
    try
        expr = Bonito.parseall(source)
        return Base.eval(runner, expr)
    catch e
        return Bonito.HTTPServer.err_to_html(e, Base.catch_backtrace())
    end
end


function parse_source(::MarkdownRunner, source)
    return try
        return Markdown.parse(source)
    catch e
        return sprint(io -> Base.showerror(io, e))
    end
end

function set_result!(editor, result::Observable, runner, source)
    result[] = parse_source(runner, source)
end

using IOCapture, ANSIColoredPrinters

const ANSI_CSS = Asset(joinpath(dirname(pathof(ANSIColoredPrinters)), "..", "docs", "src", "assets", "default.css"))

function capture_all_as_html(f::Function, logging_obs::Observable{String})
    callback_io = IOBuffer()
    @async while isopen(callback_io)
        buff = copy(take!(callback_io))
        if !isempty(buff)
            printer = HTMLPrinter(IOBuffer(buff); root_tag="span")
            str = sprint(io -> show(io, MIME"text/html"(), printer))
            logging_obs[] = str
        end
        yield()
    end
    IOCapture.capture(color=true, capture_buffer=callback_io) do
        f()
    end
    close(callback_io)
end


function set_result!(editor, result::Observable, runner::Bonito.ModuleRunner, source)
    editor.loading[] = true
    editor.show_logging[] = true
    result[] = nothing
    editor.logging_html[] = ""
    @async capture_all_as_html(editor.logging) do
        try
            expr = Bonito.parseall(source)
            result[] = Base.eval(runner, expr)
        catch e
            result[] = Bonito.HTTPServer.err_to_html(e, Base.catch_backtrace())
        finally
            editor.loading[] = false
            @async begin
                sleep(2.5)
                editor.show_logging[] = false
            end
        end
    end
end


struct CellEditor
    language::String
    chat::EvalEditor
    editor::EvalEditor
    show_output::Observable{Bool}
    show_editor::Observable{Bool}
    show_ai::Observable{Bool}
    show_controls::Observable{Bool}
end

function markdown_setup(editor, container)
    js"""
        const show_editor = $(editor.show_editor)
        const show_output = $(editor.show_output)
        const container = $(container)
        container.addEventListener('focus', (e) => {
            show_editor.notify(true);
            show_output.notify(false);
        });
        // Blur event listener (focus lost)
        function hasFocusWithin(element) {
            return element === document.activeElement || element.contains(document.activeElement);
        }
        container.addEventListener('focusout', (e) => {
            if (!container.contains(e.relatedTarget)) {
                show_editor.notify(false);
                show_output.notify(true);
                $(editor.get_source).notify(true);
            }
        });
    """
end

struct MLRunner
    editor::BonitoBook.EvalEditor
end

const SYSTEM_PROMPT = read(joinpath(@__DIR__, "templates", "system-prompt.md"), String)

function BonitoBook.set_result!(chat_editor, result::Observable, runner::MLRunner, source)
    str = Observable{String}("")
    chat_editor.loading[] = true
    chat_editor.show_output[] = true
    result[] = nothing
    on(str) do s
        try
            result[] = Markdown.parse(s)
        catch e
            result[] = s
        end
    end
    callback = Channel(1024) do c
        for msg in c
            yield() # Somehow needed?
            str[] = str[] * msg
        end
    end
    Base.errormonitor(Threads.@spawn begin
        conversation = [
            PT.SystemMessage(SYSTEM_PROMPT),
            PT.UserMessage("""
            Cell I currently work on:
            $(runner.editor.source[])
            Question being asked:
            $(source)
            """)
        ]
        msg = PT.aigenerate(conversation; streamcallback=callback)
        jleditor = runner.editor
        if isempty(strip(jleditor.source[])) && startswith(msg.content, "```julia") && endswith(msg.content, "```")
            jleditor.show_editor[] = true
            jleditor.show_output[] = true
            jleditor.set_source[] = strip(msg.content[9:end-3])
            result[] = nothing
            chat_editor.show_output[] = false
        else
            chat_editor.show_output[] = true
        end
        chat_editor.loading[] = false
    end)
end


function SmallButton(; class="", kw...)
    value = Observable(false)
    button_dom = DOM.button(
        "";
        onclick=js"event=> $(value).notify(true);",
        class="small-button $(class)",
        kw...,
    )
    return button_dom, value
end

function SmallToggle(active, args...; class="", kw...)
    class = active[] ? class : "toggled $class"
    value = Observable(false)
    button_dom = DOM.button(args...; class="small-button $(class)", kw...)

    toggle_script = js"""
        const elem = $(button_dom);
        $(active).on((x) => {
            if (!x) {
                elem.classList.add("toggled");
            } else {
                elem.classList.remove("toggled");
            }
        })
        elem.addEventListener("click", event=> {
            $(value).notify(true);
        })
    """
    on(value) do click
        active[] = !active[]
    end
    return DOM.span(button_dom, toggle_script)
end


function CellEditor(content, language, runner)
    show_editor = language != "markdown"
    show_controls = Observable(true)
    runner = language == "markdown" ? MarkdownRunner() : runner
    jleditor = EvalEditor(
        content, runner;
        show_editor=show_editor, language=language
    )
    if language == "markdown"
        notify(jleditor.source)
    end
    runner = MLRunner(jleditor)

    show_chat = Observable(false)
    chat = EvalEditor(
        "", runner;
        show_editor=false, show_output=false, language="markdown",
        lineNumbers="off", editor_classes=["chat"]
    )
    on(show_chat) do show
        chat.show_editor[] = show
        chat.show_output[] = show
    end
    return CellEditor(language, chat, jleditor, jleditor.show_output, jleditor.show_editor, show_chat, show_controls)
end

function Bonito.jsrender(session::Session, editor::CellEditor)
    jleditor = editor.editor
    chat = editor.chat
    show_chat = Observable(false)
    on(show_chat) do show
        chat.show_editor[] = show
        chat.show_output[] = show
    end

    ai = SmallToggle(show_chat; class="codicon codicon-sparkle-filled")
    out = SmallToggle(jleditor.show_output; class="codicon codicon-graph")
    show_editor = SmallToggle(jleditor.show_editor; class="codicon codicon-code")
    show_logging = SmallToggle(jleditor.show_logging; class="codicon codicon-terminal")
    hover_buttons = DOM.div(ai, show_editor, show_logging, out; class="hover-buttons")

    card_content = DOM.div(
        chat, jleditor;
        class="editor-content",
    )

    hover_container = DOM.div(
        hover_buttons, card_content; class="hover-container", tabindex=0,
    )
    hover_js = js"""
    (() => {
        const container = $(hover_container);
        const buttons = $(hover_buttons);
        container.addEventListener("mouseover", () => {
            buttons.style.opacity = 1.0;
            buttons.style.pointerEvents = "auto";  // Allow interactions
        });

        container.addEventListener("mouseleave", () => {
            buttons.style.opacity = 0.0;
            buttons.style.pointerEvents = "none";  // Prevent flickering
        });
    })()
    """
    markdown_js = editor.language == "markdown" ? markdown_setup(jleditor, hover_container) : nothing

    body = DOM.div(
        BonitoBook.CodeIcon,
        hover_container,  # Wrap everything in one container
        hover_js,
        markdown_js,
        tabindex=0,
        class="editor-container"
    )
    onjs(
        session,
        map(|, chat.loading, jleditor.loading),
        js"""
            (x) => {
                if (x) {
                    $(body).classList.add("loading-cell");
                } else {
                    $(body).classList.remove("loading-cell");
                }
            }
        """
    )

    return Bonito.jsrender(session, body)
end

struct FileEditor
    filename::String
    editor::EvalEditor
    function FileEditor(filepath, runner=nothing; language="julia", options...)
        source = read(filepath, String)
        opts = (
            minimap=Dict(:enabled => true, :autohide => true),
            scrollbar=Dict(),
            overviewRulerBorder=true,
            overviewRulerLanes=2,
            lineDecorationsWidth=10
        )
        js_init_func = js"""(editor, monaco, editor_div) => {
            $(Monaco).then(Monaco => {
                Monaco.resize_to_lines(editor, monaco, editor_div)
            })
        }"""
        editor = EvalEditor(source, runner; js_init_func=js_init_func, editor_classes=["file-editor"], hiding_direction="horizontal", language=language, opts..., options...)
        return new(filepath, editor)
    end
end



function Bonito.jsrender(session::Session, editor::FileEditor)
    relative = relpath(editor.filename, pwd())
    filename = Bonito.to_unix_path(relative)
    name = DOM.div(filename; class="file-editor-path")
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
    editor_div = DOM.div(editor.editor.editor, class="file-editor-container")
    ansi_css, meditor, logging_div, output_div = render_editor(editor.editor)
    return Bonito.jsrender(session, DOM.div(
        name,
        ansi_css,
        editor_div,
        logging_div,
        toggle_js
    ))
end
