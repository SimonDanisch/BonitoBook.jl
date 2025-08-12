# Examples page showing all BonitoBook examples

function examples()
    intro = DOM.section(
        DOM.h1("Examples", class="section-title"),
        DOM.p(
            "Explore these example notebooks to see what you can create with BonitoBook.",
            class="section-content"
        )
    )

    # Get all example folders
    examples_dir = normpath(joinpath(@__DIR__, "..", "examples"))

    # Create example cards
    example_cards = [
        ExampleCard("intro", "A quick intro to BonitoBook, giving a rough overview of the features and how to use them."),
        ExampleCard("sunny", "Sunny.jl uses Makie a lot and they have some wonderful notebooks, which we can import directly from ipynb."),
        ExampleCard("book-example", "An AI generated Book format for BonitoBook, showing how easy it is to completely change the layout."),
    ]
    # Filter out nothing values
    example_cards = filter(!isnothing, example_cards)

    examples_grid = DOM.div(
        example_cards...,
        class="examples-grid"
    )
    content = DOM.div(
        intro,
        examples_grid
    )
    return Page(content, "BonitoBook Examples")
end

include("../examples/.book-example-bbook/book.jl")

# Add routes for individual example pages
function add_example_routes!(routes)
    examples_dir = normpath(joinpath(@__DIR__, "..", "examples"))
    examples = ["intro", "sunny", "book-example"]
    constructor = Dict("book-example" => RealBook)
    for name in examples
        file = joinpath(examples_dir, "$(name).md")
        route_name = "/$(name)"
        routes[route_name] = App(title=name) do
            # Create a book instance for this example
            # Book needs to be the root element for proper functionality
            B = get(constructor, name, BonitoBook.InlineBook)
            return Page(B(file), name)
        end
    end
    return routes
end
