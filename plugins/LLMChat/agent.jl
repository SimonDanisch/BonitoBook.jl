using TOML
using Bonito

"""
    CompactingState

Tracks which tool executions have been compacted in the chat history.
This allows us to send summarized versions of old tool results to the LLM
while keeping full results on disk for the UI.

# Fields
- `compacted_cells::Set{Int}`: Cell IDs that have been marked as compacted
- `keep_last::Int`: Number of recent tool cells to keep full (default: 5)
- `min_size_to_compact::Int`: Minimum result size in chars to consider for compacting (default: 500)
"""
mutable struct CompactingState
    compacted_cells::Set{Int}
    keep_last::Int
    min_size_to_compact::Int
end

CompactingState(; keep_last::Int=5, min_size_to_compact::Int=500) =
    CompactingState(Set{Int}(), keep_last, min_size_to_compact)

"""
    load_compacting_state(folder::String)

Load compacting state from disk or create new state.
"""
function load_compacting_state(folder::String)
    state_path = joinpath(folder, "ai", "compacting-state.json")
    if isfile(state_path)
        try
            data = JSON3.read(read(state_path, String))
            return CompactingState(
                Set{Int}(get(data, :compacted_cells, Int[])),
                get(data, :keep_last, 5),
                get(data, :min_size_to_compact, 500)
            )
        catch e
            @warn "Failed to load compacting state, using defaults" exception=e
        end
    end
    return CompactingState()
end

"""
    save_compacting_state(folder::String, state::CompactingState)

Save compacting state to disk.
"""
function save_compacting_state(folder::String, state::CompactingState)
    ai_dir = joinpath(folder, "ai")
    if !isdir(ai_dir)
        mkpath(ai_dir)
    end

    state_path = joinpath(ai_dir, "compacting-state.json")
    data = Dict(
        "compacted_cells" => collect(state.compacted_cells),
        "keep_last" => state.keep_last,
        "min_size_to_compact" => state.min_size_to_compact
    )
    open(state_path, "w") do io
        JSON3.write(io, data)
    end
end

"""
    compact_tool_result(result::ToolResult; max_summary_length::Int=300)

Create a compacted/summarized version of a tool result for the LLM.
"""
function compact_tool_result(result::ToolResult; max_summary_length::Int=300)
    if !result.success
        # Keep errors full - they're important for debugging
        return result
    end

    result_str = string(result.result)
    if length(result_str) <= max_summary_length
        return result
    end

    # Create summary: first 200 chars + indicator + last 50 chars
    prefix_len = min(200, max_summary_length - 100)
    suffix_len = 50

    prefix = result_str[1:min(prefix_len, length(result_str))]
    suffix = result_str[max(1, length(result_str)-suffix_len+1):end]

    summary = """$prefix

[... $(length(result_str) - prefix_len - suffix_len) characters compacted for context efficiency ...]

$suffix"""

    return ToolResult(summary, result.success)
end

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
Returns an HTTPAgent ready to use.
"""
function load_agent_config(folder::String)
    config_path = joinpath(folder, "ai", "llm-config.toml")

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
    cells_to_messages(book; compact::Bool=true)

Convert notebook cells to agent messages with optional history compacting.
Smartly extracts content from Markdown.parse wrappers and filters out add_cell tool cells.

When `compact=true` (default), old tool results that exceed the size threshold are
automatically compacted to save context tokens. The compacting state is persisted
to disk so it survives restarts.

# Arguments
- `book`: The LLMChatBook or Book to convert
- `compact::Bool=true`: Whether to compact old, large tool results
"""
function cells_to_messages(book; compact::Bool=true)
    messages = AgentMessage[]

    # Load compacting state if enabled
    compacting_state = compact ? load_compacting_state(book.folder) : nothing

    # Collect tool cells for compacting decisions
    tool_cells = filter(book.cells) do cell
        get(cell.metadata, :tool, nothing) !== nothing
    end
    num_tool_cells = length(tool_cells)

    # Track which tool cells should be compacted (all except the last N)
    cells_to_compact = if compact && compacting_state !== nothing && num_tool_cells > compacting_state.keep_last
        Set(cell.uuid for cell in tool_cells[1:end-compacting_state.keep_last])
    else
        Set{Int}()
    end

    state_changed = false

    for cell in book.cells
        role = get(cell.metadata, :from, :assistant)
        cell_id = cell.uuid
        tool_type = get(cell.metadata, :tool, nothing)

        # For user/assistant messages, extract content smartly
        if isnothing(tool_type)
            content = cell.editor.source[]
            # Remove Markdown.parse wrapper if present
            content = extract_markdown_content(content)
            push!(messages, AgentMessage(role, content, cell_id))
        else
            TT = tool_name_to_type(string(tool_type))
            data = joinpath(book.folder, "data", "tools", "$(tool_type)-$(cell_id).json")
            tool_execution = open(io -> JSON3.read(io, ToolExecution{TT}), data)

            # Tool call message (always full)
            push!(messages, AgentMessage(:assistant, tool_execution.tool, cell_id))

            # Tool result message (potentially compacted)
            result = tool_execution.result
            if compact && cell_id in cells_to_compact
                result_size = length(string(result.result))
                if result_size >= compacting_state.min_size_to_compact
                    result = compact_tool_result(result)
                    # Track that we compacted this cell
                    if !(cell_id in compacting_state.compacted_cells)
                        push!(compacting_state.compacted_cells, cell_id)
                        state_changed = true
                    end
                end
            end
            push!(messages, AgentMessage(:user, result, cell_id))
        end
    end

    # Save compacting state if it changed
    if state_changed && compacting_state !== nothing
        save_compacting_state(book.folder, compacting_state)
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
