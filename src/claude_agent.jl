using Bonito
using Markdown
using TOML

using ClaudeCodeSDK

"""
    ClaudeAgent <: ChatAgent

A chat agent that uses Claude via the locally installed Claude Code CLI.
Requires claude-code CLI to be installed and configured.

# Fields
- `book::Book`: The book object this agent is associated with
- `options::ClaudeCodeOptions`: Configuration options for Claude Code CLI
"""
mutable struct ClaudeAgent <: ChatAgent
    book::Book
    options::ClaudeCodeOptions
end

"""
    ClaudeAgent(book::Book; config::Dict = Dict())

Create a new Claude agent using the local Claude Code CLI.

# Arguments
- `book`: The Book object this agent is associated with
- `config`: Optional configuration dictionary to override defaults
"""
function ClaudeAgent(book::Book; config::Dict = Dict())
    folder = book.folder

    # Load configuration from TOML file if it exists
    config_path = joinpath(folder, "ai", "config.toml")
    system_prompt_path = joinpath(folder, "ai", "system-prompt.md")

    # Load TOML config if it exists
    toml_config = Dict()
    if isfile(config_path)
        try
            toml_data = TOML.parsefile(config_path)
            # Flatten the nested structure
            for (_, section_data) in toml_data
                if isa(section_data, Dict)
                    for (key, value) in section_data
                        toml_config[key] = value
                    end
                end
            end
        catch e
            @warn "Failed to load TOML config from $config_path: $e"
        end
    end

    # Load system prompt if it exists
    system_prompt = ""
    if isfile(system_prompt_path)
        try
            system_prompt = read(system_prompt_path, String)
        catch e
            @warn "Failed to load system prompt from $system_prompt_path: $e"
        end
    end

    # Create default options
    default_options = ClaudeCodeOptions(
        allowed_tools = ["Read", "Write", "Bash", "Glob", "Grep", "Edit", "mcp__julia-server__julia_exec"],
        mcp_tools = ["mcp__julia-server__julia_exec"],
        max_thinking_tokens=8000,
        system_prompt=system_prompt,
        append_system_prompt=nothing,
        permission_mode="acceptEdits",
        continue_conversation=true,
        max_turns=20,
        disallowed_tools=String[],
        model="claude-sonnet-4-20250514",
        permission_prompt_tool_name=nothing,
        cwd=folder,
    )

    # Override with TOML config, then with passed config
    options = update_options(default_options, toml_config)
    options = update_options(options, config)

    return ClaudeAgent(book, options)
end


"""
    update_options(options::ClaudeCodeOptions, config::Dict)

Update ClaudeCodeOptions with values from config dict.
"""
function update_options(options::ClaudeCodeOptions, config::Dict)
    field_names = fieldnames(ClaudeCodeOptions)
    updated_values = Dict{Symbol, Any}()
    for field_name in field_names
        updated_values[field_name] = getfield(options, field_name)
    end

    for (key, value) in config
        sym_key = Symbol(key)
        if sym_key in field_names
            updated_values[sym_key] = value
        end
    end

    return ClaudeCodeOptions(; updated_values...)
end

"""
    update_option!(agent::ClaudeAgent, field::Symbol, value)

Update a single option field in the agent's configuration.
"""
function update_option!(agent::ClaudeAgent, field::Symbol, value)
    agent.options = update_options(agent.options, Dict(string(field) => value))
end

"""
    get_option(agent::ClaudeAgent, field::Symbol)

Get the value of a specific option field.
"""
function get_option(agent::ClaudeAgent, field::Symbol)
    return getfield(agent.options, field)
end

"""
    save_config_to_toml(agent::ClaudeAgent)

Save current agent configuration to TOML file.
"""
function save_config_to_toml(agent::ClaudeAgent)
    config_path = joinpath(agent.book.folder, "ai", "config.toml")

    # Create directory if it doesn't exist
    mkpath(dirname(config_path))

    # Build TOML structure, excluding nothing values
    toml_data = Dict{String, Any}()

    # Agent section
    agent_section = Dict{String, Any}(
        "model" => get_option(agent, :model),
        "max_thinking_tokens" => get_option(agent, :max_thinking_tokens),
        "max_turns" => get_option(agent, :max_turns),
        "permission_mode" => get_option(agent, :permission_mode),
        "continue_conversation" => get_option(agent, :continue_conversation)
    )
    toml_data["agent"] = agent_section

    # Tools section
    tools_section = Dict{String, Any}(
        "allowed_tools" => get_option(agent, :allowed_tools),
        "mcp_tools" => get_option(agent, :mcp_tools),
        "disallowed_tools" => get_option(agent, :disallowed_tools)
    )
    toml_data["tools"] = tools_section

    # Advanced section - only include non-nothing values
    advanced_section = Dict{String, Any}()
    append_system_prompt = get_option(agent, :append_system_prompt)
    permission_prompt_tool_name = get_option(agent, :permission_prompt_tool_name)

    if append_system_prompt !== nothing
        advanced_section["append_system_prompt"] = append_system_prompt
    end
    if permission_prompt_tool_name !== nothing
        advanced_section["permission_prompt_tool_name"] = permission_prompt_tool_name
    end

    # Only add advanced section if it has content
    if !isempty(advanced_section)
        toml_data["advanced"] = advanced_section
    end

    # Write to file
    try
        open(config_path, "w") do io
            TOML.print(io, toml_data)
        end
        @info "Configuration saved to $config_path"
    catch e
        @error "Failed to save configuration to $config_path: $e"
    end
end

function Bonito.jsrender(session::Session, msg::SystemMessage)
    return Bonito.jsrender(session, Collapsible("System", string(msg), expanded=false))
end

function Bonito.jsrender(session::Session, value::AssistantMessage)
    return Bonito.jsrender(session, DOM.div(value.content...))
end

function Bonito.jsrender(session::Session, value::ToolUseBlock)
    rendered = if value.name == "TodoWrite"
        render_todowrite_preview(value)
    elseif value.name == "mcp__julia-server__julia_exec"
        render_julia_exec_preview(value)
    else
        # Default fallback for other tools
        JSON.json(value.input)
    end
    return Bonito.jsrender(session, Collapsible("Tool Use: $(value.name)", rendered, expanded=false))
end

function render_todowrite_preview(tool_use::ToolUseBlock)
    input = tool_use.input
    todos = input["todos"]
    # Create a nice preview of the todos
    todo_items = []
    for todo in todos
        if isa(todo, Dict) && haskey(todo, "content") && haskey(todo, "status")
            status = todo["status"]
            content = todo["content"]
            priority = get(todo, "priority", "medium")

            # Choose icon based on status
            status_icon = if status == "completed"
                "✅"
            elseif status == "in_progress"
                "🔄"
            else
                "⏳"
            end

            # Priority indicator
            priority_color = if priority == "high"
                "color: #ff6b6b;"
            elseif priority == "low"
                "color: #95a5a6;"
            else
                "color: var(--text-primary);"
            end

            todo_item = DOM.div(
                DOM.span(status_icon, style="margin-right: 8px;"),
                DOM.span(content, style="$priority_color font-size: 13px;"),
                DOM.span(" ($priority)", style="font-size: 11px; color: var(--text-secondary); margin-left: 8px;"),
                style="margin-bottom: 6px; padding: 4px 8px; border-left: 3px solid var(--border-secondary);"
            )
            push!(todo_items, todo_item)
        end
    end

    preview_content = DOM.div(
        DOM.div("📝 Todo List Update", style="font-weight: 500; margin-bottom: 8px; color: var(--text-primary);"),
        DOM.div(todo_items..., style="margin-left: 12px;"),
        style="font-family: inherit;"
    )

    return preview_content
end

function render_julia_exec_preview(tool_use::ToolUseBlock)
    input = tool_use.input
    if haskey(input, "code")
        code = input["code"]
        # Create a nice code preview
        code_preview = DOM.div(
            DOM.div("💻 Julia Code Execution", style="font-weight: 500; margin-bottom: 8px; color: var(--text-primary);"),
            DOM.pre(
                code,
                style="background-color: var(--hover-bg); padding: 12px; border-radius: 6px; font-family: 'Fira Code', 'SF Mono', Consolas, monospace; font-size: 12px; line-height: 1.4; color: var(--text-primary); overflow-x: auto; border-left: 3px solid var(--accent-blue); margin: 0;"
            ),
            style="font-family: inherit;"
        )
        return code_preview
    end
    return Collapsible("Julia Exec Tool Use", JSON.json(input), expanded=false)
end

function Bonito.jsrender(session::Session, value::TextBlock)
    text = replace(value.text, r"```markdown\s*\n(.*?)\n```"s => s"\1")
    return Bonito.jsrender(session, Markdown.parse(text))
end

function Bonito.jsrender(session::Session, value::ResultMessage)
    return Bonito.jsrender(session, Collapsible("Result", string(value), expanded=false))
end


"""
    prompt(agent::ClaudeAgent, question::String; stream_callback=nothing, mcp_server_url=nothing)

Send a prompt to Claude and return the response.
If stream_callback is provided, uses streaming mode and calls the callback with each text chunk.
If mcp_server_url is provided, configures Claude to use the Julia execution MCP server.
"""
function prompt(agent::ClaudeAgent, question::String)
    # Update dynamic options based on current agent state
    # Ensure cwd is set to the book's folder
    updated_options = update_options(agent.options, Dict("cwd" => agent.book.folder))
    return query_stream(prompt=question, options=updated_options)
end

# MCP server integration will be configured externally via Claude Code CLI

"""
    settings_menu(agent::ClaudeAgent)

Returns a Bonito widget for configuring ClaudeAgent settings.
Provides user-friendly controls for model selection, thinking tokens, etc.
"""
function settings_menu(agent::ClaudeAgent)
    # Model selection mapping (user-friendly name -> actual model ID)
    model_options = ["Claude Sonnet", "Claude Opus", "Claude Haiku"]
    model_ids = Dict(
        "Claude Sonnet" => "claude-sonnet-4-20250514",
        "Claude Opus" => "claude-opus-4-20250514",
        "Claude Haiku" => "claude-haiku-4-20250514"
    )

    # Get current model and map to friendly name
    current_model = get_option(agent, :model)
    current_friendly = findfirst(==(current_model), model_ids)
    current_friendly = current_friendly !== nothing ? current_friendly : "Claude Sonnet"
    current_index = findfirst(==(current_friendly), model_options)
    current_index = current_index !== nothing ? current_index : 1

    # Create widgets using custom Components
    model_dropdown = Components.Dropdown(model_options; index=current_index)

    thinking_tokens_input = Components.NumberInput(Float64(get_option(agent, :max_thinking_tokens)))

    max_turns_input = Components.NumberInput(Float64(get_option(agent, :max_turns)))

    permission_options = ["acceptEdits", "prompt", "deny"]
    permission_labels = ["Accept Edits", "Prompt for Permission", "Deny All"]
    current_permission = get_option(agent, :permission_mode)
    permission_index = findfirst(==(current_permission), permission_options)
    permission_index = permission_index !== nothing ? permission_index : 1
    permission_dropdown = Components.Dropdown(permission_labels; index=permission_index)

    # Continue conversation toggle
    continue_toggle = @D Observable(get_option(agent, :continue_conversation))
    continue_checkbox = Components.Checkbox(continue_toggle[])

    # Tools configuration
    # Define all available tools
    all_available_tools = [
        "Read", "Write", "Edit", "MultiEdit", "Bash", "Glob", "Grep", "LS",
        "Task", "exit_plan_mode", "WebFetch", "TodoWrite", "WebSearch",
        "NotebookRead", "NotebookEdit", "mcp__ide__getDiagnostics",
        "mcp__ide__executeCode", "mcp__julia-server__julia_exec"
    ]

    current_allowed_tools = get_option(agent, :allowed_tools)

    # Create observables and checkboxes for each tool
    tool_states = Dict{String, Observable{Bool}}()
    tool_checkboxes = Dict{String, Any}()

    for tool in all_available_tools
        is_enabled = tool in current_allowed_tools
        tool_states[tool] = @D Observable(is_enabled)
        tool_checkboxes[tool] = Components.Checkbox(is_enabled)
    end

    # Create settings rows with left-aligned labels
    model_section = DOM.div(
        DOM.div("Model:", class="settings-label"),
        DOM.div(model_dropdown, class="settings-input"),
        class="settings-row"
    )

    thinking_tokens_section = DOM.div(
        DOM.div("Max Thinking Tokens:", class="settings-label"),
        DOM.div(thinking_tokens_input, class="settings-input"),
        class="settings-row"
    )

    max_turns_section = DOM.div(
        DOM.div("Max Turns:", class="settings-label"),
        DOM.div(max_turns_input, class="settings-input"),
        class="settings-row"
    )

    permission_section = DOM.div(
        DOM.div("Permission Mode:", class="settings-label"),
        DOM.div(permission_dropdown, class="settings-input"),
        class="settings-row"
    )

    continue_section = DOM.div(
        DOM.div("Continue Conversation:", class="settings-label"),
        DOM.div(continue_checkbox, class="settings-input"),
        class="settings-row"
    )

    # Create tools section
    tools_list = []
    for tool in all_available_tools
        tool_row = DOM.div(
            tool_checkboxes[tool],
            DOM.span(tool, style="margin-left: 8px; font-size: 13px;"),
            class="tool-item"
        )
        push!(tools_list, tool_row)
    end

    tools_content = DOM.div(
        tools_list...,
        class="tools-list"
    )

    tools_section = Collapsible("Allowed Tools", tools_content, expanded=false)

    # Edit system prompt button
    edit_prompt_button, edit_prompt_clicks = SmallButton("edit")
    edit_prompt_section = DOM.div(
        DOM.div("System Prompt:", class="settings-label"),
        DOM.div(edit_prompt_button, class="settings-input"),
        class="settings-row"
    )

    # Apply button
    apply_button, apply_clicks = SmallButton("check")
    apply_section = DOM.div(
        DOM.span("Apply Settings"),
        apply_button,
        class="settings-apply-section"
    )

    # Main settings card
    settings_card = DOM.div(
        SettingsStyles,
        DOM.div(
            DOM.h3("Claude Agent Settings", class="settings-title"),
            model_section,
            thinking_tokens_section,
            max_turns_section,
            permission_section,
            continue_section,
            tools_section,
            edit_prompt_section,
            apply_section
        ),
        class="settings-container"
    )

    # Set up event handlers
    on(model_dropdown.value) do selected_friendly
        selected_model = model_ids[selected_friendly]
        update_option!(agent, :model, selected_model)
        save_config_to_toml(agent)
    end

    on(thinking_tokens_input.value) do new_value
        if new_value > 0
            update_option!(agent, :max_thinking_tokens, Int(new_value))
            save_config_to_toml(agent)
        end
    end

    on(max_turns_input.value) do new_value
        if new_value > 0
            update_option!(agent, :max_turns, Int(new_value))
            save_config_to_toml(agent)
        end
    end

    on(permission_dropdown.value) do selected_label
        permission_index = findfirst(==(selected_label), permission_labels)
        if permission_index !== nothing
            selected_permission = permission_options[permission_index]
            update_option!(agent, :permission_mode, selected_permission)
            save_config_to_toml(agent)
        end
    end

    on(continue_checkbox.value) do enabled
        update_option!(agent, :continue_conversation, enabled)
        save_config_to_toml(agent)
    end

    # Set up tool checkbox event handlers
    function update_allowed_tools()
        enabled_tools = String[]
        for tool in all_available_tools
            if tool_checkboxes[tool].value[]
                push!(enabled_tools, tool)
            end
        end
        update_option!(agent, :allowed_tools, enabled_tools)
        save_config_to_toml(agent)
    end

    for tool in all_available_tools
        on(tool_checkboxes[tool].value) do _
            update_allowed_tools()
        end
    end

    on(apply_clicks) do _
        save_config_to_toml(agent)
        @info "Claude Agent settings applied successfully!"
    end

    # Handle edit system prompt button
    on(edit_prompt_clicks) do _
        system_prompt_path = joinpath(agent.book.folder, "ai", "system-prompt.md")
        open_file!(get_file_editor(agent.book), system_prompt_path)
        @info "Opened system prompt in file editor: $system_prompt_path"
    end

    return settings_card
end

# Settings-specific styles
const SettingsStyles = Styles(
    CSS(
        ".settings-container",
        "max-width" => "500px",
        "margin" => "0 auto"
    ),
    CSS(
        ".settings-title",
        "margin-top" => "0",
        "color" => "var(--text-primary)",
        "text-align" => "center",
        "font-size" => "18px",
        "margin-bottom" => "20px"
    ),
    CSS(
        ".settings-row",
        "display" => "flex",
        "align-items" => "center",
        "margin-bottom" => "16px",
        "gap" => "12px"
    ),
    CSS(
        ".settings-label",
        "font-size" => "13px",
        "color" => "var(--text-secondary)",
        "min-width" => "140px",
        "text-align" => "left",
        "flex-shrink" => "0"
    ),
    CSS(
        ".settings-input",
        "flex" => "1",
        "min-width" => "0"
    ),
    CSS(
        ".settings-apply-section",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "margin-top" => "20px",
        "gap" => "8px"
    ),
    CSS(
        ".tools-list",
        "display" => "flex",
        "flex-direction" => "column",
        "gap" => "8px",
        "padding" => "12px",
        "max-height" => "300px",
        "overflow-y" => "auto"
    ),
    CSS(
        ".tool-item",
        "display" => "flex",
        "align-items" => "center",
        "padding" => "4px 8px",
        "border-radius" => "4px",
        "transition" => "background-color 0.2s ease"
    ),
    CSS(
        ".tool-item:hover",
        "background-color" => "var(--hover-bg)"
    )
)

# Export the agent and helper functions
export ClaudeAgent, update_option!, get_option, update_options, save_config_to_toml
