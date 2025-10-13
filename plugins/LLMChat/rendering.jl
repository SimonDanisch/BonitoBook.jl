using Bonito

"""
Custom rendering for LLM Chat tools using CSS classes from ChatStyles.
"""

# ============================================================================
# BashTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::BashTool)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "💻 bash: $(tool.command)",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)
    output = get(tool.result, "output", "")

    # Command header
    header = DOM.div(
        DOM.span("💻", class="tool-icon"),
        DOM.code(tool.command, class="tool-command"),
        class="tool-header"
    )

    # Output content
    output_class = success ? "tool-output tool-output-success" : "tool-output tool-output-error"
    output_content = DOM.pre(output, class=output_class)

    # Use collapsible if output is long
    result_display = if length(output) > 200
        BonitoBook.Collapsible("Output ($(length(output)) bytes)", output_content; expanded=false)
    else
        output_content
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileReadTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileReadTool)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "📖 Reading: $(tool.path)",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)
    path = get(tool.result, "path", tool.path)

    # Header with path
    header = DOM.div(
        DOM.span("📖", class="tool-icon"),
        DOM.code(path, class="tool-path"),
        class="tool-header"
    )

    if !success
        error_msg = get(tool.result, "error", "Unknown error")
        return Bonito.jsrender(session, DOM.div(
            header,
            DOM.div(error_msg, class="tool-error"),
            class="tool-container"
        ))
    end

    content = get(tool.result, "content", "")

    # Content preview
    content_preview = DOM.pre(content, class="tool-output tool-output-success")

    # Always use collapsible for file contents
    result_display = BonitoBook.Collapsible(
        "Content ($(length(content)) bytes, $(length(split(content, '\n'))) lines)",
        content_preview;
        expanded=length(content) < 500
    )

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileWriteTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileWriteTool)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "✏️ Writing to: $(tool.path)",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)
    path = get(tool.result, "path", tool.path)

    header = DOM.div(
        DOM.span("✏️", class="tool-icon"),
        DOM.code(path, class="tool-path"),
        class="tool-header"
    )

    if !success
        error_msg = get(tool.result, "error", "Unknown error")
        return Bonito.jsrender(session, DOM.div(
            header,
            DOM.div(error_msg, class="tool-error"),
            class="tool-container"
        ))
    end

    bytes = get(tool.result, "bytes_written", 0)
    info = DOM.div("✓ Written $(bytes) bytes", class="tool-info")

    return Bonito.jsrender(session, DOM.div(header, info, class="tool-container"))
end

# ============================================================================
# FileEditTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileEditTool)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "📝 Editing: $(tool.path)",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)
    path = get(tool.result, "path", tool.path)

    header = DOM.div(
        DOM.span("📝", class="tool-icon"),
        DOM.code(path, class="tool-path"),
        class="tool-header"
    )

    if !success
        error_msg = get(tool.result, "error", "Unknown error")
        return Bonito.jsrender(session, DOM.div(
            header,
            DOM.div(error_msg, class="tool-error"),
            class="tool-container"
        ))
    end

    # Detect language from file extension
    ext = lowercase(splitext(path)[2])
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

    # Create diff editor showing the changes
    diff_editor = BonitoBook.DiffEditor(
        tool.old_text,
        tool.new_text;
        language=language,
        renderSideBySide=false,  # Inline diff view
        readOnly=true
    )

    info = DOM.div("✓ File edited successfully", class="tool-info")
    
    # Use collapsible for the diff view
    diff_display = BonitoBook.Collapsible(
        "Show changes",
        diff_editor;
        expanded=true
    )

    return Bonito.jsrender(session, DOM.div(header, info, diff_display, class="tool-container"))
end

# ============================================================================
# HttpGetTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::HttpGetTool)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "🌐 Fetching: $(tool.url)",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)
    url = get(tool.result, "url", tool.url)

    header = DOM.div(
        DOM.span("🌐", class="tool-icon"),
        DOM.a(url, href=url, target="_blank", class="tool-url"),
        class="tool-header"
    )

    if !success
        error_msg = get(tool.result, "error", "Unknown error")
        return Bonito.jsrender(session, DOM.div(
            header,
            DOM.div(error_msg, class="tool-error"),
            class="tool-container"
        ))
    end

    status = get(tool.result, "status", 0)
    content = get(tool.result, "content", "")

    status_display = DOM.div("Status: $status", class="tool-status")
    content_preview = DOM.pre(content, class="tool-output tool-output-success")

    result_display = BonitoBook.Collapsible(
        "Response ($(length(content)) bytes)",
        content_preview;
        expanded=false
    )

    return Bonito.jsrender(session, DOM.div(header, status_display, result_display, class="tool-container"))
end

# ============================================================================
# AddCellTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::AddCellTool)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "➕ Adding cell: $(tool.language)",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)

    if !success
        error_msg = get(tool.result, "error", "Unknown error")
        return Bonito.jsrender(session, DOM.div(
            DOM.div(
                DOM.span("➕", class="tool-icon"),
                DOM.span("Add Cell", class="tool-header"),
                class="tool-header"
            ),
            DOM.div(error_msg, class="tool-error"),
            class="tool-container"
        ))
    end

    language = get(tool.result, "language", tool.language)
    content = get(tool.result, "content", tool.content)

    header = DOM.div(
        DOM.span("➕", class="tool-icon"),
        DOM.span("Added $(language) cell", class="tool-path"),
        class="tool-header"
    )

    # Show preview of content
    content_preview = DOM.pre(content, class="tool-output tool-output-success")
    result_display = if length(content) > 200
        BonitoBook.Collapsible("Cell content ($(length(content)) chars)", content_preview; expanded=false)
    else
        content_preview
    end

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# FileTool Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::FileTool)
    if isnothing(tool.result)
        args_preview = join(["$(k)=$(v)" for (k,v) in tool.arguments], ", ")
        return Bonito.jsrender(session, DOM.div(
            "📁 $(tool.command) $args_preview",
            class="tool-executing"
        ))
    end

    success = get(tool.result, "success", false)
    command = get(tool.result, "command", tool.command)

    if !success
        error_msg = get(tool.result, "error", "Unknown error")
        return Bonito.jsrender(session, DOM.div(
            DOM.div(
                DOM.span("📁"),
                DOM.span("file_tool: $command", class="tool-name"),
                DOM.span("❌", class="tool-status tool-error"),
                class="tool-header tool-error-header"
            ),
            DOM.div(error_msg, class="tool-error-message"),
            class="tool-container tool-error-container"
        ))
    end

    result_data = get(tool.result, "result", nothing)

    # Format result based on command
    result_display = if result_data isa Vector && !isempty(result_data)
        # List of files/matches
        if result_data[1] isa Dict
            # Detailed readdir output
            items = [
                DOM.div(
                    DOM.span(get(item, "type", "unknown") == "directory" ? "📁" : "📄"),
                    DOM.span(get(item, "name", ""), class="file-name"),
                    DOM.span("($(get(item, "size", 0)) bytes)", class="file-size"),
                    class="file-item"
                )
                for item in result_data[1:min(50, length(result_data))]
            ]
            if length(result_data) > 50
                push!(items, DOM.div("... and $(length(result_data) - 50) more", class="file-more"))
            end
            DOM.div(items..., class="file-list")
        else
            # Simple list of paths
            items = [DOM.div("  $item", class="file-item") for item in result_data[1:min(50, length(result_data))]]
            if length(result_data) > 50
                push!(items, DOM.div("... and $(length(result_data) - 50) more", class="file-more"))
            end
            DOM.div(items..., class="file-list")
        end
    elseif result_data isa String
        # Single result string
        DOM.div(result_data, class="file-result")
    else
        # Other result types
        DOM.div(repr(result_data), class="file-result")
    end

    header = DOM.div(
        DOM.span("📁"),
        DOM.span("file_tool: $command", class="tool-name"),
        DOM.span("✓", class="tool-status tool-success"),
        class="tool-header tool-success-header"
    )

    return Bonito.jsrender(session, DOM.div(header, result_display, class="tool-container"))
end

# ============================================================================
# TodoList Rendering
# ============================================================================

function Bonito.jsrender(session::Session, tool::TodoList)
    if isnothing(tool.result)
        return Bonito.jsrender(session, DOM.div(
            "📋 Creating TODO: $(tool.title)",
            class="tool-executing"
        ))
    end

    title = get(tool.result, "title", tool.title)
    items = get(tool.result, "items", tool.items)

    # Create checklist items
    checklist_items = [
        DOM.div(
            DOM.span("☐", class="todo-checkbox"),
            DOM.span(item, class="todo-text"),
            class="todo-item"
        )
        for item in items
    ]

    return Bonito.jsrender(session, DOM.div(
        DOM.div(
            DOM.span("📋"),
            DOM.span(title),
            class="todo-title"
        ),
        DOM.div(checklist_items..., class="todo-items"),
        class="todo-container"
    ))
end

# ============================================================================
# Generic fallback for unhandled tool types
# ============================================================================

function Bonito.jsrender(session::Session, tool::AbstractTool)
    if isnothing(tool.result)
        tool_type = typeof(tool)
        return Bonito.jsrender(session, DOM.div(
            "🔧 $(nameof(tool_type)) executing...",
            class="tool-executing"
        ))
    end

    # Generic result display
    result_json = JSON3.pretty(tool.result)
    result_preview = DOM.pre(result_json, class="tool-output")

    tool_type = typeof(tool)
    header = DOM.div(
        DOM.span("🔧", class="tool-icon"),
        DOM.span(nameof(tool_type)),
        class="tool-header"
    )

    return Bonito.jsrender(session, DOM.div(header, result_preview, class="tool-container"))
end
