"""
    MarkdownRunner

Runner for processing markdown content with LaTeX math and code highlighting.

Handles markdown parsing, MathJax integration, and syntax highlighting for embedded code blocks.
"""
struct MarkdownRunner
end

"""
    parse_source(::MarkdownRunner, source)

Parse markdown source into rendered HTML with syntax highlighting and math support.

# Arguments
- `source`: Markdown source string

# Returns
Rendered markdown with embedded Monaco editors for code blocks and MathJax for LaTeX.
"""
function parse_source(::MarkdownRunner, source)
    return try
        replacements = Dict(
            Markdown.Code => (node) -> begin
                if node.language == "latex"
                    mathjax_config = Dict(
                        "chtml" => Dict(
                            "displayAlign" => "left"  # Left-align block equations
                        ),
                        "options" => Dict(
                            "enableMenu" => false  # Disable the right-click MathJax menu
                        )
                    )
                    return [Bonito.MathJax(node.code, mathjax_config)]
                elseif node.language == ""
                    return node
                else
                    editor = MonacoEditor(node.code; language = node.language, readOnly = true, lineNumbers = "off", editor_classes = ["markdown-inline-code"])
                    editor.js_init_func[] = js"""
                    (editor, monaco, editor_div) => {
                        $(Monaco).then(mod => {
                            mod.resize_to_lines(editor, monaco, editor_div);
                        });
                    }
                    """
                end
                return editor
            end
        )
        return Bonito.string_to_markdown(source, replacements)
    catch e
        return sprint(io -> Base.showerror(io, e))
    end
end


parse_source(runner::Nothing, source) = nothing

function run!(runner::MarkdownRunner, editor::EvalEditor)
    return eval_source!(editor, editor.output, runner, editor.source[])
end
function eval_source!(editor, result::Observable, runner, source)
    return result[] = parse_source(runner, source)
end

const ANSI_CSS = Asset(joinpath(dirname(pathof(ANSIColoredPrinters)), "..", "docs", "src", "assets", "default.css"))

struct RunnerTask
    source::String
    result::Observable
    editor::EvalEditor
end

"""
    AsyncRunner

Asynchronous code execution runner that handles Julia code evaluation in a separate thread.

# Fields
- `mod::Module`: Module for code execution
- `task_queue::Channel{RunnerTask}`: Queue of tasks to execute
- `thread::Task`: Background execution thread
- `callback::Base.RefValue{Function}`: Result processing callback
- `iochannel::Channel{Vector{UInt8}}`: IO redirection channel
- `redirect_target::Base.RefValue{Observable{String}}`: Target for redirected output
- `open::Threads.Atomic{Bool}`: Whether the runner is active
"""
struct AsyncRunner
    mod::Module
    task_queue::Channel{RunnerTask}
    thread::Task
    callback::Base.RefValue{Function}
    iochannel::Channel{Vector{UInt8}}
    redirect_target::Base.RefValue{Observable{String}}
    open::Threads.Atomic{Bool}
end

"""
    AsyncRunner(mod=Module(); callback=identity, spawn=false)

Create a new asynchronous code runner.

# Arguments
- `mod`: Module for code execution (defaults to new module)
- `callback`: Function to process results (defaults to identity)
- `spawn`: Whether to spawn the task (defaults to false)

# Returns
Configured `AsyncRunner` instance ready for code execution.
"""
function AsyncRunner(mod::Module = Module(); callback = identity, spawn = false)
    taskref = Ref{Task}()
    redirect_target = Base.RefValue{Observable{String}}()
    loki = ReentrantLock()
    task_queue = Channel{RunnerTask}(Inf; spawn = spawn, taskref = taskref) do chan
        for task in chan
            lock(loki) do
                redirect_target[] = task.editor.logging
                run!(mod, task)
            end
        end
    end
    io_chan = redirect_all_to_channel()
    open = Threads.Atomic{Bool}(true)
    task = Threads.@spawn begin
        while open[] && isopen(io_chan)
            bytes = take!(io_chan)
            lock(loki) do
                if !isempty(bytes) && isassigned(redirect_target)
                    printer = HTMLPrinter(IOBuffer(copy(bytes)); root_tag = "span")
                    str = sprint(io -> show(io, MIME"text/html"(), printer))
                    redirect_target[][] = str
                end
            end
        end
    end
    Base.errormonitor(task)
    return AsyncRunner(mod, task_queue, taskref[], Base.RefValue{Function}(callback), io_chan, redirect_target, open)
end

function interrupt!(runner::AsyncRunner)
    return Threads.@spawn Base.throwto(runner.thread, InterruptException())
end

function book_display(value)
    return value
end

function run!(editor::EvalEditor)
    return run!(editor.runner, editor)
end


run!(runner::AsyncRunner, editor::EvalEditor) = run!(runner.mod, RunnerTask(editor.source[], editor.output, editor))

function run!(mod::Module, task::RunnerTask)
    editor = task.editor
    result = task.result
    source = task.source
    editor.loading[] = true
    editor.show_logging[] = true
    editor.logging_html[] = ""
    try
        if startswith(source, "]")
            Pkg.REPLMode.pkgstr(source[2:end])
        elseif startswith(source, "?")
            sym = Base.eval(mod, Meta.parse(source[2:end]))
            result[] = Base.Docs.doc(sym)
        elseif startswith(source, ";")
            cmd = `$(split(source[2:end]))`
            run(cmd)
        else
            expr = Bonito.parseall(source)
            if endswith(source, ";")
                result[] = nothing
            else
                result[] = book_display(Base.eval(mod, expr))
            end
        end
    catch e
        result[] = Bonito.HTTPServer.err_to_html(e, Base.catch_backtrace())
    finally
        editor.loading[] = false
        Timer(2.5) do t
            editor.show_logging[] = false
        end
    end
    return
end

function eval_source!(editor, source::String)
    return put!(editor.runner.task_queue, RunnerTask(source, editor.output, editor))
end

struct MLRunner
    editor::BonitoBook.EvalEditor
end

const SYSTEM_PROMPT = read(joinpath(@__DIR__, "templates", "system-prompt.md"), String)

function BonitoBook.eval_source!(chat_editor, result::Observable, runner::MLRunner, source)
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
    callback = Channel(Inf) do c
        for msg in c
            yield() # Somehow needed?
            str[] = str[] * msg
        end
    end

    Base.errormonitor(
        Threads.@async begin
            conversation = [
                PT.SystemMessage(SYSTEM_PROMPT),
                PT.UserMessage(
                    """
                    Cell I currently work on:
                    $(runner.editor.source[])
                    Question being asked:
                    $(source)
                    """
                ),
            ]
            msg = PT.aigenerate(conversation; streamcallback = callback)
            jleditor = runner.editor
            if isempty(strip(jleditor.source[])) && startswith(msg.content, "```julia") && endswith(msg.content, "```")
                result[] = nothing
                toggle!(jleditor, editor = true, output = true)
                jleditor.set_source[] = strip(msg.content[9:(end - 3)])
                chat_editor.show_output[] = false
            else
                chat_editor.show_output[] = true
            end
            chat_editor.loading[] = false
        end
    )
end
