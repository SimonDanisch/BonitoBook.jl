
struct MarkdownRunner
end

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
                    editor = MonacoEditor(node.code; language=node.language, readOnly=true, lineNumbers="off", editor_classes=["markdown-inline-code"])
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

function set_result!(editor, result::Observable, runner, source)
    result[] = parse_source(runner, source)
end

const ANSI_CSS = Asset(joinpath(dirname(pathof(ANSIColoredPrinters)), "..", "docs", "src", "assets", "default.css"))

struct RunnerTask
    source::String
    result::Observable
    editor::EvalEditor
end

struct AsyncRunner
    mod::Module
    task_queue::Channel{RunnerTask}
    thread::Task
    callback::Base.RefValue{Function}
    iochannel::Channel{Vector{UInt8}}
    redirect_target::Base.RefValue{Observable{String}}
    open::Threads.Atomic{Bool}
end


const TASKS = []

function AsyncRunner(mod::Module=Module(); callback=identity, spawn=false)
    taskref = Ref{Task}()
    redirect_target = Base.RefValue{Observable{String}}()
    loki = ReentrantLock()
    empty!(TASKS)
    task_queue = Channel{RunnerTask}(Inf; spawn=spawn, taskref=taskref) do chan
        for task in chan
            lock(loki) do
                push!(TASKS, task)
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
                    printer = HTMLPrinter(IOBuffer(copy(bytes)); root_tag="span")
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
    Threads.@spawn Base.throwto(runner.thread, InterruptException())
end

function book_display(value)
    return value
end


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
end

function set_result!(editor, result::Observable, runner::AsyncRunner, source::String)
    put!(runner.task_queue, RunnerTask(source, result, editor))
end


struct MLRunner
    editor::BonitoBook.EvalEditor
end

const SYSTEM_PROMPT = read(joinpath(@__DIR__, "templates", "system-prompt.md"), String)

global ALL_MSGS = []

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
    callback = Channel(Inf) do c
        for msg in c
            yield() # Somehow needed?
            str[] = str[] * msg
        end
    end

    Base.errormonitor(Threads.@async begin
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
        empty!(ALL_MSGS)
        on(jleditor.source) do src
            push!(ALL_MSGS, src)
        end
        if isempty(strip(jleditor.source[])) && startswith(msg.content, "```julia") && endswith(msg.content, "```")
            result[] = nothing
            jleditor.show_editor[] = true
            jleditor.show_output[] = true
            jleditor.set_source[] = strip(msg.content[9:end-3])
            chat_editor.show_output[] = false
        else
            chat_editor.show_output[] = true
        end
        chat_editor.loading[] = false
    end)
end
