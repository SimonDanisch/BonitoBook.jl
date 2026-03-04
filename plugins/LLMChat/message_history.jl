"""
Message history management for the BonitoBook chat agent.

Handles:
- Converting notebook cells to agent messages
- File read deduplication
- Context compacting when history gets too long
"""

using JSON3

"""
    extract_markdown_content(source::String)

Extract content from Markdown.parse(\"\"\"...\"\"\") wrapper.
Returns the inner content or the original string if not wrapped.
"""
function extract_markdown_content(source::String)
    source = strip(source)

    # Match Markdown.parse("...") - extract content from quotes
    pattern = r"^Markdown\.parse\(\s*\"(.*)\"\s*\)\s*$"s
    m = match(pattern, source)

    if m !== nothing
        return strip(m.captures[1])
    end

    return source
end

"""
    deduplicate_file_reads!(messages::Vector{AgentMessage})

Replace duplicate file read results with references to the first read.
Modifies messages in place.
"""
function deduplicate_file_reads!(messages::Vector{AgentMessage})
    # Track file reads: path => cell_id where it was first read
    file_read_cells = Dict{String, Int}()

    for (idx, msg) in enumerate(messages)
        # Check if this is a FileReadTool
        if msg.content isa FileReadTool
            path = msg.content.path

            # Check if next message is the tool result
            if idx < length(messages)
                next_msg = messages[idx + 1]
                if next_msg.content isa ToolResult
                    if haskey(file_read_cells, path)
                        # File was already read - replace result with reference
                        ref_msg = "File already read in cell #$(file_read_cells[path]). Content unchanged."
                        messages[idx + 1] = AgentMessage(next_msg.role, ToolResult(ref_msg, true), next_msg.cell_id)
                    else
                        # First read of this file - record it
                        file_read_cells[path] = msg.cell_id
                    end
                end
            end
        end
    end
end

"""
    cells_to_messages(book)

Convert notebook cells to agent messages.

Features:
- Extracts content from Markdown.parse wrappers
- Handles :compactor role: only returns messages after the latest compactor cell
- Converts :compactor role to :user for API calls

Note: Call deduplicate_file_reads!(messages) after this to handle file deduplication.

# Arguments
- `book`: The LLMChatBook or Book to convert
"""
function cells_to_messages(book)
    messages = AgentMessage[]

    # Find the latest compactor cell index (we only need messages after it)
    last_compactor_idx = 0
    for (idx, cell) in enumerate(book.cells)
        if get(cell.metadata, :from, nothing) == :compactor
            last_compactor_idx = idx
        end
    end

    for (idx, cell) in enumerate(book.cells)
        # Skip cells before the last compactor (except include the compactor itself)
        if idx < last_compactor_idx
            continue
        end

        raw_from = get(cell.metadata, :from, :user)
        role = (raw_from == :user) ? :user : :assistant
        cell_id = cell.uuid
        tool_type = get(cell.metadata, :tool, nothing)

        # Handle compactor cells specially
        if raw_from == :compactor
            content = cell.editor.source[]
            content = extract_markdown_content(content)
            # Send as :user role to the API (it's context for the assistant)
            push!(messages, AgentMessage(:user, "[Previous conversation summary]\n$content", cell_id))
            continue
        end

        # For user/assistant messages, extract content smartly
        if isnothing(tool_type)
            content = cell.editor.source[]
            # Remove Markdown.parse wrapper if present
            content = extract_markdown_content(content)
            push!(messages, AgentMessage(role, content, cell_id))
        else
            TT = tool_name_to_type(string(tool_type))
            # Use abspath to handle relative book.folder paths correctly
            data_path = joinpath(abspath(book.folder), "data", "tools", "$(tool_type)-$(cell_id).json")
            
            if isfile(data_path)
                tool_execution = open(io -> JSON3.read(io, ToolExecution{TT}), data_path)
                # Tool call message
                push!(messages, AgentMessage(:assistant, tool_execution.tool, cell_id))
                # Tool result message
                push!(messages, AgentMessage(:user, tool_execution.result, cell_id))
            else
                # Fallback: if tool data is missing, treat as normal message
                content = cell.editor.source[]
                content = extract_markdown_content(content)
                push!(messages, AgentMessage(role, content, cell_id))
            end
        end
    end

    return messages
end

# ============================================================================
# Context Compacting
# ============================================================================

"""
    estimate_tokens(messages::Vector{AgentMessage})

Estimate token count for messages (rough: 4 chars per token).
"""
function estimate_tokens(messages::Vector{AgentMessage})
    total_chars = sum(messages; init=0) do msg
        if msg.content isa String
            length(msg.content)
        elseif msg.content isa ToolResult
            length(string(msg.content.result))
        elseif msg.content isa AbstractTool
            length(JSON3.write(msg.content))
        else
            100  # Default estimate
        end
    end
    return total_chars ÷ 4
end

"""
    find_largest_message_index(messages::Vector{AgentMessage})

Find the index of the message with the largest content.
Returns (index, size) tuple.
"""
function find_largest_message_index(messages::Vector{AgentMessage})
    max_size = 0
    max_idx = 0

    for (idx, msg) in enumerate(messages)
        size = if msg.content isa String
            length(msg.content)
        elseif msg.content isa ToolResult
            length(string(msg.content.result))
        else
            0
        end

        if size > max_size
            max_size = size
            max_idx = idx
        end
    end

    return max_idx, max_size
end

"""
    shrink_largest_message!(messages::Vector{AgentMessage})

Find and shrink the largest message. Returns true if a message was shrunk.
"""
function shrink_largest_message!(messages::Vector{AgentMessage})
    idx, size = find_largest_message_index(messages)
    if idx == 0 || size < 500
        return false
    end

    msg = messages[idx]
    # Shrink to ~1/4 of current size
    target_tokens = size ÷ 16

    if msg.content isa String
        new_content = limit_output(msg.content, target_tokens)
        messages[idx] = AgentMessage(msg.role, new_content, msg.cell_id)
        return true
    elseif msg.content isa ToolResult
        result_str = string(msg.content.result)
        new_result = limit_output(result_str, target_tokens)
        messages[idx] = AgentMessage(msg.role, ToolResult(new_result, msg.content.success), msg.cell_id)
        return true
    end
    return false
end

const SUMMARY_PROMPT = """Please write a concise summary of our conversation so far for yourself to continue working.
Include:
- What the user originally asked for
- Key files you've read or modified (with paths)
- Current state of the task (what's done, what's pending)
- Any errors encountered and how they were resolved
- Important decisions or constraints mentioned

Keep the summary under 2000 tokens. Focus on information you'll need to continue the task."""

"""
    maybe_compact!(book, agent::HTTPAgent, messages::Vector{AgentMessage};
                   max_context_tokens::Int=100000)

Compact the message history if it exceeds max_context_tokens.
Modifies messages in place by:
1. Shrinking largest messages to make room
2. Adding a summary request and calling prompt() to get the summary
3. Adding a compactor cell to the book
4. Replacing messages with just the summary

Call this after cells_to_messages() and deduplicate_file_reads!(), before prompt().
"""
function maybe_compact!(book, agent::HTTPAgent, messages::Vector{AgentMessage};
                        max_context_tokens::Int=100000)

    current_tokens = estimate_tokens(messages)

    # Only compact if we're over the limit
    if current_tokens <= max_context_tokens
        return
    end

    @info "Compacting conversation" current_tokens max_context_tokens

    # Shrink messages to make room for summary request
    while estimate_tokens(messages) > max_context_tokens - 1000
        if !shrink_largest_message!(messages)
            break
        end
    end

    # Add summary request to messages
    push!(messages, AgentMessage(:user, SUMMARY_PROMPT, nothing))

    # Call prompt to get summary (collect all text responses)
    summary_parts = String[]
    result_channel = prompt(agent, messages)
    for item in result_channel
        if item isa String
            push!(summary_parts, item)
        end
        # Ignore any tool calls during summarization
    end
    summary = join(summary_parts, "\n")

    if isempty(summary)
        summary = "Previous conversation could not be summarized. Please ask the user for context."
    end

    # Add compactor cell to the book
    compactor_code = "Markdown.parse($(repr("[Conversation Summary]\n\n" * summary)))"
    add_cell!(book, compactor_code, "julia", Dict{Symbol, Any}(:from => :compactor))

    # Replace messages with just the summary (as user context for next prompt)
    empty!(messages)
    push!(messages, AgentMessage(:user, "[Previous conversation summary]\n$summary", nothing))
end

export cells_to_messages, deduplicate_file_reads!, maybe_compact!
