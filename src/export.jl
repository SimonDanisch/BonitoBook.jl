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
            if language == "markdown"
                println(io, content)
            else
                println(io, "```$language (editor=$show_editor, logging=$show_logging, output=$show_output)")
                println(io, content)
                println(io, "```")
            end
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
using JSON3, ZipFile, Pkg

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
    project_path = Pkg.project().path
    project_dir = dirname(project_path)
    
    # Determine book file and its directory
    book_file = book.file
    book_dir = dirname(book_file)
    book_name = splitext(basename(book_file))[1]
    
    # Create temporary directory for staging
    temp_dir = mktempdir()
    
    try
        # Create the main project structure in temp directory
        zip_content_dir = joinpath(temp_dir, book_name)
        mkpath(zip_content_dir)
        
        # Copy Project.toml and Manifest.toml if they exist
        project_toml = joinpath(project_dir, "Project.toml")
        manifest_toml = joinpath(project_dir, "Manifest.toml")
        
        if isfile(project_toml)
            cp(project_toml, joinpath(zip_content_dir, "Project.toml"))
        end
        
        if isfile(manifest_toml)
            cp(manifest_toml, joinpath(zip_content_dir, "Manifest.toml"))
        end
        
        # Copy the book file
        book_basename = basename(book_file)
        cp(book_file, joinpath(zip_content_dir, book_basename))
        
        # Copy the book's hidden folder structure
        if isdir(book.folder)
            hidden_folder_name = basename(book.folder)
            cp(book.folder, joinpath(zip_content_dir, hidden_folder_name))
        end
        
        # Copy additional data files/folders in the book directory (but not other books)
        for item in readdir(book_dir)
            item_path = joinpath(book_dir, item)
            
            # Skip the book file itself and other book files, and hidden book folders
            if item == book_basename || 
               endswith(item, ".md") || 
               endswith(item, ".ipynb") ||
               startswith(item, ".") ||
               item in ["Project.toml", "Manifest.toml"]
                continue
            end
            
            # Copy data directories and files
            if isdir(item_path)
                cp(item_path, joinpath(zip_content_dir, item))
            elseif isfile(item_path)
                cp(item_path, joinpath(zip_content_dir, item))
            end
        end
        
        # Create ZIP file
        w = ZipFile.Writer(zip_path)
        try
            # Add all files recursively
            for (root, dirs, files) in walkdir(zip_content_dir)
                for file in files
                    file_path = joinpath(root, file)
                    # Calculate relative path within zip
                    rel_path = relpath(file_path, temp_dir)
                    
                    # Add file to zip
                    zip_file = ZipFile.addfile(w, rel_path)
                    write(zip_file, read(file_path))
                end
            end
        finally
            close(w)
        end
        
    finally
        # Clean up temporary directory
        rm(temp_dir; recursive=true, force=true)
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
    
    book_file = nothing
    
    # Extract ZIP file
    r = ZipFile.Reader(zip_path)
    try
        for file in r.files
            if file.uncompressedsize == 0
                # Skip directories
                continue
            end
            
            # Determine output path
            output_path = joinpath(target_dir, file.name)
            output_dir = dirname(output_path)
            
            # Create directory structure
            if !isdir(output_dir)
                mkpath(output_dir)
            end
            
            # Extract file
            open(output_path, "w") do io
                write(io, read(file, String))
            end
            
            # Track the main book file
            if endswith(file.name, ".md") || endswith(file.name, ".ipynb")
                # Look for book files in the root of the extracted content
                if count('/', file.name) == 1  # One level deep (project/book.md)
                    book_file = output_path
                end
            end
        end
    finally
        close(r)
    end
    
    if book_file === nothing
        # Fallback: look for any .md or .ipynb file in the extracted directory
        for (root, dirs, files) in walkdir(target_dir)
            for file in files
                if endswith(file, ".md") || endswith(file, ".ipynb")
                    book_file = joinpath(root, file)
                    break
                end
            end
            book_file !== nothing && break
        end
    end
    
    if book_file === nothing
        error("No book file (.md or .ipynb) found in ZIP archive")
    end
    
    @info "Imported book from ZIP to: $book_file"
    return book_file
end
