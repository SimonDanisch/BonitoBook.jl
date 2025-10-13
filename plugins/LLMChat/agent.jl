using TOML
using Bonito

"""
    LLMChatAgent

Abstract type for LLM chat agents. All LLM backends must implement this interface.

Required methods:
- `stream_response(agent::LLMChatAgent, messages::Vector, tools::Vector)::Channel`
  Returns a Channel that yields renderable content (DOM elements, strings, tool calls, etc.)
"""
abstract type LLMChatAgent end

"""
    AgentMessage

Represents a message in the conversation history.

# Fields
- `role::Symbol`: Message role (:user, :assistant, :system, :tool_result)
- `content::Any`: Message content (can be text, tool use, tool result, etc.)
- `cell_id::Union{Nothing, Int}`: Associated cell ID if applicable
"""
struct AgentMessage
    role::Symbol
    content::Any
    cell_id::Union{Nothing, Int}
end

AgentMessage(role::Symbol, content::Any) = AgentMessage(role, content, nothing)

"""
    AgentConfig

Configuration for an LLM chat agent.

# Fields
- `model::String`: Model identifier
- `max_tokens::Int`: Maximum tokens in response
- `temperature::Float64`: Sampling temperature
- `system_prompt::String`: System prompt for the agent
- `tools::Vector{Type{<:AbstractTool}}`: Available tools
- `tool_choice::String`: How to use tools ("auto", "required", "none")
"""
struct AgentConfig
    model::String
    max_tokens::Int
    temperature::Float64
    system_prompt::String
    tools::Vector{Type{<:AbstractTool}}
    tool_choice::String
end

"""
    load_agent_config(folder::String)

Load agent configuration from TOML file or create default.
"""
function load_agent_config(folder::String)
    config_path = joinpath(folder, "ai", "llm-config.toml")

    # Default configuration
    default_config = AgentConfig(
        "claude-sonnet-4-20250514",
        4096,
        0.7,
        "You are a helpful AI assistant integrated into a Julia notebook. You can execute code, read/write files, and help with programming tasks.",
        DEFAULT_TOOLS,
        "auto"
    )

    if !isfile(config_path)
        # Create default config file
        save_agent_config(folder, default_config)
        return default_config
    end

    # Load from TOML
    try
        toml_data = TOML.parsefile(config_path)

        model = get(toml_data, "model", default_config.model)
        max_tokens = get(toml_data, "max_tokens", default_config.max_tokens)
        temperature = get(toml_data, "temperature", default_config.temperature)
        tool_choice = get(toml_data, "tool_choice", default_config.tool_choice)

        # Load system prompt from separate file if it exists
        system_prompt_path = joinpath(folder, "ai", "llm-system-prompt.md")
        system_prompt = if isfile(system_prompt_path)
            read(system_prompt_path, String)
        else
            get(toml_data, "system_prompt", default_config.system_prompt)
        end

        # Parse tool names to types
        tool_names = get(toml_data, "tools", String[])
        tools = if isempty(tool_names)
            default_config.tools
        else
            parse_tool_names(tool_names)
        end

        return AgentConfig(
            model,
            max_tokens,
            temperature,
            system_prompt,
            tools,
            tool_choice
        )
    catch e
        @warn "Failed to load agent config, using defaults" exception=(e, catch_backtrace())
        return default_config
    end
end

"""
    save_agent_config(folder::String, config::AgentConfig)

Save agent configuration to TOML file.
"""
function save_agent_config(folder::String, config::AgentConfig)
    config_dir = joinpath(folder, "ai")
    if !isdir(config_dir)
        mkpath(config_dir)
    end

    config_path = joinpath(config_dir, "llm-config.toml")

    toml_data = Dict{String, Any}(
        "model" => config.model,
        "max_tokens" => config.max_tokens,
        "temperature" => config.temperature,
        "tool_choice" => config.tool_choice,
        "tools" => [tool_name(T) for T in config.tools]
    )

    open(config_path, "w") do io
        TOML.print(io, toml_data)
    end

    # Save system prompt to separate file
    system_prompt_path = joinpath(config_dir, "llm-system-prompt.md")
    write(system_prompt_path, config.system_prompt)

    return config_path
end

"""
    parse_tool_names(names::Vector{String})

Convert tool name strings to tool types.
"""
function parse_tool_names(names::Vector{String})
    tool_map = Dict(
        "bash" => BashTool,
        "file_read" => FileReadTool,
        "file_write" => FileWriteTool,
        "file_edit" => FileEditTool,
        "file_tool" => FileTool,
        "http_get" => HttpGetTool,
        "add_cell" => AddCellTool,
        "todo_list" => TodoList
    )

    tools = Type{<:AbstractTool}[]
    for name in names
        if haskey(tool_map, name)
            push!(tools, tool_map[name])
        else
            @warn "Unknown tool: $name"
        end
    end

    return isempty(tools) ? DEFAULT_TOOLS : tools
end

"""
    extract_markdown_content(source::String)

Extract content from Markdown.parse(\"\"\"...\"\"\") wrapper.
Returns the inner content or the original string if not wrapped.
"""
function extract_markdown_content(source::String)
    source = strip(source)

    # Match Markdown.parse("...") - extract content from quotes
    pattern = r"^Markdown\.parse\(\s*\"(.*)\"\s*\)\s*$"s
    m = match(pattern, source)

    if m !== nothing
        return strip(m.captures[1])
    end

    return source
end

"""
    cells_to_messages(cells::Vector{CellEditor})

Convert notebook cells to agent messages.
Smartly extracts content from Markdown.parse wrappers and filters out add_cell tool cells.
"""
function cells_to_messages(cells::Vector)
    messages = AgentMessage[]

    for cell in cells
        role = get(cell.metadata, :from, :user)
        cell_id = get(cell.metadata, :id, nothing)
        tool_type = get(cell.metadata, :tool, nothing)

        # For user/assistant messages, extract content smartly
        if role == :user
            content = cell.editor.source[]
            # Remove Markdown.parse wrapper if present
            content = extract_markdown_content(content)
            push!(messages, AgentMessage(:user, content, cell_id))
        elseif role == :assistant || role == :agent && isnothing(tool_type)
            content = cell.editor.source[]
            # Remove Markdown.parse wrapper if present
            content = extract_markdown_content(content)
            push!(messages, AgentMessage(:assistant, content, cell_id))
        else
            # Tool results: get the executed cell output and use repr
            output = cell.editor.output[]
            content = """
                source:
                $(cell.editor.source[])
                output:
                $(repr(output))
                logging:
                $(cell.editor.logging_html[])
            """
            push!(messages, AgentMessage(:tool_result, content, cell_id))
        end
    end

    return messages
end

"""
    prompt(agent::LLMChatAgent, messages::Vector{AgentMessage}, tools::Vector)

Call the agent once and return a single result.

Returns one of:
- `String`: Text response to add as markdown cell
- `ToolUse`: Tool to execute
- `Dict(:type => :cell, :content => ..., :language => ...)`: Direct cell creation
- `EndLoop`: Signal to stop the agent loop

Default implementation must be overridden by specific agent types.
"""
function prompt(agent::LLMChatAgent, messages::Vector{AgentMessage}, tools::Vector)
    error("prompt must be implemented for $(typeof(agent))")
end

# Agent creation is handled in http_agent.jl
# No fallback logic needed - we always use HTTPAgent
