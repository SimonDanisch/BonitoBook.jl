"""
MCP (Model Context Protocol) HTTP server for Julia code execution in BonitoBook
"""

using JSON3
using Random

"""
MCP server that provides Julia code execution capabilities
"""
struct MCPJuliaServer
    runner::AsyncRunner
    server::Bonito.Server
    secret::String
    function MCPJuliaServer(runner::AsyncRunner, server::Bonito.Server)
        return new(runner, server, randstring(32))
    end
end

function find_server(session::Session)
    root = Bonito.root_session(session)
    if root.asset_server isa Bonito.HTTPAssetServer
        return root.asset_server.server
    end
    if root.connection isa Bonito.AbstractWebsocketConnection
        return root.connection.server
    end
    return nothing
end


"""
Get the server URL
"""
function get_server_url(server::MCPJuliaServer)
    return Bonito.online_url(server.server, "/julia-mcp/$(server.secret)")
end


function add_julia_mpc_route!(book::Book)
    session = book.session
    runner = book.runner
    server = find_server(session)
    if isnothing(server)
        @warn "No server found for session $(session), cannot add MCP Julia server"
        return nothing
    end
    mcp_server = MCPJuliaServer(runner, server)
    book.mcp_server = mcp_server
    route!(server, "/julia-mcp/$(mcp_server.secret)" => mcp_server)
    cli = try
        ClaudeCodeSDK.find_cli()
    catch e
        @warn "Claude CLI not found, MCP server may not be fully functional" exception=(e, Base.catch_backtrace())
        nothing
    end
    if !isnothing(cli)
        cd(book.folder) do
            try
                try
                    run(`$cli mcp remove julia-server`)
                catch e
                end
                run(`$cli mcp add --transport http julia-server $(get_server_url(mcp_server))`)
            catch e
                @warn "Error when adding the MCP julia server" exception=(e, Base.catch_backtrace())
            end
        end
    else
        @warn "Claude CLI not found, MCP server may not be fully functional"
    end
    return mcp_server
end

function respond_to_request(server, method, params, id)
    if method == "tools/list"
        return create_response(id, handle_list_tools())
    elseif method == "tools/call"
        result, err = handle_call_tool(server, params)
        return create_response(id, result, err)
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
        return create_response(id, result)
    elseif method == "notifications/initialized"
        # No response needed for initialized notification
        return create_response(id, Dict())
    else
        return create_response(id, nothing, Dict("code" => -32601, "message" => "Method not found: $method"))
    end
end

## Handler for requests!
function (server::MCPJuliaServer)(context)
    req = context.request
    try
        # Parse the JSON-RPC request
        request_data = JSON3.read(String(req.body))
        method = get(request_data, "method", "")
        id = get(request_data, "id", nothing)
        params = get(request_data, "params", nothing)
        response = respond_to_request(server, method, params, id)
        # Return HTTP response
        return HTTP.Response(200,
            ["Content-Type" => "application/json"],
            JSON3.write(response)
        )
    catch e
        @error "Error handling MCP request" exception=e
        err = Dict("code" => -32700, "message" => "Parse error: $(string(e))")
        error_response = create_response(nothing, nothing, err)
        return HTTP.Response(500,
            ["Content-Type" => "application/json"],
            JSON3.write(error_response))
    end
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
        err = error isa String ? Dict("code" => -1, "message" => error) : error
        response["error"] = err
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
    runner = server.runner
    output = Observable{Any}()
    logging = Observable{String}("")
    result_log = Observable{String}("")
    on(logging) do log
        result_log[] = result_log[] * log
    end
    println("Runninc code via mpc:\n", code)
    put!(runner.task_queue, RunnerTask(code, output, logging, "julia"))
    result_chan = Channel{Any}(1)
    on(output) do res
        put!(result_chan, res)
    end
    result = take!(result_chan)
    return (!(result isa Exception), result, result_log[])
end

"""
Handle call_tool request - executes the specified tool
"""
function handle_call_tool(server::MCPJuliaServer, params)
    if params === nothing || !haskey(params, "name")
        return nothing, "Missing 'name' parameter"
    end
    tool_name = params["name"]
    arguments = get(params, "arguments", Dict())

    tool_name != "julia_exec" && return nothing, "Unknown tool: $tool_name"
    !haskey(arguments, "code") && return nothing, "Missing 'code' argument"

    code = arguments["code"]
    success, output, logging = execute_julia_code(server, code)

    if success
        # Build the response text with output and logging
        response_text = """
            Julia code executed successfully:
            Result of the execution:
            $output
            Logs:
            $logging
        """

        result = Dict{String, Any}(
            "content" => [
                Dict{String, Any}(
                    "type" => "text",
                    "text" => response_text
                )
            ]
        )
        return result, nothing
    else
        err = sprint() do io
            println("error:")
            showerror(io, output)
            println("logs:")
            println(logging)
        end
        return nothing, err
    end
end


# Export functions
export MCPJuliaServer, get_server_url
