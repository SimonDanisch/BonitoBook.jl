"""
Generic agent loop for LLM chat interactions.

Handles looping over agent prompts and cell creation.
The loop continues until:
1. The LLM responds with just text (no tool calls)
2. The stop_flag is set by the user
3. Maximum iterations are reached
"""

"""
    run_agent_loop!(book, agent, user_message::String, config::AgentConfig, stop_flag::Threads.Atomic{Bool})

Main agent loop that:
1. Adds user message as a cell
2. Repeatedly calls prompt(agent) which returns a Channel of items (tools and text)
3. Processes each item from the Channel (allowing multiple tools/text per response)
4. Stops when text is encountered or stop_flag is set

Returns a Channel for any UI updates (currently unused but kept for future extensions).
"""
function run_agent_loop!(book, agent::Any, user_message::String, config::AgentConfig, stop_flag::Threads.Atomic{Bool})
    output_channel = Channel{Any}(100)
    # Add user message cell as Julia code with Markdown.parse
    user_markdown_code = "Markdown.parse(\"\"\"$user_message\"\"\")"
    add_cell!(book, user_markdown_code, "julia", Dict{Symbol, Any}(:from => :user))
    # Run agent loop in background
    @async begin
        try
            broke = false
            for i in 1:20
                # Check stop flag
                if stop_flag[]
                    break
                end
                # Get current conversation
                messages = cells_to_messages(book.cells)

                # Call agent - returns Channel with multiple items (tools and text)
                result_channel = prompt(agent, messages, config.tools)

                # Process all items from the channel
                last_item = nothing
                for item in result_channel
                    # Process each item
                    process_item!(book, item)
                    put!(output_channel, item)
                end

                # If we got text, break the loop
                if last_item isa AbstractString
                    broke = true
                    break
                end
            end
        catch e
            @error "Agent loop error" exception=(e, catch_backtrace())
            error_msg = "Error: $(sprint(showerror, e))"
            add_cell!(book, error_msg, "markdown", Dict{Symbol, Any}(:from => :error))
        finally
            close(output_channel)
        end
    end

    return output_channel
end

"""
    process_item!(book, item)

Process a result item by converting it to a cell or executing tools.
Uses multiple dispatch to handle different item types.
"""
function process_item!(book, item::String)
    # Text content - create Julia code cell with Markdown.parse
    markdown_code = "Markdown.parse(\"\"\"$item\"\"\")"
    add_cell!(book, markdown_code, "julia", Dict{Symbol, Any}(:from => :agent))
end

function process_item!(book, item::Dict)
    # Direct cell creation (from backend)
    if haskey(item, :type) && item[:type] == :cell
        metadata = merge(Dict{Symbol, Any}(:from => :agent), get(item, :metadata, Dict()))
        add_cell!(book, item[:content], item[:language], metadata)
    end
end

extract_output(value) = value
extract_output(value::BonitoBook.NoSplat) = value.value

function process_item!(book, tool::AddCellTool)
    # AddCellTool is special - execute it and directly add the cell content
    metadata = something(tool.metadata, Dict{Symbol,Any}())
    metadata = merge(Dict{Symbol,Any}(:from => :agent), metadata)
    cell = add_cell!(book, tool.content, tool.language, metadata; editor_visible=true)
    val = cell.editor.output[]
    tool.result = Dict("success" => true, "result" => extract_output(val))
end

function process_item!(book, tool::AbstractTool)
    # Execute the tool
    execute_tool!(tool)
    # Get next cell ID
    cell_id = book.cell_id_counter[]
    # Create data/tools directory if needed
    tools_dir = joinpath(book.folder, "data", "tools")
    if !isdir(tools_dir)
        mkpath(tools_dir)
    end
    # Write tool to JSON file
    tool_type = typeof(tool)
    tool_file = joinpath(tools_dir, "$(tool_name(tool_type))-$(cell_id).json")
    write(tool_file, JSON3.write(tool))

    # Generate Julia code that reads the tool from the JSON file
    name = "$(tool_name(tool_type))-$(cell_id).json"
    tool_code = """JSON3.read(read(data"tools/$name", String), $(nameof(tool_type)))"""

    # Add as Julia code cell (will be executed and rendered)
    cell = add_cell!(book, tool_code, "julia", Dict{Symbol, Any}(:from => :tool, :tool => tool_name(tool_type)))

end

# Fallback for other types (DOM elements, etc.) - ignore
function process_item!(book, item)
    # Do nothing for unhandled types
    nothing
end


"""
    add_cell!(book, content::String, language::String, metadata::Dict)

Add a cell to the notebook.
"""
function add_cell!(book, content::String, language::String, metadata::Dict; editor_visible=false)
    # Get next ID from book's counter
    cell_id = book.cell_id_counter[]
    book.cell_id_counter[] += 1

    cell = BonitoBook.CellEditor(
        content,
        language,
        book.runner;
        show_editor=editor_visible,
        show_output = true,
        theme = book.monaco_theme,
        metadata = metadata,
        id = cell_id
    )

    # Insert cell at end
    if isempty(book.cells)
        BonitoBook.insert_editor_below!(book, cell, "beginning")
    else
        last_cell_uuid = book.cells[end].uuid
        BonitoBook.insert_editor_below!(book, cell, last_cell_uuid)
    end

    # Auto-run code cells
    if language == "julia" || language == "python"
        BonitoBook.run_sync!(cell.editor)
    end
    return cell
end
