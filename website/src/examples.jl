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
    examples_dir = normpath(joinpath(@__DIR__, "..", "..", "docs", "examples"))
    example_folders = filter(isdir, readdir(examples_dir; join=true))

    # Create example cards
    example_cards = map(example_folders) do folder
        # Skip non-book folders
        book_file = joinpath(folder, "book.md")
        if !isfile(book_file)
            return nothing
        end

        # Read the first few lines to get a description
        lines = readlines(book_file)
        title = basename(folder)

        # Try to extract title from first heading
        for line in lines
            if startswith(line, "# ")
                title = strip(line, '#')
                break
            end
        end

        # Get description from first paragraph
        description = ""
        in_code_block = false
        for line in lines
            if startswith(line, "```")
                in_code_block = !in_code_block
            elseif !in_code_block && !isempty(strip(line)) && !startswith(line, "#")
                description = strip(line)
                break
            end
        end

        # Use a default description if none found
        if isempty(description)
            descriptions = Dict(
                "juliacon25" => "Interactive exploration of JuliaCon 2025 talk submissions and data visualization.",
                "hots" => "Analysis and visualization examples using real-world datasets.",
                "intro" => "A gentle introduction to BonitoBook's features and capabilities.",
                "intro2" => "Advanced BonitoBook features and interactive components."
            )
            description = get(descriptions, basename(folder), "An example BonitoBook notebook.")
        end

        return ExampleCard(title, description, folder)
    end

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

# Add routes for individual example pages
function add_example_routes!(routes)
    examples_dir = normpath(joinpath(@__DIR__, "..", "..", "examples"))
    example_folders = filter(isdir, readdir(examples_dir; join=true))

    for folder in example_folders
        book_file = joinpath(folder, "book.md")
        if isfile(book_file)
            route_name = "/$(basename(folder))"
            routes[route_name] = App(title="BonitoBook Example: $(basename(folder))") do
                # Create a book instance for this example
                # Book needs to be the root element for proper functionality
                return Page(BonitoBook.InlineBook(folder))
            end
        end
    end

    return routes
end
