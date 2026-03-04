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

DEPRECATED: This struct is kept only for backward compatibility with config file saving.
All configuration is now handled directly by HTTPAgent.

Configuration for an LLM chat agent.

# Fields
- `model::String`: Model identifier
- `max_tokens::Int`: Maximum tokens in response
- `temperature::Float64`: Sampling temperature
- `system_prompt::String`: System prompt for the agent
- `tools::Vector{Type{<:AbstractTool}}`: Available tools
- `tool_choice::String`: How to use tools ("auto", "required", "none")
- `max_tool_use_token::Int`: Maximum tokens to send back from tool results (default: 4000)
"""
struct AgentConfig
    model::String
    max_tokens::Int
    temperature::Float64
    system_prompt::String
    tools::Vector{Type{<:AbstractTool}}
    tool_choice::String
    max_tool_use_token::Int
end

"""
    load_agent_config(folder::String)

Load agent configuration from TOML file or create default HTTPAgent.
Supports `backend = "claude-code"` to use the Claude Code CLI wrapper,
or defaults to HTTPAgent for direct API access.
Returns an LLMChatAgent ready to use.
"""
function load_agent_config(folder::String)
    config_path = joinpath(folder, "ai", "llm-config.toml")

    # Check for backend selection in config
    if isfile(config_path)
        try
            toml_data = TOML.parsefile(config_path)
            backend = get(toml_data, "backend", "http")
            if backend == "claude-code"
                return load_claude_code_config(folder)
            end
        catch
            # Fall through to default HTTP agent
        end
    end

    # Default configuration values
    default_model = "claude-sonnet-4-20250514"
    default_max_tokens = 4096
    default_temperature = 0.7
    default_system_prompt = "You are a helpful AI assistant integrated into a Julia notebook. You can execute code, read/write files, and help with programming tasks."
    default_tools = DEFAULT_TOOLS
    default_tool_choice = "auto"
    default_max_tool_use_token = 4000

    if !isfile(config_path)
        # Create default config file - save using temporary AgentConfig for compatibility
        default_config = AgentConfig(
            default_model,
            default_max_tokens,
            default_temperature,
            default_system_prompt,
            default_tools,
            default_tool_choice,
            default_max_tool_use_token
        )
        save_agent_config(folder, default_config)

        # Create and return HTTPAgent
        api = detect_api(default_model)
        return HTTPAgent(
            api;
            max_tokens=default_max_tokens,
            temperature=default_temperature,
            system_prompt=default_system_prompt,
            tools=default_tools,
            tool_choice=default_tool_choice,
            max_tool_use_token=default_max_tool_use_token
        )
    end

    # Load from TOML
    try
        toml_data = TOML.parsefile(config_path)

        model = get(toml_data, "model", default_model)
        max_tokens = get(toml_data, "max_tokens", default_max_tokens)
        temperature = get(toml_data, "temperature", default_temperature)
        tool_choice = get(toml_data, "tool_choice", default_tool_choice)
        max_tool_use_token = get(toml_data, "max_tool_use_token", default_max_tool_use_token)

        # Load system prompt from separate file if it exists
        system_prompt_path = joinpath(folder, "ai", "llm-system-prompt.md")
        system_prompt = if isfile(system_prompt_path)
            read(system_prompt_path, String)
        else
            get(toml_data, "system_prompt", default_system_prompt)
        end

        # Parse tool names to types
        tool_names = get(toml_data, "tools", String[])
        tools = if isempty(tool_names)
            default_tools
        else
            parse_tool_names(tool_names)
        end

        # Create API and HTTPAgent
        api = detect_api(model)
        return HTTPAgent(
            api;
            max_tokens=max_tokens,
            temperature=temperature,
            system_prompt=system_prompt,
            tools=tools,
            tool_choice=tool_choice,
            max_tool_use_token=max_tool_use_token
        )
    catch e
        @warn "Failed to load agent config, using defaults" exception=(e, catch_backtrace())
        # Return default HTTPAgent
        api = detect_api(default_model)
        return HTTPAgent(
            api;
            max_tokens=default_max_tokens,
            temperature=default_temperature,
            system_prompt=default_system_prompt,
            tools=default_tools,
            tool_choice=default_tool_choice,
            max_tool_use_token=default_max_tool_use_token
        )
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
        "max_tool_use_token" => config.max_tool_use_token,
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
        "todo_list" => TodoList,
        "git" => GitTool,
        "github" => GitHubTool,
        "module_function" => ModuleFunctionTool
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

# Message history functions (cells_to_messages, deduplicate_file_reads!, etc.)
# are now in message_history.jl

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
