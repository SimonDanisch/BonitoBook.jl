"""
MCP (Model Context Protocol) HTTP server for Julia code execution in BonitoBook
"""

using Bonito.HTTP
using JSON3

"""
MCP server that provides Julia code execution capabilities
"""
mutable struct MCPJuliaServer
    runner::Union{AsyncRunner, Nothing}
    server::Union{HTTP.Server, Nothing}
    port::Int
    host::String

    function MCPJuliaServer(runner; port=8237, host="127.0.0.1")
        new(runner, nothing, port, host)
    end
end

"""
MCP JSON-RPC 2.0 message structure
"""
struct MCPRequest
    jsonrpc::String
    id::Union{String, Int, Nothing}
    method::String
    params::Union{Dict{String, Any}, Nothing}
end

struct MCPResponse
    jsonrpc::String
    id::Union{String, Int, Nothing}
    result::Union{Dict{String, Any}, Nothing}
    error::Union{Dict{String, Any}, Nothing}
end

"""
Create a JSON-RPC response
"""
function create_response(id, result=nothing, error=nothing)
    response = Dict{String, Any}(
        "jsonrpc" => "2.0",
        "id" => id
    )

    if error !== nothing
        response["error"] = error
    else
        response["result"] = result
    end

    return response
end

"""
Handle list_tools request - returns available tools
"""
function handle_list_tools()
    tools = [
        Dict{String, Any}(
            "name" => "julia_exec",
            "description" => "Execute Julia code in the current BonitoBook module context. This preserves variables and state between executions, making it perfect for interactive development and analysis.",
            "inputSchema" => Dict{String, Any}(
                "type" => "object",
                "properties" => Dict{String, Any}(
                    "code" => Dict{String, Any}(
                        "type" => "string",
                        "description" => "The Julia code to execute"
                    )
                ),
                "required" => ["code"]
            )
        )
    ]

    return Dict("tools" => tools)
end

"""
Execute Julia code using the server's runner
"""
function execute_julia_code(server::MCPJuliaServer, code::String)
    @show code
    if server.runner === nothing
        return (false, "No runner available - server not properly initialized")
    end
    mod = (server.runner isa AsyncRunner) ? server.runner.mod : Main
    result = fetch(spawnat(1) do
        try
            return include_string(mod, code)
        catch e
            return e
        end
    end)

    return (!(result isa Exception), result)
end

"""
Handle call_tool request - executes the specified tool
"""
function handle_call_tool(server::MCPJuliaServer, id, params)
    if params === nothing || !haskey(params, "name")
        return Dict("error" => Dict("code" => -1, "message" => "Missing tool name"))
    end

    tool_name = params["name"]
    arguments = get(params, "arguments", Dict())

    if tool_name == "julia_exec"
        if !haskey(arguments, "code")
            return Dict("error" => Dict("code" => -1, "message" => "Missing 'code' argument"))
        end

        code = arguments["code"]
        success, output = execute_julia_code(server, code)

        if success
            result = Dict{String, Any}(
                "content" => [
                    Dict{String, Any}(
                        "type" => "text",
                        "text" => "Julia code executed successfully:\\n```julia\\n$code\\n```\\n\\nOutput:\\n```\\n$output\\n```"
                    )
                ]
            )
            return Dict("result" => result)
        else
            return Dict("error" => Dict("code" => -1, "message" => output))
        end
    else
        return Dict("error" => Dict("code" => -1, "message" => "Unknown tool: $tool_name"))
    end
end

"""
HTTP request handler for MCP requests
"""
function mcp_request_handler(server::MCPJuliaServer)
    return function(req::HTTP.Request)
        try
            # Parse the JSON-RPC request
            request_data = JSON3.read(String(req.body))

            method = get(request_data, "method", "")
            id = get(request_data, "id", nothing)
            params = get(request_data, "params", nothing)

            response = if method == "tools/list"
                create_response(id, handle_list_tools())
            elseif method == "tools/call"
                response_data = handle_call_tool(server, id, params)
                if haskey(response_data, "error")
                    create_response(id, nothing, response_data["error"])
                else
                    create_response(id, response_data["result"])
                end
            elseif method == "initialize"
                # Initialize response
                result = Dict{String, Any}(
                    "protocolVersion" => "2024-11-05",
                    "capabilities" => Dict{String, Any}(
                        "tools" => Dict{String, Any}()
                    ),
                    "serverInfo" => Dict{String, Any}(
                        "name" => "BonitoBook Julia Executor",
                        "version" => "1.0.0"
                    )
                )
                create_response(id, result)
            elseif method == "initialized"
                # No response needed for initialized notification
                create_response(id, Dict())
            else
                create_response(id, nothing, Dict("code" => -32601, "message" => "Method not found: $method"))
            end

            # Return HTTP response
            return HTTP.Response(200,
                ["Content-Type" => "application/json"],
                JSON3.write(response))

        catch e
            @error "Error handling MCP request" exception=e
            error_response = create_response(nothing, nothing,
                Dict("code" => -32700, "message" => "Parse error: $(string(e))"))
            return HTTP.Response(500,
                ["Content-Type" => "application/json"],
                JSON3.write(error_response))
        end
    end
end


function try_listen(handler, url, port)
    try
        return HTTP.serve!(handler, url, port)
    catch e
        if e isa Base.IOError
            #address already in use
            if e.code == Base.UV_EADDRINUSE
                return try_listen(handler, url, port + 1)
            end
        end
        rethrow(e)
    end
end


"""
Start the MCP HTTP server
"""
function start_server!(server::MCPJuliaServer)
    if server.server !== nothing
        @warn "Server already running"
        return server.port
    end

    handler = mcp_request_handler(server)
    # Start HTTP server
    server.server = try_listen(handler, server.host, server.port)

    @info "MCP Julia Server started on $(server.host):$(server.port)"
    cli = ClaudeCodeSDK.find_cli()
    if !isnothing(cli)
        run(`$cli mcp add --transport http julia-server $(get_server_url(server))`)
    else
        @warn "Claude CLI not found, MCP server may not be fully functional"
    end
    return server.port
end

"""
Stop the MCP HTTP server
"""
function stop_server!(server::MCPJuliaServer)
    if server.server !== nothing
        close(server.server)
        server.server = nothing
        @info "MCP Julia Server stopped"
    end
end

"""
Get the server URL
"""
function get_server_url(server::MCPJuliaServer)
    port = server.server.listener.hostport
    return "http://$(server.host):$(port)"
end

# Export functions
export MCPJuliaServer, start_server!, stop_server!, get_server_url
