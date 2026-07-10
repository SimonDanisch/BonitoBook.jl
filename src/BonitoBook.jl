module BonitoBook

using Bonito
using Markdown
using UUIDs
using Pkg
using ANSIColoredPrinters
using Logging
using Markdown
using Bonito.HTTP
using JSON3
using Observables

# Global constant defining all supported languages
const ALL_LANGUAGES = Dict(
    "julia" => (icon = "julia-logo", always_available = true, activation_help = "", extension_module = nothing),
    "markdown" => (icon = "markdown", always_available = true, activation_help = "", extension_module = nothing),
    "python" => (icon = "python-logo", always_available = false, activation_help = "Install and import PythonCall.jl and CondaPkg.jl packages to enable Python support", extension_module = :BonitoBookPythonCallExt)
)

function asset_path(paths...)
    #return joinpath(@__DIR__, "assets", paths...)
    return joinpath(pkgdir(@__MODULE__), "src", "assets", paths...)
end

function assets(paths...)
    return Asset(asset_path(paths...))
end

"""
    icon(name::String; size="16px", class="", style="", kw...)

Create an inline SVG icon from the assets/icons directory.

# Arguments
- `name`: Icon name (without .svg extension)
- `size`: Icon size (default: "16px")
- `class`: Additional CSS classes
- `style`: Additional inline styles
- `kw...`: Additional attributes for the icon element

# Returns
DOM element with the SVG icon rendered inline.

# Examples
```julia
# Basic icon
play_icon = icon("play")

# Icon with custom size and class
save_icon = icon("save", size="20px", class="toolbar-icon")

# Icon with custom styling
error_icon = icon("error", style="color: red;")
```
"""
function icon(name::String; size = "1.2em", class = "", style = Styles(), kw...)
    candidates = [f for f in map(x->asset_path("icons", x), [name, "$(name).png", "$(name).svg"]) if isfile(f)]
    if isempty(candidates)
        error("No icon found for '$name'.")
    end
    file = only(candidates)
    asset = Asset(file)
    # Just return the asset with minimal styling to match codicon behavior
    return DOM.img(
        src = asset;
        class = "codicon $(class)",
        style = Styles(style, "width" => size),
        kw...
    )
end

include("redirect_io.jl")
include("components.jl")
include("bb-components.jl")
include("editor.jl")
include("sidebar.jl")
include("tabbed_editor.jl")
include("eval_file_on_change.jl")
include("logging.jl")
include("style.jl")
include("book.jl")
include("error-display.jl")
include("runners.jl")
include("export.jl")
include("import.jl")
include("completions.jl")
include("interact.jl")
include("chat.jl")
include("mcp_julia_server.jl")
include("welcomepage.jl")

export Book, ChatComponent, ChatAgent, ChatMessage, MCPJuliaServer, Collapsible, Components, LoggingWidget, export_zip, import_zip, InteractiveError
export InlineBook
export LanguageEval, JuliaEval, eval_code, get_language_evaluators
export ALL_LANGUAGES
export Welcome, serve_welcome

function _MakieModule end


"""
    MakieModule()

Returns a module-like object that provides access to Makie functionality.
This function is a stub that gets implemented when Makie is loaded
through the BonitoBookMakieExt extension.

# Example
```julia
MakieModule().set_theme!(size = (650, 450))
MakieModule().set_theme!(MakieModule().theme_dark(), size = (650, 450))
```
"""
function MakieModule()
    if !isnothing(Base.get_extension(@__MODULE__, :BonitoBookMakieExt))
        return _MakieModule()
    else
        return nothing
    end
end

function __init__()

    # Julia 1.11 has a bug https://github.com/JuliaLang/julia/issues/56077 
    # hence we need to do something dirty here:
    dir = !isnothing(pkgdir(@__MODULE__)) ? joinpath(pkgdir(@__MODULE__), "src") : isdir(@__DIR__) ? (@__DIR__) : joinpath(dirname(pkgdir(Bonito)), "BonitoBook/src")

    global Monaco = ES6Module(joinpath(dir, "javascript", "Monaco.js"))

    return
end

end
