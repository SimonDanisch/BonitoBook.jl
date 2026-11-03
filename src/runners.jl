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

# `LogEntry`, `CONSOLE_LOG_BYTE_CAP` and `push_console!` are defined in
# book.jl (which is included before runners.jl) because `Book` itself
# has a `console_log::Observable{Vector{LogEntry}}` field. The runner
# uses them here once the chain has been wired.

# `cell_id == 0` means "no book cell" — used for standalone EvalEditors
# (e.g. FileEditor) or when a RunnerTask is built without explicit
# attribution. The worker still pushes to console_log under id 0 so
# global stdout has a home in the attributed history.
struct RunnerTask
    source::String
    result::Observable{Any}
    logging::Observable
    language::String
    cell_id::Int
end

# Back-compat constructor: callers that don't supply a cell_id get 0.
RunnerTask(source, result, logging, language) =
    RunnerTask(source, result, logging, language, 0)

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
    # Observable mirroring `book.logging_mode`. Lives on the runner so
    # any code path can route off it without a back-reference to Book.
    logging_mode::Observable{Symbol}
    # Attributed log buffer (`Observable{Vector{LogEntry}}`) owned by
    # the Book; `nothing` for standalone runners.
    console_log::Any
    # Single permanent sink fed by the stdout-redirect pipe. All
    # bytes the pipe reader copies in land here; a listener fans
    # them out to (current_logging[], console_log) so we don't have
    # to swap the redirect target per task. Swapping was racy: the
    # pipe reader runs in its own goroutine and chunks could arrive
    # after the per-task listener was removed in `finally`.
    worker_sink::Observable{String}
    # Cell whose stdout we're currently attributing. The worker
    # updates these refs as it picks each task off the queue; they
    # stay set until the next task overwrites them, so late chunks
    # belong to whichever task just finished (rather than being
    # mis-attributed to global / cell 0).
    current_cell_id::Base.RefValue{Int}
    current_logging::Base.RefValue{Any}
    # Where to route bytes when no task is active (boot time only).
    global_logger::Observable{String}
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
function AsyncRunner(project::String, mod::Module=Module(gensym("BonitoBook"));
                     callback=identity, global_logger=Observable(""),
                     logging_mode::Observable{Symbol}=Observable{Symbol}(:respect_cell),
                     console_log=nothing)
    language_evaluators = get_language_evaluators()
    task_queue = Channel{RunnerTask}(Inf)
    redirect_target = redirect_all_to_channel()

    # Permanent worker sink — every chunk the pipe reader produces
    # lands here and is fanned out below. We never swap the redirect
    # target after this point, which removes the per-task race where
    # late chunks would arrive after the per-task listener had been
    # torn down in `finally`.
    worker_sink = Observable("")
    redirect_target[] = worker_sink

    current_cell_id = Ref(0)
    current_logging = Base.RefValue{Any}(global_logger)

    on(worker_sink) do chunk
        isempty(chunk) && return
        # 1) Forward to whichever per-cell logging observable is
        #    "current" — that's the cell whose stdout these bytes
        #    belong to. The cell's `terminal_output` listener picks
        #    it up from there.
        log_obs = current_logging[]
        if log_obs !== nothing
            log_obs[] = chunk
        end
        # 2) Attributed mirror into the book-wide console log.
        if console_log !== nothing
            push_console!(console_log, LogEntry(current_cell_id[], chunk, time()))
        end
    end

    taskref = spawnat(1) do
        for task in task_queue
            # Update attribution before eval — bytes the cell prints
            # land in the listener above tagged with this task's id.
            # We deliberately do NOT clear these refs in `finally`:
            # the pipe reader is async, so chunks can arrive after
            # invokelatest returns; keeping the refs set until the
            # NEXT task starts means those late bytes stay attributed
            # to the task that produced them.
            current_cell_id[] = task.cell_id
            current_logging[] = task.logging
            try
                Base.invokelatest(run!, mod, language_evaluators, task)
                println()
            catch e
                @error "Error running code: $(task.source)" exception = (e, catch_backtrace())
            end
        end
    end
    return AsyncRunner(mod, project, language_evaluators, task_queue, taskref,
                       Base.RefValue{Function}(callback), logging_mode,
                       console_log, worker_sink, current_cell_id,
                       current_logging, global_logger)
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
        task = RunnerTask(editor.source[], editor.output, editor.logging,
                          editor.language, editor.cell_id[])
        # Same attribution dance the worker loop does: point the
        # ref pair at this task before running, leave them set
        # afterwards so late chunks from the pipe reader land
        # under the right cell id.
        runner.current_cell_id[] = task.cell_id
        runner.current_logging[] = task.logging
        Base.invokelatest(run!, runner.mod, runner.language_evaluators, task)
    end)
    return
end

function run!(runner::AsyncRunner, editor::EvalEditor)
    editor.loading[] = true
    # We used to force `editor.show_logging[] = true` here and then
    # `Timer(2.5)` it back to false after the run completed. That
    # interacted badly with two things:
    #   (1) `any_visible = show_editor | show_logging` drives the
    #       cell-editor card's `hide-vertical` class on JS-side; once
    #       both observables landed at `false` (e.g. user toggled the
    #       editor off, then 2.5 s after a run the logging auto-hid)
    #       the whole card_content vanished. For cells whose output
    #       is `nothing` (like `using …`) only the hover-buttons
    #       remained, making the cell appear to disappear.
    #   (2) Any `println` output that the user wanted to read got
    #       wiped 2.5 s after the run, which is short enough that you
    #       miss it if you blink.
    # Visibility is now driven solely by the cell's own
    # `show_logging` attribute; the runner doesn't touch it.
    empty!(editor.terminal_output)
    put!(runner.task_queue, RunnerTask(editor.source[], editor.output,
                                       editor.logging, editor.language,
                                       editor.cell_id[]))
    deregister = nothing
    deregister = on(editor.output) do _
        editor.loading[] = false
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
