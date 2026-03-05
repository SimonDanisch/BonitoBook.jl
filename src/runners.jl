using Pkg

"""
Abstract base type for language evaluators.
Implementations should define eval_code method.
"""
abstract type LanguageEval end

"""
    eval_code(evaluator::LanguageEval, mod::Module, file::String, line::Int, source::String)

Evaluate source code using the given language evaluator.

# Arguments
- `evaluator`: The language-specific evaluator
- `mod`: Module for code execution
- `file`: Source file name (for error reporting)
- `line`: Starting line number (for error reporting)
- `source`: Source code to evaluate

# Returns
Result of the code evaluation, or nothing if no result.
"""
function eval_code end

"""
    JuliaEval <: LanguageEval

Julia code evaluator that uses Base.include_string for execution.
"""
struct JuliaEval <: LanguageEval end

function book_include(bookmodule, bookfile, bookfolder, include_file)
    to_try = [
        include_file,
        joinpath(dirname(bookfile), include_file),
        joinpath(bookfolder, include_file)
    ]
    for file in to_try
        if isfile(file)
            return Base._include(identity, bookmodule, abspath(file))
        end
    end
    error("Cant include $(include_file)")
end

function eval_code(::JuliaEval, mod::Module, file::String, line::Int, source::String)
    if startswith(source, "]")
        Pkg.REPLMode.pkgstr(source[2:end])
        return nothing
    elseif startswith(source, "?")
        sym = Base.eval(mod, Meta.parse(source[2:end]))
        return Base.Docs.doc(sym)
    elseif startswith(source, ";")
        cmd = `$(split(source[2:end]))`
        run(cmd)
        return nothing
    else
        res = Base.include_string(mod, source)
        if endswith(source, ";")
            return nothing
        else
            return res
        end
    end
end

"""
    MarkdownRunner

Runner for processing markdown content with LaTeX math and code highlighting.

Handles markdown parsing, MathJax integration, and syntax highlighting for embedded code blocks.
"""
struct MarkdownRunner
    folder::String
end
MarkdownRunner() = MarkdownRunner("")

"""
    parse_source(::MarkdownRunner, source)

Parse markdown source into rendered HTML with syntax highlighting and math support.

# Arguments
- `source`: Markdown source string

# Returns
Rendered markdown with embedded Monaco editors for code blocks and MathJax for LaTeX.
"""
function parse_source(runner::MarkdownRunner, source)
    return try
        replacements = Dict{Any, Function}(
            # CommonMark replacement keys (used by CommonMark parser path)
            CommonMark.CodeBlock => (node) -> begin
                info = node.t.info
                if info == "latex"
                    return Bonito.KaTeX(node.literal)
                elseif isempty(info)
                    return nothing  # Use default rendering
                else
                    editor = MonacoEditor(node.literal; language=info, readOnly=true, lineNumbers="off", editor_classes=["markdown-inline-code"])
                    editor.js_init_func[] = js"""
                    (editor) => {
                        Promise.all([$(Monaco), editor.monaco, editor.editor]).then(([mod, monaco, e]) => {
                            // Resize editor to fit content
                            mod.resize_to_lines(e, monaco, editor.editor_div);
                        });
                    }
                    """
                    return editor
                end
            end,
            CommonMark.Image => (node) -> begin
                # Convert relative image paths to Bonito Asset
                url = node.t.destination
                if startswith(url, "./data/") || startswith(url, "data/")
                    # Relative path - use Asset to serve from bbook/data folder
                    filename = replace(url, r"^\.?/?data/" => "")
                    image_path = joinpath(runner.folder, "data", filename)
                    if isfile(image_path)
                        return Asset(image_path)
                    else
                        @warn "Image not found: $image_path"
                        return nothing  # Use default rendering
                    end
                else
                    # Absolute or external URL - use default rendering
                    return nothing
                end
            end,
            # Legacy stdlib Markdown keys (kept for backward compatibility)
            Markdown.Code => (node) -> begin
                if node.language == "latex"
                    return [Bonito.KaTeX(node.code)]
                elseif node.language == ""
                    return node
                else
                    editor = MonacoEditor(node.code; language=node.language, readOnly=true, lineNumbers="off", editor_classes=["markdown-inline-code"])
                    editor.js_init_func[] = js"""
                    (editor) => {
                        Promise.all([$(Monaco), editor.monaco, editor.editor]).then(([mod, monaco, e]) => {
                            // Resize editor to fit content
                            mod.resize_to_lines(e, monaco, editor.editor_div);
                        });
                    }
                    """
                    return editor
                end
            end,
            Markdown.Image => (node) -> begin
                # Convert relative image paths to Bonito Asset
                url = node.url
                if startswith(url, "./data/") || startswith(url, "data/")
                    # Relative path - use Asset to serve from bbook/data folder
                    filename = replace(url, r"^\.?/?data/" => "")
                    image_path = joinpath(runner.folder, "data", filename)
                    if isfile(image_path)
                        return Asset(image_path)
                    else
                        @warn "Image not found: $image_path"
                        return node
                    end
                else
                    # Absolute or external URL - keep as is
                    return node
                end
            end
        )
        return Bonito.string_to_markdown(source, replacements)
    catch e
        return sprint(io -> Base.showerror(io, e))
    end
end

parse_source(runner::Nothing, source) = nothing

struct RunnerTask
    source::String
    result::Observable{Any}
    logging::Observable
    language::String
end

"""
    AsyncRunner

Asynchronous code execution runner that handles multi-language code evaluation in a separate thread.

# Fields
- `mod::Module`: Module for code execution
- `project::String`: Project directory path
- `language_evaluators::Dict{String, LanguageEval}`: Dictionary of language-specific evaluators
- `task_queue::Channel{RunnerTask}`: Queue of tasks to execute
- `thread::Task`: Background execution thread
- `callback::Base.RefValue{Function}`: Result processing callback
"""
struct AsyncRunner
    mod::Module
    project::String
    language_evaluators::Dict{String,LanguageEval}
    task_queue::Channel{RunnerTask}
    thread::Task
    callback::Base.RefValue{Function}
end

function Base.close(runner::AsyncRunner)
    close(runner.task_queue)
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

global LOGGING_OBS = []


"""
    get_language_evaluators()

Get dictionary of language evaluators, including extensions.
Base implementation includes Julia, extensions are loaded via Base.get_extension.
"""
function get_language_evaluators()
    evaluators = Dict{String,LanguageEval}()

    for (lang_name, lang) in ALL_LANGUAGES
        if lang.always_available
            # Add always available languages
            if lang_name == "julia"
                evaluators[lang_name] = JuliaEval()
            end
        else
            # Check if extension is loaded and get evaluator from it
            if lang.extension_module !== nothing
                ext = Base.get_extension(BonitoBook, lang.extension_module)
                if ext !== nothing
                    try
                        evaluator = ext.get_language_evaluator()
                        evaluators[lang_name] = evaluator
                    catch e
                        @warn "Failed to get language evaluator for $(lang_name) from extension $(lang.extension_module): $e"
                    end
                end
            end
        end
    end
    return evaluators
end

"""
    AsyncRunner(project::String, mod=Module(); callback=identity, global_logger=Observable(""))

Create a new asynchronous code runner.

# Arguments
- `project`: Project directory path
- `mod`: Module for code execution (defaults to new module)
- `callback`: Function to process results (defaults to identity)
- `global_logger`: Observable for global logging output

# Returns
Configured `AsyncRunner` instance ready for code execution.
"""
function AsyncRunner(project::String, mod::Module=Module(gensym("BonitoBook")); callback=identity, global_logger=Observable(""))
    language_evaluators = get_language_evaluators()
    task_queue = Channel{RunnerTask}(Inf)
    redirect_target = redirect_all_to_channel()
    redirect_target[] = global_logger

    taskref = spawnat(1) do
        for task in task_queue
            try
                redirect_target[] = task.logging
                Base.invokelatest(run!, mod, language_evaluators, task)
                println()
            catch e
                @error "Error running code: $(task.source)" exception = (e, catch_backtrace())
            finally
                redirect_target[] = global_logger
            end
        end
    end
    return AsyncRunner(mod, project, language_evaluators, task_queue, taskref, Base.RefValue{Function}(callback))
end

function interrupt!(runner::AsyncRunner)
    return Threads.@spawn Base.throwto(runner.thread, InterruptException())
end

# Hyperscript.jl flattens and splats any vector/iterable recursively
# So DOM.div([1, 2, 3]) becomes DOM.div(1, 2, 3) and DOM.div([1, 2, [3, 4]]) becomes DOM.div(1, 2, 3, 4)
# Which is really bad for displaying objects as part of the DOM.
# It seems very breaking to change the behavior of Hyperscript.jl, so we just define a NoSplat type
# to prevent this behavior and wrap values we want to display in it.

"""
    NoSplat(value)

DOM.div(NoSplat(value)) will not splat the value, but render it just as DOM.div(value).
This is useful for displaying iterables/arrays in the DOM without flattening them.
"""
struct NoSplat
    value::Any
end

function Bonito.jsrender(session::Session, value::NoSplat)
    return Bonito.jsrender(session, value.value)
end

function book_display(value)
    return NoSplat(value)
end

function run!(editor::EvalEditor)
    return run!(editor.runner, editor)
end

run!(::Nothing, ::EvalEditor) = nothing

function run!(runner::MarkdownRunner, editor::EvalEditor)
    editor.output[] = parse_source(runner, editor.source[])
    editor.loading[] = false
    return
end

run_sync!(editor::EvalEditor) = run_sync!(editor.runner, editor)

function run_sync!(runner::MarkdownRunner, editor::EvalEditor)
    editor.output[] = parse_source(runner, editor.source[])
    return
end

function run_sync!(runner::AsyncRunner, editor::EvalEditor)
    fetch(spawnat(1) do
        task = RunnerTask(editor.source[], editor.output, editor.logging, editor.language)
        Base.invokelatest(run!, runner.mod, runner.language_evaluators, task)
    end)
    return
end

function run!(runner::AsyncRunner, editor::EvalEditor)
    editor.loading[] = true
    editor.show_logging[] = true
    empty!(editor.terminal_output)
    put!(runner.task_queue, RunnerTask(editor.source[], editor.output, editor.logging, editor.language))
    deregister = nothing
    deregister = on(editor.output) do _
        editor.loading[] = false
        Timer(2.5) do t
            editor.show_logging[] = false
        end
        off(deregister)
    end
    return
end

function run!(mod::Module, language_evaluators::Dict{String,LanguageEval}, task::RunnerTask)
    result = task.result
    source = task.source
    language = task.language
    try
        # Use language-specific evaluator
        evaluator = get(language_evaluators, language, nothing)
        if evaluator === nothing
            help = get(ALL_LANGUAGES, language, (; activation_help="Language $(language) is not currently implemented. Check out docs to see how to add support for a new language."))
            throw(ErrorException("No evaluator for language '$language' found. $(help.activation_help)"))
        end
        eval_result = eval_code(evaluator, mod, "", 1, source)
        result[] = Base.invokelatest(book_display, eval_result)
    catch e
        # Avoid `mod.current_book` direct access here: in long-lived runner tasks this can
        # hit world-age issues when `current_book` is defined after the task started.
        book_ref = Base.invokelatest(() -> mod.current_book())
        if book_ref isa Book
            result[] = InteractiveError(e, Base.catch_backtrace(), book_ref)
        else
            # Last resort fallback if no book context is available.
            result[] = Base.invokelatest(book_display, sprint(showerror, e))
        end
    end
    return
end
