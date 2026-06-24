module BonitoBook

using Bonito
using Markdown
using CommonMark
using Typst_jll
using UUIDs
using Pkg
using Logging
using Markdown
using Bonito.HTTP
using JSON3
using Observables
using TOML

# Global constant defining all supported languages
const ALL_LANGUAGES = Dict(
    "julia" => (icon = "julia-logo", always_available = true, activation_help = "", extension_module = nothing),
    "markdown" => (icon = "markdown", always_available = true, activation_help = "", extension_module = nothing),
    "python" => (icon = "python-logo", always_available = false, activation_help = "Install and import PythonCall.jl and CondaPkg.jl packages to enable Python support", extension_module = :BonitoBookPythonCallExt)
)

function asset_path(paths...)
    return joinpath(@__DIR__, "assets", paths...)
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
    # Return the asset with both width and height set to ensure proper sizing
    # Using max-width/max-height prevents icons from becoming unexpectedly large
    return DOM.img(
        src = asset;
        class = "codicon $(class)",
        style = Styles(style, "width" => size, "height" => size, "max-width" => size, "max-height" => size),
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
include("plugin_templates.jl")

"""
    current_book(session::Session)

Retrieve the current book instance from a Bonito session.
"""
function current_book(session::Session)
    return get(session.metadata, :current_book, nothing)
end

# Include plugins as submodules
include("../plugins/Slideshow/book.jl")

export Book, ChatComponent, ChatAgent, ChatMessage, MCPJuliaServer, Collapsible, Components, LoggingWidget, export_zip, import_zip, InteractiveError
export InlineBook, current_book
export LanguageEval, JuliaEval, eval_code, get_language_evaluators
export ALL_LANGUAGES
export SlideshowBooks, SimpleCounterBooks
export PluginInfo, discover_plugins, get_plugin_info, list_plugins
export create_book_from_plugin, initialize_plugin_template

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

end
