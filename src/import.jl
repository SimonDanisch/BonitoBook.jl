using JSON, Markdown

function markdown2book(md; all_blocks_as_cell = false)
    cells = Cell[]
    last_md = nothing
    function append_last_md()
        return if !isnothing(last_md) && !isempty(last_md)
            parsed = Markdown.MD(last_md, md.meta)
            push!(cells, Cell("markdown", string(parsed)))
            last_md = nothing
        end
    end
    for content in md.content
        if content isa Markdown.Code
            languages = split(content.language, " ")
            language = languages[1]
            if language in ("markdown", "julia", "python")
                # We only treat ```language bool bool bool bool as a code block (our format)
                # Option to force all blocks as code blocks, for markdown not written by us
                if all_blocks_as_cell || length(languages) == 5
                    append_last_md()
                    show_fields = parse.(Bool, languages[2:end])
                    push!(cells, Cell(language, content.code, nothing, show_fields...))
                else
                    # Otherwise we treat it as inline markdown code block
                    isnothing(last_md) && (last_md = [])
                    push!(last_md, content)
                end
            end
        else
            isnothing(last_md) && (last_md = [])
            push!(last_md, content)
        end
    end
    append_last_md()
    return cells
end

function ipynb2book(json_path::String)
    # Read the JSON file
    json_content = JSON.parsefile(json_path)
    cells = Cell[]
    for cell in json_content["cells"]
        cell_type = cell["cell_type"]
        if cell_type == "code"
            source = join(cell["source"], "")
            language = json_content["metadata"]["kernelspec"]["language"]
            if language == "markdown"
                fields = (false, false, true, false)
            else
                fields = (true, false, true, false)
            end
            isempty(source) || push!(cells, Cell(language, source, nothing, fields...))
        elseif cell_type == "markdown"
            source = join(cell["source"], "")

            isempty(source) || push!(cells, Cell("markdown", source))
        end
    end
    return cells
end

function load_book(path)
    if endswith(path, ".ipynb")
        return ipynb2book(path)
    elseif endswith(path, ".md")
        md = Markdown.parse_file(path)
        return markdown2book(md)
    else
        error("Unsupported file format. Only .ipynb and .md files are supported.")
    end
end

function cells2editors(cells, runner)
    return map(cells) do cell
        return CellEditor(
            cell.source, string(cell.language), runner;
            show_editor = cell.show_editor,
            show_logging = cell.show_logging,
            show_output = cell.show_output,
            show_chat = cell.show_chat
        )
    end
end
