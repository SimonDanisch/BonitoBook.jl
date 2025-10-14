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
5. Implement `execute_tool(tool::YourTool, book)` to perform the action
"""
abstract type AbstractTool end

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
    execute_tool!(tool::AbstractTool)

Execute the tool with error handling, mutate its result field, and return the result.
This is a generic wrapper that calls execute_tool(tool) and handles exceptions.
"""
function execute_tool!(tool::AbstractTool)
    try
        tool.result = execute_tool(tool)
    catch e
        tool.result = Dict("error" => sprint(showerror, e))
    end
    return tool.result
end


# ============================================================================
# Core Tools
# ============================================================================

"""
    BashTool <: AbstractTool

Execute bash commands in the shell.
"""
mutable struct BashTool <: AbstractTool
    command::String
    result::Union{Nothing, Any}
end

BashTool(command::String) = BashTool(command, nothing)

tool_name(::Type{BashTool}) = "bash"
tool_description(::Type{BashTool}) = "Execute bash commands in the shell. Use for file operations, running scripts, etc."
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

Read contents of a file.
"""
mutable struct FileReadTool <: AbstractTool
    path::String
    result::Union{Nothing, Any}
end

FileReadTool(path::String) = FileReadTool(path, nothing)

tool_name(::Type{FileReadTool}) = "file_read"
tool_description(::Type{FileReadTool}) = "Read the contents of a file from the filesystem."
tool_input_schema(::Type{FileReadTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "path" => Dict(
            "type" => "string",
            "description" => "Path to the file to read"
        )
    ),
    "required" => ["path"]
)

function execute_tool(tool::FileReadTool)
    if !isfile(tool.path)
        error("File not found: $(tool.path)")
    end
    return read(tool.path, String)
end

"""
    FileWriteTool <: AbstractTool

Write content to a file.
"""
mutable struct FileWriteTool <: AbstractTool
    path::String
    content::String
    result::Union{Nothing, Any}
end

FileWriteTool(path::String, content::String) = FileWriteTool(path, content, nothing)

tool_name(::Type{FileWriteTool}) = "file_write"
tool_description(::Type{FileWriteTool}) = "Write content to a file. Creates the file if it doesn't exist, overwrites if it does."
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
mutable struct FileEditTool <: AbstractTool
    path::String
    old_text::String
    new_text::String
    result::Union{Nothing, Any}
end

FileEditTool(path::String, old_text::String, new_text::String) = FileEditTool(path, old_text, new_text, nothing)

tool_name(::Type{FileEditTool}) = "file_edit"
tool_description(::Type{FileEditTool}) = "Edit a file by replacing specific text. Finds and replaces the old_text with new_text."
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
mutable struct HttpGetTool <: AbstractTool
    url::String
    result::Union{Nothing, Any}
end

HttpGetTool(url::String) = HttpGetTool(url, nothing)

tool_name(::Type{HttpGetTool}) = "http_get"
tool_description(::Type{HttpGetTool}) = "Fetch content from a URL via HTTP GET request."
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
    return Dict("status" => response.status, "content" => String(response.body))
end

"""
    AddCellTool <: AbstractTool

Add a new cell to the notebook.
"""
mutable struct AddCellTool <: AbstractTool
    language::String
    content::String
    metadata::Union{Nothing, Dict{Symbol, Any}}
    result::Union{Nothing, Any}
end

AddCellTool(language::String, content::String, metadata::Union{Nothing, Dict{Symbol, Any}}=nothing) = AddCellTool(language, content, metadata, nothing)

tool_name(::Type{AddCellTool}) = "add_cell"
tool_description(::Type{AddCellTool}) = "Add a new cell to the notebook. Can be used to add code or markdown cells."
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
mutable struct TodoList <: AbstractTool
    title::String
    items::Vector{String}
    status::Vector{Bool}  # Track completion status of each item
    result::Union{Nothing, Any}
end

TodoList(title::String, items::Vector{String}) = TodoList(title, items, fill(false, length(items)), nothing)
TodoList(title::String, items::Vector{String}, status::Vector{Bool}) = TodoList(title, items, status, nothing)

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
mutable struct FileTool <: AbstractTool
    command::String  # ls, glob, find, pwd, cp, mv, rm, mkdir, readdir
    arguments::Dict{String, Any}
    result::Union{Nothing, Any}
end

FileTool(command::String, arguments::Dict{String, Any}) = FileTool(command, arguments, nothing)

function FileTool(command::String, arguments::Union{Nothing, Dict{String, Any}}, result=nothing)
    # If arguments is provided, use it
    _args = isnothing(arguments) ? Dict{String, Any}() : arguments
    # Otherwise, collect kwargs as arguments
    return FileTool(command, _args, nothing)
end

tool_name(::Type{FileTool}) = "file_tool"
tool_description(::Type{FileTool}) = """Perform file system operations safely. Use this instead of bash for file operations.

Commands:
- pwd: Get current directory
- ls: List files in directory
- readdir: List files with size/type details
- glob: Find files matching glob pattern (e.g., "*.jl", "test_*.txt")
- find: Search for files by name substring
- mkdir: Create directory (creates parent dirs if needed)
- cp: Copy file or directory
- mv: Move/rename file or directory
- rm: Remove file or directory"""

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
        matches = String[]

        function search_dir(dir)
            try
                for entry in readdir(dir)
                    fullpath = joinpath(dir, entry)
                    if occursin(pattern, entry)
                        push!(matches, fullpath)
                    end
                    if recursive && isdir(fullpath)
                        search_dir(fullpath)
                    end
                end
            catch e
                # Skip directories we can't read
            end
        end

        search_dir(path)
        return matches
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
    TodoList
