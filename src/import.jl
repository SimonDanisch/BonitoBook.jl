"""
    parse_cell_options(options_str)

Parse cell options from named tuple or legacy format.
Returns (show_editor, show_logging, show_output, id, metadata_dict)

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
            id = nothing
            metadata = Dict{Symbol, Any}()

            for pair in pairs
                key_val = split(strip(pair), "=", limit=2)
                if length(key_val) == 2
                    key = strip(key_val[1])
                    val_str = strip(key_val[2])

                    # Try to parse the value appropriately
                    val = try
                        # Try boolean first
                        if val_str in ("true", "false")
                            parse(Bool, val_str)
                        # Try integer
                        elseif occursin(r"^\d+$", val_str)
                            parse(Int, val_str)
                        # Try symbol (starts with :)
                        elseif startswith(val_str, ":")
                            Symbol(val_str[2:end])
                        # Otherwise keep as string (remove quotes if present)
                        else
                            strip(val_str, ['"', '\''])
                        end
                    catch
                        val_str
                    end

                    if key == "editor"
                        editor = val
                    elseif key == "logging"
                        logging = val
                    elseif key == "output"
                        output = val
                    elseif key == "id"
                        id = val
                    else
                        # Store additional metadata
                        metadata[Symbol(key)] = val
                    end
                end
            end

            return (editor, logging, output, id, metadata)
        catch e
            # Fall back to legacy format if parsing fails
            @debug "Failed to parse cell options as named tuple: $e"
        end
    end

    # Legacy format: space-separated booleans
    parts = split(options_str)
    if length(parts) == 3
        parsed = parse.(Bool, parts)
        return (parsed[1], parsed[2], parsed[3], nothing, Dict{Symbol, Any}())
    end

    # Default fallback
    return (true, false, true, nothing, Dict{Symbol, Any}())
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
    fallback_counter = Ref(1)  # Fallback counter for cells without id

    function append_last_md()
        if !isnothing(last_md) && !isempty(last_md)
            parsed = Markdown.MD(last_md, md.meta)
            id = fallback_counter[]
            fallback_counter[] += 1
            push!(cells, Cell("markdown", string(parsed), nothing, false, false, true, id, Dict{Symbol, Any}()))
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
                        show_editor, show_logging, show_output, id, metadata = parse_cell_options(options_str)
                    else
                        # Default show fields for all_blocks_as_cell mode
                        show_editor, show_logging, show_output, id, metadata = (true, false, true, nothing, Dict{Symbol, Any}())
                    end

                    # Use fallback counter if no id provided
                    if isnothing(id)
                        id = fallback_counter[]
                        fallback_counter[] += 1
                    end

                    push!(cells, Cell(language, content.code, nothing, show_editor, show_logging, show_output, id, metadata))
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
    # Read the json file
    json_content = JSON3.read(read(json_path))
    cells = Cell[]
    fallback_counter = Ref(1)  # Fallback counter for cells without id

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

            # Extract metadata from cell metadata if present
            metadata = Dict{Symbol, Any}()
            id = nothing
            if haskey(cell, "metadata") && haskey(cell["metadata"], "bonitobook")
                bb_meta = cell["metadata"]["bonitobook"]
                for (k, v) in pairs(bb_meta)
                    if k == "id"
                        id = v
                    elseif k != "show_editor" && k != "show_output" && k != "show_logging"
                        metadata[Symbol(k)] = v
                    end
                end
            end

            # Use fallback counter if no id
            if isnothing(id)
                id = fallback_counter[]
                fallback_counter[] += 1
            end

            if language == "markdown"
                show_editor, show_logging, show_output = (false, false, true)
            else
                show_editor, show_logging, show_output = (true, false, true)
            end
            isempty(source) || push!(cells, Cell(language, source, nothing, show_editor, show_logging, show_output, id, metadata))
        elseif cell_type == "markdown"
            source = join(cell["source"], "")
            id = fallback_counter[]
            fallback_counter[] += 1
            isempty(source) || push!(cells, Cell("markdown", source, nothing, false, false, true, id, Dict{Symbol, Any}()))
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
        # Detect whether the file is actually a Jupyter notebook (JSON) or
        # a markdown file with .ipynb extension (used by some BonitoBook examples).
        content = read(path, String)
        stripped = lstrip(content)
        if startswith(stripped, '{')
            return ipynb2book(path)
        else
            @info "File $path has .ipynb extension but contains markdown, loading as markdown"
            md = Markdown.parse(content)
            return markdown2book(md, all_blocks_as_cell=all_blocks_as_cell)
        end
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
function cells2editors(cells, runner, theme = Observable("default"), folder = "")
    return map(cells) do cell
        return CellEditor(
            cell.source, string(cell.language), runner;
            show_editor = cell.show_editor,
            show_logging = cell.show_logging,
            show_output = cell.show_output,
            theme = theme,
            metadata = cell.metadata,
            id = cell.id
        )
    end
end
