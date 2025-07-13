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
    on(file_watcher) do _time
        try
            res = Base._include(identity, module_context, filepath)
            current_output[] = res
            last_valid_output[] = res
        catch e
            current_output[] = e
        end
    end
    notify(file_watcher)
    # Create async task for file watching
    watcher_task = Ref{Task}()
    close = Threads.Atomic{Bool}(false)
    # Start file watcher task
    watcher_task[] = @async begin
        while !close[]
            try
                # Watch for file changes
                result = FileWatching.watch_file(filepath)
                if result.changed || result.renamed
                    file_watcher[] = mtime(filepath)
                end
            catch e
                if e isa InterruptException
                    break
                end
                @error "Error watching file $filepath: $(string(e))" exception=(e, catch_backtrace())
                # Sleep briefly on error and try again
                sleep(0.1)
            end
        end
    end

    return EvalFileOnChange(filepath, current_output, last_valid_output, file_watcher, watcher_task, close)
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
