
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

using IOCapture, ANSIColoredPrinters

const ANSI_CSS = Asset(joinpath(dirname(pathof(ANSIColoredPrinters)), "..", "docs", "src", "assets", "default.css"))

function capture_all_as_html(f::Function, logging_obs::Observable{String})
    callback_io = IOBuffer()
    chan = Channel(Inf) do chan
        for msg in chan
            logging_obs[] = msg
        end
    end
    Threads.@spawn while isopen(callback_io)
        yield()
        buff = copy(take!(callback_io))
        if !isempty(buff)
            printer = HTMLPrinter(IOBuffer(buff); root_tag="span")
            str = sprint(io -> show(io, MIME"text/html"(), printer))
            put!(chan, str)
        end
    end
    IOCapture.capture(color=true, capture_buffer=callback_io) do
        f()
    end
    close(callback_io)
end

struct RunnerTask
    source::String
    result::Observable
    editor::EvalEditor
end

struct ThreadRunner
    mod::Module
    task_queue::Channel{RunnerTask}
    thread::Task
end

function ThreadRunner(mod::Module)
    taskref = Ref{Task}()
    task_queue = Channel{RunnerTask}(Inf; spawn=true, taskref=taskref) do chan
        for task in chan
            run!(mod, task)
        end
    end
    return ThreadRunner(mod, task_queue, taskref[])
end

function interrupt!(runner::ThreadRunner)
    Threads.@spawn Base.throwto(runner.thread, InterruptException())
end

function book_display(value)
    return value
end

using Pkg

function run!(mod::Module, task::RunnerTask)
    editor = task.editor
    result = task.result
    source = task.source
    editor.loading[] = true
    editor.show_logging[] = true
    editor.logging_html[] = ""
    capture_all_as_html(editor.logging) do
        try
            if startswith(source, "]")
                Pkg.REPLMode.pkgstr(source[2:end])
            elseif startswith(source, "?")
                sym = Base.eval(mod, Meta.parse(source[2:end]))
                result[] = Base.Docs.doc(sym)
            elseif startswith(source, ";")
                println("Running in REPL mode")
                cmd = `$(split(source[2:end]))`
                run(cmd)
            else
                expr = Bonito.parseall(source)
                result[] = book_display(Base.eval(mod, expr))
            end
        catch e
            result[] = Bonito.HTTPServer.err_to_html(e, Base.catch_backtrace())
        finally
            editor.loading[] = false
            @async begin
                # Hide logging after some time
                sleep(2.5)
                editor.show_logging[] = false
            end
        end
    end
end



function set_result!(editor, result::Observable, runner::ThreadRunner, source::String)
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
