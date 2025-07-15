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
- Use `BonitoBook.insert_cell_at!(@Book(), "1 + 1", language, :end)` to insert a code cell at the end of the current book. Supported languages are python, julia and markdown. Julia is preferred, but if something only works in Python, that can be used.  Python packages are installed via julia `CondaPkg.add("package_name")`.
Only append finished and polished code to the notebook and not steps inbetween!
Keep it short and simple! Don't create multiple, similar versions or implement not requested features (e.g. adding an additional line plot, if only a heatmap was requested).
Only add a new cell after you verified that the code works and does what was requested.
"""


function Bonito.jsrender(session::Session, msg::SystemMessage)
    return Bonito.jsrender(session, Collapsible("System", string(msg), expanded=false))
end

function Bonito.jsrender(session::Session, value::AssistantMessage)
    return Bonito.jsrender(session, DOM.div(value.content...))
end
function Bonito.jsrender(::Session, value::ToolUseBlock)
    json = JSON.json(value.input)
    return Bonito.jsrender(session, Collapsible("Tool Use: $(value.name)", json, expanded=false))
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
        model="claude-opus-4-20250514",
        permission_prompt_tool_name=nothing,
        cwd="."
    )
    return query_stream(prompt=question, options=options)
end

# MCP server integration will be configured externally via Claude Code CLI

# Export the agent
export ClaudeAgent
