const asset = Asset("https://cdnjs.cloudflare.com/ajax/libs/html-to-image/1.10.10/html-to-image.min.js")

function export_svg(element)
    return js"""(()=> {
        function filter (node) {
            return (node.tagName !== 'SCRIPT');
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
end

function export_html(filename, book)
    Bonito.export_static(filename, App(book))
end

function export_jl(file::AbstractString, book::Book)
    app = App() do s
        body = Centered(DOM.div(book.cells...))
        document = DOM.div(DOM.div(body; style=Styles("width" => "100%")))
        return DOM.div(book.style_editor.editor.output, document)
    end
    Bonito.export_static(file, app)
    return file
end

function export_md(file::AbstractString, book::Book)
    open(file, "w") do io
        for cell_editor in book.cells
            language = cell_editor.language
            editor = cell_editor.editor
            content = editor.source[]
            show_editor = editor.show_editor[]
            show_logging = editor.show_logging[]
            show_output = editor.show_output[]
            show_chat = cell_editor.show_ai[]
            if language == "markdown"
                println(io, content)
            else
                println(io, "```$language $(show_editor) $(show_logging) $(show_output) $(show_chat)")
                println(io, content)
                println(io, "```")
            end
        end
    end
    return file
end
