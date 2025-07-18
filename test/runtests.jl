using WGLMakie
using BonitoBook, Bonito
using PythonCall, Observables
using ClaudeCodeSDK
rm(BonitoBook.Monaco.bundle_file)
rm(joinpath(@__DIR__, "Getting-Started"), recursive = true, force = true)
app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "Getting-Started.md"))
end

rm(joinpath(@__DIR__, "Sunny", "01_LSWT_CoRh2O4"), recursive = true, force = true)
app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "Sunny", "01_LSWT_CoRh2O4.ipynb"))
end

import Makie.SpecApi as S
p1 = S.Scatter(1:4; color=1:4)
p2 = S.Lines(1:4; color=1:4)
a = S.Colorbar(p1)
b = S.Colorbar(p2)

Makie.distance_score(
    p1,
    p2,
    Dict()
)

using AlgebraOfGraphics

begin
    Vis = visual(Violin)
    penguins = AlgebraOfGraphics.penguins()
    p = data(penguins) * Vis * mapping(:species, :bill_depth_mm, color=:sex, dodge=:sex)
    gspec = AlgebraOfGraphics.draw_to_spec(p)
    f, ax, pl = plot(gspec)
end

begin
    Vis = visual(Violin)
    penguins = AlgebraOfGraphics.penguins()
    p = data(penguins) * Vis * mapping(:species, :bill_depth_mm, color=:sex, dodge=:sex)
    gspec = AlgebraOfGraphics.draw_to_spec(p)
    pl[1] = gspec
end

gspec.content[1][2].plots[1].kwargs






x = rand(1:4, 333)
y = rand(333)
violin(x, y; color=map(x -> x == 1 ? :red : x == 2 ? :blue : x == 3 ? :green : :orange, x))


import Makie.SpecApi as S
function to_spec(Typ)
    pl = Typ(copy(x), copy(y) .+ rand(length(y));
        color=map(x-> x == 1 ? :red : x == 2 ? :blue : x == 3 ? :green : :orange, x),
        orientation=:horizontal,
        dodge=x,
        cycle=nothing
    )
    attr = Dict(
        :yscale      => identity,
        :ylabel      => "bill_depth_mm",
        :ytickformat => Makie.Automatic(),
        :xlabel      => "species",
        :xticks      => (Base.OneTo(3), ["Adelie", "Chinstrap", "Gentoo"]),
        :yticks      => Makie.Automatic()
    )
    ax = S.Axis(; plots=[pl], attr...)
    return S.GridLayout([ax])
end

f, ax, pl = plot(to_spec(S.Violin))

pl[1] = to_spec(S.BoxPlot)
pl[1] = to_spec(S.Violin)

a = to_spec(S.BoxPlot)
b = to_spec(S.Violin)
Makie.distance_score(
    a.content[1][2].plots[1],
    b.content[1][2].plots[1],
    Dict()
)



boxplot(x, y, color=x)

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

mcp_tools = ["mcp__julia-server__julia_exec"]
tools = ["Read", "Write", "Bash", "Glob", "Grep", "Edit", mcp_tools[1]]
options = ClaudeCodeOptions(
    allowed_tools=tools,
    max_thinking_tokens=8000,
    system_prompt="",
    append_system_prompt=nothing,
    mcp_tools=mcp_tools,
    # mcp_servers=mcp_servers,
    permission_mode="acceptEdits",
    continue_conversation=true,
    max_turns=20,
    disallowed_tools=String[],
    model="claude-sonnet-4-20250514",
    permission_prompt_tool_name=nothing,
    cwd="."
)
for message in query(prompt="Can you run julia code `rand(10) .+ 10`", options=options)
    if message isa AssistantMessage
        for block in message.content
            println(block)
        end
    end
end
