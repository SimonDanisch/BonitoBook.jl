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

# Parsed cells (`markdown2book`, `ipynb2book`): a cell without an explicit id
# arrives with 0. Free ids start past the largest explicit one, so a file that
# mixes `id=`-tagged cells with plain markdown never gives two cells one id, and
# the same file always parses to the same ids (`apply_file_changes!` matches on them).
# An id the file repeats stays with its first cell; the later ones get free ids
# (books saved while the old parser counted prose cells into tagged ids carry such
# repeats, e.g. docs/examples/intro.md).
function assign_cell_ids!(cells::Vector{Cell})
    counter = Ref(maximum(c -> c.id, cells; init = 0) + 1)
    taken = Set{Int}()
    for (i, c) in enumerate(cells)
        if c.id != 0 && !(c.id in taken)
            push!(taken, c.id)
        else
            cells[i] = Cell(c.language, c.source, c.output, c.show_editor, c.show_logging, c.show_output,
                            counter[], c.metadata)
            counter[] += 1
        end
    end
    return counter
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

    # Cells without an explicit `id=` get 0 here and a free id at the end.
    function append_last_md()
        if !isnothing(last_md) && !isempty(last_md)
            parsed = Markdown.MD(last_md, md.meta)
            push!(cells, Cell("markdown", string(parsed), nothing, false, false, true, 0, Dict{Symbol, Any}()))
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

                    push!(cells, Cell(language, content.code, nothing, show_editor, show_logging, show_output,
                                      something(id, 0), metadata))
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
    assign_cell_ids!(cells)
    return cells
end

"""
    read_ipynb(io::IO; default_language="julia")
    read_ipynb(path::AbstractString; default_language="julia")

Read a Jupyter notebook without executing it. Returns a named tuple with
`language`, notebook `metadata` and ordered `cells`. Each cell has `cell_type`,
joined `source`, `metadata` and saved `outputs`. Output dictionaries retain all
MIME representations, stream text and error tracebacks as stored in the file.
Empty and raw cells are retained for viewers; `ipynb2book` converts the supported
cells into runnable BonitoBook cells.
"""
function read_ipynb(io::IO; default_language::AbstractString = "julia")
    notebook = JSON3.read(read(io, String), Dict{String, Any})
    metadata = get(notebook, "metadata", Dict{String, Any}())
    language = String(get(get(metadata, "kernelspec", Dict{String, Any}()),
                          "language", default_language))
    cells = map(get(notebook, "cells", [])) do cell
        source = get(cell, "source", "")
        return (cell_type = String(get(cell, "cell_type", "code")),
                source = source isa AbstractString ? String(source) : join(source),
                metadata = get(cell, "metadata", Dict{String, Any}()),
                outputs = get(cell, "outputs", []))
    end
    return (language = language, metadata = metadata, cells = cells)
end

read_ipynb(path::AbstractString; default_language::AbstractString = "julia") =
    open(io -> read_ipynb(io; default_language), path)

"""
    ipynb2book(json_path)

Convert a Jupyter notebook file to book cells.

# Arguments
- `json_path`: Path to the .ipynb file

# Returns
Vector of `Cell` objects representing the notebook content.
"""
function ipynb2book(json_path::String)
    notebook = read_ipynb(json_path)
    cells = Cell[]

    # Cells without a `bonitobook.id` get 0 here and a free id at the end.
    for cell in notebook.cells
        cell_type = cell.cell_type
        if cell_type == "code"
            source = cell.source
            language = notebook.language

            # Extract metadata from cell metadata if present
            metadata = Dict{Symbol, Any}()
            id = nothing
            if haskey(cell.metadata, "bonitobook")
                bb_meta = cell.metadata["bonitobook"]
                for (k, v) in pairs(bb_meta)
                    if k == "id"
                        id = v
                    elseif k != "show_editor" && k != "show_output" && k != "show_logging"
                        metadata[Symbol(k)] = v
                    end
                end
            end

            if language == "markdown"
                show_editor, show_logging, show_output = (false, false, true)
            else
                show_editor, show_logging, show_output = (true, false, true)
            end
            isempty(source) || push!(cells, Cell(language, source, nothing, show_editor, show_logging, show_output,
                                                 something(id, 0), metadata))
        elseif cell_type == "markdown"
            source = cell.source
            isempty(source) || push!(cells, Cell("markdown", source, nothing, false, false, true, 0, Dict{Symbol, Any}()))
        end
    end
    assign_cell_ids!(cells)
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
            id = cell.id,
            folder = folder
        )
    end
end
