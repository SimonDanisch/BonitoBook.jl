"""
    LoggingWidget

A widget for displaying formatted logging output with ANSI color support.
Wraps Bonito's TerminalOutput for streaming log display.

# Fields
- `logging::Observable{String}`: Input channel - receives pre-converted HTML chunks
- `output::TerminalOutput`: The underlying terminal output widget
- `direction::String`: Show/hide direction ("horizontal" or "vertical")
"""
struct LoggingWidget
    logging::Observable{String}
    output::TerminalOutput
    direction::String
end

"""
    LoggingWidget(; direction="horizontal")

Create a new logging widget with empty initial state.
"""
function LoggingWidget(; direction="horizontal")
    logging = Observable("")
    output = TerminalOutput(; style=Styles("min-height" => "100px"))
    on(logging) do str
        if !isempty(str)
            append_html!(output, str)
        end
    end
    return LoggingWidget(logging, output, direction)
end

"""
    clear_logging!(widget::LoggingWidget)

Clear all logging content from the widget.
"""
function clear_logging!(widget::LoggingWidget)
    empty!(widget.output)
end

function Bonito.jsrender(session::Session, widget::LoggingWidget)
    return Bonito.jsrender(session, DOM.div(
        widget.output;
        class="logging-widget"
    ))
end
