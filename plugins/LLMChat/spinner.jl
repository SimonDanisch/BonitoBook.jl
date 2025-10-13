"""
Compact spinner component specifically for LLMChat status indicators.
Shows small animated dots next to the chat input field.
"""

"""
    TaskSpinner

A unified spinner that supports nested task execution with dynamic text updates.

# Fields
- `text::Observable{String}`: Observable text displayed by the spinner
- `stop::Threads.Atomic{Bool}`: Atomic flag to signal task cancellation
- `timeout::Float64`: Maximum execution time in seconds (default 300.0)
- `poll_interval::Float64`: How often to check stop flag in seconds (default 0.1)
"""
struct TaskSpinner
    text::Observable{String}
    stop::Threads.Atomic{Bool}
    timeout::Float64
    poll_interval::Float64
end

TaskSpinner(text::Observable{String}, stop::Threads.Atomic{Bool}) = TaskSpinner(text, stop, 300.0, 0.1)
TaskSpinner() = TaskSpinner(Observable(""), Threads.Atomic{Bool}(false), 300.0, 0.1)

"""
    async_spinner!(f::Function, task_spinner::TaskSpinner, text::String)

Execute a function asynchronously with the spinner showing the given text.
Supports nested calls - updates text for the duration of the closure and restores previous text after.
Polls until completion, checking stop flag and timeout. Returns the value returned by the function.

# Arguments
- `f::Function`: Function to execute (can return a value)
- `task_spinner::TaskSpinner`: The spinner instance
- `text::String`: Text to display while executing

# Returns
The return value of `f()` or `nothing` if stopped/timed out

# Throws
- `ErrorException`: If timeout is reached
"""
function async_spinner!(f::Function, task_spinner::TaskSpinner, text::String)
    # Save previous text
    previous_text = task_spinner.text[]
    # Update to new text
    task_spinner.text[] = text
    # Start the task
    task = @async f()
    result = nothing
    start_time = time()
    try
        # Poll until task completes, stop flag is set, or timeout
        while !istaskdone(task)
            # Check stop flag
            if task_spinner.stop[]
                @info "Task cancelled by stop flag"
                break
            end

            # Check timeout
            if time() - start_time > task_spinner.timeout
                throw(ErrorException("Task timed out after $(task_spinner.timeout)s"))
            end
            # Sleep briefly before checking again
            sleep(task_spinner.poll_interval)
        end

        # If task completed naturally, get the result
        if istaskdone(task) && !task_spinner.stop[]
            result = fetch(task)
        end
    finally
        # Restore previous text
        task_spinner.text[] = previous_text
    end
    return result
end

function async_spinner!(f::Function, task_spinner::Nothing, text::String)
    f()
end

function async_spinner!(f::Function, task_spinner::TaskSpinner, text::String, iterable)
    for item in iterable
        task_spinner.stop[] && break
        stop = async_spinner!(()->f(item), task_spinner, text)
        stop === true && break
    end
end

struct LLMChatSpinner
    message::Observable{String}
end
# Spinner styles with CSS animation
const LLMSpinnerStyles = Styles(
    CSS(
        ".llm-spinner-hidden",
        "display" => "none"
    ), CSS(
        ".llm-spinner-active",
        "display" => "flex",
        "align-items" => "center",
        "gap" => "4px",
        "animation" => "fadeIn 0.2s ease-in",
        "opacity" => "0.7"
    ), CSS(
        ".llm-spinner-dot",
        "width" => "4px",
        "height" => "4px",
        "border-radius" => "50%",
        "background-color" => "var(--accent-blue, #4a9eff)",
        "animation" => "pulse 1.4s ease-in-out infinite",
        "opacity" => "0.5"
    ), CSS(
        ".llm-spinner-dot:nth-child(1)",
        "animation-delay" => "0s"
    ), CSS(
        ".llm-spinner-dot:nth-child(2)",
        "animation-delay" => "0.2s"
    ), CSS(
        ".llm-spinner-dot:nth-child(3)",
        "animation-delay" => "0.4s"
    ), CSS(
        ".llm-spinner-text",
        "margin-left" => "2px",
        "font-size" => "10px",
        "color" => "var(--text-secondary)",
        "opacity" => "0.7"
    ), CSS(
        "@keyframes pulse",
        "0%, 100%" => Dict("opacity" => "0.3", "transform" => "scale(0.9)"),
        "50%" => Dict("opacity" => "0.8", "transform" => "scale(1.1)")
    ), CSS(
        "@keyframes fadeIn",
        "from" => Dict("opacity" => "0"),
        "to" => Dict("opacity" => "0.7")
    )
)

function Bonito.jsrender(session::Session, spinner::LLMChatSpinner)
    # Create spinner with animated dots - visible when message is not empty
    spinner_content = map(spinner.message) do msg
        if !isempty(msg)
            DOM.div(
                DOM.span(class="llm-spinner-dot"),
                DOM.span(class="llm-spinner-dot"),
                DOM.span(class="llm-spinner-dot"),
                DOM.span(msg, class="llm-spinner-text"),
                class="llm-spinner-active"
            )
        else
            DOM.div(class="llm-spinner-hidden")
        end
    end

    return Bonito.jsrender(session, spinner_content)
end
