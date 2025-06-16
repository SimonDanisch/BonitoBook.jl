module BonitoBook

using Bonito
using Markdown
using UUIDs
using Pkg
using ANSIColoredPrinters
using Logging
using WGLMakie

"""
    assets(paths...)

Get an asset file from the package assets directory.

# Arguments
- `paths...`: Path components relative to the assets directory

# Returns
`Asset` object for the specified file.

# Examples
```julia
# Get the Julia logo
logo = assets("julia-dots.svg")

# Get a font file
font = assets("codicon.ttf")
```
"""
function assets(paths...)
    return Asset(joinpath(@__DIR__, "assets", paths...))
end

# Write your package code here.
function eval_source! end

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
