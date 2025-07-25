"""
    LoggingWidget

A widget for displaying formatted logging output with HTML rendering.
Factored out from EvalEditor to be reusable for global logging.

# Fields
- `logging::Observable{String}`: Raw logging output
- `logging_html::Observable{String}`: HTML-formatted logging output
- `visible::Observable{Bool}`: Whether the logging widget is visible
- `new_content::Observable{Bool}`: Whether there's new content since last view
"""
struct LoggingWidget
    logging::Observable{String}
    logging_html::Observable{String}
    direction::String
end

"""
    LoggingWidget()

Create a new logging widget with empty initial state.
"""
function LoggingWidget(; direction="horizontal")
    logging = @D Observable("")
    logging_html = @D Observable("")
    # Convert raw logging to HTML when logging changes
    on(logging) do str
        if !isempty(str)
            logging_html[] = logging_html[] * str
        end
    end
    return LoggingWidget(logging, logging_html, direction)
end

"""
    clear_logging!(widget::LoggingWidget)

Clear all logging content from the widget.
"""
function clear_logging!(widget::LoggingWidget)
    widget.logging[] = ""
    widget.logging_html[] = ""
end

"""
    render_logging_widget(widget::LoggingWidget; direction="horizontal")

Render the logging widget as a DOM element.

# Arguments
- `widget::LoggingWidget`: The logging widget to render
- `direction::String`: Direction for show/hide animations ("horizontal" or "vertical")
"""
function Bonito.jsrender(session::Session, widget::LoggingWidget)
    direction = widget.direction
    hiding = "hide-$direction"
    showing = "show-$direction"

    # Create the HTML observable for rendering
    logging_html = @D Observable(HTML(""))
    on(widget.logging_html) do str
        isempty(str) && return
        # Don't wrap in <pre> since ANSIColoredPrinters already provides formatted HTML
        logging_html[] = HTML(str)
    end

    # Dynamic class based on visibility
    return Bonito.jsrender(session, DOM.div(
        ANSI_CSS,
        logging_html;
        class = "logging-widget",
        style = Styles("min-height" => "100px")
    ))
end
