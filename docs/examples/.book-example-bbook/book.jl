using BonitoBook, Bonito, Dates, Markdown


"""
    RealBook

A specialized Book wrapper that provides enhanced academic book features including:
- Chapter and section numbering
- Academic layout and typography  
- Enhanced figure and table management
- Bibliography integration
- Print-optimized styling
- Embedding-friendly layout (no fixed positioning)

This struct wraps the standard BonitoBook.Book and adds academic publishing features
optimized for web embedding with relative positioning and flexible layout.
"""
struct RealBook
    book::BonitoBook.Book
    title::String
    author::String
    institution::String
    date::String
    abstract::String
    toc_enabled::Bool
    chapter_numbering::Bool
    print_optimized::Bool
end


function RealBook(
    filename::String;
    title::String = "",
    author::String = "",
    institution::String = "",
    date::String = Dates.format(Dates.now(), "yyyy-mm-dd"),
    abstract::String = "",
    toc_enabled::Bool = true,
    chapter_numbering::Bool = true,
    print_optimized::Bool = true,
    book_kwargs...
)
    # Create the underlying Book from the markdown file
    book = BonitoBook.Book(filename; all_blocks_as_cell=true, book_kwargs...)
    for cell in book.cells
        BonitoBook.run_sync!(cell.editor)
    end
    return RealBook(
        book,
        title,
        author,
        institution,
        date,
        abstract,
        toc_enabled,
        chapter_numbering,
        print_optimized
    )
end

"""
Custom jsrender for RealBook that adds academic book layout and features.
"""
function Bonito.jsrender(session::Session, real_book::RealBook)
    # Get the base book rendering
    book = real_book.book


    # Create table of contents if enabled
    toc_sidebar = real_book.toc_enabled ? create_toc_sidebar_widget(real_book) : DOM.div()

    # Wrap the book content with academic structure - optimized for embedding
    academic_book = DOM.div(
        book.style_eval.last_valid_output,
        # Add custom CSS class for academic styling
        class = "real-book-container",
        style = "display: flex; position: relative; width: auto; max-width: 1200px; margin: 20px auto; overflow: visible; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 12px rgba(0,0,0,0.1);",

        # Left sidebar TOC (contained within parent container)
        real_book.toc_enabled ? DOM.div(
            toc_sidebar,
            class = "book-toc-sidebar",
            style = "width: 200px; position: relative; flex-shrink: 0; overflow-y: auto; background-color: #f8f9fa; border-right: 1px solid #dee2e6; padding: 12px; align-self: stretch;"
        ) : DOM.div(),

        # Main content area with proper centering
        DOM.div(
            # Main book content with academic wrapper
            DOM.div(
                book.cells,
                class = "book-main-content academic-content",
                style = "width: 100%; display: flex; flex-direction: column; align-items: center;"
            ),

            # Footer with academic metadata
            create_footer(real_book),
            class = "book-main-area",
            style = "flex: 1; padding: 20px; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; min-width: 0; overflow: visible;"
        )
    )
    return Bonito.jsrender(session, academic_book)
end


"""
    extract_headings_from_markdown(content::String)

Extract headings from markdown content for TOC generation.
Returns array of (level, text, id) tuples.
"""
function extract_headings_from_markdown(content::String)
    headings = []
    # Parse the markdown content properly
    parsed = Markdown.parse(content)
    # Walk through the markdown AST to find headings
    extract_headings_from_ast!(headings, parsed)
    return headings
end

get_level(::Markdown.Header{N}) where N = N

"""
    extract_headings_from_ast!(headings, ast)

Recursively extract headings from a Markdown AST.
"""
function extract_headings_from_ast!(headings, ast)
    if ast isa Markdown.Header
        level = get_level(ast)
        text = only(ast.text)
        push!(headings, (level, text, text))
    elseif hasproperty(ast, :content) && ast.content isa Vector
        # Recursively process nested content
        for item in ast.content
            extract_headings_from_ast!(headings, item)
        end
    end
end

"""
    extract_text_content(markdown_element)

Extract plain text content from markdown elements, handling inline formatting.
"""
function extract_text_content(element)
    if element isa String
        return element
    elseif element isa Vector
        return join([extract_text_content(item) for item in element], "")
    elseif hasfield(typeof(element), :content)
        return extract_text_content(element.content)
    elseif hasfield(typeof(element), :text)
        return element.text
    else
        return string(element)
    end
end

"""
Create table of contents sidebar widget.
"""
function create_toc_sidebar_widget(real_book::RealBook)
    # Read the markdown file to extract headings
    headings = []

    content = read(real_book.book.file, String)
    headings = extract_headings_from_markdown(content)

    # Build TOC structure
    toc_items = []

    for (level, text, id) in headings
        # Skip the main title (level 1) if it matches the book title
        if level == 1 && text == real_book.title
            continue
        end
        # Create appropriate indentation based on heading level
        indent = (level - 1) * 20  # pixels
        item = DOM.div(
            DOM.a(
                text,
                href = "#" * replace(id, " " => "%20"),
                style = "text-decoration: none; color: #3498db; transition: all 0.2s; display: block; padding: 4px 8px; border-radius: 4px; font-size: $(level <= 2 ? "0.95em" : "0.9em"); font-weight: $(level <= 2 ? "500" : "normal");",
                onmouseover = "this.style.backgroundColor='#e3f2fd'; this.style.color='#1976d2';",
                onmouseout = "this.style.backgroundColor='transparent'; this.style.color='#3498db';"
            ),
            style = "margin-left: $(indent)px; margin-bottom: 2px;"
        )

        push!(toc_items, item)
    end

    # If no headings found, show a message
    if isempty(toc_items)
        toc_content = DOM.p(
            "No headings found in document.",
            style = "font-style: italic; color: #7f8c8d; text-align: center;"
        )
    else
        toc_content = DOM.div(toc_items...)
    end

    return DOM.div(
        class = "book-toc toc-sidebar",
        DOM.h3(
            "Table of Contents",
            style = "color: #2c3e50; margin-bottom: 1.5em; font-size: 1.2em; font-weight: bold; border-bottom: 2px solid #3498db; padding-bottom: 0.5em;"
        ),

        toc_content
    )
end

"""
Create academic footer with metadata.
"""
function create_footer(real_book::RealBook)
    return DOM.div(
        class = "book-footer",
        style = "margin-top: 4em; padding: 2em; border-top: 1px solid #dee2e6; color: #7f8c8d; font-size: 0.9em; text-align: center;",

        DOM.p(
            "© $(Dates.year(Dates.now())) $(real_book.author). All rights reserved.",
            style = "margin-bottom: 0.5em;"
        ),

        DOM.p(
            "Generated with BonitoBook - An Interactive Academic Publishing Platform",
            style = "font-style: italic;"
        )
    )
end
