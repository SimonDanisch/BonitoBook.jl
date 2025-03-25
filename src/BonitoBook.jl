module BonitoBook

using Bonito
using Markdown
using UUIDs
using Pkg
using ANSIColoredPrinters
using Logging


function assets(paths...)
    return Asset(joinpath(@__DIR__, "assets", paths...))
end

# Write your package code here.
function set_result! end

include("redirect_io.jl")
include("editor.jl")
include("book.jl")
include("components.jl")
include("runners.jl")
include("export.jl")
include("import.jl")
include("completions.jl")
include("interact.jl")
# include("ai.jl")

export Book

end
