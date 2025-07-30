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

"""
    export_jl(file, book)

Export a book to a Julia-specific HTML format with styling.

# Arguments
- `file`: Output file path
- `book::Book`: Book to export

# Returns
Path to the exported file.
"""
function export_jl(file::AbstractString, book::Book)
    app = App() do s
        body = Centered(DOM.div(book.cells...))
        document = DOM.div(DOM.div(body; style = Styles("width" => "100%")))
        # Inject script to set export mode global variable and add CSS class
        export_mode_script = js"""
            window.BONITO_EXPORT_MODE = true;
            document.body.classList.add('bonito-export-mode');
        """
        return DOM.div(book.style_eval.last_valid_output, export_mode_script, document)
    end
    Bonito.export_static(file, app)
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
