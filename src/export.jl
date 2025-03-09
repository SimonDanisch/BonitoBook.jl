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
