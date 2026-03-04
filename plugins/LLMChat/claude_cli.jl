"""
Claude Code CLI wrapper for the LLMChat plugin.
Spawns the `claude` CLI with `--output-format stream-json` and parses the
streaming NDJSON output into items compatible with the agent loop.
"""

using UUIDs

# ============================================================================
# Configuration
# ============================================================================

"""
    ClaudeCodeConfig

Configuration for Claude Code CLI agent.

# Fields
- `model::String`: Model to use (e.g. "claude-sonnet-4-20250514")
- `system_prompt::String`: System prompt text
- `allowed_tools::Vector{String}`: Tools to allow (e.g. ["Read", "Write", "Bash"])
- `permission_mode::String`: Permission mode ("acceptEdits", "prompt", "deny")
- `max_turns::Int`: Maximum conversation turns
- `cwd::String`: Working directory for CLI
- `max_thinking_tokens::Int`: Maximum thinking tokens
- `continue_conversation::Bool`: Whether to continue from previous session
- `session_id::String`: Unique ID for this conversation session
"""
struct ClaudeCodeConfig
    model::String
    system_prompt::String
    allowed_tools::Vector{String}
    permission_mode::String
    max_turns::Int
    cwd::String
    max_thinking_tokens::Int
    continue_conversation::Bool
    session_id::String
end

function ClaudeCodeConfig(;
    model="claude-sonnet-4-20250514",
    system_prompt="",
    allowed_tools=["Read", "Write", "Bash", "Glob", "Grep", "Edit"],
    permission_mode="acceptEdits",
    max_turns=20,
    cwd=pwd(),
    max_thinking_tokens=8000,
    continue_conversation=true,
    session_id=string(UUIDs.uuid4())
)
    return ClaudeCodeConfig(
        model, system_prompt, allowed_tools, permission_mode,
        max_turns, cwd, max_thinking_tokens, continue_conversation, session_id
    )
end

# ============================================================================
# Agent
# ============================================================================

"""
    ClaudeCodeAgent <: LLMChatAgent

Agent that uses the Claude Code CLI for chat interactions.
Uses session-aware one-shot commands to maintain history and synchronization.
"""
mutable struct ClaudeCodeAgent <: LLMChatAgent
    config::ClaudeCodeConfig
    cli_path::String
    # Track last item type for agent loop stop detection
    last_item::Base.RefValue{Union{Nothing, AbstractTool, String}}
    needs_to_be_done::Dict{DataType, AbstractTool}
    # History tracking for synchronization
    last_messages::Vector{AgentMessage}
end

function ClaudeCodeAgent(config::ClaudeCodeConfig)
    cli = find_claude_cli()
    return ClaudeCodeAgent(
        config, cli, 
        Ref{Union{Nothing, AbstractTool, String}}(nothing), 
        Dict{DataType, AbstractTool}(),
        AgentMessage[]
    )
end

# ============================================================================
# CLI Discovery
# ============================================================================

"""
    find_claude_cli() -> String

Find the `claude` CLI binary. Searches PATH and common installation locations.
"""
function find_claude_cli()
    # Try PATH first
    path = Sys.which("claude")
    if path !== nothing
        return path
    end

    # Common npm global install locations
    home = homedir()
    candidates = [
        joinpath(home, ".local", "bin", "claude"),
        joinpath(home, ".npm-global", "bin", "claude"),
        "/usr/local/bin/claude",
        "/usr/bin/claude",
    ]

    for candidate in candidates
        if isfile(candidate)
            return candidate
        end
    end

    error("Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code")
end

# ============================================================================
# Command Building
# ============================================================================

"""
    build_command(agent::ClaudeCodeAgent, prompt_text::String; resume::Bool=false) -> Cmd

Build the CLI command. Uses --resume if resume=true, otherwise --session-id.
"""
function build_command(agent::ClaudeCodeAgent, prompt_text::String; resume::Bool=false)
    config = agent.config
    args = String[agent.cli_path]

    # Output format
    push!(args, "--output-format", "stream-json")

    # Verbose for tool details
    push!(args, "--verbose")

    # Session persistence
    if resume && config.continue_conversation
        push!(args, "--resume", config.session_id)
    else
        push!(args, "--session-id", config.session_id)
    end

    # Model
    if !isempty(config.model)
        push!(args, "--model", config.model)
    end

    # System prompt
    if !isempty(config.system_prompt)
        push!(args, "--system-prompt", config.system_prompt)
    end

    # Allowed tools
    if !isempty(config.allowed_tools)
        push!(args, "--allowedTools", join(config.allowed_tools, ","))
    end

    # Permission mode
    if !isempty(config.permission_mode)
        push!(args, "--permission-mode", config.permission_mode)
    end

    # Max turns
    push!(args, "--max-turns", string(config.max_turns))

    # Prompt (non-interactive mode)
    push!(args, "-p", prompt_text)

    # Build Cmd with working directory
    cmd = Cmd(Cmd(args); dir=config.cwd)

    # Unset CLAUDECODE env var to allow nested execution
    cmd = addenv(cmd, "CLAUDECODE" => "")

    return cmd
end

# ============================================================================
# Stream Parsing
# ============================================================================

"""
    parse_stream_message(line::String) -> Union{Nothing, String, AbstractTool}

Parse a single NDJSON line from the Claude CLI stream-json output.
Returns `nothing` for non-content messages, a `String` for text content,
or an `AbstractTool` for tool use blocks.
"""
function parse_stream_message(line::AbstractString)
    stripped = strip(line)
    isempty(stripped) && return nothing

    # Only parse lines that look like JSON
    startswith(stripped, '{') || return nothing

    local data
    try
        data = JSON3.read(stripped)
    catch
        return nothing
    end

    msg_type = get(data, :type, "")

    if msg_type == "assistant"
        return parse_assistant_message(data)
    elseif msg_type == "result"
        # Result message text duplicates the last assistant message, so skip it
        return nothing
    end

    # system, user, and other types are ignored
    return nothing
end

"""
    parse_assistant_message(data) -> Vector{Union{String, AbstractTool}}

Parse an assistant message and extract content blocks.
Returns a vector of items (text strings and tool objects).
"""
function parse_assistant_message(data)
    message = get(data, :message, nothing)
    message === nothing && return nothing

    content = get(message, :content, nothing)
    content === nothing && return nothing

    items = Union{String, AbstractTool}[]

    if content isa AbstractString
        push!(items, content)
        return items
    end

    # Content is an array of blocks
    for block in content
        block_type = get(block, :type, "")

        if block_type == "text"
            text = get(block, :text, "")
            if !isempty(strip(text))
                push!(items, text)
            end
        elseif block_type == "tool_use"
            tool = parse_tool_use(block)
            if tool !== nothing
                push!(items, tool)
            end
        end
        # tool_result blocks are handled by Claude internally
    end

    return items
end

"""
    parse_tool_use(block) -> Union{Nothing, AbstractTool}

Convert a tool_use block from Claude CLI into an AbstractTool.
Maps Claude's built-in tool names to our LLMChat tool types.
"""
function parse_tool_use(block)
    name = get(block, :name, "")
    input = get(block, :input, Dict())

    # Map Claude Code tool names to our AbstractTool types
    if name == "Read"
        path = get(input, :file_path, get(input, :path, ""))
        return FileReadTool(path)
    elseif name == "Write"
        path = get(input, :file_path, get(input, :path, ""))
        content = get(input, :content, "")
        return FileWriteTool(path, content)
    elseif name == "Edit"
        path = get(input, :file_path, get(input, :path, ""))
        old_text = get(input, :old_string, get(input, :old_text, ""))
        new_text = get(input, :new_string, get(input, :new_text, ""))
        return FileEditTool(path, old_text, new_text)
    elseif name == "Bash"
        command = get(input, :command, "")
        return BashTool(command)
    elseif name == "Glob"
        pattern = get(input, :pattern, get(input, :path, "*"))
        return FileTool("glob", Dict{String, Any}("pattern" => pattern))
    elseif name == "Grep"
        pattern = get(input, :pattern, "")
        path = get(input, :path, ".")
        # Use a real shell command string for Grep, which we'll handle better in BashTool
        return BashTool("grep -r $(repr(pattern)) $(repr(path))")
    elseif name == "mcp__julia-server__julia_exec" || name == "mcp__julia__julia_eval"
        code = get(input, :code, "")
        return AddCellTool("julia", code, nothing)
    elseif name == "mcp__julia__julia_restart"
        # Map restart to a Julia call (though real restart is handled by the server)
        # We just show it as a code cell for now
        return AddCellTool("julia", "# Requesting Julia session restart...\n# (Note: This is handled by the MCP server)", nothing)
    elseif name == "mcp__julia__julia_list_sessions"
        # Execute the listing code
        code = "using BonitoBook; # Listing sessions via MCP not fully exposed yet"
        return AddCellTool("julia", "# Listing active Julia sessions", nothing)
    elseif name == "TodoWrite"
        # Map Claude Code's TodoWrite to our TodoList
        todos = get(input, :todos, [])
        items = String[]
        status = Bool[]
        for todo in todos
            push!(items, get(todo, :task, get(todo, :text, "todo")))
            push!(status, get(todo, :status, "") == "done")
        end
        return TodoList("Claude's Plan", items, status)
    elseif name == "WebSearch"
        query = get(input, :query, "")
        return BashTool("# WebSearch: $query\n# (Web search not natively supported yet, showing as comment)")
    elseif name == "Agent"
        type = get(input, :subagent_type, "Explore")
        desc = get(input, :description, "")
        prompt_text = get(input, :prompt, "")
        return BashTool("# Agent ($type): $desc\n# Prompt: $prompt_text\n# (Subagent delegation not supported yet)")
    else
        # Unknown tool — wrap as bash for display
        @warn "Unknown Claude Code tool: $name" input
        return BashTool("# Claude tool: $name\n$(JSON3.write(input))")
    end
end

# ============================================================================
# Prompt / Streaming
# ============================================================================

"""
    prompt(callback, agent::ClaudeCodeAgent, messages::Vector{AgentMessage}; spinner=nothing)

Spawn the Claude CLI, stream its output, and call `callback` with each
content item (String or AbstractTool).
"""
function prompt(callback, agent::ClaudeCodeAgent, messages::Vector{AgentMessage};
    spinner::Union{TaskSpinner, Nothing}=nothing)

    if isempty(messages)
        callback("No user message found.")
        return
    end

    # 1. Detect history state
    is_new_session = isempty(agent.last_messages)
    new_history = messages[1:end-1]
    
    # History changed if we had a cache and it doesn't match the current notebook state
    history_modified = !is_new_session && (agent.last_messages != new_history)
    
    # We need full context if it's a new Julia session with existing notebook history,
    # OR if the user manually edited/deleted cells.
    needs_full_context = (is_new_session && !isempty(new_history)) || history_modified

    # 2. Determine prompt text
    if needs_full_context
        # Replay the whole state as context to sync Claude with the notebook
        history_str = build_history_context(new_history)
        prompt_text = history_str * "\n--- New User Prompt ---\n" * string(messages[end].content)
    else
        # Normal flow (standard append) - just send the latest message
        prompt_text = string(messages[end].content)
    end

    # Update tracked history cache
    agent.last_messages = copy(messages)

    # 3. Build and execute command
    # We only use --resume if it's NOT the first time we send something in this Julia session
    cmd = build_command(agent, prompt_text; resume=!is_new_session)

    try
        process = open(cmd, "r")
        try
            for line in eachline(process)
                # Check stop flag from UI
                if spinner !== nothing && spinner.stop[]
                    kill(process)
                    break
                end

                result = parse_stream_message(line)
                if result === nothing
                    continue
                elseif result isa Vector
                    for item in result
                        callback(item)
                    end
                else
                    callback(result)
                end
            end
        finally
            close(process)
        end
    catch e
        if !(e isa InterruptException)
            @warn "Claude CLI error" exception=(e, catch_backtrace())
            callback("Error communicating with Claude CLI: $(string(e))")
        end
    end
end

function build_history_context(messages)
    isempty(messages) && return ""
    ctx = "Context from the current notebook session (replaying history for synchronization):\n\n"
    for msg in messages
        role = msg.role == :user ? "User" : "Assistant"
        content = string(msg.content)
        # We avoid nesting big tool result data in the history context if possible
        ctx *= "[$role]: $content\n\n"
    end
    return ctx
end

"""
    prompt(agent::ClaudeCodeAgent, messages::Vector{AgentMessage}; spinner=nothing)

Spawn the Claude CLI and return a Channel yielding content items.
"""
function prompt(agent::ClaudeCodeAgent, messages::Vector{AgentMessage};
    spinner::Union{TaskSpinner, Nothing}=nothing)
    return Channel{Union{AbstractTool, String}}(Inf; spawn=true) do chan
        prompt(item -> put!(chan, item), agent, messages; spinner=spinner)
    end
end

# Make isdone work with ClaudeCodeAgent
function isdone(agent::ClaudeCodeAgent)
    if !isempty(agent.needs_to_be_done)
        finished = all(isdone, values(agent.needs_to_be_done))
        if finished
            empty!(agent.needs_to_be_done)
        end
        return finished
    end
    return agent.last_item[] isa String
end

# ============================================================================
# Config Loading
# ============================================================================

"""
    load_claude_code_config(folder::String) -> ClaudeCodeAgent

Load Claude Code agent configuration from `ai/llm-config.toml`.
"""
function load_claude_code_config(folder::String)
    config_path = joinpath(folder, "ai", "llm-config.toml")

    defaults = ClaudeCodeConfig(; cwd=pwd())

    if !isfile(config_path)
        return ClaudeCodeAgent(defaults)
    end

    try
        toml_data = TOML.parsefile(config_path)

        model = get(toml_data, "model", defaults.model)
        max_turns = get(toml_data, "max_turns", defaults.max_turns)
        permission_mode = get(toml_data, "permission_mode", defaults.permission_mode)
        max_thinking_tokens = get(toml_data, "max_thinking_tokens", defaults.max_thinking_tokens)
        continue_conversation = get(toml_data, "continue_conversation", defaults.continue_conversation)
        allowed_tools = get(toml_data, "allowed_tools", defaults.allowed_tools)

        # Load system prompt from separate file
        system_prompt_path = joinpath(folder, "ai", "llm-system-prompt.md")
        system_prompt = if isfile(system_prompt_path)
            read(system_prompt_path, String)
        else
            get(toml_data, "system_prompt", defaults.system_prompt)
        end

        config = ClaudeCodeConfig(;
            model=model,
            system_prompt=system_prompt,
            allowed_tools=allowed_tools,
            permission_mode=permission_mode,
            max_turns=max_turns,
            cwd=pwd(),
            max_thinking_tokens=max_thinking_tokens,
            continue_conversation=continue_conversation,
        )
        return ClaudeCodeAgent(config)
    catch e
        @warn "Failed to load Claude Code config, using defaults" exception=(e, catch_backtrace())
        return ClaudeCodeAgent(defaults)
    end
end
