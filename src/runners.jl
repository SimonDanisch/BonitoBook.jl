using PythonCall

mutable struct PythonRunner
    globals::Py
    locals::Py
    function PythonRunner()
        return new(PythonCall.pydict(), PythonCall.pydict())
    end
end

global eval_python_code = nothing

function get_func()
    if isnothing(eval_python_code)
        pyexec(
            """
            import ast
            import textwrap

            def eval_python_code(source, globals_dict, locals_dict):
                tree = ast.parse(source, mode="exec")
                body = tree.body
                n = len(body)
                if n == 0:
                    return None

                exprs = body[:-1]
                last_stmt = body[-1]

                if exprs:
                    init_code = textwrap.dedent("\\n".join(ast.unparse(stmt) for stmt in exprs))
                    exec(init_code, globals_dict, locals_dict)

                if isinstance(last_stmt, ast.Expr):
                    tail_expr = ast.unparse(last_stmt.value)
                    return eval(tail_expr, globals_dict, locals_dict)
                else:
                    full_code = textwrap.dedent(source)
                    exec(full_code, globals_dict, locals_dict)
                    return None
            """, Main
        )
        global eval_python_code = pyeval("eval_python_code", Main)
    end
    return eval_python_code
end


function transfer_python_vars(python_dict::Py, julia_module, var_type::String)
    jl_dict = pyconvert(Dict, python_dict)
    for key in keys(jl_dict)
        key_str = string(key)
        if !startswith(key_str, "_")  # Skip private variables
            julia_symbol = Symbol(key_str)
            if !hasproperty(julia_module, julia_symbol)
                try
                    value = jl_dict[key]
                    @eval julia_module $julia_symbol = $value
                catch e
                    @warn "Could not transfer Python $var_type variable $key_str to Julia: " e
                end
            end
        end
    end
    return
end

function eval_python_code_jl(runner::PythonRunner, mod, filename, start_line, python_source)
    eval_py = get_func()  # Ensure eval_python_code is defined
    result = eval_py(python_source, runner.globals, runner.locals)
    # PythonCall.pyexec(python_source, runner.globals, runner.locals)
    transfer_python_vars(runner.globals, mod, "global")
    transfer_python_vars(runner.locals, mod, "local")
    return result
end


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
                    return editor
                end
            end
        )
        return Bonito.string_to_markdown(source, replacements)
    catch e
        return sprint(io -> Base.showerror(io, e))
    end
end

parse_source(runner::Nothing, source) = nothing

const ANSI_CSS = Asset(joinpath(dirname(pathof(ANSIColoredPrinters)), "..", "docs", "src", "assets", "default.css"))

struct RunnerTask
    source::String
    result::Observable{Any}
    logging::Observable
    language::String
end

"""
    AsyncRunner

Asynchronous code execution runner that handles Julia and Python code evaluation in a separate thread.

# Fields
- `mod::Module`: Module for code execution
- `python_runner::PythonRunner`: Python execution context
- `task_queue::Channel{RunnerTask}`: Queue of tasks to execute
- `thread::Task`: Background execution thread
- `callback::Base.RefValue{Function}`: Result processing callback
- `iochannel::Channel{Vector{UInt8}}`: IO redirection channel
- `redirect_target::Base.RefValue{Observable{String}}`: Target for redirected output
- `open::Threads.Atomic{Bool}`: Whether the runner is active
"""
struct AsyncRunner
    mod::Module
    python_runner::PythonRunner
    task_queue::Channel{RunnerTask}
    thread::Task
    callback::Base.RefValue{Function}
    iochannel::Channel{Vector{UInt8}}
    redirect_target::Base.RefValue{Observable{String}}
    open::Threads.Atomic{Bool}
end

function set_task_tid!(task::Task, tid::Integer)
    task.sticky = true
    return ccall(:jl_set_task_tid, Cint, (Any, Cint), task, tid - 1)
end
function spawnat(f, tid)
    task = Task(f)
    set_task_tid!(task, tid)
    schedule(task)
    return task
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
function AsyncRunner(mod::Module = Module(gensym("BonitoBook")); callback = identity, spawn = false)
    redirect_target = Base.RefValue{Observable{String}}()
    python_runner = fetch(
        spawnat(1) do
            PythonRunner()
        end
    )
    loki = ReentrantLock()
    task_queue = Channel{RunnerTask}(Inf)
    taskref = spawnat(1) do
        for task in task_queue
            lock(loki) do
                try
                    redirect_target[] = task.logging
                    run!(mod, python_runner, task)
                catch e
                    @error "Error running code: $(task.source)" exception = (e, catch_backtrace())
                end
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
    return AsyncRunner(mod, python_runner, task_queue, taskref, Base.RefValue{Function}(callback), io_chan, redirect_target, open)
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

function run!(::Nothing, editor::EvalEditor)
end

function run!(runner::MarkdownRunner, editor::EvalEditor)
    editor.output[] = parse_source(runner, editor.source[])
    return
end

function run!(runner::AsyncRunner, editor::EvalEditor)
    editor.loading[] = true
    editor.show_logging[] = true
    editor.logging_html[] = ""
    put!(runner.task_queue, RunnerTask(editor.source[], editor.output, editor.logging, editor.language))
    deregister = nothing
    deregister = on(editor.result) do result
        editor.loading[] = false
        Timer(2.5) do t
            editor.show_logging[] = false
        end
        off(deregister)
    end
    return
end

function run!(mod::Module, python_runner::PythonRunner, task::RunnerTask)
    result = task.result
    source = task.source
    language = task.language
    try
        if language == "python"
            # Execute Python code
            py_result = eval_python_code_jl(python_runner, mod, "", 1, source)
            result[] = py_result
        else
            # Execute Julia code (default behavior)
            if startswith(source, "]")
                Pkg.REPLMode.pkgstr(source[2:end])
            elseif startswith(source, "?")
                sym = Base.eval(mod, Meta.parse(source[2:end]))
                result[] = Base.Docs.doc(sym)
            elseif startswith(source, ";")
                cmd = `$(split(source[2:end]))`
                run(cmd)
            else
                if endswith(source, ";")
                    result[] = nothing
                else
                    result[] = book_display(Base.include_string(mod, source))
                end
            end
        end
    catch e
        result[] = Bonito.HTTPServer.err_to_html(e, Base.catch_backtrace())
    end
    return
end
