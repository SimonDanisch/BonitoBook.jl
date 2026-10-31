"""
    LogEntry(cell_id, html, time)

One chunk of attributed console output. `cell_id` is the book cell
that owned the stdout/stderr write at the moment the chunk was
emitted (`0` for global / out-of-task writes). `html` is the
ANSI-converted HTML string the cell's logging pipeline produces.
`time` is a wall-clock timestamp from `time()`, used purely for
display.
"""
struct LogEntry
    cell_id::Int
    html::String
    time::Float64
end

# Soft cap on total characters held in `book.console_log`. We trim
# from the front when this is exceeded so a long-running session
# with chatty `println` doesn't grow memory unboundedly. 1 MB ≈ 10k
# lines of typical log output; well above what a user reads in a
# session, well below anything that would slow rendering.
const CONSOLE_LOG_BYTE_CAP = 1_048_576

"""
    push_console!(console_log, entry)

Append `entry` to the book's attributed console log, trimming oldest
entries until the total HTML payload is at or below
`CONSOLE_LOG_BYTE_CAP`. Notifies the observable exactly once so
widgets watching it can rerender on the new state.
"""
function push_console!(console_log::Observable{Vector{LogEntry}}, entry::LogEntry)
    entries = console_log[]
    push!(entries, entry)
    total = sum(sizeof(e.html) for e in entries; init = 0)
    while total > CONSOLE_LOG_BYTE_CAP && length(entries) > 1
        dropped = popfirst!(entries)
        total -= sizeof(dropped.html)
    end
    notify(console_log)
    return entry
end

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

"""
    ConsoleLogWidget(console_log)

Renders a book's `Observable{Vector{LogEntry}}` (the attributed
console history populated by the runner regardless of `logging_mode`)
as a chronological list, with each entry prefixed by its cell id so
the user can tell which cell produced which output.

The widget reactively re-renders only when new entries arrive, and
auto-scrolls to the bottom so the freshest output is always in view.
A clear button (visible when the user hovers) empties the buffer.
"""
struct ConsoleLogWidget
    console_log::Observable{Vector{LogEntry}}
end

function _format_entry(entry::LogEntry)
    label = entry.cell_id == 0 ? "·" : string("cell ", entry.cell_id)
    # `entry.html` is already ANSI-converted; wrap it in a row that
    # carries the cell-id badge for attribution. We use raw HTML
    # interpolation here because `entry.html` is trusted output from
    # our own ANSI-to-HTML pipeline.
    return DOM.div(
        DOM.span(label; class = "console-cell-id"),
        Bonito.DontEscape(entry.html);
        class = "console-entry",
    )
end

function Bonito.jsrender(session::Session, widget::ConsoleLogWidget)
    # `map` over the Observable so the rendered list refreshes when
    # `push_console!` notifies — Bonito's diffing makes this a cheap
    # re-render rather than a full DOM reflow. The mapped output is a
    # DOM tree (serialisable), so we don't need a msgpack mapping for
    # `LogEntry` and can keep that type as a plain Julia struct.
    rendered = map(widget.console_log) do entries
        DOM.div([_format_entry(e) for e in entries]...;
                class = "console-entries")
    end
    container = DOM.div(rendered; class = "console-log-widget")
    # Auto-scroll to bottom on new content. We can't watch the
    # `console_log` observable from JS (`LogEntry` isn't MsgPack-able
    # and there's no reason to ship the raw struct to the client when
    # the server already rendered the list). A MutationObserver on
    # the `.console-entries` subtree handles it cleanly.
    scroll_to_bottom = js"""
        const root = $(container);
        const scroll = () => {
            const sc = root.querySelector('.console-entries');
            if (sc) sc.scrollTop = sc.scrollHeight;
        };
        const observer = new MutationObserver(
            () => requestAnimationFrame(scroll));
        observer.observe(root, { childList: true, subtree: true });
        requestAnimationFrame(scroll);
    """
    return Bonito.jsrender(session, DOM.div(container, scroll_to_bottom))
end

"""
    clear_console!(book::AbstractBook)

Empty the attributed console history. Wired to the "clear" button in
the console widget, but also useful from Julia for tests.
"""
function clear_console!(console_log::Observable{Vector{LogEntry}})
    empty!(console_log[])
    notify(console_log)
    return
end
