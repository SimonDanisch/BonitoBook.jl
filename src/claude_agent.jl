using Bonito
using Markdown

using ClaudeCodeSDK

"""
    ClaudeAgent <: ChatAgent

A chat agent that uses Claude via the locally installed Claude Code CLI.
Requires claude-code CLI to be installed and configured.

# Fields
- `use_tools::Bool`: Whether to enable tool use
"""
struct ClaudeAgent <: ChatAgent
    use_tools::Bool
end

"""
    ClaudeAgent(; use_tools=false)

Create a new Claude agent using the local Claude Code CLI.

# Arguments
- `use_tools`: Whether to enable tool use for code execution
"""
function ClaudeAgent(; use_tools::Bool = true)
    return ClaudeAgent(use_tools)
end

global CLAUDE_SYSTEM_PROMPT = """
You are a helpful Julia programming assistant integrated into BonitoBook.
Help with code analysis, editing, and execution.
- Use `@doc(sym_or_var)` to get documentation for a function or package.
- use `names(PackageName)` to get a list of functions in a package.
- Use `using PackageName` to load a package.
- Use `BonitoBook.insert_cell_at!(@Book(), "1 + 1", "julia", :end)` to insert a code cell at the end of the current book.
Only append finished and polished code to the notebook and not steps inbetween!
Keep it short and simple! Don't create multiple, similar versions or implement not requested features (e.g. adding an additional line plot, if only a heatmap was requested).
"""


"""
    prompt(agent::ClaudeAgent, question::String; stream_callback=nothing, mcp_server_url=nothing)

Send a prompt to Claude and return the response.
If stream_callback is provided, uses streaming mode and calls the callback with each text chunk.
If mcp_server_url is provided, configures Claude to use the Julia execution MCP server.
"""
function prompt(agent::ClaudeAgent, question::String; stream_callback=nothing, mcp_server_url=nothing)
    try
        # Configure options for Claude Code CLI with MCP server for Julia execution
        tools = agent.use_tools ? ["Read", "Write", "Bash", "Glob", "Grep", "Edit", "mcp__julia-server__julia_exec"] : String[]
        mcp_tools = ["mcp__julia-server__julia_exec"]
        options = ClaudeCodeOptions(
            allowed_tools=tools,
            mcp_tools=mcp_tools,
            max_thinking_tokens=8000,
            system_prompt=CLAUDE_SYSTEM_PROMPT,
            append_system_prompt=nothing,
            permission_mode="acceptEdits",
            continue_conversation=true,
            resume=nothing,
            max_turns=20,
            disallowed_tools=String[],
            model="claude-sonnet-4-20250514",
            permission_prompt_tool_name=nothing,
            cwd="."
        )

        # Use streaming if callback is provided
        # Stream the response with callback
        for message in query_stream(prompt=question, options=options)
            if message isa AssistantMessage
                for block in message.content
                    if block isa TextBlock
                        stream_callback(block.text)
                    end
                end
            end
        end
        return "" # Return empty since streaming was handled by callback

    catch e
        return "Error communicating with Claude: $(string(e))"
    end
end

# MCP server integration will be configured externally via Claude Code CLI

# Export the agent
export ClaudeAgent
