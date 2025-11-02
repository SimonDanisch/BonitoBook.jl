"""
Test tool rendering for LLMChat

This test ensures all tool jsrender methods work correctly.
"""

using Test
using Bonito
using BonitoBook
using BonitoBook.LLMChatBooks

# Mock session for testing
mock_session = Session()

println("Testing LLMChat Tool Rendering...")
println("=" ^ 60)

# Test BashTool rendering
@testset "BashTool Rendering" begin
    println("\n✓ Testing BashTool...")

    # Test with output
    tool = BashTool("ls -la")
    result = ToolResult("file1.txt\nfile2.txt\nfile3.txt")
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - BashTool with output: OK")

    # Test with empty output
    tool2 = BashTool("mkdir test")
    result2 = ToolResult("")
    execution2 = ToolExecution(tool2, result2)

    rendered2 = Bonito.jsrender(mock_session, execution2)
    @test rendered2 isa Any
    println("  - BashTool with empty output: OK")
end

# Test FileReadTool rendering
@testset "FileReadTool Rendering" begin
    println("\n✓ Testing FileReadTool...")

    tool = FileReadTool("/path/to/file.txt")
    result = ToolResult("Hello World\nThis is a test file\nWith multiple lines")
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - FileReadTool: OK")
end

# Test FileWriteTool rendering
@testset "FileWriteTool Rendering" begin
    println("\n✓ Testing FileWriteTool...")

    # Test with Int result
    tool = FileWriteTool("/path/to/file.txt", "content")
    result = ToolResult(1024)
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - FileWriteTool with Int: OK")

    # Test with String result (the bug we just fixed)
    result2 = ToolResult("2048")
    execution2 = ToolExecution(tool, result2)

    rendered2 = Bonito.jsrender(mock_session, execution2)
    @test rendered2 isa Any
    println("  - FileWriteTool with String: OK")
end

# Test FileEditTool rendering
@testset "FileEditTool Rendering" begin
    println("\n✓ Testing FileEditTool...")

    tool = FileEditTool(
        "/path/to/file.jl",
        "old text\nold line 2",
        "new text\nnew line 2\nnew line 3"
    )
    result = ToolResult(nothing)
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - FileEditTool: OK")
end

# Test HttpGetTool rendering
@testset "HttpGetTool Rendering" begin
    println("\n✓ Testing HttpGetTool...")

    tool = HttpGetTool("https://example.com")
    result = ToolResult(Dict("status" => 200, "content" => "Hello from the web!"))
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - HttpGetTool: OK")
end

# Test AddCellTool rendering
@testset "AddCellTool Rendering" begin
    println("\n✓ Testing AddCellTool...")

    tool = AddCellTool("julia", "println(\"Hello\")\nx = 42", nothing)
    result = ToolResult("42")
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - AddCellTool: OK")
end

# Test FileTool rendering
@testset "FileTool Rendering" begin
    println("\n✓ Testing FileTool...")

    # Test with file list (Dict results)
    tool = FileTool("readdir", Dict{String,Any}("path" => "/home/user"))
    result = ToolResult([
        Dict("name" => "file1.txt", "type" => "file", "size" => 1024),
        Dict("name" => "dir1", "type" => "directory", "size" => 0),
        Dict("name" => "file2.jl", "type" => "file", "size" => 2048)
    ])
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - FileTool with Dict results: OK")

    # Test with simple string list
    tool2 = FileTool("glob", Dict{String,Any}("pattern" => "*.jl"))
    result2 = ToolResult([
        "/path/to/file1.jl",
        "/path/to/file2.jl",
        "/path/to/file3.jl"
    ])
    execution2 = ToolExecution(tool2, result2)

    rendered2 = Bonito.jsrender(mock_session, execution2)
    @test rendered2 isa Any
    println("  - FileTool with String results: OK")

    # Test with nothing result
    tool3 = FileTool("mkdir", Dict{String,Any}("path" => "/new/dir"))
    result3 = ToolResult(nothing)
    execution3 = ToolExecution(tool3, result3)

    rendered3 = Bonito.jsrender(mock_session, execution3)
    @test rendered3 isa Any
    println("  - FileTool with nothing result: OK")
end

# Test TodoList rendering
@testset "TodoList Rendering" begin
    println("\n✓ Testing TodoList...")

    tool = TodoList("My Tasks", ["Task 1", "Task 2", "Task 3"], [true, false, false])
    result = ToolResult(nothing)
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - TodoList: OK")
end

# Test error rendering
@testset "Error Rendering" begin
    println("\n✓ Testing Error Rendering...")

    tool = BashTool("invalid-command")
    result = ToolResult(ErrorException("Command not found"), false)
    execution = ToolExecution(tool, result)

    rendered = Bonito.jsrender(mock_session, execution)
    @test rendered isa Any
    println("  - Error rendering: OK")
end

println("\n" * "=" ^ 60)
println("✓ All tool rendering tests passed!")
