module BonitoBook

using Bonito
using Markdown
using UUIDs
using Pkg
using ANSIColoredPrinters
using Logging
using WGLMakie
using Markdown
using Bonito.HTTP
using JSON3
using CondaPkg


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
include("book.jl")
include("runners.jl")
include("export.jl")
include("import.jl")
include("completions.jl")
include("interact.jl")
include("chat.jl")
include("mcp_julia_server.jl")
# include("ai.jl")

export Book, ChatComponent, ChatAgent, ChatMessage, MCPJuliaServer, Collapsible, Components, LoggingWidget, export_zip, import_zip
export InlineBook

end
