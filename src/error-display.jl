"""
    InteractiveError(error, stacktrace)

An interactive error display widget that shows errors with collapsible stacktraces,
clickable file paths, and filtering options.

# Fields
- `error::Any`: The error object
- `stacktrace::Vector`: The stacktrace vector (raw backtrace from catch_backtrace)
"""
struct InteractiveError
    error::Any
    stacktrace::Vector
end

"""
    process_stacktrace(stacktrace::Vector, filtered::Bool = true)

Process stacktrace using Base.show_backtrace and optionally filter it.
This follows the same approach as Bonito.HTTPServer.err_to_html.

# Arguments
- `stacktrace`: The raw stacktrace vector from catch_backtrace
- `filtered`: Whether to show filtered view (default: true)

# Returns
Processed stacktrace string ready for display.
"""
function process_stacktrace(stacktrace::Vector, filtered::Bool = true)
    stacktrace_msg = sprint() do io
        iol = IOContext(io, :stacktrace_types_limited => Base.RefValue(true))
        Base.show_backtrace(iol, stacktrace)
    end

    if !filtered
        return stacktrace_msg
    end

    # Filter out Julia base paths and eval noise
    lines = split(stacktrace_msg, '\n', keepempty=false)
    filtered_lines = String[]

    for line in lines
        # Keep lines that don't contain common Julia base patterns
        if !(
            contains(line, r"/julia/.*\.jl") ||
            contains(line, r"\\julia\\.*\.jl") ||
            contains(line, r"@Base") ||
            contains(line, r"sysimg\.jl") ||
            contains(line, r"boot\.jl") ||
            (contains(line, "eval") && contains(line, r"top-level|anonymous"))
        )
            push!(filtered_lines, line)
        end
    end

    return join(filtered_lines, '\n')
end

"""
    linkify_stacktrace_string(stacktrace_string::String, session::Session)

Process stacktrace string to make file paths clickable.
Based on the linkify_stacktrace function from Bonito.HTTPServer.
"""
function linkify_stacktrace_string(stacktrace_string::String, session::Session)
    lines = split(stacktrace_string, '\n'; keepempty=false)
    elements = []

    for line in lines
        # Match file paths - more comprehensive regex to catch various patterns
        # Matches: /path/file.jl:123, C:\path\file.jl:123, ./path/file.jl:123, ~/path/file.jl:123, path/file.jl:123, etc.
        m = match(r"^(.*?)([A-Za-z]:[\\/].*?\.jl|[\.~\/].*?\.jl|[\w\/\\]+\.jl):(\d+)(.*)", line)
        if m !== nothing
            prefix, file, line_num, suffix = m.captures
            normalized_file = replace(file, "\\" => "/")  # Convert Windows paths to `/`

            # Create a click observable for this file link
            click_obs = Observable(false)

            # Set up the callback to open the file when clicked
            on(session, click_obs) do _
                try
                    # Try to find the current book and open the file
                    # This is a bit of a workaround - we'll get the book from the global scope
                    # current_book = @Book()
                    file_editor = get_file_editor(current_book)

                    # Parse line number
                    line_number = tryparse(Int, line_num)
                    if !isnothing(line_number) && isfile(normalized_file)
                        open_file!(file_editor, normalized_file; line=line_number)
                    elseif isfile(normalized_file)
                        open_file!(file_editor, normalized_file)
                    else
                        @warn "File not found: $normalized_file"
                    end
                catch e
                    @warn "Could not open file $normalized_file: $e"
                end
            end

            push!(
                elements,
                DOM.span(
                    String(prefix),
                    DOM.a(
                        file * ":" * line_num;
                        href = "#",
                        class = "error-file-link",
                        onclick = js"event => {event.preventDefault(); $(click_obs).notify(true);}",
                        title = "Click to open $(normalized_file):$(line_num) in editor"
                    ),
                    String(suffix),
                ),
                DOM.br(),
            )
        else
            m2 = match(r"^(.*?)(\[\d+\])", line)
            if !isnothing(m2)
                prefix, suffix = m2.captures
                push!(
                    elements,
                    DOM.span(String(line); style="color: darkred; font-weight: bold;"),
                    DOM.br(),
                )
            else
                push!(elements, DOM.span(String(line)), DOM.br())
            end
        end
    end

    return DOM.div(elements...; class="stacktrace-content")
end

"""
Render an InteractiveError as an interactive DOM element.
"""
function Bonito.jsrender(session::Session, interactive_error::InteractiveError)
    # Format the error message
    error_msg = sprint() do io
        Base.showerror(io, interactive_error.error)
    end

    # Create observable for filtering toggle
    show_filtered = Observable(true)

    # Create the stacktrace content that updates when toggle changes
    stacktrace_content = map(show_filtered) do filtered
        stacktrace_string = process_stacktrace(interactive_error.stacktrace, filtered)
        return linkify_stacktrace_string(stacktrace_string, session)
    end

    # Create filter toggle button using BonitoBook's SmallToggle
    filter_button_text = map(show_filtered) do filtered
        filtered ? "Show Full Stacktrace" : "Show Filtered Stacktrace"
    end

    # Create the toggle button
    toggle_button = DOM.div(
        SmallToggle(show_filtered, icon("filter"), title="Toggle stacktrace filtering"),
        DOM.span(filter_button_text, style="margin-left: 8px; font-size: 0.9em; color: var(--text-secondary);"),
        style = "margin: 8px 0; text-align: right; display: flex; align-items: center; justify-content: flex-end;"
    )

    # Count lines for display
    stacktrace_line_count = map(show_filtered) do filtered
        stacktrace_string = process_stacktrace(interactive_error.stacktrace, filtered)
        length(split(stacktrace_string, '\n'; keepempty=false))
    end

    # Create collapsible title that shows frame count
    collapsible_title = map(stacktrace_line_count) do count
        "Stacktrace ($(count) lines)"
    end

    # Create the collapsible stacktrace content
    stacktrace_collapsible_content = DOM.div(
        toggle_button,
        DOM.div(
            stacktrace_content,
            style = "max-height: 400px; overflow-y: auto; font-family: monospace; font-size: 12px; line-height: 1.4; background-color: var(--bg-primary, #fff); padding: 8px; border-radius: 4px;"
        )
    )

    # Create the collapsible stacktrace using BonitoBook's Collapsible component
    stacktrace_collapsible = Collapsible(
        "Stacktrace", # We'll use a simple title since the dynamic one is complex
        stacktrace_collapsible_content,
        expanded = false
    )

    # Create the complete error display
    error_widget = DOM.div(
        # Error header
        DOM.div(
            DOM.h4(
                "Error: $(typeof(interactive_error.error))",
                style = "color: #dc3545; margin: 0 0 8px 0; font-size: 1.1em;"
            ),
            DOM.pre(
                error_msg,
                style = "background-color: #f8d7da; color: #721c24; padding: 12px; border-radius: 6px; margin: 8px 0; font-family: monospace; white-space: pre-wrap; word-wrap: break-word;"
            ),
            style = "margin-bottom: 16px;"
        ),
        # Collapsible stacktrace
        stacktrace_collapsible,
        class = "interactive-error-widget",
        style = "border: 1px solid var(--border-primary); border-radius: 8px; padding: 16px; margin: 8px 0; background-color: var(--bg-primary);"
    )

    return error_widget
end
