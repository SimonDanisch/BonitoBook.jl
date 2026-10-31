using Bonito
using FileWatching

"""
    EvalFileOnChange

A component that watches a file and evaluates it whenever it changes.
Shows a popup on evaluation errors with options to keep or reset changes.

# Fields
- `filepath::String`: Path to the file to watch
- `current_output::Observable`: Current evaluation result (value or error)
- `last_valid_output::Observable`: Last successful evaluation result
- `last_valid_source::Observable`: Last successful source code
- `file_watcher::Observable`: File modification watcher
- `watcher_task::Ref{Task}`: Reference to the file watching task
"""
mutable struct EvalFileOnChange
    filepath::String
    current_output::Observable{Any}
    last_valid_output::Observable{Any}
    file_watcher::Observable
    watcher_task::Ref{Task}
    close::Threads.Atomic{Bool}
    function EvalFileOnChange(
            filepath::String, current_output::Observable, last_valid_output::Observable,
            file_watcher::Observable, watcher_task::Ref{Task},
            close::Threads.Atomic{Bool}
        )
        obj = new(filepath, current_output, last_valid_output, file_watcher, watcher_task, close)
        finalizer(obj) do obj
            obj.close[] = true
        end
        return obj
    end
end

function start_watch_loop!(efo::EvalFileOnChange)
    if isassigned(efo.watcher_task) && !istaskdone(efo.watcher_task[])
        efo.close[] = true
        wait(efo.watcher_task[])
        efo.close[] = false
    end
    file = efo.filepath
    efo.watcher_task[] = @async begin
        while !efo.close[]
            try
                result = FileWatching.watch_file(efo.filepath, 1)
                if result.changed || result.renamed || file != efo.filepath
                    efo.file_watcher[] = mtime(efo.filepath)
                    file = efo.filepath
                end
            catch e
                if e isa InterruptException || !isfile(efo.filepath)
                    break
                end
                @error "Error watching file $(efo.filepath): $(string(e))" exception = (e, catch_backtrace())
            end
        end
        println("DONE WATCHING")
    end
end

"""
    EvalFileOnChange(filepath::String; module_context=Main)

Create a new EvalFileOnChange component for the given file.

# Arguments
- `filepath`: Path to the file to watch and evaluate
- `module_context`: Module context for evaluation (default: Main)
"""
function EvalFileOnChange(filepath::String; module_context=Main)
    # Create file watcher observable
    file_watcher = Observable(mtime(filepath))
    current_output = Observable{Any}(nothing)
    last_valid_output = Observable{Any}(nothing)

    # Create async task for file watching
    watcher_task = Ref{Task}()
    close = Threads.Atomic{Bool}(false)
    efo = EvalFileOnChange(filepath, current_output, last_valid_output, file_watcher, watcher_task, close)
    on(file_watcher) do _time
        try
            res = Base._include(identity, module_context, efo.filepath)
            current_output[] = res
            last_valid_output[] = res
        catch e
            @warn "Error evaluating file $filepath: $(string(e))" exception = (e, catch_backtrace())
            current_output[] = e
        end
    end
    start_watch_loop!(efo)
    return efo
end

"""
    update_filepath!(eval_component::EvalFileOnChange, new_filepath::String)

Update the file path being watched by the EvalFileOnChange component.
Stops watching the old file and starts watching the new one.
"""
function update_filepath!(eval_component::EvalFileOnChange, new_filepath::String)
    eval_component.filepath = new_filepath
end

function Bonito.jsrender(session::Session, eval_component::EvalFileOnChange)
    # Create popup for errors only
    popup_content = Observable(DOM.div())
    popup = PopUp(popup_content; show = false)

    # Handle output changes
    on(eval_component.current_output; update = true) do output
        if output isa Exception
            # Show error in popup
            popup_content[] = DOM.div(
                DOM.h3("Error in file: $(basename(eval_component.filepath))"),
                DOM.pre(sprint(showerror, output);
                    style = Styles(
                        "max-height" => "400px",
                        "overflow-y" => "auto",
                        "background-color" => "var(--bg-primary)",
                        "padding" => "10px",
                        "border-radius" => "5px",
                        "font-size" => "12px"
                    )
                )
            )
            popup.show[] = true
        else
            # Hide popup on successful evaluation
            popup.show[] = false
        end
    end

    # Clean up watcher when session closes
    on(session.on_close) do _
        eval_component.close[] = true
    end

    # Return just the popup
    # The actual output is accessed via eval_component.current_output
    return Bonito.jsrender(session, DOM.div(popup))
end
