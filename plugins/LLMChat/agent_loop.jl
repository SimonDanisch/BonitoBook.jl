"""
Generic agent loop for LLM chat interactions.

Handles looping over agent prompts and cell creation.
The loop continues until:
1. The LLM responds with just text (no tool calls)
2. The stop_flag is set by the user
3. Maximum iterations are reached
"""

"""
    run_agent_loop!(book, agent, user_message::String, config::AgentConfig, task_spinner::TaskSpinner)

Main agent loop that:
1. Adds user message as a cell
2. Repeatedly calls prompt(agent) which returns a Channel of items (tools and text)
3. Processes each item from the Channel (allowing multiple tools/text per response)
4. Stops when text is encountered or stop_flag is set

Uses TaskSpinner for visual feedback at different levels.

Returns a Channel for any UI updates (currently unused but kept for future extensions).
"""
function run_agent_loop!(book, agent::Any, user_message::String, config::AgentConfig, task_spinner::TaskSpinner)
    # Add user message cell as Julia code with Markdown.parse
    user_markdown_code = "Markdown.parse($(repr(user_message)))"
    add_cell!(book, user_markdown_code, "julia", Dict{Symbol, Any}(:from => :user))
    async_spinner!(task_spinner, "agent loop", 1:50) do i
        # Get current conversation
        messages = cells_to_messages(book)
        # Call agent with nested spinner - returns Channel with multiple items (tools and text)
        result_channel = async_spinner!(task_spinner, "asking") do
            prompt(agent, messages, config.tools; spinner=task_spinner)
        end
        # Process all items from the channel
        async_spinner!(task_spinner, "processing ai", result_channel) do item
            process_item!(book, agent, item)
        end
        # Return true for stopping early
        isdone(agent) && return true
    end
    return
end

function isdone(agent::HTTPAgent)
    if !isempty(agent.needs_to_be_done)
        finished = all(isdone, values(agent.needs_to_be_done))
        if finished
            empty!(agent.needs_to_be_done)
        end
        return finished
    end
    return agent.last_item[] isa String
end

multi_task_tool(item) = false

function process_item!(book, agent::HTTPAgent, item)
    agent.last_item[] = item
    if multi_task_tool(item)
        agent.needs_to_be_done[typeof(item)] = item
    end
    try
        process_item!(book, item)
    catch e
        error_msg = "Error processing item of type $(typeof(item)): $(e)"
        process_item!(book, error_msg)
    end
end

"""
    process_item!(book, item)

Process a result item by converting it to a cell or executing tools.
Uses multiple dispatch to handle different item types.
"""
function process_item!(book, item::String)
    # Text content - create Julia code cell with Markdown.parse
    markdown_code = "Markdown.parse($(repr(item)))"
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

function store_tool_exe!(book, tool_execution, cell_id=book.cell_id_counter[])
     # Get next cell ID
    # Create data/tools directory if needed
    tools_dir = joinpath(book.folder, "data", "tools")
    if !isdir(tools_dir)
        mkpath(tools_dir)
    end
    # Write ToolExecution to JSON file
    tool_type = typeof(tool_execution.tool)
    tool_file = joinpath(tools_dir, "$(tool_name(tool_type))-$(cell_id).json")
    open(io-> JSON3.write(io, tool_execution), tool_file, "w")
    return tool_file
end


function process_item!(book, tool::AddCellTool)
    # AddCellTool is special - execute it and directly add the cell content
    metadata = something(tool.metadata, Dict{Symbol,Any}())
    metadata = merge(Dict{Symbol,Any}(:from => :agent, :tool => "add_cell"), metadata)
    cell = add_cell!(book, tool.content, tool.language, metadata; editor_visible=true)
    val = cell.editor.output[]
    result = ToolResult(repr(extract_output(val)))
    # Create ToolExecution and serialize it
    tool_execution = ToolExecution(tool, result)
    store_tool_exe!(book, tool_execution, cell.uuid)
    return cell
end

function process_item!(book, tool::AbstractTool)
    # Execute the tool and get result
    result = execute_tool!(tool)

    # Create ToolExecution
    tool_execution = ToolExecution(tool, result)
    path = store_tool_exe!(book, tool_execution)

    # Generate Julia code that reads the ToolExecution from the JSON file
    name = basename(path)
    tool_code = """open(io -> JSON3.read(io, $(typeof(tool_execution))), data"tools/$name")"""
    tool_type = tool_name(typeof(tool))
    # Add as Julia code cell (will be executed and rendered)
    cell = add_cell!(book, tool_code, "julia", Dict{Symbol, Any}(:from => :tool, :tool => tool_type))

    return cell  # Return the cell for TodoList tracking
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
