module BonitoBook

using Bonito
using Markdown
using BonitoMLTools


function assets(paths...)
    return Asset(joinpath(@__DIR__, "assets", paths...))
end

# Write your package code here.
include("editor.jl")
include("export.jl")
include("book.jl")
# include("ai.jl")

end
