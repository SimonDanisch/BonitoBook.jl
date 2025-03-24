module BonitoBook

using Bonito
using Markdown
using BonitoMLTools
using UUIDs

function assets(paths...)
    return Asset(joinpath(@__DIR__, "assets", paths...))
end

# Write your package code here.
function set_result! end

include("components.jl")
include("editor.jl")
include("runners.jl")
include("export.jl")
include("book.jl")
include("import.jl")
include("completions.jl")
include("interact.jl")
# include("ai.jl")

end
