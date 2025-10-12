using Bonito.HTTP
using JSON3
using Bonito.Base64

"""
    HTTPAgentConfig

Configuration for HTTP-based LLM agents (OpenAI, Claude, Ollama, etc.)

# Fields
- `endpoint::String`: API endpoint URL
- `model::String`: Model identifier
- `api_key::Union{String, Nothing}`: API key (not needed for Ollama)
- `headers_fn::Function`: Function that returns request headers
- `request_fn::Function`: Function that builds request body
- `response_fn::Function`: Function that parses streaming response chunks
- `system_prompt::String`: System prompt for the agent
"""
struct HTTPAgentConfig
    endpoint::String
    model::String
    api_key::Union{String, Nothing}
    headers_fn::Function
    request_fn::Function
    response_fn::Function
    system_prompt::String
end

"""
    HTTPAgent <: LLMChatAgent

Generic HTTP-based agent that works with OpenAI, Claude, Ollama, and compatible APIs.
"""
struct HTTPAgent <: LLMChatAgent
    config::HTTPAgentConfig
end

# ============================================================================
# Provider-specific configurations
# ============================================================================

"""
    openai_config(model::String; api_key=nothing, endpoint="https://api.openai.com/v1/chat/completions")

Create configuration for OpenAI API.
"""
function openai_config(model::String; api_key=nothing, endpoint="https://api.openai.com/v1/chat/completions")
    api_key = something(api_key, get(ENV, "OPENAI_API_KEY", nothing))

    headers_fn = (key) -> [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $key"
    ]

    request_fn = (messages, tools, model) -> Dict(
        "model" => model,
        "messages" => messages,
        "stream" => true,
        "tools" => isempty(tools) ? nothing : [tool_to_openai(T) for T in tools]
    )

    response_fn = parse_openai_response

    return HTTPAgentConfig(endpoint, model, api_key, headers_fn, request_fn, response_fn, DEFAULT_SYSTEM_PROMPT)
end

"""
    claude_config(model::String; api_key=nothing, endpoint="https://api.anthropic.com/v1/messages")

Create configuration for Claude API.
"""
function claude_config(model::String; api_key=nothing, endpoint="https://api.anthropic.com/v1/messages")
    api_key = something(api_key, get(ENV, "CLAUDE_API_KEY", nothing))

    headers_fn = (key) -> [
        "Content-Type" => "application/json",
        "x-api-key" => key,
        "anthropic-version" => "2023-06-01"
    ]

    request_fn = (messages, tools, model) -> begin
        # Extract system message
        system_msg = ""
        user_messages = []
        for msg in messages
            if msg["role"] == "system"
                system_msg = msg["content"]
            else
                push!(user_messages, msg)
            end
        end

        Dict(
            "model" => model,
            "messages" => user_messages,
            "system" => system_msg,
            "stream" => true,
            "max_tokens" => 4096,
            "tools" => isempty(tools) ? nothing : [tool_to_claude(T) for T in tools]
        )
    end

    response_fn = parse_claude_response

    return HTTPAgentConfig(endpoint, model, api_key, headers_fn, request_fn, response_fn, DEFAULT_SYSTEM_PROMPT)
end

"""
    ollama_config(model::String; endpoint="http://localhost:11434/api/chat")

Create configuration for Ollama.
"""
function ollama_config(model::String; endpoint="http://localhost:11434/api/chat")
    headers_fn = (_) -> ["Content-Type" => "application/json"]

    request_fn = (messages, tools, model) -> Dict(
        "model" => model,
        "messages" => messages,
        "stream" => true,
        "tools" => isempty(tools) ? nothing : [tool_to_openai(T) for T in tools]  # Ollama uses OpenAI format
    )

    response_fn = parse_ollama_response

    return HTTPAgentConfig(endpoint, model, nothing, headers_fn, request_fn, response_fn, DEFAULT_SYSTEM_PROMPT)
end

const DEFAULT_SYSTEM_PROMPT = """
You are a helpful AI assistant integrated into a Julia notebook.

# Available Tools
You have access to the following tools:
- **bash**: Execute shell commands (args: command)
- **file_read**: Read file contents (args: path)
- **file_write**: Write content to file (args: path, content)
- **file_edit**: Edit file by replacing text (args: path, old_text, new_text)
- **http_get**: Fetch URL content (args: url)
- **add_cell**: Add a julia code/markdown cell which gets executed immediately. Use this if asked to execute julia code (args: language, content, metadata)
- **todo**: Add a todo item (args: description)

# Tool Usage
Use tools via the standard API tool calling mechanism (function calling for OpenAI/Ollama, tools for Claude).
The tools will be executed automatically and results will be shown in the notebook.

# Agent Loop Behavior
- If you respond with a tool, the loop will execute it and show the result and continue.
- If you respond with text, the loop will stop and show your message.
- You can call multiple tools in sequence if needed.
- You can use tools, provide explanations, add cells, etc.
- The loop allows iterative work: respond → see results → respond again


# Guidelines
1. Break complex tasks into steps
2. Use tools to inspect files, run code, and perform actions
4. When the task is complete, call `end_loop` tool
5. Keep things concise and to the point
6. Dont do more than the user asked for
7. Start with the todo tool, if there are multiple steps.
8. If the user asks for code, always use the add_cell tool to add a new cell with the julia code.
9. Dont ever use println if not explicitely asked for. You're in a notebook, every last line will get visualized as a cell output.

# Julia specific tips:
- Use `@doc(sym_or_var)` to get documentation for a function or package.
- Use `names(PackageName)` to get a list of functions in a package.
- Use `using PackageName` to load a package.
- Pkg.status() to see installed packages - never install a package if its already in the env.
If asked for code or commands, you only answer the requested command/code without any explanation!
If asked something simple, give the simplest version. For example, if asked for a slider, give a simple slider without any additional options, but assign it to a variable.
"""

# ============================================================================
# Core implementation
# ============================================================================

"""
    prompt(agent::HTTPAgent, messages::Vector{AgentMessage}, tools::Vector)

Call the HTTP agent with streaming and return a Channel that yields complete content blocks (tools and text).
The Channel is closed after all items are yielded.
"""
function prompt(agent::HTTPAgent, messages::Vector{AgentMessage}, tools::Vector)
    config = agent.config
    # Convert messages to API format
    api_messages = [
        Dict("role" => "system", "content" => config.system_prompt),
        [message_to_api(msg) for msg in messages]...
    ]
    # Build request with streaming enabled
    request_body = config.request_fn(api_messages, tools, config.model)

    # Remove null fields
    filter!(p -> p.second !== nothing, request_body)

    headers = config.api_key !== nothing ? config.headers_fn(config.api_key) : config.headers_fn(nothing)

    # Create output channel for complete tools and strings
    output_channel = Channel{Union{AbstractTool, String}}(100)

    @async begin
        try
            # Use HTTP.request with response_stream to handle streaming
            response = HTTP.request(
                "POST",
                config.endpoint,
                headers,
                JSON3.write(request_body);
                response_stream = IOBuffer()
            )

            # Get the response body
            response_body = String(take!(response.body))

            # Split into SSE lines and process
            for line in split(response_body, '\n')
                # Skip empty lines
                if isempty(strip(line))
                    continue
                end

                # Parse SSE format: "data: {...}" or just "event: ..."
                if startswith(line, "data: ")
                    data_str = strip(line[7:end])

                    # Skip SSE control messages
                    if data_str == "[DONE]" || isempty(data_str)
                        continue
                    end

                    try
                        chunk = JSON3.read(data_str)
                        # Pass chunk to response parser which accumulates and emits complete items
                        config.response_fn(chunk, output_channel)
                    catch e
                        @debug "Failed to parse streaming chunk" exception=e data=data_str
                    end
                end
            end
        catch e
            @error "Streaming error" exception=(e, catch_backtrace())
        finally
            close(output_channel)
        end
    end

    return output_channel
end

# ============================================================================
# Message conversion
# ============================================================================

"""
    message_to_api(msg::AgentMessage)

Convert AgentMessage to API format with support for text, images, and files.
"""
function message_to_api(msg::AgentMessage)
    role = msg.role == :assistant ? "assistant" : "user"
    content = msg.content

    # Check if content contains image or file references
    # Format: ![image](path/to/image.png) or [file](path/to/file.txt)
    if content isa String
        content_parts = parse_content_with_media(content)
        if length(content_parts) > 1
            # Multi-part message with images/files
            return Dict("role" => role, "content" => content_parts)
        end
    end

    # Simple text message
    return Dict("role" => role, "content" => string(content))
end

"""
    parse_content_with_media(text::String)

Parse markdown content and extract embedded images/files.
Returns array of content parts for multi-modal APIs.
"""
function parse_content_with_media(text::String)
    parts = []
    current_text = IOBuffer()

    # Simple regex to find markdown images and links
    pattern = r"!\[([^\]]*)\]\(([^\)]+)\)|\[([^\]]+)\]\(([^\)]+)\)"

    last_pos = 1
    for m in eachmatch(pattern, text)
        # Add text before match
        if m.offset > last_pos
            text_before = text[last_pos:m.offset-1]
            write(current_text, text_before)
        end

        if m.match[1] == '!'
            # Image: ![alt](path)
            path = m.captures[2]
            if isfile(path)
                # Flush current text
                current = String(take!(current_text))
                if !isempty(strip(current))
                    push!(parts, Dict("type" => "text", "text" => current))
                end

                # Add image
                mime = get_mime_type(path)
                if mime !== nothing
                    image_data = base64encode(read(path))
                    push!(parts, Dict(
                        "type" => "image_url",
                        "image_url" => Dict("url" => "data:$mime;base64,$image_data")
                    ))
                end
            else
                write(current_text, m.match)
            end
        else
            # Regular link - check if it's a file
            link_text = m.captures[3]
            path = m.captures[4]

            if isfile(path) && !is_image_file(path)
                # Flush current text
                current = String(take!(current_text))
                if !isempty(strip(current))
                    push!(parts, Dict("type" => "text", "text" => current))
                end

                # Add file content as text
                try
                    file_content = read(path, String)
                    file_text = "[$link_text]:\n```\n$file_content\n```"
                    push!(parts, Dict("type" => "text", "text" => file_text))
                catch
                    write(current_text, m.match)
                end
            else
                write(current_text, m.match)
            end
        end

        last_pos = m.offset + length(m.match)
    end

    # Add remaining text
    if last_pos <= length(text)
        write(current_text, text[last_pos:end])
    end

    current = String(take!(current_text))
    if !isempty(strip(current))
        push!(parts, Dict("type" => "text", "text" => current))
    end

    return isempty(parts) ? [Dict("type" => "text", "text" => text)] : parts
end

function get_mime_type(path::String)
    ext = lowercase(splitext(path)[2])
    mime_map = Dict(
        ".png" => "image/png",
        ".jpg" => "image/jpeg",
        ".jpeg" => "image/jpeg",
        ".gif" => "image/gif",
        ".webp" => "image/webp"
    )
    return get(mime_map, ext, nothing)
end

function is_image_file(path::String)
    ext = lowercase(splitext(path)[2])
    return ext in [".png", ".jpg", ".jpeg", ".gif", ".webp"]
end

# ============================================================================
# Tool conversion
# ============================================================================

"""
    tool_to_openai(::Type{T}) where T <: AbstractTool

Convert tool to OpenAI format.
"""
function tool_to_openai(::Type{T}) where T <: AbstractTool
    return Dict(
        "type" => "function",
        "function" => Dict(
            "name" => tool_name(T),
            "description" => tool_description(T),
            "parameters" => tool_input_schema(T)
        )
    )
end

"""
    tool_to_claude(::Type{T}) where T <: AbstractTool

Convert tool to Claude format.
"""
function tool_to_claude(::Type{T}) where T <: AbstractTool
    return Dict(
        "name" => tool_name(T),
        "description" => tool_description(T),
        "input_schema" => tool_input_schema(T)
    )
end

# ============================================================================
# Helper functions
# ============================================================================

"""
    tool_name_to_type(name::String)

Convert tool name string to tool type.
"""
function tool_name_to_type(name::String)
    tool_map = Dict(
        "bash" => BashTool,
        "file_read" => FileReadTool,
        "file_write" => FileWriteTool,
        "file_edit" => FileEditTool,
        "http_get" => HttpGetTool,
        "add_cell" => AddCellTool,
        "todo" => TodoTool
    )
    return get(tool_map, name, nothing)
end


# ============================================================================
# Response parsing - Streaming accumulators
# ============================================================================

"""
    OpenAIStreamState

Accumulator for OpenAI streaming chunks. Tracks partial tool calls and text.
"""
mutable struct OpenAIStreamState
    tool_calls::Dict{Int, Dict{String, Any}}  # index => {name, arguments}
    text_buffer::String
end

OpenAIStreamState() = OpenAIStreamState(Dict{Int, Dict{String, Any}}(), "")

"""
    parse_openai_response(chunk, output_channel::Channel)

Parse OpenAI streaming chunk and emit complete tools/text to output_channel.
Accumulates partial data and only emits when complete.
"""
const openai_state = Ref{Union{OpenAIStreamState, Nothing}}(nothing)

function parse_openai_response(chunk, output_channel::Channel)
    # Initialize state on first chunk
    if openai_state[] === nothing
        openai_state[] = OpenAIStreamState()
    end
    state = openai_state[]

    try
        if haskey(chunk, :choices) && !isempty(chunk.choices)
            choice = chunk.choices[1]
            delta = get(choice, :delta, nothing)

            if delta !== nothing
                # Handle tool calls (accumulate arguments)
                if haskey(delta, :tool_calls)
                    for tool_delta in delta.tool_calls
                        idx = tool_delta.index

                        if !haskey(state.tool_calls, idx)
                            state.tool_calls[idx] = Dict("name" => "", "arguments" => "")
                        end

                        # Accumulate function name
                        if haskey(tool_delta, :function) && haskey(tool_delta.function, :name)
                            state.tool_calls[idx]["name"] = tool_delta.function.name
                        end

                        # Accumulate arguments
                        if haskey(tool_delta, :function) && haskey(tool_delta.function, :arguments)
                            state.tool_calls[idx]["arguments"] *= tool_delta.function.arguments
                        end
                    end
                end

                # Handle text content (accumulate)
                if haskey(delta, :content) && delta.content !== nothing
                    state.text_buffer *= delta.content
                end
            end

            # Check if this is the final chunk
            finish_reason = get(choice, :finish_reason, nothing)
            if finish_reason !== nothing && finish_reason != "null"
                # Emit all accumulated tools
                for (idx, tool_data) in sort(collect(state.tool_calls), by=first)
                    tool_name = tool_data["name"]
                    args_json = tool_data["arguments"]

                    if !isempty(tool_name) && !isempty(args_json)
                        tool_type = tool_name_to_type(tool_name)
                        if tool_type !== nothing
                            try
                                tool = JSON3.read(args_json, tool_type)
                                put!(output_channel, tool)
                            catch e
                                @warn "Failed to parse tool arguments" tool_name args_json exception=e
                            end
                        end
                    end
                end

                # Emit accumulated text if present
                if !isempty(strip(state.text_buffer))
                    put!(output_channel, state.text_buffer)
                end

                # Reset state for next request
                openai_state[] = nothing
            end
        end
    catch e
        @warn "Failed to parse OpenAI streaming chunk" exception=e
        openai_state[] = nothing
    end
end

"""
    ClaudeStreamState

Accumulator for Claude streaming chunks. Tracks current content block being built.
"""
mutable struct ClaudeStreamState
    current_block_index::Int
    current_block_type::String
    text_buffer::String
    tool_name::String
    tool_input_buffer::String
end

ClaudeStreamState() = ClaudeStreamState(-1, "", "", "", "")

"""
    parse_claude_response(chunk, output_channel::Channel)

Parse Claude streaming chunk and emit complete tools/text to output_channel.
Claude streams with events: content_block_start, content_block_delta, content_block_stop
"""
const claude_state = Ref{Union{ClaudeStreamState, Nothing}}(nothing)

function parse_claude_response(chunk, output_channel::Channel)
    # Initialize state on first chunk
    if claude_state[] === nothing
        claude_state[] = ClaudeStreamState()
    end
    state = claude_state[]

    try
        event_type = get(chunk, :type, "")

        if event_type == "content_block_start"
            # New content block starting
            block = chunk.content_block
            state.current_block_index = chunk.index
            state.current_block_type = block.type

            if block.type == "tool_use"
                state.tool_name = block.name
                state.tool_input_buffer = ""
            elseif block.type == "text"
                state.text_buffer = ""
            end

        elseif event_type == "content_block_delta"
            # Accumulate content for current block
            delta = chunk.delta

            if delta.type == "text_delta"
                state.text_buffer *= delta.text
            elseif delta.type == "input_json_delta"
                state.tool_input_buffer *= delta.partial_json
            end

        elseif event_type == "content_block_stop"
            # Block complete - emit to channel
            if state.current_block_type == "text"
                if !isempty(strip(state.text_buffer))
                    put!(output_channel, state.text_buffer)
                end
                state.text_buffer = ""
            elseif state.current_block_type == "tool_use"
                if !isempty(state.tool_name) && !isempty(state.tool_input_buffer)
                    tool_type = tool_name_to_type(state.tool_name)
                    if tool_type !== nothing
                        try
                            tool = JSON3.read(state.tool_input_buffer, tool_type)
                            put!(output_channel, tool)
                        catch e
                            @warn "Failed to parse tool input" tool_name=state.tool_name input=state.tool_input_buffer exception=e
                        end
                    end
                end
                state.tool_name = ""
                state.tool_input_buffer = ""
            end

        elseif event_type == "message_stop"
            # Message complete - reset state
            claude_state[] = nothing
        end
    catch e
        @warn "Failed to parse Claude streaming chunk" exception=e
        claude_state[] = nothing
    end
end

"""
    parse_ollama_response(chunk, output_channel::Channel)

Parse Ollama streaming chunk and emit complete tools/text to output_channel.
Ollama uses OpenAI-compatible format with deltas.
"""
const ollama_state = Ref{Union{OpenAIStreamState, Nothing}}(nothing)

function parse_ollama_response(chunk, output_channel::Channel)
    # Ollama uses OpenAI format, so reuse OpenAI state structure
    if ollama_state[] === nothing
        ollama_state[] = OpenAIStreamState()
    end
    state = ollama_state[]

    try
        if haskey(chunk, :message)
            message = chunk.message

            # Handle tool calls (accumulate)
            if haskey(message, :tool_calls)
                for tool_call in message.tool_calls
                    idx = get(tool_call, :index, 0)

                    if !haskey(state.tool_calls, idx)
                        state.tool_calls[idx] = Dict("name" => "", "arguments" => "")
                    end

                    if haskey(tool_call, :function)
                        func = tool_call.function
                        if haskey(func, :name)
                            state.tool_calls[idx]["name"] = func.name
                        end
                        if haskey(func, :arguments)
                            state.tool_calls[idx]["arguments"] *= func.arguments
                        end
                    end
                end
            end

            # Handle text content (accumulate)
            if haskey(message, :content) && message.content !== nothing
                state.text_buffer *= message.content
            end
        end

        # Check if done
        if haskey(chunk, :done) && chunk.done
            # Emit all accumulated tools
            for (idx, tool_data) in sort(collect(state.tool_calls), by=first)
                tool_name = tool_data["name"]
                args_json = tool_data["arguments"]

                if !isempty(tool_name) && !isempty(args_json)
                    tool_type = tool_name_to_type(tool_name)
                    if tool_type !== nothing
                        try
                            tool = JSON3.read(args_json, tool_type)
                            put!(output_channel, tool)
                        catch e
                            @warn "Failed to parse tool arguments" tool_name args_json exception=e
                        end
                    end
                end
            end

            # Emit accumulated text if present
            if !isempty(strip(state.text_buffer))
                put!(output_channel, state.text_buffer)
            end

            # Reset state
            ollama_state[] = nothing
        end
    catch e
        @warn "Failed to parse Ollama streaming chunk" exception=e
        ollama_state[] = nothing
    end
end

# ============================================================================
# Agent creation helpers
# ============================================================================

"""
    create_http_agent(; provider=:auto)

Create HTTP agent based on available API keys or specified provider.
Supported providers: :openai, :claude, :ollama, :auto
"""
function create_http_agent(; provider=:auto)
    if provider == :auto
        # Auto-detect based on environment
        if haskey(ENV, "CLAUDE_API_KEY")
            provider = :claude
        elseif haskey(ENV, "OPENAI_API_KEY")
            provider = :openai
        else
            provider = :ollama  # Fallback to local Ollama
        end
    end

    config = if provider == :openai
        openai_config("gpt-4")
    elseif provider == :claude
        claude_config("sonnet")
    elseif provider == :ollama
        ollama_config("gpt-oss:20b-gpu")
    else
        error("Unknown provider: $provider")
    end

    return HTTPAgent(config)
end

"""
    create_llm_chat_agent(book::BonitoBook.Book)

Create LLM chat agent for the plugin. Always uses HTTPAgent with auto-detection.
"""
function create_llm_chat_agent(book::BonitoBook.Book)
    return create_http_agent()
end
