using WGLMakie
using BonitoBook, Bonito
using PythonCall, Observables
using ClaudeCodeSDK
rm(BonitoBook.Monaco.bundle_file)
rm(joinpath("dev", "BonitoBook", "test", "Sunny", "01_LSWT_CoRh2O4"), recursive = true, force = true)

app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "Sunny", "01_LSWT_CoRh2O4.ipynb"))
end



app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "Getting-Started.md"))
end

style = include(joinpath("..", "src", "templates", "style.jl"))
app = App() do
    DOM.div(style, BonitoBook.ChatComponent(BonitoBook.MockChatAgent()))
end

using WGLMakie
using BonitoBook, Bonito, WGLMakie
styles = include("../src/templates/style.jl")

# TODO
#=
- [x] cleanup hover menu + delete
* saving + versioning
* global IO redirect
* display + plugins
* export
* AoG demo
* folder
=#

import Makie.SpecApi as S
@manipulate for vis in (
        contour = visual(Contour),
        scatter = visual(Scatter),
        violin = visual(Violin),
    )
    layer = AlgebraOfGraphics.density() * vis
    penguin_bill * mapping(; color = :species)
end

using ClaudeCodeSDK
tools = ["Read", "Write", "Bash", "Glob", "Grep", "Edit"]

# Configure MCP server for Julia execution
# Based on Claude CLI docs: {"type": "http", "url": "https://example.com/mcp"}
julia_config = McpServerConfig(
    Dict{String, Any}(
        "type" => "http",
        "url" => "http://127.0.0.1:8237"
    ),
    env=Dict{String, Any}()
)
mcp_servers=Dict{String, McpServerConfig}(
    "julia_exec" => julia_config
)


mcp_tools = ["julia_exec"]
options = ClaudeCodeOptions(
    allowed_tools=tools,
    max_thinking_tokens=8000,
    system_prompt="",
    append_system_prompt=nothing,
    mcp_tools=mcp_tools,
    mcp_servers=mcp_servers,
    permission_mode="acceptEdits",
    continue_conversation=true,
    resume=nothing,
    max_turns=20,
    disallowed_tools=String[],
    model="claude-sonnet-4-20250514",
    permission_prompt_tool_name=nothing,
    cwd="."
)
mcp_config = Dict("mcpServers" => options.mcp_servers)
println(ClaudeCodeSDK.JSON.json(mcp_config))

write("mcp_config.json", ClaudeCodeSDK.JSON.json(mcp_config))
run(`claude --mcp-config mcp_config.json`)

for message in query(prompt="Can you run julia code `rand(10) .+ 10`", options=options)
    if message isa AssistantMessage
        for block in message.content
            if block isa TextBlock
                stream_callback(block.text)
            end
        end
    end
end
