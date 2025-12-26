using JSON3
using Glob

"""
    AbstractTool

Base type for all LLM tools. Tools define actions the agent can take.

To create a custom tool:
1. Define a struct inheriting from AbstractTool
2. Implement `tool_name(::Type{YourTool})` to return the tool name
3. Implement `tool_description(::Type{YourTool})` to describe what it does
4. Implement `tool_input_schema(::Type{YourTool})` to define input parameters
5. Implement `execute_tool(tool::YourTool)` to perform the action
"""
abstract type AbstractTool end

"""
    ToolResult

Result of executing a tool. Contains the result data and whether it succeeded.

# Fields
- `result::Any`: The result data (can be string, dict, array, etc.)
- `success::Bool`: Whether the tool execution succeeded (auto-set from result type)
"""
struct ToolResult
    result::Any
    success::Bool
end

# Constructor that auto-detects success from Exception
function ToolResult(result)
    success = !(result isa Exception)
    return ToolResult(result, success)
end

"""
    ToolExecution{T<:AbstractTool}

Represents a tool execution with its tool and result.
Used for serialization and message conversion.

# Fields
- `tool::T`: The tool that was executed
- `result::ToolResult`: The result of the execution
"""
struct ToolExecution{T<:AbstractTool}
    tool::T
    result::ToolResult
end

"""
    SummarizedToolExecution{T<:AbstractTool}

Represents a summarized tool execution for display efficiency.
The full execution is stored on disk and can be retrieved via cell ID.

# Fields
- `tool::T`: The tool that was executed
- `result_summary::String`: Summary of the result
- `result_size::Int`: Size of the full result in characters
- `cell_id::String`: ID of the cell containing this execution (for lookup)
- `is_error::Bool`: Whether the execution resulted in an error
"""
struct SummarizedToolExecution{T<:AbstractTool}
    tool::T
    result_summary::String
    result_size::Int
    cell_id::String
    is_error::Bool
end

"""
    should_summarize(result::ToolResult; min_size=1000)

Check if a tool result should be summarized based on its size.
"""
function should_summarize(result::ToolResult; min_size=1000)
    if !result.success
        return false  # Don't summarize errors
    end

    # Check size of result
    result_str = string(result.result)
    return length(result_str) >= min_size
end

"""
    summarize_result(result::ToolResult; max_length=200)

Create a summary of a tool result by truncating it intelligently.
"""
function summarize_result(result::ToolResult; max_length=200)
    if !result.success
        return string(result.result)  # Keep errors full
    end

    result_str = string(result.result)

    if length(result_str) <= max_length
        return result_str
    end

    # For long results, show first 150 chars + ellipsis + last 50 chars
    prefix_len = max_length - 53  # Leave room for ellipsis and suffix
    suffix_len = 50

    prefix = result_str[1:min(prefix_len, length(result_str))]
    if length(result_str) > prefix_len + suffix_len
        suffix = result_str[end-suffix_len+1:end]
        return prefix * "\n...\n[$(length(result_str) - prefix_len - suffix_len) chars omitted]\n...\n" * suffix
    else
        return prefix * "..."
    end
end

"""
    SummarizedToolExecution(execution::ToolExecution{T}, cell_id::String) where T

Create a summarized version of a tool execution.
"""
function SummarizedToolExecution(execution::ToolExecution{T}, cell_id::String) where T
    summary = summarize_result(execution.result)
    size = length(string(execution.result.result))
    is_error = !execution.result.success

    return SummarizedToolExecution{T}(
        execution.tool,
        summary,
        size,
        cell_id,
        is_error
    )
end

"""
    tool_name(::Type{<:AbstractTool})

Return the name of the tool as it should be presented to the LLM.
"""
function tool_name(::Type{<:AbstractTool})
    error("tool_name must be implemented for each tool type")
end

"""
    tool_description(::Type{<:AbstractTool})

Return a description of what the tool does for the LLM.
"""
function tool_description(::Type{<:AbstractTool})
    error("tool_description must be implemented for each tool type")
end

"""
    tool_input_schema(::Type{<:AbstractTool})

Return the JSON schema for the tool's input parameters.
"""
function tool_input_schema(::Type{<:AbstractTool})
    error("tool_input_schema must be implemented for each tool type")
end

"""
    execute_tool(tool::AbstractTool)

Execute the tool and return the raw result without error handling.
Each tool type must implement this method.
"""
function execute_tool(tool::AbstractTool)
    error("execute_tool must be implemented for each tool type")
end

"""
    limit_output(result, max_tokens::Int)

Limit the output size to approximately max_tokens.
Assumes ~4 characters per token as a rough estimate.

# Arguments
- `result`: The result to limit (String, Dict, Array, or other)
- `max_tokens::Int`: Maximum tokens to allow

# Returns
Limited version of the result, truncated with indicator if too long.
"""
function limit_output(result::String, max_tokens::Int)
    max_chars = max_tokens * 4  # Rough estimate: 4 chars per token
    if length(result) <= max_chars
        return result
    end
    truncated = result[1:max_chars]
    return truncated * "\n\n... [OUTPUT TRUNCATED - showing first ~$max_tokens tokens of $(length(result) ÷ 4) total tokens]"
end

function limit_output(result::Dict, max_tokens::Int)
    # Convert to JSON string, limit, and parse back
    json_str = JSON3.write(result)
    limited_str = limit_output(json_str, max_tokens)

    # If truncated, return a simplified dict with truncation notice
    if contains(limited_str, "OUTPUT TRUNCATED")
        return Dict(
            "_truncated" => true,
            "_message" => "Output too large, showing summary",
            "_original_size_tokens" => length(json_str) ÷ 4,
            "_max_tokens" => max_tokens,
            "_partial_data" => result
        )
    end
    return result
end

function limit_output(result::AbstractArray, max_tokens::Int)
    # Convert to JSON string and limit
    json_str = JSON3.write(result)
    max_chars = max_tokens * 4

    if length(json_str) <= max_chars
        return result
    end

    # Return truncated array with notice
    total_items = length(result)
    # Estimate how many items we can fit
    avg_item_size = length(json_str) ÷ total_items
    items_to_keep = max(1, (max_chars ÷ 2) ÷ avg_item_size)

    truncated_result = result[1:min(items_to_keep, total_items)]
    return [
        truncated_result...,
        Dict(
            "_truncated" => true,
            "_showing" => length(truncated_result),
            "_total" => total_items,
            "_message" => "Array truncated to fit token limit"
        )
    ]
end

function limit_output(result::Exception, max_tokens::Int)
    # Limit exception message and stack trace
    error_str = sprint(showerror, result, catch_backtrace())
    return limit_output(error_str, max_tokens)
end

# Fallback for other types - convert to string and limit
function limit_output(result, max_tokens::Int)
    result_str = repr(result)
    return limit_output(result_str, max_tokens)
end

"""
    execute_tool!(tool::AbstractTool, max_tokens::Int=4000)

Execute the tool with error handling and return a ToolResult with output limited to max_tokens.
This is a generic wrapper that calls execute_tool(tool) and handles exceptions.

# Arguments
- `tool::AbstractTool`: The tool to execute
- `max_tokens::Int`: Maximum tokens to include in the result (default: 4000)
"""
function execute_tool!(tool::AbstractTool, max_tokens::Int=4000)
    try
        result = execute_tool(tool)
        limited_result = limit_output(result, max_tokens)
        return ToolResult(limited_result)
    catch e
        limited_error = limit_output(e, max_tokens)
        return ToolResult(limited_error)
    end
end


# ============================================================================
# Core Tools
# ============================================================================

"""
    BashTool <: AbstractTool

Execute bash commands in the shell.
"""
struct BashTool <: AbstractTool
    command::String
end

tool_name(::Type{BashTool}) = "bash"
tool_description(::Type{BashTool}) = """Execute bash commands in the shell.

**Usage Guidelines:**
- Use for running scripts, git operations, and system commands
- For file operations, prefer the `file_tool` instead (safer, no shell injection)
- Commands run in the current working directory
- Long-running commands may timeout

**Examples:**
- `git status` - Check git status
- `julia -e 'println(1+1)'` - Quick Julia evaluation (prefer add_cell for complex code)
- `ls -la` - List files with details"""
tool_input_schema(::Type{BashTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "command" => Dict(
            "type" => "string",
            "description" => "The bash command to execute"
        )
    ),
    "required" => ["command"]
)

function execute_tool(tool::BashTool)
    return read(Cmd(split(tool.command, " "; keepempty=false)), String)
end

"""
    FileReadTool <: AbstractTool

Read contents of a file, optionally specifying line ranges.
"""
struct FileReadTool <: AbstractTool
    path::String
    line_start::Union{Nothing, Int}
    line_end::Union{Nothing, Int}
end

FileReadTool(path::String) = FileReadTool(path, nothing, nothing)

tool_name(::Type{FileReadTool}) = "file_read"
tool_description(::Type{FileReadTool}) = """Read the contents of a file from the filesystem.

**Usage Guidelines:**
- Returns the full file content as text (or specified line range)
- Binary files may return garbled content
- Large files will be truncated to fit token limits
- Use `file_tool` with `readdir` to list directory contents first
- Use `line_start` and `line_end` to read specific line ranges (1-indexed, inclusive)

**Examples:**
- Read entire file: `{"path": "file.jl"}`
- Read lines 10-20: `{"path": "file.jl", "line_start": 10, "line_end": 20}`
- Read from line 50 to end: `{"path": "file.jl", "line_start": 50}`

**Tip:** After reading, the file will be opened in the side editor for your reference."""
tool_input_schema(::Type{FileReadTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "path" => Dict(
            "type" => "string",
            "description" => "Path to the file to read"
        ),
        "line_start" => Dict(
            "type" => "integer",
            "description" => "Starting line number (1-indexed, inclusive). If not specified, reads from beginning."
        ),
        "line_end" => Dict(
            "type" => "integer",
            "description" => "Ending line number (1-indexed, inclusive). If not specified, reads to end."
        )
    ),
    "required" => ["path"]
)

function execute_tool(tool::FileReadTool)
    if !isfile(tool.path)
        error("File not found: $(tool.path)")
    end
    
    content = read(tool.path, String)
    
    # If no line range specified, return full content
    if isnothing(tool.line_start) && isnothing(tool.line_end)
        return content
    end
    
    # Split into lines and extract range
    lines = split(content, '\n')
    total_lines = length(lines)
    
    start_line = isnothing(tool.line_start) ? 1 : tool.line_start
    end_line = isnothing(tool.line_end) ? total_lines : tool.line_end
    
    # Validate range
    if start_line < 1 || start_line > total_lines
        error("line_start ($start_line) out of range (file has $total_lines lines)")
    end
    if end_line < start_line || end_line > total_lines
        error("line_end ($end_line) out of range or before line_start (file has $total_lines lines)")
    end
    
    selected_lines = lines[start_line:end_line]
    result = join(selected_lines, '\n')
    
    # Add helpful header if range was used
    if !isnothing(tool.line_start) || !isnothing(tool.line_end)
        header = "# Lines $start_line-$end_line of $(basename(tool.path)) (total: $total_lines lines)\n\n"
        result = header * result
    end
    
    return result
end

"""
    FileWriteTool <: AbstractTool

Write content to a file.
"""
struct FileWriteTool <: AbstractTool
    path::String
    content::String
end

tool_name(::Type{FileWriteTool}) = "file_write"
tool_description(::Type{FileWriteTool}) = """Write content to a file. Creates the file if it doesn't exist, overwrites if it does.

**Usage Guidelines:**
- Parent directories are created automatically if they don't exist
- Use `file_edit` for modifying existing files (safer for partial changes)
- Returns the number of bytes written
- The file will be opened in the side editor after writing

**Warning:** This overwrites the entire file! For partial edits, use `file_edit` instead."""
tool_input_schema(::Type{FileWriteTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "path" => Dict(
            "type" => "string",
            "description" => "Path to the file to write"
        ),
        "content" => Dict(
            "type" => "string",
            "description" => "Content to write to the file"
        )
    ),
    "required" => ["path", "content"]
)

function execute_tool(tool::FileWriteTool)
    # Create parent directory if needed
    parent_dir = dirname(tool.path)
    if !isempty(parent_dir) && !isdir(parent_dir)
        mkpath(parent_dir)
    end

    bytes_written = write(tool.path, tool.content)
    return bytes_written
end

"""
    FileEditTool <: AbstractTool

Edit a file by replacing old content with new content.
"""
struct FileEditTool <: AbstractTool
    path::String
    old_text::String
    new_text::String
end

tool_name(::Type{FileEditTool}) = "file_edit"
tool_description(::Type{FileEditTool}) = """Edit a file by replacing specific text. Finds and replaces old_text with new_text.

**Usage Guidelines:**
- The old_text must exist in the file exactly (including whitespace)
- Use `file_read` first to see the exact content you want to replace
- Only the first occurrence is replaced
- The file will be opened in the side editor after editing

**Best Practice:** Include enough context in old_text to ensure you're replacing the right section.
For example, include surrounding lines if the target line appears multiple times."""
tool_input_schema(::Type{FileEditTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "path" => Dict(
            "type" => "string",
            "description" => "Path to the file to edit"
        ),
        "old_text" => Dict(
            "type" => "string",
            "description" => "Text to find and replace"
        ),
        "new_text" => Dict(
            "type" => "string",
            "description" => "Text to replace with"
        )
    ),
    "required" => ["path", "old_text", "new_text"]
)

function execute_tool(tool::FileEditTool)
    if !isfile(tool.path)
        error("File not found: $(tool.path)")
    end
    content = read(tool.path, String)
    if !occursin(tool.old_text, content)
        error("Old text not found in file")
    end
    new_content = replace(content, tool.old_text => tool.new_text)
    write(tool.path, new_content)
    return "success"
end

"""
    HttpGetTool <: AbstractTool

Fetch content from a URL via HTTP GET.
"""
struct HttpGetTool <: AbstractTool
    url::String
end

tool_name(::Type{HttpGetTool}) = "http_get"
tool_description(::Type{HttpGetTool}) = """Fetch content from a URL via HTTP GET request.

**Returns:**
- `status`: HTTP status code (200, 404, etc.)
- `content`: Response body as text

**Usage Guidelines:**
- Useful for fetching documentation, API responses, or web content
- Large responses will be truncated
- For complex HTTP operations, use `add_cell` with HTTP.jl code instead"""
tool_input_schema(::Type{HttpGetTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "url" => Dict(
            "type" => "string",
            "description" => "The URL to fetch"
        )
    ),
    "required" => ["url"]
)

function execute_tool(tool::HttpGetTool)
    response = HTTP.get(tool.url)
    return Dict("status" => response.status, "content" => String(copy(response.body)))
end

"""
    AddCellTool <: AbstractTool

Add a new cell to the notebook.
"""
struct AddCellTool <: AbstractTool
    language::String
    content::String
    metadata::Union{Nothing, Dict{Symbol, Any}}
end

AddCellTool(language::String, content::String) = AddCellTool(language, content, nothing)

tool_name(::Type{AddCellTool}) = "add_cell"
tool_description(::Type{AddCellTool}) = """Add a new cell to the notebook and execute it. This is the primary way to run Julia code.

**Languages:**
- `julia`: Execute Julia code (auto-runs and shows output)
- `python`: Execute Python code (auto-runs)
- `markdown`: Add markdown documentation (renders as HTML)

**Julia Best Practices:**
- Don't use println unless explicitly asked - the last expression is automatically displayed
- Use `let` blocks for temporary computations to avoid polluting the namespace
- Use `@doc function_name` to get documentation
- Use WGLMakie for plotting (not Plots.jl) unless asked otherwise
- Never use `Pkg.activate()` or `Pkg.add()` - assume the environment is set up

**Examples:**
```julia
# Good: let block for temporary work
let x = [1,2,3]
    sum(x) / length(x)
end

# Good: Direct expression (output shown automatically)
DataFrame(a=1:3, b=["x","y","z"])

# Bad: Unnecessary println
println(sum([1,2,3]))  # Don't do this
```"""
tool_input_schema(::Type{AddCellTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "language" => Dict(
            "type" => "string",
            "description" => "Programming language (julia, python, markdown)",
            "enum" => ["julia", "python", "markdown"]
        ),
        "content" => Dict(
            "type" => "string",
            "description" => "Content of the cell"
        ),
        "metadata" => Dict(
            "type" => "object",
            "description" => "Optional metadata for the cell",
            "properties" => Dict{String, Any}()
        )
    ),
    "required" => ["language", "content"]
)

function execute_tool(tool::AddCellTool)
    # This will be handled by the agent loop directly
    return nothing
end

"""
    TodoList <: AbstractTool

Create a TODO list/plan for the task. Useful for breaking down complex tasks into steps.
"""
struct TodoList <: AbstractTool
    title::String
    items::Vector{String}
    status::Vector{Bool}  # Track completion status of each item
end

TodoList(title::String, items::Vector{String}) = TodoList(title, items, fill(false, length(items)))

tool_name(::Type{TodoList}) = "todo_list"
tool_description(::Type{TodoList}) = """Create or update a TODO list to track task progress.

IMPORTANT: Once you create a TODO list, you MUST complete ALL items before responding with text.
After completing each task, return an updated TODO list with the same title to mark items as done.

The loop will continue until all TODO items are marked complete."""

tool_input_schema(::Type{TodoList}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "title" => Dict(
            "type" => "string",
            "description" => "Title of the TODO list (e.g., 'Plan for implementing feature X'). Keep the same title when updating."
        ),
        "items" => Dict(
            "type" => "array",
            "description" => "List of TODO items/steps. When updating, include ALL items with the same text.",
            "items" => Dict("type" => "string")
        ),
        "status" => Dict(
            "type" => "array",
            "description" => "Completion status for each item (true=done, false=pending). Must match items length.",
            "items" => Dict("type" => "boolean")
        )
    ),
    "required" => ["title", "items", "status"]
)

"""
    isdone(tool::TodoList)

Check if all TODO items are completed.
"""
function isdone(tool::TodoList)
    return !isempty(tool.status) && all(tool.status)
end

multi_task_tool(item::TodoList) = true

# Nothing needs to be done
execute_tool(tool::TodoList) = nothing

"""
    FileTool <: AbstractTool

Perform file system operations safely without bash.
Supports: ls, glob, find, pwd, cp, mv, rm, mkdir, readdir
"""
struct FileTool <: AbstractTool
    command::String  # ls, glob, find, pwd, cp, mv, rm, mkdir, readdir
    arguments::Dict{String, Any}
    function FileTool(command::String, arguments::Union{Nothing,Dict{String,Any}})
        # If arguments is provided, use it
        isnothing(arguments) || return new(command, arguments)
        # Otherwise, collect kwargs as arguments
        return new(command, Dict{String,Any}())
    end
end

# Custom constructor for JSON3 deserialization - handles both formats:
# 1. {"command": "pwd", "arguments": {}} - correct format
# 2. {"command": "pwd", "path": "."} - flattened format from OpenAI


tool_name(::Type{FileTool}) = "file_tool"
tool_description(::Type{FileTool}) = """Perform file system operations safely without shell injection risks. Prefer this over bash for file operations.

**Commands:**
- `pwd`: Get current working directory (no arguments needed)
- `ls`: List files in directory → `{path: "."}`
- `readdir`: List files with size/type/modified details → `{path: "."}`
- `glob`: Find files matching pattern → `{pattern: "*.jl", path: "."}`
- `find`: Search by name substring → `{pattern: "test", path: ".", recursive: true}`
- `mkdir`: Create directory (parents too) → `{path: "/new/dir"}`
- `cp`: Copy file/directory → `{path: "src", destination: "dst", recursive: true}`
- `mv`: Move/rename → `{path: "old", destination: "new"}`
- `rm`: Remove file/directory → `{path: "file", recursive: true}`

**Best Practice:** Use `readdir` first to explore, then `glob` or `find` to locate specific files."""

tool_input_schema(::Type{FileTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "command" => Dict(
            "type" => "string",
            "enum" => ["ls", "glob", "find", "pwd", "cp", "mv", "rm", "mkdir", "readdir"],
            "description" => "File system operation to perform"
        ),
        "arguments" => Dict(
            "type" => "object",
            "description" => """Arguments for the command:
- pwd: {} (no arguments)
- ls: {path: "/path/to/dir"} (defaults to ".")
- readdir: {path: "/path/to/dir"} (returns detailed info)
- glob: {pattern: "*.jl", path: "/search/here"} (path defaults to ".")
- find: {pattern: "test", path: "/search/here", recursive: true}
- mkdir: {path: "/new/directory"}
- cp: {path: "/source", destination: "/dest", recursive: true}
- mv: {path: "/source", destination: "/dest"}
- rm: {path: "/to/remove", recursive: true}""",
            "properties" => Dict(
                "path" => Dict("type" => "string"),
                "pattern" => Dict("type" => "string"),
                "destination" => Dict("type" => "string"),
                "recursive" => Dict("type" => "boolean")
            )
        )
    ),
    "required" => ["command", "arguments"]
)

function find_file(dir::String, pattern::String, recursive::Bool, matches=String[])
    for entry in readdir(dir)
        fullpath = joinpath(dir, entry)
        if occursin(pattern, entry)
            push!(matches, fullpath)
        end
        if recursive && isdir(fullpath)
            find_file(fullpath, pattern, recursive, matches)
        end
    end
    return matches
end

function execute_tool(tool::FileTool)
    args = tool.arguments
    if tool.command == "pwd"
        return pwd()
    elseif tool.command == "ls"
        path = get(args, "path", ".")
        return readdir(path)
    elseif tool.command == "readdir"
        path = get(args, "path", ".")
        entries = readdir(path; join=false)
        # Get detailed info for each entry
        details = map(entries) do entry
            fullpath = joinpath(path, entry)
            stat_info = try
                s = stat(fullpath)
                Dict(
                    "name" => entry,
                    "type" => isdir(s) ? "directory" : isfile(s) ? "file" : "other",
                    "size" => s.size,
                    "modified" => s.mtime
                )
            catch e
                Dict("name" => entry, "type" => "unknown", "error" => string(e))
            end
        end
        return details
    elseif tool.command == "glob"
        pattern = get(args, "pattern", nothing)
        if pattern === nothing
            error("Pattern required for glob")
        end
        path = get(args, "path", ".")
        pattern_path = joinpath(path, pattern)
        return glob(pattern_path)
    elseif tool.command == "find"
        pattern = get(args, "pattern", nothing)
        if pattern === nothing
            error("Pattern required for find")
        end
        path = get(args, "path", ".")
        recursive = get(args, "recursive", false)
        return find_file(path, pattern, recursive)
    elseif tool.command == "mkdir"
        path = get(args, "path", nothing)
        if path === nothing
            error("Path required for mkdir")
        end
        mkpath(path)
        return nothing
    elseif tool.command == "cp"
        path = get(args, "path", nothing)
        destination = get(args, "destination", nothing)
        if path === nothing || destination === nothing
            error("Path and destination required for cp")
        end
        recursive = get(args, "recursive", false)
        if recursive
            cp(path, destination; force=true)
        else
            cp(path, destination)
        end
        return nothing
    elseif tool.command == "mv"
        path = get(args, "path", nothing)
        destination = get(args, "destination", nothing)
        if path === nothing || destination === nothing
            error("Path and destination required for mv")
        end
        mv(path, destination; force=true)
        return nothing
    elseif tool.command == "rm"
        path = get(args, "path", nothing)
        if path === nothing
            error("Path required for rm")
        end
        recursive = get(args, "recursive", false)
        if recursive
            rm(path; recursive=true, force=true)
        else
            rm(path)
        end
        return nothing
    else
        error("Unknown command: $(tool.command)")
    end
end

"""
    ToolLookupTool <: AbstractTool

Retrieve the full result of a previously executed tool (useful when tool result was summarized).

# Fields
- `cell_id::String`: The ID of the cell containing the tool execution
- `tool_name::String`: The name of the tool (e.g., "bash", "read", "write")
"""
struct ToolLookupTool <: AbstractTool
    cell_id::String
    tool_name::String
end

tool_name(::Type{ToolLookupTool}) = "lookup_tool_result"
tool_description(::Type{ToolLookupTool}) = "Retrieve the full result of a previously executed tool. Use this when you need to see the complete output of a summarized tool execution."

tool_input_schema(::Type{ToolLookupTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "cell_id" => Dict(
            "type" => "string",
            "description" => "The cell ID shown in the summarized tool execution"
        ),
        "tool_name" => Dict(
            "type" => "string",
            "description" => "The name of the tool (e.g., 'bash', 'read', 'write')"
        )
    ),
    "required" => ["cell_id", "tool_name"]
)

function execute_tool!(tool::ToolLookupTool, book_folder::String)
    tools_dir = joinpath(book_folder, "data", "tools")
    json_file = joinpath(tools_dir, "$(tool.tool_name)-$(tool.cell_id).json")

    if !isfile(json_file)
        return ToolResult("Tool execution file not found: $(json_file)")
    end

    try
        # Read the JSON file and return the full result
        json_str = read(json_file, String)
        json_data = JSON3.read(json_str)

        # Extract the result
        result = get(json_data, :result, nothing)
        if result === nothing
            return ToolResult("No result found in tool execution")
        end

        # Return the full result
        result_str = string(result[:result])
        return ToolResult("Full result from $(tool.tool_name) (cell $(tool.cell_id)):\n\n$(result_str)")
    catch e
        return ToolResult("Error loading tool execution: $(e)")
    end
end

# Need to handle the book_folder parameter - add helper that extracts it from max_token param
function execute_tool!(tool::ToolLookupTool, max_token::Int)
    # This is a workaround - we need access to the book folder
    # For now, return an error message asking the user to use the UI toggle instead
    return ToolResult("Please use the 'Show Full Result' button in the UI to view the complete tool output. Tool lookup via API is not yet supported.")
end

# Export all tools
const DEFAULT_TOOLS = [
    BashTool,
    FileReadTool,
    FileWriteTool,
    FileEditTool,
    FileTool,
    HttpGetTool,
    AddCellTool,
    TodoList
]
export BashTool,
    FileReadTool,
    FileWriteTool,
    FileEditTool,
    FileTool,
    HttpGetTool,
    AddCellTool,
    TodoList,
    ToolExecution,
    ToolResult

# ============================================================================
# Git Tool
# ============================================================================

"""
    GitTool <: AbstractTool

Execute git commands safely in the current repository.
"""
struct GitTool <: AbstractTool
    command::String
    args::Vector{String}
end

GitTool(command::String) = GitTool(command, String[])

tool_name(::Type{GitTool}) = "git"
tool_description(::Type{GitTool}) = """Execute git commands in the current repository.

**Usage Guidelines:**
- Safe for read operations: status, log, diff, show, branch, etc.
- Use for inspecting repository state and history
- Commands run in the current working directory
- For write operations (commit, push, etc.), prefer explicit user confirmation

**Supported Commands:**
- `status` - Show working tree status
- `log` - Show commit logs (use args for options like ["-10", "--oneline"])
- `diff` - Show changes between commits, commit and working tree, etc.
- `show` - Show various types of objects
- `branch` - List, create, or delete branches
- `remote` - Manage set of tracked repositories
- `blame` - Show what revision and author last modified each line
- `ls-files` - Show information about files in the index and working tree
- `config` - Get repository or global options

**Examples:**
- `{"command": "status"}` - Get current status
- `{"command": "log", "args": ["-10", "--oneline"]}` - Get last 10 commits
- `{"command": "diff", "args": ["HEAD~1"]}` - Show changes in last commit
- `{"command": "branch", "args": ["-a"]}` - List all branches
- `{"command": "show", "args": ["HEAD:path/to/file.jl"]}` - Show file from commit

**Safety:** Write operations (commit, push, pull, merge, rebase) require explicit confirmation."""
tool_input_schema(::Type{GitTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "command" => Dict(
            "type" => "string",
            "description" => "Git command to execute (e.g., 'status', 'log', 'diff')",
            "enum" => ["status", "log", "diff", "show", "branch", "remote", "blame", "ls-files", "config", "rev-parse"]
        ),
        "args" => Dict(
            "type" => "array",
            "items" => Dict("type" => "string"),
            "description" => "Arguments to pass to the git command"
        )
    ),
    "required" => ["command"]
)

function execute_tool(tool::GitTool)
    # Validate command is safe (read-only)
    safe_commands = ["status", "log", "diff", "show", "branch", "remote", "blame", "ls-files", "config", "rev-parse"]
    if !(tool.command in safe_commands)
        error("Git command '$(tool.command)' is not allowed. Only read operations are permitted: $(join(safe_commands, ", "))")
    end
    
    # Build command
    cmd_parts = ["git", tool.command]
    if !isempty(tool.args)
        append!(cmd_parts, tool.args)
    end
    
    # Execute
    try
        result = read(Cmd(cmd_parts), String)
        return result
    catch e
        if e isa ProcessFailedException
            # Try to get stderr for better error messages
            error("Git command failed: $(tool.command) $(join(tool.args, " "))")
        else
            rethrow(e)
        end
    end
end

# ============================================================================
# GitHub Tool
# ============================================================================

"""
    GitHubTool <: AbstractTool

Interact with GitHub API to fetch repository information, issues, PRs, etc.
"""
struct GitHubTool <: AbstractTool
    action::String
    owner::String
    repo::String
    params::Dict{String, Any}
end

GitHubTool(action::String, owner::String, repo::String) = GitHubTool(action, owner, repo, Dict{String, Any}())

tool_name(::Type{GitHubTool}) = "github"
tool_description(::Type{GitHubTool}) = """Interact with GitHub API to fetch repository information.

**Usage Guidelines:**
- No authentication required for public repositories
- Use for fetching issues, pull requests, releases, commits, etc.
- Rate limited to 60 requests per hour for unauthenticated requests

**Supported Actions:**
- `get_repo` - Get repository information
- `list_issues` - List repository issues (params: {"state": "open|closed|all", "per_page": 30})
- `get_issue` - Get specific issue (params: {"number": 123})
- `list_pulls` - List pull requests (params: {"state": "open|closed|all", "per_page": 30})
- `get_pull` - Get specific pull request (params: {"number": 123})
- `list_commits` - List repository commits (params: {"per_page": 30, "sha": "branch"})
- `get_commit` - Get specific commit (params: {"sha": "commit_sha"})
- `list_releases` - List repository releases
- `get_release` - Get specific release (params: {"tag": "v1.0.0"})
- `get_readme` - Get repository README
- `get_contents` - Get repository file contents (params: {"path": "path/to/file"})

**Examples:**
- `{"action": "get_repo", "owner": "JuliaLang", "repo": "Julia"}` - Get Julia repo info
- `{"action": "list_issues", "owner": "JuliaLang", "repo": "Julia", "params": {"state": "open", "per_page": 10}}` - List open issues
- `{"action": "get_pull", "owner": "MakieOrg", "repo": "Makie.jl", "params": {"number": 1234}}` - Get specific PR
- `{"action": "get_contents", "owner": "JuliaLang", "repo": "Julia", "params": {"path": "README.md"}}` - Get README"""

tool_input_schema(::Type{GitHubTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "action" => Dict(
            "type" => "string",
            "description" => "GitHub API action to perform",
            "enum" => ["get_repo", "list_issues", "get_issue", "list_pulls", "get_pull", "list_commits", "get_commit", "list_releases", "get_release", "get_readme", "get_contents"]
        ),
        "owner" => Dict(
            "type" => "string",
            "description" => "Repository owner (user or organization)"
        ),
        "repo" => Dict(
            "type" => "string",
            "description" => "Repository name"
        ),
        "params" => Dict(
            "type" => "object",
            "description" => "Additional parameters for the action (varies by action)",
            "properties" => Dict(
                "number" => Dict("type" => "integer"),
                "state" => Dict("type" => "string", "enum" => ["open", "closed", "all"]),
                "per_page" => Dict("type" => "integer"),
                "sha" => Dict("type" => "string"),
                "tag" => Dict("type" => "string"),
                "path" => Dict("type" => "string")
            )
        )
    ),
    "required" => ["action", "owner", "repo"]
)

function execute_tool(tool::GitHubTool)
    base_url = "https://api.github.com"
    
    # Build URL based on action
    url = if tool.action == "get_repo"
        "$base_url/repos/$(tool.owner)/$(tool.repo)"
    elseif tool.action == "list_issues"
        state = get(tool.params, "state", "open")
        per_page = get(tool.params, "per_page", 30)
        "$base_url/repos/$(tool.owner)/$(tool.repo)/issues?state=$state&per_page=$per_page"
    elseif tool.action == "get_issue"
        number = tool.params["number"]
        "$base_url/repos/$(tool.owner)/$(tool.repo)/issues/$number"
    elseif tool.action == "list_pulls"
        state = get(tool.params, "state", "open")
        per_page = get(tool.params, "per_page", 30)
        "$base_url/repos/$(tool.owner)/$(tool.repo)/pulls?state=$state&per_page=$per_page"
    elseif tool.action == "get_pull"
        number = tool.params["number"]
        "$base_url/repos/$(tool.owner)/$(tool.repo)/pulls/$number"
    elseif tool.action == "list_commits"
        per_page = get(tool.params, "per_page", 30)
        sha = get(tool.params, "sha", "")
        query = "per_page=$per_page" * (isempty(sha) ? "" : "&sha=$sha")
        "$base_url/repos/$(tool.owner)/$(tool.repo)/commits?$query"
    elseif tool.action == "get_commit"
        sha = tool.params["sha"]
        "$base_url/repos/$(tool.owner)/$(tool.repo)/commits/$sha"
    elseif tool.action == "list_releases"
        "$base_url/repos/$(tool.owner)/$(tool.repo)/releases"
    elseif tool.action == "get_release"
        tag = tool.params["tag"]
        "$base_url/repos/$(tool.owner)/$(tool.repo)/releases/tags/$tag"
    elseif tool.action == "get_readme"
        "$base_url/repos/$(tool.owner)/$(tool.repo)/readme"
    elseif tool.action == "get_contents"
        path = tool.params["path"]
        "$base_url/repos/$(tool.owner)/$(tool.repo)/contents/$path"
    else
        error("Unknown action: $(tool.action)")
    end
    
    # Make request
    headers = [
        "Accept" => "application/vnd.github.v3+json",
        "User-Agent" => "BonitoBook-LLM-Agent"
    ]
    
    response = HTTP.get(url, headers)
    
    if response.status != 200
        error("GitHub API request failed with status $(response.status)")
    end
    
    # Parse JSON response
    json_response = JSON3.read(String(copy(response.body)))
    
    return json_response
end

# ============================================================================
# Module Function Tool
# ============================================================================

"""
    ModuleFunctionTool <: AbstractTool

Add or update a function in a Julia module with metadata and analysis.
"""
struct ModuleFunctionTool <: AbstractTool
    module_name::String
    function_code::String
    analyze::Bool
end

ModuleFunctionTool(module_name::String, function_code::String) = ModuleFunctionTool(module_name, function_code, true)

tool_name(::Type{ModuleFunctionTool}) = "module_function"
tool_description(::Type{ModuleFunctionTool}) = """Add or update a function in a Julia module with optional analysis.

**Usage Guidelines:**
- Define or update functions in a specific module
- Optionally analyze with @code_warntype and JET.jl for performance insights
- Automatically formats code using JuliaFormatter
- Useful for iterative function development and optimization

**Features:**
- **Code Analysis**: Get type stability warnings via @code_warntype
- **JET Analysis**: Static analysis for potential errors and type issues
- **Auto-formatting**: Consistent code style via JuliaFormatter
- **Module isolation**: Functions are defined in specified module

**Examples:**
- `{"module_name": "MyModule", "function_code": "function foo(x) x^2 end", "analyze": true}` - Add function with analysis
- `{"module_name": "Main", "function_code": "function bar(x::Int) x + 1 end", "analyze": false}` - Add without analysis

**Note:** Module must exist or be creatable. Analysis requires JET.jl to be available."""

tool_input_schema(::Type{ModuleFunctionTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "module_name" => Dict(
            "type" => "string",
            "description" => "Name of the module to define the function in"
        ),
        "function_code" => Dict(
            "type" => "string",
            "description" => "Complete function definition code"
        ),
        "analyze" => Dict(
            "type" => "boolean",
            "description" => "Whether to run code_warntype and JET analysis (default: true)",
            "default" => true
        )
    ),
    "required" => ["module_name", "function_code"]
)

function execute_tool(tool::ModuleFunctionTool)
    results = Dict{String, Any}()
    
    # Get or create module
    mod = try
        getfield(Main, Symbol(tool.module_name))
    catch
        # Try to create module if it doesn't exist
        Core.eval(Main, :(module $(Symbol(tool.module_name)) end))
        getfield(Main, Symbol(tool.module_name))
    end
    
    # Parse and evaluate the function
    try
        expr = Meta.parse(tool.function_code)
        Core.eval(mod, expr)
        results["status"] = "success"
        results["message"] = "Function defined in module $(tool.module_name)"
    catch e
        results["status"] = "error"
        results["error"] = sprint(showerror, e)
        return results
    end
    
    # Extract function name for analysis
    function_name = try
        expr = Meta.parse(tool.function_code)
        if expr.head == :function || expr.head == :(=)
            sig = expr.args[1]
            if sig isa Symbol
                sig
            elseif sig.head == :call
                sig.args[1]
            elseif sig.head == :where || sig.head == :(::)
                # Handle parametric functions
                inner = sig.args[1]
                if inner isa Symbol
                    inner
                elseif inner.head == :call
                    inner.args[1]
                else
                    nothing
                end
            else
                nothing
            end
        else
            nothing
        end
    catch
        nothing
    end
    
    # Perform analysis if requested
    if tool.analyze && !isnothing(function_name)
        func = try
            getfield(mod, function_name)
        catch
            nothing
        end
        
        if !isnothing(func)
            # Get method information
            ms = methods(func)
            results["methods"] = "$(length(ms)) method(s) defined"
            
            # Code warntype analysis for first method
            if length(ms) > 0
                m = first(ms)
                try
                    warntype_output = sprint() do io
                        Base.code_warntype(io, func, m.sig.parameters[2:end])
                    end
                    results["code_warntype"] = warntype_output
                catch e
                    results["code_warntype"] = "Could not run @code_warntype: $(sprint(showerror, e))"
                end
            end
            
            # JET analysis if available (must use invokelatest since JET is loaded at runtime)
            if isdefined(Main, :JET)
                try
                    jet_mod = Main.JET
                    # Can't use macros from dynamically loaded modules, use function call instead
                    report = Base.invokelatest(jet_mod.report_opt, func)
                    results["jet_analysis"] = string(report)
                catch e
                    results["jet_analysis"] = "JET analysis not available or failed: $(sprint(showerror, e))"
                end
            else
                results["jet_analysis"] = "JET.jl not loaded (use: using JET)"
            end
        end
    end
    
    # Format code
    try
        if isdefined(Main, :JuliaFormatter)
            formatted = Main.JuliaFormatter.format_text(tool.function_code)
            results["formatted_code"] = formatted
        else
            results["formatted_code"] = "JuliaFormatter not loaded"
        end
    catch e
        results["formatted_code"] = "Formatting failed: $(sprint(showerror, e))"
    end
    
    return results
end
