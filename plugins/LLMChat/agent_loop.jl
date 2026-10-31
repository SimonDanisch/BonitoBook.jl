"""
Generic agent loop for LLM chat interactions.

Handles looping over agent prompts and cell creation.
The loop continues until:
1. The LLM responds with just text (no tool calls)
2. The stop_flag is set by the user
3. Maximum iterations are reached
"""

"""
    unwrap_exception(e)

Recursively unwrap nested exceptions (TaskFailedException, HTTP.RequestError, etc.)
to find the root cause. Returns a tuple (root_exception, original_exception).
"""
function unwrap_exception(e)
    original = e
    while true
        if e isa Base.TaskFailedException
            # Get the exception from the failed task
            e = e.task.result
        elseif hasproperty(e, :error) && e.error isa Exception
            # HTTP.RequestError and similar wrappers
            e = e.error
        else
            break
        end
    end
    return (e, original)
end

"""
    find_prompt_too_long_error(e)

Search through nested exceptions to find a PromptTooLongError.
Returns the PromptTooLongError if found, nothing otherwise.
"""
function find_prompt_too_long_error(e)
    root, _ = unwrap_exception(e)
    if root isa PromptTooLongError
        return root
    end
    return nothing
end

"""
    CompactingResult

Result of compacting messages to fit within token limits.

# Fields
- `messages::Vector{AgentMessage}`: The compacted messages
- `estimated_tokens::Int`: Estimated token count after compacting
- `keep_last::Union{Int, Nothing}`: Final keep_last setting used
- `min_size::Union{Int, Nothing}`: Final min_size setting used
- `attempts::Int`: Number of compacting iterations performed
- `success::Bool`: Whether compacting succeeded (tokens under limit)
"""
struct CompactingResult
    messages::Vector{AgentMessage}
    estimated_tokens::Int
    keep_last::Union{Int, Nothing}
    min_size::Union{Int, Nothing}
    attempts::Int
    success::Bool
end

"""
    compact_messages_to_fit(book, agent; keep_last=nothing, min_size=nothing, max_attempts=10)

Compact conversation messages to fit within the API's token limit.

Iteratively increases compacting aggressiveness until messages fit or max_attempts reached.

# Arguments
- `book`: The notebook containing conversation cells
- `agent`: The HTTPAgent (provides token limit and estimation)
- `keep_last`: Initial keep_last setting (default: nothing = use default 5)
- `min_size`: Initial min_size setting (default: nothing = use default 500)
- `max_attempts`: Maximum compacting iterations (default: 10)

# Returns
A `CompactingResult` with the compacted messages and metadata.

# Example
```julia
result = compact_messages_to_fit(book, agent)
if result.success
    # Use result.messages for API call
else
    # Handle context limit exceeded
end
```
"""
function compact_messages_to_fit(book, agent;
    keep_last::Union{Int, Nothing}=nothing,
    min_size::Union{Int, Nothing}=nothing,
    max_attempts::Int=10)

    # Get token limit for this API
    token_limit = context_limit(agent.api)
    # Leave 10% headroom for response tokens
    max_input_tokens = Int(floor(token_limit * 0.9))

    # Get messages with current compacting settings
    messages = cells_to_messages(book; keep_last=keep_last, min_size=min_size)
    estimated_tokens = estimate_request_tokens(agent, messages)

    attempts = 0

    while estimated_tokens > max_input_tokens && attempts < max_attempts
        attempts += 1
        ratio = estimated_tokens / max_input_tokens

        # Increase compacting aggressiveness based on how much we need to cut
        current_keep_last = something(keep_last, 5)
        current_min_size = something(min_size, 500)

        if ratio > 1.5
            keep_last = max(0, current_keep_last - 2)
            min_size = max(10, current_min_size ÷ 4)
        elseif ratio > 1.2
            keep_last = max(0, current_keep_last - 1)
            min_size = max(50, current_min_size ÷ 2)
        else
            keep_last = max(0, current_keep_last - 1)
            min_size = max(100, current_min_size - 100)
        end

        @info "Proactive compacting" attempt=attempts estimated_tokens max_input_tokens ratio=round(ratio, digits=2) new_keep_last=keep_last new_min_size=min_size

        # Re-fetch messages with new compacting settings
        messages = cells_to_messages(book; keep_last=keep_last, min_size=min_size)
        estimated_tokens = estimate_request_tokens(agent, messages)
    end

    success = estimated_tokens <= max_input_tokens
    return CompactingResult(messages, estimated_tokens, keep_last, min_size, attempts, success)
end

"""
    run_agent_loop!(book, agent::HTTPAgent, user_message::String, task_spinner::TaskSpinner, sanitizer_config::SanitizerConfig, file_editor)

Main agent loop that:
1. Adds user message as a cell
2. Repeatedly calls prompt(agent) which returns a Channel of items (tools and text)
3. Processes each item from the Channel (allowing multiple tools/text per response)
4. Stops when text is encountered or stop_flag is set

Uses TaskSpinner for visual feedback at different levels.
Uses sanitizer_config to validate code before execution.
Uses file_editor to automatically open files when file tools are used.

Returns a Channel for any UI updates (currently unused but kept for future extensions).
"""
function run_agent_loop!(book, agent::HTTPAgent, user_message::String, task_spinner::TaskSpinner, sanitizer_config::SanitizerConfig, file_editor)
    # Add user message cell as Julia code with Markdown.parse
    user_markdown_code = "Markdown.parse($(repr(user_message)))"
    add_cell!(book, user_markdown_code, "julia", Dict{Symbol, Any}(:from => :user))

    # Track compacting aggressiveness - will be adjusted based on token estimates
    compacting_keep_last = Ref{Union{Int, Nothing}}(nothing)
    compacting_min_size = Ref{Union{Int, Nothing}}(nothing)

    async_spinner!(task_spinner, "agent loop", 1:50) do i
        try
            # Compact messages to fit within token limit
            result = compact_messages_to_fit(book, agent;
                keep_last=compacting_keep_last[],
                min_size=compacting_min_size[])

            # Update compacting settings for next iteration
            compacting_keep_last[] = result.keep_last
            compacting_min_size[] = result.min_size
            messages = result.messages

            if !result.success
                # Still over limit after max attempts - show error
                @error "Cannot fit conversation in context window" estimated_tokens=result.estimated_tokens
                error_markdown = "Markdown.parse($(repr("⚠️ **Context Limit Exceeded:**\nThe conversation history is too long even after aggressive compacting (~$(result.estimated_tokens) tokens > $(Int(floor(context_limit(agent.api) * 0.9))) maximum).\n\nPlease start a new conversation or manually delete some old cells.")))"
                add_cell!(book, error_markdown, "julia", Dict{Symbol, Any}(:from => :system, :error => true))
                return true  # Stop the loop
            end

            # Call agent with nested spinner - returns Channel with multiple items (tools and text)
            result_channel = async_spinner!(task_spinner, "asking") do
                prompt(agent, messages; spinner=task_spinner)
            end
            # Process all items from the channel
            async_spinner!(task_spinner, "processing ai", result_channel) do item
                process_agent_item!(book, agent, item, sanitizer_config, file_editor)
            end

            # Reset compacting to defaults after successful request
            compacting_keep_last[] = nothing
            compacting_min_size[] = nothing

            # Return true for stopping early
            isdone(agent) && return true
        catch e
            # Check if this is a PromptTooLongError (possibly wrapped in TaskFailedException)
            # This is a fallback - proactive checking above should catch most cases
            prompt_error = find_prompt_too_long_error(e)
            if prompt_error !== nothing
                # This shouldn't normally happen since we check proactively, but handle it anyway
                @error "Unexpected PromptTooLongError (proactive check should have caught this)" current_tokens=prompt_error.current_tokens max_tokens=prompt_error.max_tokens
                error_markdown = "Markdown.parse($(repr("⚠️ **Context Limit Exceeded:**\nThe conversation history is too long ($(prompt_error.current_tokens) tokens > $(prompt_error.max_tokens) maximum).\n\nPlease start a new conversation or manually delete some old cells.")))"
                add_cell!(book, error_markdown, "julia", Dict{Symbol, Any}(:from => :system, :error => true))
                return true  # Stop the loop
            else
                # Catch other errors and feed them back to the LLM as a system message
                # This allows the agent to see and react to errors (e.g., avoid repeating failed tools)
                error_msg = sprint(showerror, e)
                bt = catch_backtrace()
                @error "Agent loop error, feeding back to LLM" exception=(e, bt)

                # Add error as a system/assistant message so the LLM can see it
                error_markdown = "Markdown.parse($(repr("⚠️ **System Error:**\n```\n$error_msg\n```\nPlease acknowledge this error and adjust your approach if needed.")))"
                add_cell!(book, error_markdown, "julia", Dict{Symbol, Any}(:from => :system, :error => true))

                # Don't stop the loop - let the LLM react to the error on next iteration
                return false
            end
        end
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

function process_agent_item!(book, agent::HTTPAgent, item, sanitizer_config::SanitizerConfig, file_editor)
    agent.last_item[] = item
    if multi_task_tool(item)
        agent.needs_to_be_done[typeof(item)] = item
    end
    try
        process_item!(book, item, agent, sanitizer_config, file_editor)
    catch e
        error_msg = "Error processing item of type $(typeof(item)): $(e)"
        process_item!(book, error_msg, agent, sanitizer_config, file_editor)
    end
end

"""
    process_item!(book, item, agent, sanitizer_config, file_editor)

Process a result item by converting it to a cell or executing tools.
Uses multiple dispatch to handle different item types.
Opens files in file_editor when file tools are executed.
"""
function process_item!(book, item::String, agent::HTTPAgent, sanitizer_config::SanitizerConfig, file_editor)
    # Text content - create Julia code cell with Markdown.parse
    markdown_code = "Markdown.parse($(repr(item)))"
    add_cell!(book, markdown_code, "julia", Dict{Symbol, Any}(:from => :agent))
end

function process_item!(book, item::Dict, agent::HTTPAgent, sanitizer_config::SanitizerConfig, file_editor)
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
    tool_file = joinpath(tools_dir, "$(Base.invokelatest(tool_name, tool_type))-$(cell_id).json")
    open(io-> JSON3.write(io, tool_execution), tool_file, "w")
    return tool_file
end


function process_item!(book, tool::AddCellTool, agent::HTTPAgent, sanitizer_config::SanitizerConfig, file_editor)
    # AddCellTool is special - execute it and directly add the cell content
    # But first, sanitize the code if it's Julia
    if tool.language == "julia"
        violation = check_code_safety(tool.content, sanitizer_config)
        if violation !== nothing
            # Code is unsafe - create an error cell instead
            error_msg = format_violation_error(violation, tool.content)
            error_code = """error($(repr(error_msg)))"""
            metadata = something(tool.metadata, Dict{Symbol,Any}())
            metadata = merge(Dict{Symbol,Any}(:from => :agent, :tool => "add_cell", :sanitizer_blocked => true), metadata)
            cell = add_cell!(book, error_code, "julia", metadata; editor_visible=true)
            val = cell.editor.output[]
            result = ToolResult(repr(extract_output(val)))
            tool_execution = ToolExecution(tool, result)
            store_tool_exe!(book, tool_execution, cell.uuid)
            return cell
        end
    end

    # Code is safe (or not Julia) - proceed normally
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

function process_item!(book, tool::AbstractTool, agent::HTTPAgent, sanitizer_config::SanitizerConfig, file_editor)
    # Execute the tool and get result with token limit
    result = execute_tool!(tool, agent.max_tool_use_token)

    # Create ToolExecution
    tool_execution = ToolExecution(tool, result)
    path = store_tool_exe!(book, tool_execution)

    # Generate Julia code that reads the ToolExecution from the JSON file
    name = basename(path)
    tool_code = """open(io -> JSON3.read(io, $(typeof(tool_execution))), data"tools/$name")"""
    tool_type = Base.invokelatest(tool_name, typeof(tool))
    # Add as Julia code cell (will be executed and rendered)
    cell = add_cell!(book, tool_code, "julia", Dict{Symbol, Any}(:from => :tool, :tool => tool_type))

    # Open file in editor for file-related tools
    open_file_in_editor(tool, file_editor)

    return cell  # Return the cell for TodoList tracking
end

# Fallback for other types (DOM elements, etc.) - ignore
function process_item!(book, item, agent::HTTPAgent, sanitizer_config::SanitizerConfig, file_editor)
    # Do nothing for unhandled types
    nothing
end

# Helper function to open files in editor when file tools are used
function open_file_in_editor(tool::FileReadTool, file_editor)
    if isfile(tool.path)
        BonitoBook.open_file!(file_editor, tool.path)
    end
end

function open_file_in_editor(tool::FileWriteTool, file_editor)
    if isfile(tool.path)
        BonitoBook.open_file!(file_editor, tool.path)
    end
end

function open_file_in_editor(tool::FileEditTool, file_editor)
    if isfile(tool.path)
        BonitoBook.open_file!(file_editor, tool.path)
    end
end

# Fallback for other tools - do nothing
function open_file_in_editor(tool::AbstractTool, file_editor)
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

    class = get(metadata, :from, :agent) == :user ? "cell-from-user" : "cell-from-agent"

    # Create cell editor
    cell = BonitoBook.CellEditor(
        content,
        language,
        book.runner;
        show_editor=editor_visible,
        show_output = true,
        theme = book.monaco_theme,
        metadata = metadata,
        id = cell_id,
        class = class
    )

    # Insert at end
    BonitoBook.insert_editor!(book, cell, length(book.cells) + 1)

    # Auto-run code cells
    if language == "julia" || language == "python"
        BonitoBook.run_sync!(cell.editor)
    end
    return cell
end

"""
    summarize_old_tool_executions!(book; keep_last=5)

Background task that summarizes old tool executions to save memory/display space.
Keeps the last `keep_last` tool executions as full, summarizes the rest.
"""
function summarize_old_tool_executions!(book; keep_last=5)
    # Get all tool cells (cells with metadata :from => :tool)
    tool_cells = filter(book.cells) do cell
        get(cell.metadata, :from, nothing) == :tool
    end

    # If we have fewer than keep_last+1 tool cells, nothing to summarize
    if length(tool_cells) <= keep_last
        return
    end

    # Get cells to summarize (all except the last keep_last)
    cells_to_summarize = tool_cells[1:end-keep_last]

    for cell in cells_to_summarize
        # Check if already summarized (skip if so)
        if contains(cell.editor.content[], "SummarizedToolExecution")
            continue
        end

        # Extract the tool name and cell ID from the current code
        # Current format: open(io -> JSON3.read(io, ToolExecution{SomeTool}), data"tools/toolname-cellid.json")
        content = cell.editor.content[]
        m = match(r"data\"tools/(.*?)-(.*?)\.json\"", content)
        if m === nothing
            @warn "Could not extract tool info from cell content" content=content
            continue
        end

        tool_name_str = m.captures[1]
        cell_id = m.captures[2]

        # Get the full path to the JSON file
        tools_dir = joinpath(book.folder, "data", "tools")
        json_file = joinpath(tools_dir, "$(tool_name_str)-$(cell_id).json")

        if !isfile(json_file)
            @warn "Tool execution JSON file not found" file=json_file
            continue
        end

        try
            # Read the full execution to check if it should be summarized
            # We need to read it as generic ToolExecution first to check size
            json_str = read(json_file, String)
            json_data = JSON3.read(json_str)

            # Check result size
            result_str = string(get(json_data, :result, Dict())[:result])
            if length(result_str) < 1000
                continue  # Don't summarize small results
            end

            # Create summarized version
            # New code format: Use a special loader that creates SummarizedToolExecution
            new_code = """
            begin
                # Load full execution and create summarized version
                json_file = data"tools/$(tool_name_str)-$(cell_id).json"
                # This will be rendered as summarized automatically
                open(io -> JSON3.read(io, ToolExecution), json_file)
            end
            """

            # Note: The actual summarization happens in rendering based on age
            # For now, we just keep the full execution but mark it for potential summarization
            # A more sophisticated approach would be to modify the JSON file or cell output

            # Actually, let's not modify cells automatically for now
            # Instead, we'll implement this as an opt-in feature that can be triggered manually
            # or by a background task that the user can control

        catch e
            @warn "Error processing cell for summarization" cell_id=cell.uuid exception=(e, catch_backtrace())
            continue
        end
    end
end
