using Revise
using WGLMakie
using BonitoBook, Bonito
using PythonCall, Observables
using ClaudeCodeSDK
rm(BonitoBook.Monaco.bundle_file)
rm(Bonito.BonitoLib.bundle_file)
# rm(joinpath(@__DIR__, "Getting-Started"), recursive = true, force = true)
app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "Getting-Started.md"); all_blocks_as_cell=true, replace_style=true)
end

app = App(title = "BonitoBook") do s
    return BonitoBook.InlineBook(joinpath(@__DIR__, "..", "docs", "intro2.md"))
end

app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "..", "docs", "intro.md"); replace_style=true)
end

rm(joinpath(@__DIR__, "Sunny", "01_LSWT_CoRh2O4"), recursive = true, force = true)

app = App(title = "BonitoBook") do s
    return  Book(joinpath(@__DIR__, "Sunny", "01_LSWT_CoRh2O4.ipynb"))
end

@edit Bonito.jsrender(Session(), book.current_cell[].editor.output[])
m = Bonito.richest_mime(book.current_cell[].editor.output[])
@edit show(IOBuffer(), m, book.current_cell[].editor.output[].figure)
book.current_cell[].editor.output[].scene.current_screens


app = App(title = "BonitoBook") do s
    return  Book(joinpath(@__DIR__, "..", "examples", "juliacon25.md"); replace_style=true)
end

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

style = include("../src/templates/style.jl")
App() do
    style = Styles(CSS(
        ".book-spinner",
        "width" => "100%",
        "height" => "6px",
        "position" => "relative",
        "overflow" => "hidden",
        "pointer-events" => "none",
        "display" => "block",
        "background-color" => "black",
        "animation" => "spinner-pulse 1.5s ease-in-out infinite"
    ),
    CSS(
        "@keyframes spinner-pulse",
         CSS("0%", "background-color" => "black"),
         CSS("50%", "background-color" => "green"),
         CSS("100%", "background-color" => "blue")
     ))
    DOM.div(style, DOM.div(class="book-spinner"))
end
