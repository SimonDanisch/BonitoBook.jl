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

Export book to static HTML file.

- `filename::String`: Output file path
- `book::Book`: Book to export
"""
function export_html(filename, book)
    return Bonito.export_static(filename, App(book))
end

struct InlineBook
    book::AbstractBook
end

function run_all!(book::AbstractBook)
    hasproperty(book, :book) && run_all!(book.book)
    return book
end

function run_all!(book::Book)
    for cell in book.cells
        run_sync!(cell.editor)
    end
    return book
end

function InlineBook(path::String; replace_style::Bool = false)
    book = create_book(path; replace_style=replace_style)
    run_all!(book)
    return InlineBook(book)
end

# Just render the whole book for any plugin
function export_dom(::Session, book::AbstractBook)
    return book
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

Export book to HTML with styling.

- `file::AbstractString`: Output file path
- `book::Book`: Book to export
"""
function export_html(file::AbstractString, book::Book)
    Bonito.export_static(file, App((s)-> export_dom(s, book)))
    return file
end

"""
    export_md(file, book)

Export book to markdown with cell metadata.

- `file::AbstractString`: Output file path
- `book::Book`: Book to export
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
            metadata = cell_editor.metadata

            # Build options string with metadata
            opts = ["editor=$show_editor", "logging=$show_logging", "output=$show_output"]

            # Add uuid as id
            push!(opts, "id=$(cell_editor.uuid)")

            # Add metadata fields
            for (key, val) in metadata
                val_str = if val isa Symbol
                    ":$val"
                elseif val isa String
                    "\"$val\""
                else
                    string(val)
                end
                push!(opts, "$key=$val_str")
            end

            opts_str = join(opts, ", ")
            # Use a fence long enough to not conflict with backticks in content
            fence = "```"
            while occursin(fence, content)
                fence *= "`"
            end
            println(io, "$fence$language ($opts_str)")
            println(io, content)
            println(io, fence)
        end
    end
    return file
end

"""
    cell_output_to_file(output_dir, cell_id, value) -> Union{String, Nothing}

Save a cell's output value to a file in the output directory.
Returns the relative path to the saved file, or nothing if the value can't be saved.

Tries formats in order: image/png, image/svg+xml, text/html, text/plain.
"""
function cell_output_to_file(output_dir::String, cell_id::Int, value)
    isnothing(value) && return nothing
    # Unwrap NoSplat
    if value isa NoSplat
        value = value.value
    end
    isnothing(value) && return nothing

    mkpath(output_dir)

    # Try PNG
    if showable(MIME"image/png"(), value)
        path = joinpath(output_dir, "cell_$(cell_id).png")
        open(path, "w") do io
            show(io, MIME"image/png"(), value)
        end
        return "cell_$(cell_id).png"
    end

    # Try SVG
    if showable(MIME"image/svg+xml"(), value)
        path = joinpath(output_dir, "cell_$(cell_id).svg")
        open(path, "w") do io
            show(io, MIME"image/svg+xml"(), value)
        end
        return "cell_$(cell_id).svg"
    end

    # Try text/html - save as .html snippet for reference
    if showable(MIME"text/html"(), value)
        path = joinpath(output_dir, "cell_$(cell_id).html")
        open(path, "w") do io
            show(io, MIME"text/html"(), value)
        end
        return "cell_$(cell_id).html"
    end

    # Fallback: text/plain
    path = joinpath(output_dir, "cell_$(cell_id).txt")
    open(path, "w") do io
        show(io, MIME"text/plain"(), value)
    end
    return "cell_$(cell_id).txt"
end

"""
    export_md_with_results(file, book; output_dir=nothing)

Export book to markdown with cell outputs inlined as images or code blocks.
Output files are saved to `output_dir` (defaults to `./<name>-bbook/data/output/`).

Images are referenced as `![](./path/to/output.png)` for GitHub markdown compatibility.

- `file::AbstractString`: Output file path
- `book::Book`: Book to export
- `output_dir`: Directory for output files (default: auto)
"""
function export_md_with_results(file::AbstractString, book::Book; output_dir::String = "")
    if isempty(output_dir)
        output_dir = joinpath(book.folder, "data", "output")
    end
    mkpath(output_dir)

    # Compute relative path from the markdown file to the output dir
    md_dir = dirname(abspath(file))
    rel_output_dir = relpath(abspath(output_dir), md_dir)

    open(file, "w") do io
        for cell_editor in book.cells
            language = cell_editor.language
            editor = cell_editor.editor
            content = editor.source[]

            if language == "markdown"
                println(io, content)
            else
                # Write the code block
                println(io, "```$language")
                println(io, content)
                println(io, "```")
                println(io)

                # Write the output
                output_val = editor.output[]
                output_file = cell_output_to_file(output_dir, cell_editor.uuid, output_val)
                if !isnothing(output_file)
                    rel_path = joinpath(rel_output_dir, output_file)
                    if endswith(output_file, ".png") || endswith(output_file, ".svg")
                        println(io, "![Output]($(rel_path))")
                    elseif endswith(output_file, ".html")
                        # Include HTML inline for GitHub (limited support)
                        println(io, "<!-- Output: $(rel_path) -->")
                    elseif endswith(output_file, ".txt")
                        txt = read(joinpath(output_dir, output_file), String)
                        if !isempty(strip(txt))
                            println(io, "```")
                            println(io, txt)
                            println(io, "```")
                        end
                    end
                end
            end
            println(io)
        end
    end
    return file
end

"""
    export_quarto(file, book)

Export book to Quarto format.

- `file::AbstractString`: Output file path
- `book::Book`: Book to export
"""
function export_quarto(file::AbstractString, book::Book)
    open(file, "w") do io
        for cell_editor in book.cells
            language = cell_editor.language
            editor = cell_editor.editor
            content = editor.source[]
            show_editor = editor.show_editor[]
            _ = editor.show_logging[]  # Not used in Quarto export
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
using JSON3, ZipFile, Pkg, p7zip_jll

"""
    export_ipynb(file, book)

Export book to Jupyter notebook format.

- `file::AbstractString`: Output file path
- `book::Book`: Book to export
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
        metadata = cell_editor.metadata

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
            _ = language == "julia" ? "julia" : language  # Not used currently

            # Build bonitobook metadata including cell metadata
            bb_meta = Dict(
                "show_editor" => show_editor,
                "show_output" => show_output
            )
            # Add additional metadata
            for (k, v) in metadata
                bb_meta[string(k)] = v
            end

            cell = Dict(
                "cell_type" => "code",
                "execution_count" => nothing,
                "metadata" => Dict(
                    "bonitobook" => bb_meta
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

"""
    export_zip(book::Book, zip_path::String)

Export a book and its Julia project to a ZIP file.

# Arguments
- `book::Book`: Book to export
- `zip_path::String`: Output ZIP file path

# Returns
Path to the exported ZIP file.

The ZIP contains:
- The book file (`.md` or `.ipynb`)
- The book's hidden folder structure (`.book-name-bbook/`)
- Project.toml and Manifest.toml from the current Julia project
- Any additional data files in the project directory

# Examples
```julia
book = Book("mybook.md")
export_zip(book, "mybook.zip")
```
"""
function export_zip(book::Book, zip_path::String)
    # Get project information
    project_path = dirname(Pkg.project().path)

    # Determine book file and its directory
    book_file = book.file
    book_dir = book.folder
    # Create temporary directory for staging
    temp_dir = mktempdir() do temp_dir
        cp(book_file, joinpath(temp_dir, basename(book_file)))
        cp(book_dir, joinpath(temp_dir, basename(book_dir)))
        project_toml = joinpath(project_path, "Project.toml")
        manifest_toml = joinpath(project_path, "Manifest.toml")
        cp(project_toml, joinpath(temp_dir, "Project.toml"))
        cp(manifest_toml, joinpath(temp_dir, "Manifest.toml"))
        run(`$(p7zip_jll.p7zip()) a -tzip $(zip_path) $(temp_dir)/\*`)
    end
    @info "Exported book to ZIP: $zip_path"
    return zip_path
end

"""
    import_zip(zip_path::String, target_dir::String="")

Import a book from a ZIP file created by export_zip.

# Arguments
- `zip_path::String`: Path to the ZIP file to import
- `target_dir::String`: Directory to extract to (default: uses zip filename)

# Returns
Path to the extracted book file.

# Examples
```julia
# Extract to directory named after zip file
book_path = import_zip("mybook.zip")

# Extract to specific directory
book_path = import_zip("mybook.zip", "/path/to/extract")
```
"""
function import_zip(zip_path::String, target_dir::String="")
    if !isfile(zip_path)
        error("ZIP file not found: $zip_path")
    end

    # Determine extraction directory
    if isempty(target_dir)
        zip_name = splitext(basename(zip_path))[1]
        target_dir = joinpath(dirname(zip_path), zip_name)
    end

    # Create target directory if it doesn't exist
    if !isdir(target_dir)
        mkpath(target_dir)
    elseif !isempty(readdir(target_dir))
        @warn "Target directory is not empty: $target_dir"
    end

    # Extract ZIP file
    run(`$(p7zip_jll.p7zip()) x -tzip -y -o$(target_dir) $(zip_path)`)
    book_file = joinpath(target_dir, basename(splitext(zip_path)[1]) * ".md")
    @info "Imported book from ZIP to: $book_file"
    return book_file, target_dir
end

# ============================================================================
# Typst / PDF Export
# ============================================================================

"""
    export_typst(file, book; output_dir="", style_path=nothing)

Export book to Typst markup. Uses `export_md_with_results` to generate markdown
with inlined outputs, then converts to Typst via CommonMark's `typst()` writer.

# Arguments
- `file::AbstractString`: Output .typ file path
- `book::Book`: Book to export
- `output_dir::String`: Directory for output files (default: auto)
- `style_path`: Custom style.typ path (default: loaded via `get_file_path`)
"""
function export_typst(file::AbstractString, book::Book; output_dir::String="", style_path=nothing)
    # Step 1: Generate markdown with results
    tmp_md = tempname() * ".md"
    export_md_with_results(tmp_md, book; output_dir=output_dir)

    # Step 2: Parse with CommonMark
    source = read(tmp_md, String)
    rm(tmp_md; force=true)

    parser = Bonito.bonito_parser()
    ast = parser(source)

    # Step 3: Convert to Typst markup
    typst_content = CommonMark.typst(ast)

    # Step 4: Load style template
    if style_path === nothing
        style_path, _ = get_file_path(book.folder, "style.typ")
    end
    style_content = if isfile(style_path)
        read(style_path, String)
    else
        ""
    end

    # Step 5: Write combined Typst file
    open(file, "w") do io
        if !isempty(style_content)
            println(io, style_content)
            println(io)
        end
        write(io, typst_content)
    end

    @info "Exported book to Typst: $file"
    return file
end

"""
    export_pdf(file, book; output_dir="", style_path=nothing)

Export book to PDF via Typst. Generates a .typ intermediate file,
then compiles it with `typst compile`.

# Arguments
- `file::AbstractString`: Output .pdf file path
- `book::Book`: Book to export
- `output_dir::String`: Directory for output files (default: auto)
- `style_path`: Custom style.typ path (default: loaded via `get_file_path`)
"""
function export_pdf(file::AbstractString, book::Book; output_dir::String="", style_path=nothing)
    # Generate .typ intermediate
    typ_file = tempname() * ".typ"
    export_typst(typ_file, book; output_dir=output_dir, style_path=style_path)

    # Compile with Typst
    try
        run(`$(Typst_jll.typst()) compile $(typ_file) $(file)`)
        @info "Exported book to PDF: $file"
    finally
        rm(typ_file; force=true)
    end

    return file
end
