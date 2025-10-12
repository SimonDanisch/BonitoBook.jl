using JSON3

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
        tool.result = Dict("success" => false, "error" => sprint(showerror, e))
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
    output = read(Cmd(split(tool.command, " "; keepempty=false)), String)
    return Dict("output" => output, "success" => true)
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
        return Dict("content" => "", "success" => false, "error" => "File not found: $(tool.path)")
    else
        content = read(tool.path, String)
        return Dict("content" => content, "success" => true, "path" => tool.path)
    end
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

    write(tool.path, tool.content)
    return Dict("success" => true, "path" => tool.path, "bytes_written" => length(tool.content))
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
        return Dict("success" => false, "error" => "File not found: $(tool.path)")
    elseif !occursin(tool.old_text, read(tool.path, String))
        return Dict("success" => false, "error" => "Old text not found in file")
    else
        content = read(tool.path, String)
        new_content = replace(content, tool.old_text => tool.new_text)
        write(tool.path, new_content)
        return Dict("success" => true, "path" => tool.path)
    end
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
    return Dict(
        "success" => true,
        "status" => response.status,
        "content" => String(response.body),
        "url" => tool.url
    )
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
    # Return the cell data to be added
    metadata = something(tool.metadata, Dict{Symbol, Any}())
    return Dict(
        "success" => true,
        "language" => tool.language,
        "content" => tool.content,
        "metadata" => metadata
    )
end

"""
    TodoTool <: AbstractTool

Create a TODO list/plan for the task. Useful for breaking down complex tasks into steps.
"""
mutable struct TodoTool <: AbstractTool
    title::String
    items::Vector{String}
    result::Union{Nothing, Any}
end

TodoTool(title::String, items::Vector{String}) = TodoTool(title, items, nothing)

tool_name(::Type{TodoTool}) = "todo"
tool_description(::Type{TodoTool}) = "Create a TODO list or plan. Use this to break down complex tasks into manageable steps before starting implementation."
tool_input_schema(::Type{TodoTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "title" => Dict(
            "type" => "string",
            "description" => "Title of the TODO list (e.g., 'Plan for implementing feature X')"
        ),
        "items" => Dict(
            "type" => "array",
            "description" => "List of TODO items/steps",
            "items" => Dict("type" => "string")
        )
    ),
    "required" => ["title", "items"]
)

function execute_tool(tool::TodoTool)
    # Format as markdown checklist
    formatted_items = ["- [ ] $item" for item in tool.items]
    markdown_content = "## $(tool.title)\n\n" * join(formatted_items, "\n")

    return Dict(
        "success" => true,
        "title" => tool.title,
        "items" => tool.items,
        "markdown" => markdown_content
    )
end

# Export all tools
const DEFAULT_TOOLS = [
    BashTool,
    FileReadTool,
    FileWriteTool,
    FileEditTool,
    HttpGetTool,
    AddCellTool,
    TodoTool
]
export BashTool,
    FileReadTool,
    FileWriteTool,
    FileEditTool,
    HttpGetTool,
    AddCellTool,
    TodoTool
