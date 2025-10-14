using Bonito

"""
Custom rendering for LLM Chat tools using CSS classes from ChatStyles.
"""

# ============================================================================
# Helper Functions
# ============================================================================

"""
    get_error(tool::AbstractTool)

Returns the error message if the tool result contains an error, otherwise returns nothing.
"""
function get_error(tool::AbstractTool)
    if isnothing(tool.result)
        return nothing
    end
    if tool.result isa Dict && haskey(tool.result, "error")
        return tool.result["error"]
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

# ============================================================================
# BashTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::BashTool)
    tool_name = "bash"
    args_display = tool.command

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Output is the result string
    output = tool.result
    lines = split(output, '\n')

    # Header with info
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.code(args_display, class="tool-args"),
        DOM.span("$(length(lines)) lines", class="tool-info"),
        class="tool-header"
    )

    # Detailed output
    output_content = DOM.pre(output, class="tool-output")

    # Use collapsible for long output
    result_display = if length(lines) > 3
        BonitoBook.Collapsible("Output", output_content; expanded=false)
    else
        output_content
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileReadTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileReadTool)
    tool_name = "file_read"
    args_display = tool.path

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Content is the result string
    content = tool.result
    lines = split(content, '\n')

    # Header with info
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.code(args_display, class="tool-args"),
        DOM.span("$(length(content)) bytes, $(length(lines)) lines", class="tool-info"),
        class="tool-header"
    )

    # Detailed content
    content_preview = DOM.pre(content, class="tool-output")

    # Use collapsible for file contents
    result_display = BonitoBook.Collapsible(
        "Content",
        content_preview;
        expanded=length(lines) <= 3
    )

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileWriteTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileWriteTool)
    tool_name = "file_write"
    args_display = tool.path

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Result is the number of bytes written
    bytes_written = tool.result

    # Header with info
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.code(args_display, class="tool-args"),
        DOM.span("$(bytes_written) bytes written", class="tool-info"),
        class="tool-header"
    )

    return Bonito.jsrender(session, DOM.div(header, class="tool-container"))
end

# ============================================================================
# FileEditTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileEditTool)
    tool_name = "file_edit"
    args_display = tool.path
    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
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

    # Header
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.code(args_display, class="tool-args"),
        DOM.span("edited", class="tool-info"),
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

    # Use collapsible for the diff view
    diff_display = BonitoBook.Collapsible(
        "Changes",
        diff_editor;
        expanded=true
    )

    return Bonito.jsrender(session, DOM.div(header, diff_display, class="tool-container"))
end

# ============================================================================
# HttpGetTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::HttpGetTool)
    tool_name = "http_get"
    args_display = tool.url

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Result is a dict with status and content
    status = tool.result["status"]
    content = tool.result["content"]

    # Header with status
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.a(args_display, href=tool.url, target="_blank", class="tool-args"),
        DOM.span("status: $status, $(length(content)) bytes", class="tool-info"),
        class="tool-header"
    )

    # Content preview
    content_preview = DOM.pre(content, class="tool-output")

    result_display = BonitoBook.Collapsible(
        "Response",
        content_preview;
        expanded=false
    )

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# AddCellTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::AddCellTool)
    tool_name = "add_cell"
    args_display = "$(tool.language)"

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    lines = split(tool.content, '\n')

    # Header
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        DOM.span("$(length(lines)) lines", class="tool-info"),
        class="tool-header"
    )

    # Show preview of content
    content_preview = DOM.pre(tool.content, class="tool-output")
    result_display = if length(lines) > 3
        BonitoBook.Collapsible("Content", content_preview; expanded=false)
    else
        content_preview
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileTool)
    tool_name = "file_tool"
    args_preview = join(["$(k)=$(v)" for (k,v) in tool.arguments], ", ")
    args_display = "$(tool.command) $(args_preview)"

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Result data
    result_data = tool.result

    # Format result based on type
    if result_data isa Vector && !isempty(result_data)
        # List of files/matches
        if result_data[1] isa Dict
            # Detailed readdir output
            items = [
                DOM.div(
                    DOM.span(get(item, "type", "unknown") == "directory" ? "[D]" : "[F]", class="file-type"),
                    DOM.span(get(item, "name", ""), class="file-name"),
                    DOM.span("($(get(item, "size", 0)) bytes)", class="file-size"),
                    class="file-item"
                )
                for item in result_data[1:min(50, length(result_data))]
            ]
            if length(result_data) > 50
                push!(items, DOM.div("... and $(length(result_data) - 50) more", class="file-more"))
            end
            list_content = DOM.div(items..., class="file-list")
        else
            # Simple list of paths
            items = [DOM.div(item, class="file-item") for item in result_data[1:min(50, length(result_data))]]
            if length(result_data) > 50
                push!(items, DOM.div("... and $(length(result_data) - 50) more", class="file-more"))
            end
            list_content = DOM.div(items..., class="file-list")
        end

        # Header
        header = DOM.div(
            DOM.span(tool_name, class="tool-name"),
            DOM.code(args_display, class="tool-args"),
            DOM.span("$(length(result_data)) items", class="tool-info"),
            class="tool-header"
        )

        result_display = if length(result_data) > 3
            BonitoBook.Collapsible("Results", list_content; expanded=false)
        else
            list_content
        end
    elseif result_data isa String || result_data === nothing
        # Single result string or nothing
        info_text = isnothing(result_data) ? "done" : result_data
        header = DOM.div(
            DOM.span(tool_name, class="tool-name"),
            DOM.code(args_display, class="tool-args"),
            DOM.span(info_text, class="tool-info"),
            class="tool-header"
        )
        result_display = DOM.div()
    else
        # Other result types
        header = DOM.div(
            DOM.span(tool_name, class="tool-name"),
            DOM.code(args_display, class="tool-args"),
            class="tool-header"
        )
        result_display = DOM.pre(repr(result_data), class="tool-output")
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# TodoList Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::TodoList)
    tool_name = "todo_list"
    # Create checklist items with status
    checklist_items = [
        DOM.div(
            DOM.span(tool.status[i] ? "[✓]" : "[ ]", class="todo-checkbox"),
            DOM.span(item, class="todo-text"),
            class="todo-item"
        )
        for (i, item) in enumerate(tool.items)
    ]

    # Header
    completed = count(tool.status)
    total = length(tool.items)
    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(tool.title, class="tool-args"),
        DOM.span("$completed/$total", class="tool-info"),
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

function Bonito.jsrender(session::Session, tool::AbstractTool)
    tool_type = typeof(tool)
    tool_name = string(nameof(tool_type))
    args_display = "unknown"

    if isnothing(tool.result)
        return Bonito.jsrender(session, render_executing(tool_name, args_display))
    end

    # Check for error
    error_msg = get_error(tool)
    if !isnothing(error_msg)
        return Bonito.jsrender(session, render_error(tool_name, args_display, error_msg))
    end

    # Generic result display
    result_json = JSON3.pretty(tool.result)
    result_preview = DOM.pre(result_json, class="tool-output")

    header = DOM.div(
        DOM.span(tool_name, class="tool-name"),
        DOM.span(args_display, class="tool-args"),
        class="tool-header"
    )

    return Bonito.jsrender(session, DOM.div(header, result_preview, class="tool-container"))
end
