"""
Generic agent loop for LLM chat interactions.

Handles looping over agent prompts and cell creation.
The loop continues until:
1. The LLM responds with just text (no tool calls)
2. The stop_flag is set by the user
3. Maximum iterations are reached
"""

"""
    run_with_spinner!(func, spinner, stop_flag::Threads.Atomic{Bool};
                      timeout=300.0, poll_interval=0.1)

Run a function with a spinner and proper cancellation support.
Uses polling to check stop_flag and timeout while task runs.

# Arguments
- `func`: Function to run (should be interruptible)
- `spinner`: Spinner to show during execution
- `stop_flag`: Atomic bool for cancellation
- `timeout`: Maximum execution time in seconds (default 300s = 5min)
- `poll_interval`: How often to check stop_flag in seconds (default 0.1s)

# Returns
The result of `func()` or `nothing` if stopped/timed out

# Throws
- `TaskFailedException`: If the task errors
- `TimeoutError`: If timeout is reached
"""
function run_with_spinner!(func, spinner, stop_flag::Threads.Atomic{Bool};
                           timeout=300.0, poll_interval=0.1)
    # Show spinner
    spinner.visible[] = true

    # Start the task
    task = @async func()

    result = nothing
    start_time = time()

    try
        # Poll until task completes, stop_flag is set, or timeout
        while !istaskdone(task)
            # Check stop flag
            if stop_flag[]
                @info "Task cancelled by stop flag"
                # Try to interrupt the task
                try
                    Base.schedule(task, InterruptException(); error=true)
                catch
                end
                break
            end

            # Check timeout
            if time() - start_time > timeout
                @warn "Task timed out after $(timeout)s"
                try
                    Base.schedule(task, InterruptException(); error=true)
                catch
                end
                throw(ErrorException("Task timed out after $(timeout)s"))
            end

            # Sleep briefly before checking again
            sleep(poll_interval)
        end

        # If task completed naturally, get the result
        if istaskdone(task) && !stop_flag[]
            result = fetch(task)
        end

    catch e
        if !isa(e, InterruptException)
            @error "Error in run_with_spinner!" exception=(e, catch_backtrace())
            rethrow(e)
        end
    finally
        # Always hide spinner
        spinner.visible[] = false
    end

    return result
end

"""
    run_agent_loop!(book, agent, user_message::String, config::AgentConfig, stop_flag::Threads.Atomic{Bool};
                    http_spinner=nothing, channel_spinner=nothing, loop_spinner=nothing)

Main agent loop that:
1. Adds user message as a cell
2. Repeatedly calls prompt(agent) which returns a Channel of items (tools and text)
3. Processes each item from the Channel (allowing multiple tools/text per response)
4. Stops when text is encountered or stop_flag is set

Optional spinner arguments for visual feedback at different levels.

Returns a Channel for any UI updates (currently unused but kept for future extensions).
"""
function run_agent_loop!(book, agent::Any, user_message::String, config::AgentConfig, stop_flag::Threads.Atomic{Bool};
                         http_spinner=nothing, channel_spinner=nothing, loop_spinner=nothing)
    output_channel = Channel{Any}(100)
    # Add user message cell as Julia code with Markdown.parse
    user_markdown_code = "Markdown.parse(\"\"\"$user_message\"\"\")"
    add_cell!(book, user_markdown_code, "julia", Dict{Symbol, Any}(:from => :user))
    # Run agent loop in background
    @async begin
        try
            broke = false
            for i in 1:20
                # Show loop spinner for this iteration
                if loop_spinner !== nothing
                    loop_spinner.visible[] = true
                end

                # Check stop flag
                if stop_flag[]
                    @info "Agent loop stopped by stop flag"
                    break
                end

                # Get current conversation
                messages = cells_to_messages(book.cells)

                # Call agent with HTTP spinner - returns Channel with multiple items (tools and text)
                result_channel = prompt(agent, messages, config.tools;
                                       spinner=http_spinner, stop_flag=stop_flag)

                # Show channel spinner while processing results
                if channel_spinner !== nothing
                    channel_spinner.visible[] = true
                end

                # Process all items from the channel
                last_item = nothing
                for item in result_channel
                    # Check stop flag while processing
                    if stop_flag[]
                        @info "Channel processing stopped by stop flag"
                        break
                    end

                    # Process each item
                    process_item!(book, item)
                    put!(output_channel, item)
                    last_item = item
                end

                # Hide channel spinner after processing
                if channel_spinner !== nothing
                    channel_spinner.visible[] = false
                end

                # Hide loop spinner after iteration
                if loop_spinner !== nothing
                    loop_spinner.visible[] = false
                end

                # If we got text, break the loop
                if last_item isa AbstractString
                    broke = true
                    break
                end

                # Check stop flag before next iteration
                if stop_flag[]
                    break
                end
            end
        catch e
            if !isa(e, InterruptException)
                @error "Agent loop error" exception=(e, catch_backtrace())
                error_msg = "Error: $(sprint(showerror, e))"
                add_cell!(book, error_msg, "markdown", Dict{Symbol, Any}(:from => :error))
            end
        finally
            # Hide all spinners
            if http_spinner !== nothing
                http_spinner.visible[] = false
            end
            if channel_spinner !== nothing
                channel_spinner.visible[] = false
            end
            if loop_spinner !== nothing
                loop_spinner.visible[] = false
            end
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
    metadata = merge(Dict{Symbol,Any}(:from => :agent, :tool => "add_cell"), metadata)
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
