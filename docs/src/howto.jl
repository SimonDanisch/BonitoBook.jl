# How-To page showing all BonitoBook how-to guides

function howto()
    intro = DOM.section(
        DOM.h1("How-To Guides", class="section-title"),
        DOM.p(
            "Learn how to extend and customize BonitoBook with these step-by-step guides.",
            class="section-content"
        )
    )

    # Create how-to cards
    howto_cards = [
        ExampleCard("language-evaluator", "Learn how to create a custom language evaluator to run code in your preferred language."),
        ExampleCard("bonitobook-plugin", "Step-by-step guide to creating BonitoBook plugins like slideshow, draggable layouts, and custom book formats."),
        ExampleCard("slideshow-presentation", "Learn how to create engaging presentations using the slideshow plugin with navigation and styling tips."),
    ]
    # Filter out nothing values
    howto_cards = filter(!isnothing, howto_cards)

    howto_grid = DOM.div(
        howto_cards...,
        class="examples-grid"
    )
    content = DOM.div(
        intro,
        howto_grid;
        class="example-content"
    )
    return Page(content, "BonitoBook How-To Guides")
end

# Add routes for individual how-to pages
function add_howto_routes!(routes)
    howto_dir = normpath(joinpath(@__DIR__, "..", "howto"))
    guides = ["language-evaluator", "bonitobook-plugin", "slideshow-presentation"]
    for name in guides
        file = joinpath(howto_dir, "$(name).md")
        route_name = "/$(name)"
        routes[route_name] = App(title=name) do
            # Create a book instance for this how-to guide
            return Page(BonitoBook.InlineBook(file), name)
        end
    end
    return routes
end
