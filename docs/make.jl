title = "BonitoBook Documentation"
link = "https://bonitobook.org"
description = "Interactive notebooks powered by Julia and Bonito"

# Load packages
using CondaPkg
using PythonCall # Enable Python integration

using BonitoBook
using BonitoBook.Bonito
using Markdown

# Include our website module
include("src/Website.jl")
using .Website

function create_routes()
    routes = Routes(
        "/" => App(Website.index, title="BonitoBook"),
        "/examples" => App(Website.examples, title="Examples"),
        "/howto" => App(Website.howto, title="How-To Guides"),
        "/blog" => App(Website.blog, title="Blog"),
    )
    # Add individual example pages
    Website.add_example_routes!(routes)
    # Add individual how-to pages
    Website.add_howto_routes!(routes)
    # Add individual blog posts
    Website.add_blogposts!(routes)
    return routes
end

# Build static site
dir = joinpath(@__DIR__, "build")
!isdir(dir) && mkdir(dir)
Bonito.export_static(dir, create_routes())
# using Revise
# routes, task, server = interactive_server(["src/"]) do
#     return create_routes()
# end

using BonitoSites

# Generate RSS feed
rss_path = joinpath(dir, "rss.xml")
entries = last.(Website.all_posts())
BonitoSites.generate_rss_feed(entries, rss_path; title, link, description, relative_path="./website/")

# Deploy to GitHub Pages
BonitoSites.deploy(
    "github.com/SimonDanisch/BonitoBook.jl.git";
    push_preview=true,
    devbranch="main",
    devurl="website"
)
