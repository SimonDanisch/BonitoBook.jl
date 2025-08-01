const asset = Asset("https://cdnjs.cloudflare.com/ajax/libs/html-to-image/1.10.10/html-to-image.min.js")

function export_svg(element)
    return DOM.div(
        asset,
        js"""(()=> {
            function filter (node) {
                return (node.tagName !== 'SCRIPT');
            }
            if (typeof htmlToImage === 'undefined') {
                console.error('htmlToImage library not loaded');
                return;
            }
            htmlToImage.toSvg($element, {filter}).then((dataUrl) => {
                const link = document.createElement('a');
                link.href = dataUrl;
                link.download = 'output.svg';
                link.click();
            }).catch(function (error) {
                console.error('Could not convert', error);
            })
        })()
        """
    )
end

"""
    export_html(filename, book)

Export a book to a static HTML file.

# Arguments
- `filename`: Output HTML file path
- `book::Book`: Book to export

# Returns
Path to the exported HTML file.
"""
function export_html(filename, book)
    return Bonito.export_static(filename, App(book))
end

struct InlineBook
    book::Book
end

function InlineBook(path::String)
    book = Book(path)
    for cell in book.cells
        run_sync!(cell.editor)
    end
    return InlineBook(book)
end

function Bonito.jsrender(session::Session, inline_book::InlineBook)
    return Bonito.jsrender(session, export_dom(session, inline_book.book))
end

function export_dom(session::Session, book::Book)
    # Create export menu that matches saving_menu style
        # Pre-save the markdown file
    md_file = book.file
    export_md(md_file, book)
    save_md = DOM.div(
        BonitoBook.icon("markdown");
        class = "small-button",
        onclick = js"""() => {
            $(download_file_js(session, md_file))
        }"""
    )
    save_pdf = DOM.div(
        BonitoBook.icon("file-pdf");
        class = "small-button",
        onclick = js"""()=> window.print();"""
    )

    export_menu = DOM.div(DOM.div(
        BonitoBook.icon("save"), save_md, save_pdf;
        class = "saving small-menu-bar"
    ); class = "book-main-menu")

    body = Centered(DOM.div(export_menu, book.cells...))
    document = DOM.div(DOM.div(body; style = Styles("width" => "100%")))
    # Inject script to set export mode global variable and add CSS class
    export_mode_script = js"""
        window.BONITO_EXPORT_MODE = true;
        document.body.classList.add('bonito-export-mode');
    """
    return DOM.div(book.style_eval.last_valid_output, export_mode_script, document)
end

"""
    export_html(file, book)

Export a book to a Julia-specific HTML format with styling.

# Arguments
- `file`: Output file path
- `book::Book`: Book to export

# Returns
Path to the exported file.
"""
function export_html(file::AbstractString, book::Book)
    Bonito.export_static(file, App((s)-> export_dom(s, book)))
    return file
end

"""
    export_md(file, book)

Export a book to markdown format, preserving cell metadata.

# Arguments
- `file`: Output markdown file path
- `book::Book`: Book to export

# Returns
Path to the exported markdown file.

The exported markdown includes cell visibility flags in code block headers.
"""
function export_md(file::AbstractString, book::Book)
    open(file, "w") do io
        for cell_editor in book.cells
            language = cell_editor.language
            editor = cell_editor.editor
            content = editor.source[]
            show_editor = editor.show_editor[]
            show_logging = editor.show_logging[]
            show_output = editor.show_output[]
            if language == "markdown"
                println(io, content)
            else
                println(io, "```$language $(show_editor) $(show_logging) $(show_output)")
                println(io, content)
                println(io, "```")
            end
        end
    end
    return file
end

"""
    export_quarto(file, book)

Export a book to Quarto format (.qmd), preserving cell metadata and structure.

# Arguments
- `file`: Output Quarto file path (.qmd)
- `book::Book`: Book to export

# Returns
Path to the exported Quarto file.

The exported Quarto format uses Quarto's executable code blocks with proper metadata.
"""
function export_quarto(file::AbstractString, book::Book)
    open(file, "w") do io
        for cell_editor in book.cells
            language = cell_editor.language
            editor = cell_editor.editor
            content = editor.source[]
            show_editor = editor.show_editor[]
            show_logging = editor.show_logging[]
            show_output = editor.show_output[]

            if language == "markdown"
                println(io, content)
            else
                # Quarto format uses {language} syntax for executable blocks
                # Add execution options based on visibility flags
                execution_opts = []
                if !show_output
                    push!(execution_opts, "output: false")
                end
                if !show_editor
                    push!(execution_opts, "echo: false")
                end

                opts_str = isempty(execution_opts) ? "" : ", $(join(execution_opts, ", "))"
                println(io, "```{$language$opts_str}")
                println(io, content)
                println(io, "```")
            end
            println(io) # Add blank line between cells
        end
    end
    return file
end
using JSON3

"""
    export_ipynb(file, book)

Export a book to Jupyter notebook format (.ipynb), preserving cell structure.

# Arguments
- `file`: Output Jupyter notebook file path (.ipynb)
- `book::Book`: Book to export

# Returns
Path to the exported Jupyter notebook file.

The exported notebook uses the standard Jupyter notebook v4.5 format.
"""
function export_ipynb(file::AbstractString, book::Book)

    # Create notebook structure
    cells = []

    for cell_editor in book.cells
        language = cell_editor.language
        editor = cell_editor.editor
        content = editor.source[]
        show_editor = editor.show_editor[]
        show_output = editor.show_output[]

        # Split content into lines for Jupyter format
        source_lines = split(content, '\n', keepempty=true)
        # Add newlines to all lines except the last
        source_array = [i < length(source_lines) ? line * "\n" : line for (i, line) in enumerate(source_lines)]

        if language == "markdown"
            cell = Dict(
                "cell_type" => "markdown",
                "metadata" => Dict(),
                "source" => source_array
            )
        else
            # Map language names to Jupyter kernel names
            kernel_language = language == "julia" ? "julia" : language

            cell = Dict(
                "cell_type" => "code",
                "execution_count" => nothing,
                "metadata" => Dict(
                    "bonitobook" => Dict(
                        "show_editor" => show_editor,
                        "show_output" => show_output
                    )
                ),
                "outputs" => [],
                "source" => source_array
            )
        end

        push!(cells, cell)
    end

    # Create notebook metadata - default to Julia kernel
    kernelspec = Dict(
        "display_name" => "Julia",
        "language" => "julia",
        "name" => "julia"
    )

    # Check if there are any Python cells and adjust kernel accordingly
    has_python = any(c -> get(c, "cell_type", "") == "code" &&
                           any(line -> occursin(r"^(import|from)\s+\w+", line),
                               get(c, "source", [])), cells)

    if has_python
        kernelspec = Dict(
            "display_name" => "Python 3",
            "language" => "python",
            "name" => "python3"
        )
    end

    notebook = Dict(
        "cells" => cells,
        "metadata" => Dict(
            "kernelspec" => kernelspec,
            "language_info" => Dict(
                "name" => kernelspec["language"]
            ),
            "bonitobook" => Dict(
                "exported_from" => "BonitoBook.jl"
            )
        ),
        "nbformat" => 4,
        "nbformat_minor" => 5
    )

    # Write JSON to file
    open(file, "w") do io
        JSON3.pretty(io, notebook)
    end

    return file
end
