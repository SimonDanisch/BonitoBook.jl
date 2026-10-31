module Website

using BonitoBook
using BonitoBook.Bonito
using Markdown

# Asset helpers
function asset_path(files...)
    path = normpath(joinpath(@__DIR__, "assets", files...))
    return path
end

img_asset(files...) = Asset(asset_path("images", files...))
css_asset(files...) = Asset(asset_path("css", files...))

# Include components
include("components.jl")
include("index.jl")
include("examples.jl")
include("howto.jl")
include("blog.jl")

export index, examples, howto, blog, add_example_routes!, add_howto_routes!, add_blogposts!, all_posts

end
