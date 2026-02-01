function execute_markdown(filepath::String)
    content = read(filepath, String)
    md = Markdown.parse(content)
    for block in md.content
        if block isa Markdown.Code && block.language == "julia"
            include_string(Main, block.code)
        end
    end
end