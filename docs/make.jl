title = "BonitoBook Documentation"
link = "https://bonitobook.org"
description = "Interactive notebooks powered by Julia and Bonito"

# Load packages
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
    )
    # Add individual example pages
    Website.add_example_routes!(routes)

    return routes
end

# Build static site
dir = joinpath(@__DIR__, "build")
!isdir(dir) && mkdir(dir)
Bonito.export_static(dir, create_routes())
using BonitoSites

# Deploy to GitHub Pages
BonitoSites.deploy(
    "github.com/SimonDanisch/BonitoBook.jl.git";
    push_preview=true,
    devbranch="main",
    devurl="website"
)
