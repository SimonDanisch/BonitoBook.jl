using Bonito

"""
Custom rendering for LLM Chat tools using CSS classes from ChatStyles.
"""

# ============================================================================
# Helper Functions
# ============================================================================

"""
    get_error(execution::ToolExecution)

Returns the error message if the tool result contains an error, otherwise returns nothing.
"""
function get_error(execution::ToolExecution)
    result = execution.result
    if !result.success && result.result isa Exception
        return string(result.result)
    end
    if result.result isa Dict && haskey(result.result, "error")
        return result.result["error"]
    end
    return nothing
end

"""
    render_tool_header(tool_name::String, args_display::String)

Renders a standard tool header with the tool name and arguments.
"""
function render_tool_header(tool_name::String, args_display::String)
    return DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        class="tool-header"
    )
end

"""
    render_executing(tool_name::String, args_display::String)

Renders the executing state for a tool.
"""
function render_executing(tool_name::String, args_display::String)
    return DOM.div(
        "$(tool_name): $(args_display)",
        class="tool-executing"
    )
end

"""
    render_error(tool_name::String, args_display::String, error_msg::String)

Renders an error state for a tool.
"""
function render_error(tool_name::String, args_display::String, error_msg::String)
    header = render_tool_header(tool_name, args_display)
    return DOM.div(
        header,
        DOM.div(error_msg, class="tool-error"),
        class="tool-container tool-error-container"
    )
end

"""
    format_bytes(size::Int)

Format byte size in human-readable format.
"""
function format_bytes(size::Int)
    if size < 1024
        return "$(size) B"
    elseif size < 1024^2
        return "$(round(size/1024, digits=1)) KB"
    elseif size < 1024^3
        return "$(round(size/1024^2, digits=1)) MB"
    else
        return "$(round(size/1024^3, digits=2)) GB"
    end
end


# ============================================================================
# BashTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{BashTool})
    tool = execution.tool
    result = execution.result
    tool_name = "bash"
    args_display = tool.command

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Output is the result string
    output = result.result
    lines = split(output, '\n')
    line_count = length(lines)

    # Header with info
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        DOM.span(isempty(strip(output)) ? "✓ done" : "$(line_count) $(line_count == 1 ? "line" : "lines")", class="tool-info"),
        class="tool-header"
    )

    # Only show output if not empty
    if isempty(strip(output))
        result_display = DOM.div()
    else
        # Detailed output
        output_content = DOM.pre(output, class="tool-output")

        # Use collapsible for longer output
        result_display = if line_count > 10
            BonitoBook.Collapsible("Output ($(line_count) lines)", output_content; expanded=false)
        elseif line_count > 3
            BonitoBook.Collapsible("Output", output_content; expanded=true)
        else
            output_content
        end
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileReadTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{FileReadTool})
    tool = execution.tool
    result = execution.result
    tool_name = "read"
    args_display = tool.path

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Content is the result string
    content = result.result
    lines = split(content, '\n')
    line_count = length(lines)
    byte_count = length(content)

    # Format file size
    size_str = byte_count < 1024 ? "$(byte_count) B" :
               byte_count < 1024^2 ? "$(round(byte_count/1024, digits=1)) KB" :
               "$(round(byte_count/1024^2, digits=1)) MB"

    # Open file button with Observable click handler
    click = Observable(false)
    open_btn = DOM.button("📂 Open", class="tool-open-btn", onclick=js"event=> $(click).notify(true)")
    on(session, click) do _
        book = BonitoBook.current_book(session)
        if isnothing(book)
            book = BonitoBook.current_book()
        end
        if !isnothing(book) && haskey(book.widgets, "file_editor")
            file_editor = book.widgets["file_editor"]
            if isfile(tool.path)
                BonitoBook.open_file!(file_editor, tool.path)
            end
        end
    end

    # Header with info and open button
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        DOM.span("$(size_str), $(line_count) $(line_count == 1 ? "line" : "lines")", class="tool-info"),
        open_btn,
        class="tool-header"
    )

    # Detailed content
    content_preview = DOM.pre(content, class="tool-output")

    # Use collapsible for file contents
    result_display = if line_count > 20
        BonitoBook.Collapsible("Content ($(line_count) lines)", content_preview; expanded=false)
    elseif line_count > 5
        BonitoBook.Collapsible("Content", content_preview; expanded=true)
    else
        content_preview
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileWriteTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{FileWriteTool})
    tool = execution.tool
    result = execution.result
    tool_name = "write"
    args_display = tool.path

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Result is the number of bytes written (handle both String and Int)
    bytes_written = result.result
    if bytes_written isa String
        bytes_written = tryparse(Int, bytes_written)
        if isnothing(bytes_written)
            bytes_written = 0
        end
    end

    # Format size
    size_str = bytes_written < 1024 ? "$(bytes_written) B" :
               bytes_written < 1024^2 ? "$(round(bytes_written/1024, digits=1)) KB" :
               "$(round(bytes_written/1024^2, digits=1)) MB"

    # Open file button with Observable click handler
    click = Observable(false)
    open_btn = DOM.button("📂 Open", class="tool-open-btn", onclick=js"event=> $(click).notify(true)")
    on(session, click) do _
        book = BonitoBook.current_book(session)
        if isnothing(book)
            book = BonitoBook.current_book()
        end
        if !isnothing(book) && haskey(book.widgets, "file_editor")
            file_editor = book.widgets["file_editor"]
            if isfile(tool.path)
                BonitoBook.open_file!(file_editor, tool.path)
            end
        end
    end

    # Header with info and open button
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        DOM.span("✓ wrote $(size_str)", class="tool-info"),
        open_btn,
        class="tool-header"
    )

    return Bonito.jsrender(session, DOM.div(header, class="tool-container"))
end

# ============================================================================
# FileEditTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{FileEditTool})
    tool = execution.tool
    result = execution.result
    tool_name = "edit"
    args_display = tool.path

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Open file button with Observable click handler
    click = Observable(false)
    open_btn = DOM.button("📂 Open", class="tool-open-btn", onclick=js"event=> $(click).notify(true)")
    on(session, click) do _
        book = BonitoBook.current_book(session)
        if isnothing(book)
            book = BonitoBook.current_book()
        end
        if !isnothing(book) && haskey(book.widgets, "file_editor")
            file_editor = book.widgets["file_editor"]
            if isfile(tool.path)
                BonitoBook.open_file!(file_editor, tool.path)
            end
        end
    end

    # Detect language from file extension
    ext = lowercase(splitext(tool.path)[2])
    language = if ext == ".jl"
        "julia"
    elseif ext in [".py", ".pyw"]
        "python"
    elseif ext in [".js", ".mjs"]
        "javascript"
    elseif ext in [".md", ".markdown"]
        "markdown"
    elseif ext in [".html", ".htm"]
        "html"
    elseif ext == ".css"
        "css"
    elseif ext == ".json"
        "json"
    elseif ext in [".yml", ".yaml"]
        "yaml"
    elseif ext == ".toml"
        "toml"
    else
        "text"
    end

    # Calculate some stats
    old_lines = length(split(tool.old_text, '\n'))
    new_lines = length(split(tool.new_text, '\n'))
    line_diff = new_lines - old_lines
    diff_str = line_diff == 0 ? "modified" :
               line_diff > 0 ? "+$(line_diff) $(abs(line_diff) == 1 ? "line" : "lines")" :
               "$(line_diff) $(abs(line_diff) == 1 ? "line" : "lines")"

    # Header with open button
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        DOM.span("✓ $(diff_str)", class="tool-info"),
        open_btn,
        class="tool-header"
    )

    # Create diff editor showing the changes
    diff_editor = BonitoBook.DiffEditor(
        tool.old_text,
        tool.new_text;
        language=language,
        renderSideBySide=false,
        readOnly=true
    )

    # Use collapsible for the diff view - expanded by default for small changes
    diff_display = BonitoBook.Collapsible(
        "Changes",
        diff_editor;
        expanded=(abs(line_diff) <= 10)
    )

    return Bonito.jsrender(session, DOM.div(header, diff_display, class="tool-container"))
end

# ============================================================================
# HttpGetTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{HttpGetTool})
    tool = execution.tool
    result = execution.result
    tool_name = "http"
    args_display = tool.url

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Result is a dict with status and content
    status = result.result["status"]
    content = result.result["content"]
    byte_count = length(content)

    # Format size
    size_str = byte_count < 1024 ? "$(byte_count) B" :
               byte_count < 1024^2 ? "$(round(byte_count/1024, digits=1)) KB" :
               "$(round(byte_count/1024^2, digits=1)) MB"

    # Status indicator
    status_str = status == 200 ? "✓ $(status)" : "⚠ $(status)"

    # Header with status
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.a(args_display, href=tool.url, target="_blank", class="tool-url"),
        DOM.span("$(status_str), $(size_str)", class="tool-info"),
        class="tool-header"
    )

    # Content preview
    content_preview = DOM.pre(content, class="tool-output")

    # Collapsible response - collapsed by default for large responses
    result_display = if byte_count > 1024
        BonitoBook.Collapsible("Response ($(size_str))", content_preview; expanded=false)
    else
        BonitoBook.Collapsible("Response", content_preview; expanded=true)
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# AddCellTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{AddCellTool})
    tool = execution.tool
    result = execution.result
    tool_name = "add_cell"
    args_display = tool.language

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    lines = split(tool.content, '\n')
    line_count = length(lines)

    # Header
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        DOM.span("✓ $(line_count) $(line_count == 1 ? "line" : "lines")", class="tool-info"),
        class="tool-header"
    )

    # Show preview of content
    content_preview = DOM.pre(tool.content, class="tool-output")
    result_display = if line_count > 10
        BonitoBook.Collapsible("Code ($(line_count) lines)", content_preview; expanded=false)
    elseif line_count > 3
        BonitoBook.Collapsible("Code", content_preview; expanded=true)
    else
        content_preview
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{FileTool})
    tool = execution.tool
    result = execution.result
    tool_name = "file"

    # Create cleaner args display
    args_parts = String[]
    push!(args_parts, tool.command)
    for (k, v) in tool.arguments
        if k != :command
            push!(args_parts, "$(k)=$(v)")
        end
    end
    args_display = join(args_parts, " ")

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Result data
    result_data = result.result

    # Format result based on type
    if result_data isa Vector && !isempty(result_data)
        # List of files/matches
        if result_data[1] isa Dict
            # Detailed readdir output - show formatted file list
            preview_limit = 10  # Show first 10 items in preview
            all_items = [
                DOM.div(
                    DOM.span(get(item, "type", "unknown") == "directory" ? "📁" : "📄", class="file-type"),
                    DOM.span(get(item, "name", ""), class="file-name"),
                    DOM.span(format_file_size(get(item, "size", 0)), class="file-size"),
                    class="file-item"
                )
                for item in result_data
            ]

            # Create preview (first 10 items)
            preview_items = all_items[1:min(preview_limit, length(all_items))]
            preview_content = DOM.div(preview_items..., class="file-list")

            # Full content
            if length(all_items) > preview_limit
                full_content = DOM.div(
                    all_items...,
                    class="file-list"
                )
            else
                full_content = preview_content
            end

            list_content = full_content
        else
            # Simple list of paths
            preview_limit = 10
            all_items = [
                DOM.div(
                    DOM.span("📄", class="file-type"),
                    DOM.span(item, class="file-name"),
                    class="file-item"
                )
                for item in result_data
            ]

            preview_items = all_items[1:min(preview_limit, length(all_items))]
            preview_content = DOM.div(preview_items..., class="file-list")

            if length(all_items) > preview_limit
                full_content = DOM.div(all_items..., class="file-list")
            else
                full_content = preview_content
            end

            list_content = full_content
        end

        # Header with count
        total_count = length(result_data)
        header = DOM.div(
            DOM.span(tool_name, class="tool-name"),
            DOM.span(args_display, class="tool-args"),
            DOM.span("$(total_count) $(total_count == 1 ? "item" : "items")", class="tool-info"),
            class="tool-header"
        )

        # Use collapsible for more than 3 items, show preview first
        result_display = if total_count > 10
            BonitoBook.Collapsible(
                "Show all $(total_count) items",
                list_content;
                expanded=false
            )
        elseif total_count > 3
            BonitoBook.Collapsible(
                "Files",
                list_content;
                expanded=true
            )
        else
            list_content
        end
    elseif result_data isa String || result_data === nothing
        # Single result string or nothing
        info_text = isnothing(result_data) ? "✓ done" : result_data
        header = DOM.div(
            DOM.span(tool_name, class="tool-name"),
            DOM.span(args_display, class="tool-args"),
            DOM.span(info_text, class="tool-info"),
            class="tool-header"
        )
        result_display = DOM.div()
    else
        # Other result types
        header = DOM.div(
            DOM.span(tool_name, class="tool-name"),
            DOM.span(args_display, class="tool-args"),
            class="tool-header"
        )
        result_display = DOM.pre(repr(result_data), class="tool-output")
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# Helper function to format file sizes nicely
function format_file_size(bytes::Int)
    if bytes < 1024
        return "$(bytes) B"
    elseif bytes < 1024^2
        return "$(round(bytes/1024, digits=1)) KB"
    elseif bytes < 1024^3
        return "$(round(bytes/1024^2, digits=1)) MB"
    else
        return "$(round(bytes/1024^3, digits=2)) GB"
    end
end

# ============================================================================
# TodoList Rendering
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{TodoList})
    tool = execution.tool
    result = execution.result
    tool_name = "todo"

    # Create checklist items with status
    checklist_items = [
        DOM.div(
            DOM.span(tool.status[i] ? "✓" : "○", class="todo-checkbox"),
            DOM.span(item, class="todo-text"),
            class="todo-item"
        )
        for (i, item) in enumerate(tool.items)
    ]

    # Header
    completed = count(tool.status)
    total = length(tool.items)
    progress_str = completed == total ? "✓ complete" : "$(completed)/$(total) done"

    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(tool.title, class="tool-args"),
        DOM.span(progress_str, class="tool-info"),
        class="tool-header"
    )

    return Bonito.jsrender(session, DOM.div(
        header,
        DOM.div(checklist_items..., class="todo-items"),
        class="tool-container todo-container"
    ))
end

# ============================================================================
# Generic fallback for unhandled tool types
# ============================================================================

function Bonito.jsrender(session::Session, execution::ToolExecution{T}) where T <: AbstractTool
    tool = execution.tool
    result = execution.result
    tool_type = typeof(tool)
    tool_name = string(nameof(tool_type))
    args_display = "unknown"

    # Check for error
    error_msg = get_error(execution)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Generic result display
    result_json = JSON3.pretty(result.result)
    result_preview = DOM.pre(result_json, class="tool-output")

    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        class="tool-header"
    )

    return Bonito.jsrender(session, DOM.div(header, result_preview, class="tool-container"))
end

# ============================================================================
# Summarized Tool Execution Rendering
# ============================================================================

"""
    Bonito.jsrender(session::Session, execution::SummarizedToolExecution{T}) where T

Renders a summarized tool execution with toggle to view full result.
"""
function Bonito.jsrender(session::Session, execution::SummarizedToolExecution{T}) where T <: AbstractTool
    tool = execution.tool
    tool_type_name = Base.invokelatest(tool_name, typeof(tool))

    # Get args display (call the specific tool's jsrender logic would be complex,
    # so for now we'll just show the type)
    args_display = "summarized"

    # Create status badge
    size_display = format_bytes(execution.result_size)
    status_badge = DOM.span(
        "📊 Summary ($(size_display))",
        class="tool-summary-badge"
    )

    # Header with summary badge
    header = DOM.div(
        DOM.span(tool_type_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        status_badge,
        class="tool-header"
    )

    # Summary content
    summary_content = DOM.pre(execution.result_summary, class="tool-output tool-summary-content")

    # Toggle button and full content container
    is_expanded = Observable(false)
    full_content = Observable{Any}(DOM.div(""))  # Will be populated on expand

    toggle_button = DOM.button(
        map(is_expanded) do expanded
            expanded ? "Hide Full Result ▲" : "Show Full Result ▼"
        end,
        class="tool-summary-toggle"
    )

    full_container = DOM.div(
        map(is_expanded) do expanded
            if expanded
                # Load the full result from the JSON file
                tools_dir = joinpath(dirname(dirname(dirname(@__FILE__))), "data", "tools")
                json_file = joinpath(tools_dir, "$(tool_type_name)-$(execution.cell_id).json")

                if isfile(json_file)
                    try
                        full_exec = open(io -> JSON3.read(io, ToolExecution{T}), json_file)
                        result_str = string(full_exec.result.result)
                        return DOM.pre(result_str, class="tool-output tool-full-content")
                    catch e
                        return DOM.div("Error loading full result: $(e)", class="tool-error")
                    end
                else
                    return DOM.div("Full result file not found", class="tool-error")
                end
            else
                return DOM.div("")
            end
        end,
        class="tool-full-container"
    )

    # JavaScript for toggle button
    toggle_script = js"""
        const btn = $(toggle_button);
        btn.addEventListener('click', () => {
            $(is_expanded).notify(!$(is_expanded).value);
        });
    """

    container = DOM.div(
        header,
        summary_content,
        DOM.div(toggle_button, class="tool-summary-toggle-container"),
        full_container,
        toggle_script,
        class="tool-container tool-summarized-container"
    )

    return Bonito.jsrender(session, container)
end
