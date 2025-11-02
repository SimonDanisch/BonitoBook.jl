using Bonito.HTTP
using JSON3
using Bonito.Base64

"""
    AbstractApi

Base type for all HTTP API implementations (OpenAI, Claude, Ollama, etc.)
"""
abstract type AbstractApi end

"""
    OpenAIApi <: AbstractApi

Configuration for OpenAI API.

# Fields
- `endpoint::String`: API endpoint URL
- `model::String`: Model identifier
- `api_key::String`: API key
- `system_prompt::String`: System prompt for the agent
"""
struct OpenAIApi <: AbstractApi
    endpoint::String
    model::String
    api_key::String
    system_prompt::String
end

"""
    ClaudeApi <: AbstractApi

Configuration for Claude/Anthropic API.

# Fields
- `endpoint::String`: API endpoint URL
- `model::String`: Model identifier
- `api_key::String`: API key
- `system_prompt::String`: System prompt for the agent
"""
struct ClaudeApi <: AbstractApi
    endpoint::String
    model::String
    api_key::String
    system_prompt::String
end

"""
    OllamaApi <: AbstractApi

Configuration for Ollama (local) API.

# Fields
- `endpoint::String`: API endpoint URL
- `model::String`: Model identifier
- `system_prompt::String`: System prompt for the agent
"""
struct OllamaApi <: AbstractApi
    endpoint::String
    model::String
    system_prompt::String
end

"""
    HTTPAgent <: LLMChatAgent

Generic HTTP-based agent that works with OpenAI, Claude, Ollama, and compatible APIs.

# Fields
- `api::AbstractApi`: The API provider (OpenAI, Claude, Ollama)
- `max_tokens::Int`: Maximum tokens in response
- `temperature::Float64`: Sampling temperature
- `system_prompt::String`: System prompt for the agent
- `tools::Vector{Type{<:AbstractTool}}`: Available tools
- `tool_choice::String`: How to use tools ("auto", "required", "none")
- `max_tool_use_token::Int`: Maximum tokens to send back from tool results
- `needs_to_be_done::Dict{DataType, AbstractTool}`: TodoList or other multi-step tasks
- `last_item::Base.RefValue{Union{AbstractTool, String}}`: Last processed item
"""
struct HTTPAgent <: LLMChatAgent
    api::AbstractApi
    max_tokens::Int
    temperature::Float64
    system_prompt::String
    tools::Vector{DataType}
    tool_choice::String
    max_tool_use_token::Int
    # TodoList or other tools implementing multi-step tasks
    needs_to_be_done::Dict{DataType,AbstractTool}
    last_item::Base.RefValue{Union{AbstractTool,String}}
end

# Full constructor with keyword arguments for customization
function HTTPAgent(api::AbstractApi;
    max_tokens::Int=4096,
    temperature::Float64=0.7,
    system_prompt::String="You are a helpful AI assistant integrated into a Julia notebook.",
    tools::Vector{DataType}=DEFAULT_TOOLS,
    tool_choice::String="auto",
    max_tool_use_token::Int=4000)
    return HTTPAgent(
        api,
        max_tokens,
        temperature,
        system_prompt,
        tools,
        tool_choice,
        max_tool_use_token,
        Dict{DataType,AbstractTool}(),
        Ref{Union{AbstractTool,String}}("")
    )
end

# ============================================================================
# API Methods
# ============================================================================

"""
    headers(api::AbstractApi)

Get HTTP headers for the API request.
"""
function headers(api::OpenAIApi)
    return [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $(api.api_key)"
    ]
end

function headers(api::ClaudeApi)
    return [
        "Content-Type" => "application/json",
        "x-api-key" => api.api_key,
        "anthropic-version" => "2023-06-01"
    ]
end

function headers(api::OllamaApi)
    return ["Content-Type" => "application/json"]
end

"""
    base_url(api::AbstractApi)

Get the base URL/endpoint for the API.
"""
base_url(api::AbstractApi) = api.endpoint

"""
    model_name(api::AbstractApi)

Get the model name for the API.
"""
model_name(api::AbstractApi) = api.model

"""
    system_prompt(api::AbstractApi)

Get the system prompt for the API.
"""
system_prompt(api::AbstractApi) = api.system_prompt

"""
    request_body(api::AbstractApi, messages::Vector, tools::Vector)

Build the request body for the API.
"""
function request_body(api::OpenAIApi, messages::Vector, tools::Vector)
    body = Dict(
        "model" => api.model,
        "messages" => messages,
        "stream" => true
    )
    if !isempty(tools)
        body["tools"] = [tool_to_openai(T) for T in tools]
    end
    return body
end

function request_body(api::ClaudeApi, messages::Vector, tools::Vector)
    # Extract system message (Claude handles it separately)
    system_msg = api.system_prompt
    user_messages = filter(m -> m["role"] != "system", messages)

    body = Dict(
        "model" => api.model,
        "messages" => user_messages,
        "system" => system_msg,
        "stream" => true,
        "max_tokens" => 64000
    )
    if !isempty(tools)
        body["tools"] = [tool_to_claude(T) for T in tools]
    end
    return body
end

function request_body(api::OllamaApi, messages::Vector, tools::Vector)
    body = Dict(
        "model" => api.model,
        "messages" => messages,
        "stream" => true
    )
    if !isempty(tools)
        body["tools"] = [tool_to_openai(T) for T in tools]  # Ollama uses OpenAI format
    end
    return body
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
    return OpenAIApi(endpoint, model, api_key, DEFAULT_SYSTEM_PROMPT)
end

"""
    claude_config(model::String; api_key=nothing, endpoint="https://api.anthropic.com/v1/messages")

Create configuration for Claude API.
"""
function claude_config(model::String; api_key=nothing, endpoint="https://api.anthropic.com/v1/messages")
    api_key = something(api_key, get(ENV, "CLAUDE_API_KEY", nothing))
    return ClaudeApi(endpoint, model, api_key, DEFAULT_SYSTEM_PROMPT)
end

"""
    ollama_config(model::String; endpoint="http://localhost:11434/api/chat")

Create configuration for Ollama.
"""
function ollama_config(model::String; endpoint="http://localhost:11434/api/chat")
    return OllamaApi(endpoint, model, DEFAULT_SYSTEM_PROMPT)
end

"""
    detect_api(model::String)

Detect and create the appropriate API based on the model name.
"""
function detect_api(model::String)
    # Detect based on model name patterns
    if startswith(model, "claude") || contains(model, "claude")
        api_key = get(ENV, "CLAUDE_API_KEY", nothing)
        return ClaudeApi("https://api.anthropic.com/v1/messages", model, api_key, "")
    elseif startswith(model, "gpt") || contains(model, "openai")
        api_key = get(ENV, "OPENAI_API_KEY", nothing)
        return OpenAIApi("https://api.openai.com/v1/chat/completions", model, api_key, "")
    else
        # Fallback to Ollama for local models
        return OllamaApi("http://localhost:11434/api/chat", model, "")
    end
end

const DEFAULT_SYSTEM_PROMPT = """
You are a helpful AI assistant integrated into a Julia notebook.

# Agent Loop Behavior
- If you respond with a tool, the loop will execute it and show the result, add it to the message history and continue.
- If you respond with text AND there's no active TODO, the loop will stop and show your message.
- You can call multiple tools in sequence if needed.
- The loop allows iterative work: respond → see results → respond again
- Don't hesitate to use tools to inspect files, run code, and perform actions

# Guidelines
* Keep things concise and to the point
* Don't do more than the user asked for
* If the user asks for code, always use the add_cell tool to add a new cell with the julia code
* Don't ever use println if not explicitly asked for - you're in a notebook, every last line gets visualized as cell output
* Always use WGLMakie for plotting unless explicitly asked for another library

# Julia specific tips:
- Please dont ever activate any Pkg env! Always assume the user started you in the target env
- Use `@doc(sym_or_var)` to get documentation for a function or package
- Use `names(PackageName)` to get a list of functions in a package
- Use `using PackageName` to load a package
- Pkg.status() to see installed packages - never install a package if it's already in the env
- If asked for code or commands, only answer the requested command/code without explanation
- If asked something simple, give the simplest version (e.g., for a slider, give a simple slider assigned to a variable)
"""

# ============================================================================
# Core implementation
# ============================================================================

"""
    parse_sse(io::IO, callback::Function; spinner::Union{TaskSpinner, Nothing}=nothing)

Parse Server-Sent Events (SSE) from an IO stream and call callback with each parsed JSON chunk.
Handles line buffering and SSE format ("data: {...}").

# Arguments
- `io`: The IO stream to read from
- `callback`: Function to call with each parsed JSON chunk
- `spinner`: Optional TaskSpinner for cancellation
"""
function parse_sse(callback::Function, io::IO; spinner::Union{TaskSpinner,Nothing}=nothing)
    line_buffer = ""

    # Read response stream chunk by chunk
    while !eof(io)
        # Check stop flag
        if spinner !== nothing && spinner.stop[]
            @info "SSE parsing cancelled by stop flag"
            break
        end

        # Read available data
        chunk = String(readavailable(io))
        line_buffer *= chunk

        # Process complete lines
        while contains(line_buffer, '\n')
            line, line_buffer = split(line_buffer, '\n', limit=2)

            # Skip empty lines
            if isempty(strip(line))
                continue
            end

            # Parse SSE format: "data: {...}"
            if startswith(line, "data: ")
                data_str = strip(line[7:end])

                # Skip SSE control messages
                if data_str == "[DONE]" || isempty(data_str)
                    continue
                end
                parsed_chunk = JSON3.read(data_str)
                callback(parsed_chunk)
            end
        end
    end

    # Process any remaining data in buffer
    if !isempty(strip(line_buffer)) && startswith(line_buffer, "data: ")
        data_str = strip(line_buffer[7:end])
        if data_str != "[DONE]" && !isempty(data_str)
            parsed_chunk = JSON3.read(data_str)
            callback(parsed_chunk)
        end
    end
end

"""
    prompt(agent::HTTPAgent, messages::Vector{AgentMessage};
           spinner::Union{TaskSpinner, Nothing}=nothing)

Call the HTTP agent with streaming and return a Channel that yields complete content blocks (tools and text).
The Channel is closed after all items are yielded.

# Optional Arguments
- `spinner`: TaskSpinner for operation tracking and cancellation
"""
function prompt(callback, agent::HTTPAgent, messages::Vector{AgentMessage};
    spinner::Union{TaskSpinner,Nothing}=nothing)
    api = agent.api

    # Convert messages to API format
    api_messages = [
        Dict("role" => "system", "content" => agent.system_prompt),
        [message_to_api(api, msg) for msg in messages]...
    ]

    # Build request with streaming enabled
    body = request_body(api, api_messages, agent.tools)

    # Remove null fields
    filter!(p -> p.second !== nothing, body)
    req_headers = headers(api)

    # Use HTTP.open for true streaming, disable automatic status exceptions
    HTTP.open("POST", base_url(api), req_headers; status_exception=false) do io
        async_spinner!(spinner, "http request") do
            # Write request body
            JSON3.write(io, body)
            closewrite(io)

            # Start reading response
            resp = startread(io)
            # Check response status
            if resp.status >= 400
                # Read error response body
                error_body = read(io, String)
                callback("HTTP $(resp.status): $error_body")
                return
            end

            # Parse SSE stream and pass chunks to response parser
            try
                state = parse_state(api)
                parse_sse(io, spinner=spinner) do parsed_chunk
                    parse_response(state, parsed_chunk) do item
                        callback(item)
                    end
                end
            catch e
                @warn "Failed to parse SSE stream" exception = e
                callback("Error parsing response stream: $(string(e))")
            end
        end
    end
end


function prompt(agent::HTTPAgent, messages::Vector{AgentMessage};
    spinner::Union{TaskSpinner,Nothing}=nothing)
    return Channel{Union{AbstractTool,String}}(Inf, spawn=true) do chan
        prompt(item -> put!(chan, item), agent, messages; spinner=spinner)
        close(chan)
    end
end

# ============================================================================
# Message conversion
# ============================================================================

"""
    message_to_api(api::AbstractApi, msg::AgentMessage)

Convert AgentMessage to API-specific format. Default implementation for Claude-style APIs.
"""
function message_to_api(api::AbstractApi, msg::AgentMessage)
    api_role = msg.role == :user ? "user" : "assistant"
    content_value = message_to_api(api, msg.content, msg.cell_id)
    return Dict("role" => api_role, "content" => content_value)
end

"""
    message_to_api(api::OpenAIApi, msg::AgentMessage)

Convert AgentMessage to OpenAI format. Merges additional fields from content conversion.
"""
function message_to_api(api::OpenAIApi, msg::AgentMessage)
    api_role = msg.role == :user ? "user" : "assistant"

    # Get content value or additional fields from content-specific method
    content_or_fields = message_to_api(api, msg.content, msg.cell_id)

    # Start with base message dict
    msg_dict = Dict{String,Any}("role" => api_role, "content" => nothing)

    # If content method returned a dict, merge additional fields
    if content_or_fields isa Dict
        merge!(msg_dict, content_or_fields)
    else
        # Otherwise it's just the content value
        msg_dict["content"] = content_or_fields
    end

    return msg_dict
end

# Ollama uses OpenAI format
message_to_api(api::OllamaApi, msg::AgentMessage) = message_to_api(OpenAIApi("", "", "", ""), msg)

# ============================================================================
# Content value conversion (returns just the content value, not full message dict)
# ============================================================================

"""
    message_to_api(api::AbstractApi, content::AbstractString, cell_id)

Convert string to content value (string or array of content parts for multimodal).
"""
function message_to_api(api::AbstractApi, content::AbstractString, cell_id)
    content_parts = parse_content_with_media(string(content))

    if length(content_parts) > 1
        # Multi-part message with images/files
        return content_parts
    end
    # Simple text message
    return string(content)
end

"""
    message_to_api(api::AbstractApi, tool::AbstractTool, cell_id)

Convert tool to content value (array with tool_use block for Claude-style APIs).
"""
function message_to_api(api::AbstractApi, tool::AbstractTool, cell_id)
    tool_id = "tool_$(cell_id)"
    return [Dict(
        "type" => "tool_use",
        "id" => tool_id,
        "name" => Base.invokelatest(tool_name, typeof(tool)),
        "input" => tool
    )]
end

"""
    message_to_api(api::OpenAIApi, tool::AbstractTool, cell_id)

Convert tool for OpenAI format (returns dict with tool_calls field to be merged).
"""
function message_to_api(api::OpenAIApi, tool::AbstractTool, cell_id)
    tool_id = "tool_$(cell_id)"
    fields = [String(f) => getfield(tool, f) for f in propertynames(tool)]

    return Dict(
        "tool_calls" => [Dict(
            "id" => tool_id,
            "type" => "function",
            "function" => Dict(
                "name" => Base.invokelatest(tool_name, typeof(tool)),
                "arguments" => JSON3.write(Dict(fields))
            )
        )]
    )
end

"""
    message_to_api(api::AbstractApi, result::ToolResult, cell_id)

Convert tool result to content value (array with tool_result block for Claude-style APIs).
"""
function message_to_api(api::AbstractApi, result::ToolResult, cell_id)
    tool_id = "tool_$(cell_id)"

    # Convert result to string
    result_str = if !result.success && result.result isa Exception
        "Error: $(string(result.result))"
    elseif result.result isa Dict && haskey(result.result, "error")
        "Error: $(result.result["error"])"
    else
        repr(result.result)
    end

    return [Dict(
        "type" => "tool_result",
        "tool_use_id" => tool_id,
        "content" => result_str
    )]
end

"""
    message_to_api(api::OpenAIApi, result::ToolResult, cell_id)

Convert tool result for OpenAI format (returns dict with role and tool_call_id to be merged).
"""
function message_to_api(api::OpenAIApi, result::ToolResult, cell_id)
    tool_id = "tool_$(cell_id)"

    # Convert result to string
    result_str = if !result.success && result.result isa Exception
        "Error: $(string(result.result))"
    elseif result.result isa Dict && haskey(result.result, "error")
        "Error: $(result.result["error"])"
    else
        repr(result.result)
    end

    return Dict(
        "role" => "tool",
        "tool_call_id" => tool_id,
        "content" => result_str
    )
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
function tool_to_openai(::Type{T}) where T<:AbstractTool
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
function tool_to_claude(::Type{T}) where T<:AbstractTool
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
        "file_tool" => FileTool,
        "http_get" => HttpGetTool,
        "add_cell" => AddCellTool,
        "todo_list" => TodoList
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
    tool_calls::Dict{Int,Dict{String,Any}}  # index => {name, arguments}
    text_buffer::String
end

OpenAIStreamState() = OpenAIStreamState(Dict{Int,Dict{String,Any}}(), "")
parse_state(::Union{OllamaApi,OpenAIApi}) = OpenAIStreamState()

function parse_response(f, state::OpenAIStreamState, chunk)
    choices = get(chunk, :choices, nothing)
    if choices === nothing || isempty(choices)
        return
    end

    choice = choices[1]
    delta = get(choice, :delta, nothing)
    if delta !== nothing
        # --- Handle tool calls ---
        if haskey(delta, :tool_calls)
            for tool_delta in delta.tool_calls
                idx = tool_delta.index
                tool = get!(state.tool_calls, idx, Dict("name" => "", "arguments" => ""))
                func = get(tool_delta, :function, nothing)
                if func !== nothing
                    if haskey(func, :name) && !isempty(func.name)
                        tool["name"] = func.name
                    end
                    if haskey(func, :arguments) && func.arguments !== nothing
                        tool["arguments"] *= func.arguments
                    end
                end
            end
        end

        # --- Handle text output ---
        if haskey(delta, :content) && delta.content !== nothing
            state.text_buffer *= delta.content
        end
    end
    # --- Handle completion ---
    if get(choice, :finish_reason, nothing) !== nothing
        # Emit tool calls first
        for (idx, tool_data) in sort(collect(state.tool_calls), by=first)
            tool_name = tool_data["name"]
            args_json = tool_data["arguments"]

            if !isempty(tool_name) && !isempty(args_json)
                tool_type = tool_name_to_type(tool_name)
                if tool_type !== nothing
                    try
                        tool = JSON3.read(args_json, tool_type)
                        f(tool)
                    catch e
                        @warn "Failed to parse tool arguments" tool_name args_json exception = e
                    end
                end
            end
        end
        # Emit text if any
        if !isempty(strip(state.text_buffer))
            f(state.text_buffer)
        end
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
    stop_reason::Union{String,Nothing}
end

ClaudeStreamState() = ClaudeStreamState(-1, "", "", "", "", nothing)


parse_state(::ClaudeApi) = ClaudeStreamState()

function parse_response(f, state::ClaudeStreamState, chunk)
    event_type = get(chunk, :type, "")

    if event_type == "message_start"
        # Message starting - can access initial metadata if needed
        # Currently nothing to do here
        return
    elseif event_type == "content_block_start"
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
                f(state.text_buffer)
            end
            state.text_buffer = ""
        elseif state.current_block_type == "tool_use"
            if !isempty(state.tool_name) && !isempty(state.tool_input_buffer)
                tool_type = tool_name_to_type(state.tool_name)
                if tool_type !== nothing
                    try
                        # Fix common LLM mistakes: "null" string should be null
                        # Replace "metadata": "null" with "metadata": null
                        fixed_input = replace(state.tool_input_buffer, r"\"metadata\"\s*:\s*\"null\"" => "\"metadata\": null")
                        tool = JSON3.read(fixed_input, tool_type)
                        f(tool)
                    catch e
                        @warn "Failed to parse tool input" tool_name = state.tool_name input = state.tool_input_buffer exception = e
                    end
                end
            end
            state.tool_name = ""
            state.tool_input_buffer = ""
        end

    elseif event_type == "message_delta"
        # Message-level updates (stop_reason, usage, etc.)
        if haskey(chunk, :delta)
            delta = chunk.delta
            if haskey(delta, :stop_reason) && delta.stop_reason !== nothing
                state.stop_reason = delta.stop_reason
            end
        end

    elseif event_type == "message_stop"
        # End of message - handle incomplete blocks and emit stop_reason if we have one
        # If we have incomplete content when message stops, emit what we have
        if state.stop_reason == "max_tokens"
            # Handle incomplete tool - warn about it
            if state.current_block_type == "tool_use" && !isempty(state.tool_input_buffer)
                @warn "Tool call truncated due to max_tokens" tool_name = state.tool_name partial_input = state.tool_input_buffer
            end
            # Handle incomplete text - emit it
            if state.current_block_type == "text" && !isempty(strip(state.text_buffer))
                f(state.text_buffer)
            end
        end
        if state.stop_reason !== nothing
            # Emit stop reason as informational message only for actual issues
            stop_msg = if state.stop_reason == "max_tokens"
                "⚠️ Response truncated: Maximum token limit reached"
            elseif state.stop_reason == "end_turn"
                # Normal text completion - don't emit anything
                nothing
            elseif state.stop_reason == "tool_use"
                # Normal tool use completion - don't emit anything
                nothing
            elseif state.stop_reason == "stop_sequence"
                "Response stopped at specified sequence"
            else
                # Unknown stop reason - report it
                "Response stopped: $(state.stop_reason)"
            end

            if stop_msg !== nothing
                f(stop_msg)
            end
        end
        return

    elseif event_type == "ping"
        # Keepalive ping - nothing to do
        return
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

    api = if provider == :openai
        openai_config("gpt-4")
    elseif provider == :claude
        claude_config("sonnet")
    elseif provider == :ollama
        ollama_config("gpt-oss:20b-gpu")
    else
        error("Unknown provider: $provider")
    end

    return HTTPAgent(api)
end

"""
    create_llm_chat_agent(book::BonitoBook.Book)

Create LLM chat agent for the plugin. Always uses HTTPAgent with auto-detection.
"""
function create_llm_chat_agent(book::BonitoBook.Book)
    return create_http_agent()
end
