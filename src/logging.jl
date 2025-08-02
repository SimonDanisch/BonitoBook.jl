const ANSI_CSS = Styles(
    # Define ANSI color variables for light theme
    CSS(
        "@media (prefers-color-scheme: light), (prefers-color-scheme: no-preference)",
        CSS(
            ":root",
            # Standard ANSI colors optimized for light backgrounds
            "--ansi-black" => "#000000",
            "--ansi-red" => "#cd3131",
            "--ansi-green" => "#00bc00",
            "--ansi-yellow" => "#949800",
            "--ansi-blue" => "#0451a5",
            "--ansi-magenta" => "#bc05bc",
            "--ansi-cyan" => "#0598bc",
            "--ansi-white" => "#555555",
            # Bright ANSI colors
            "--ansi-bright-black" => "#686868",
            "--ansi-bright-red" => "#ff5555",
            "--ansi-bright-green" => "#55ff55",
            "--ansi-bright-yellow" => "#ffff55",
            "--ansi-bright-blue" => "#5555ff",
            "--ansi-bright-magenta" => "#ff55ff",
            "--ansi-bright-cyan" => "#55ffff",
            "--ansi-bright-white" => "#ffffff"
        )
    ),

    # Define ANSI color variables for dark theme
    CSS(
        "@media (prefers-color-scheme: dark)",
        CSS(
            ":root",
            # Standard ANSI colors optimized for dark backgrounds
            "--ansi-black" => "#000000",
            "--ansi-red" => "#f44747",
            "--ansi-green" => "#4ec9b0",
            "--ansi-yellow" => "#dcdcaa",
            "--ansi-blue" => "#569cd6",
            "--ansi-magenta" => "#c678dd",
            "--ansi-cyan" => "#56b6c2",
            "--ansi-white" => "#d4d4d4",
            # Bright ANSI colors
            "--ansi-bright-black" => "#808080",
            "--ansi-bright-red" => "#ff6b6b",
            "--ansi-bright-green" => "#6bffb8",
            "--ansi-bright-yellow" => "#ffffa0",
            "--ansi-bright-blue" => "#7cc3ff",
            "--ansi-bright-magenta" => "#ff8cff",
            "--ansi-bright-cyan" => "#8cffff",
            "--ansi-bright-white" => "#ffffff"
        )
    ),

    # Text formatting
    CSS("span.sgr1", "font-weight" => "bolder"),
    CSS("span.sgr2", "font-weight" => "lighter"),
    CSS("span.sgr3", "font-style" => "italic"),
    CSS("span.sgr4", "text-decoration" => "underline"),
    CSS(
        "span.sgr7",
        "color" => "var(--bg-primary)",
        "background-color" => "var(--text-primary)"
    ),
    CSS(
        "span.sgr8, span.sgr8 span, span span.sgr8",
        "color" => "transparent"
    ),
    CSS("span.sgr9", "text-decoration" => "line-through"),

    # Standard colors (30-37) using CSS variables
    CSS("span.sgr30", "color" => "var(--ansi-black)"),
    CSS("span.sgr31", "color" => "var(--ansi-red)"),
    CSS("span.sgr32", "color" => "var(--ansi-green)"),
    CSS("span.sgr33", "color" => "var(--ansi-yellow)"),
    CSS("span.sgr34", "color" => "var(--ansi-blue)"),
    CSS("span.sgr35", "color" => "var(--ansi-magenta)"),
    CSS("span.sgr36", "color" => "var(--ansi-cyan)"),
    CSS("span.sgr37", "color" => "var(--ansi-white)"),

    # Background colors (40-47)
    CSS("span.sgr40", "background-color" => "var(--ansi-black)"),
    CSS("span.sgr41", "background-color" => "var(--ansi-red)"),
    CSS("span.sgr42", "background-color" => "var(--ansi-green)"),
    CSS("span.sgr43", "background-color" => "var(--ansi-yellow)"),
    CSS("span.sgr44", "background-color" => "var(--ansi-blue)"),
    CSS("span.sgr45", "background-color" => "var(--ansi-magenta)"),
    CSS("span.sgr46", "background-color" => "var(--ansi-cyan)"),
    CSS("span.sgr47", "background-color" => "var(--ansi-white)"),

    # Bright colors (90-97)
    CSS("span.sgr90", "color" => "var(--ansi-bright-black)"),
    CSS("span.sgr91", "color" => "var(--ansi-bright-red)"),
    CSS("span.sgr92", "color" => "var(--ansi-bright-green)"),
    CSS("span.sgr93", "color" => "var(--ansi-bright-yellow)"),
    CSS("span.sgr94", "color" => "var(--ansi-bright-blue)"),
    CSS("span.sgr95", "color" => "var(--ansi-bright-magenta)"),
    CSS("span.sgr96", "color" => "var(--ansi-bright-cyan)"),
    CSS("span.sgr97", "color" => "var(--ansi-bright-white)"),

    # Bright background colors (100-107)
    CSS("span.sgr100", "background-color" => "var(--ansi-bright-black)"),
    CSS("span.sgr101", "background-color" => "var(--ansi-bright-red)"),
    CSS("span.sgr102", "background-color" => "var(--ansi-bright-green)"),
    CSS("span.sgr103", "background-color" => "var(--ansi-bright-yellow)"),
    CSS("span.sgr104", "background-color" => "var(--ansi-bright-blue)"),
    CSS("span.sgr105", "background-color" => "var(--ansi-bright-magenta)"),
    CSS("span.sgr106", "background-color" => "var(--ansi-bright-cyan)"),
    CSS("span.sgr107", "background-color" => "var(--ansi-bright-white)")
)


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
    logging = Observable("")
    logging_html = Observable("")
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
    logging_html = Observable(HTML(""))
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
