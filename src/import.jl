using JSON, Markdown

"""
    parse_cell_options(options_str)

Parse cell options from named tuple or legacy format.

- `options_str::String`: Options string
"""
function parse_cell_options(options_str)
    options_str = strip(options_str)

    # Try to parse as named tuple format first
    if startswith(options_str, "(") && endswith(options_str, ")")
        try
            # Remove parentheses and parse as NamedTuple
            inner = strip(options_str[2:end-1])

            # Parse each key=value pair
            pairs = split(inner, ",")
            editor = true
            logging = false
            output = true

            for pair in pairs
                key_val = split(strip(pair), "=")
                if length(key_val) == 2
                    key = strip(key_val[1])
                    val = parse(Bool, strip(key_val[2]))
                    if key == "editor"
                        editor = val
                    elseif key == "logging"
                        logging = val
                    elseif key == "output"
                        output = val
                    end
                end
            end

            return (editor, logging, output)
        catch
            # Fall back to legacy format if parsing fails
        end
    end

    # Legacy format: space-separated booleans
    parts = split(options_str)
    if length(parts) == 3
        return parse.(Bool, parts)
    end

    # Default fallback
    return (true, false, true)
end

"""
    markdown2book(md; all_blocks_as_cell=false)

Parse markdown document into book cells.

- `md`: Parsed markdown document
- `all_blocks_as_cell::Bool`: Treat all code blocks as cells
"""
function markdown2book(md; all_blocks_as_cell = false)
    cells = Cell[]
    last_md = nothing
    function append_last_md()
        if !isnothing(last_md) && !isempty(last_md)
            parsed = Markdown.MD(last_md, md.meta)
            push!(cells, Cell("markdown", string(parsed)))
            last_md = nothing
        end
        return
    end
    for content in md.content
        if content isa Markdown.Code
            code_parts = split(content.language, " ", limit=2)
            language = code_parts[1]
            if !isempty(language) && language in ("markdown", "julia", "python")
                # Check if this is a code cell with options
                has_options = length(code_parts) == 2 && !isempty(strip(code_parts[2]))

                if all_blocks_as_cell || has_options
                    append_last_md()

                    if has_options
                        options_str = strip(code_parts[2])
                        show_fields = parse_cell_options(options_str)
                    else
                        # Default show fields for all_blocks_as_cell mode
                        show_fields = (true, false, true)
                    end
                    push!(cells, Cell(language, content.code, nothing, show_fields...))
                else
                    # Otherwise we treat it as inline markdown code block
                    isnothing(last_md) && (last_md = [])
                    push!(last_md, content)
                end
            else
                # Handle unknown languages by treating as markdown
                isnothing(last_md) && (last_md = [])
                push!(last_md, content)
            end
        else
            isnothing(last_md) && (last_md = [])
            push!(last_md, content)
        end
    end
    append_last_md()
    return cells
end

"""
    ipynb2book(json_path)

Convert a Jupyter notebook file to book cells.

# Arguments
- `json_path`: Path to the .ipynb file

# Returns
Vector of `Cell` objects representing the notebook content.
"""
function ipynb2book(json_path::String)
    # Read the JSON file
    json_content = JSON.parsefile(json_path)
    cells = Cell[]
    for cell in json_content["cells"]
        cell_type = cell["cell_type"]
        if cell_type == "code"
            source = join(cell["source"], "")
            # Safe access to kernelspec language
            language = "julia"  # default
            if haskey(json_content, "metadata") &&
                    haskey(json_content["metadata"], "kernelspec") &&
                    haskey(json_content["metadata"]["kernelspec"], "language")
                language = json_content["metadata"]["kernelspec"]["language"]
            end
            if language == "markdown"
                fields = (false, false, true)
            else
                fields = (true, false, true)
            end
            isempty(source) || push!(cells, Cell(language, source, nothing, fields...))
        elseif cell_type == "markdown"
            source = join(cell["source"], "")

            isempty(source) || push!(cells, Cell("markdown", source))
        end
    end
    return cells
end

"""
    load_book(path)

Load a book from a file path, supporting both markdown (.md) and Jupyter notebook (.ipynb) formats.

# Arguments
- `path`: Path to the book file

# Returns
Vector of `Cell` objects representing the book content.

# Supported formats
- `.md`: Markdown files with embedded code blocks
- `.ipynb`: Jupyter notebook files
"""
function load_book(path; all_blocks_as_cell=false)
    if endswith(path, ".ipynb")
        return ipynb2book(path)
    elseif endswith(path, ".md")
        md = Markdown.parse_file(path)
        return markdown2book(md, all_blocks_as_cell=all_blocks_as_cell)
    else
        error("Unsupported file format. Only .ipynb and .md files are supported.")
    end
end

"""
    cells2editors(cells, runner)

Convert a vector of cells to interactive cell editors.

# Arguments
- `cells`: Vector of `Cell` objects
- `runner`: Code execution runner

# Returns
Vector of `CellEditor` objects ready for interactive use.
"""
function cells2editors(cells, runner)
    return map(cells) do cell
        return CellEditor(
            cell.source, string(cell.language), runner;
            show_editor = cell.show_editor,
            show_logging = cell.show_logging,
            show_output = cell.show_output
        )
    end
end
