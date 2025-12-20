using Test
using JSON3
using HTTP
using Bonito
using Hyperscript
using BonitoBook.LLMChatBooks

@testset "LLMChat Tools" begin
    @testset "BashTool" begin
        # Test JSON deserialization
        tool_json = """{"command":"echo 'test'"}"""
        tool = JSON3.read(tool_json, BashTool)
        @test tool isa BashTool
        @test tool.command == "echo 'test'"

        # Test execution returns ToolResult
        result = execute_tool!(tool)
        @test result isa ToolResult
        @test result.success == true
        @test occursin("test", string(result.result))

        # Test ToolExecution for serialization
        execution = ToolExecution(tool, result)
        @test execution.tool === tool
        @test execution.result === result

        # Test JSON roundtrip via ToolExecution
        json = JSON3.write(execution)
        deserialized = JSON3.read(json, ToolExecution{BashTool})
        @test deserialized.tool.command == tool.command
        @test deserialized.result.success == true

        # Test jsrender of ToolExecution
        session = Session()
        rendered = Bonito.jsrender(session, deserialized)
        @test rendered isa Hyperscript.Node
        @test occursin("tool-container", string(rendered))
    end

    @testset "FileReadTool" begin
        # Create test file
        test_file = tempname()
        write(test_file, "Test content for FileReadTool")

        # Test JSON deserialization
        tool_json = """{"path":"$(replace(test_file, "\\" => "\\\\"))"}"""
        tool = JSON3.read(tool_json, FileReadTool)
        @test tool isa FileReadTool
        @test tool.path == test_file

        # Test execution
        result = execute_tool!(tool)
        @test result isa ToolResult
        @test result.success == true
        @test occursin("Test content for FileReadTool", string(result.result))

        # Test non-existent file
        tool_bad = FileReadTool("/nonexistent/file.txt")
        result_bad = execute_tool!(tool_bad)
        @test result_bad isa ToolResult
        @test result_bad.success == false

        # Cleanup
        rm(test_file, force=true)
    end

    @testset "FileWriteTool" begin
        test_file = tempname()

        # Test execution
        tool = FileWriteTool(test_file, "Written by FileWriteTool")
        result = execute_tool!(tool)
        @test result isa ToolResult
        @test result.success == true
        @test isfile(test_file)
        @test read(test_file, String) == "Written by FileWriteTool"

        # Test with subdirectory creation
        test_subdir = joinpath(tempdir(), "test_subdir_$(rand(1:10000))", "subdir", "file.txt")
        tool_sub = FileWriteTool(test_subdir, "Test content")
        result_sub = execute_tool!(tool_sub)
        @test result_sub.success == true
        @test isfile(test_subdir)

        # Cleanup
        rm(test_file, force=true)
        rm(dirname(dirname(test_subdir)), force=true, recursive=true)
    end

    @testset "FileEditTool" begin
        # Create test file
        test_file = tempname()
        write(test_file, "Hello World")

        # Test execution
        tool = FileEditTool(test_file, "World", "Julia")
        result = execute_tool!(tool)
        @test result isa ToolResult
        @test result.success == true
        @test read(test_file, String) == "Hello Julia"

        # Test with non-existent old_text
        tool_bad = FileEditTool(test_file, "NotFound", "Replacement")
        result_bad = execute_tool!(tool_bad)
        @test result_bad.success == false

        # Cleanup
        rm(test_file, force=true)
    end

    @testset "HttpGetTool" begin
        # Test execution (uses httpbin.org for testing)
        tool = HttpGetTool("https://httpbin.org/status/200")
        result = execute_tool!(tool)
        @test result isa ToolResult
        @test result.success == true
        @test result.result isa Dict
        @test result.result["status"] == 200
    end

    @testset "AddCellTool" begin
        # Test JSON deserialization without metadata
        tool = AddCellTool("julia", "println(\"Hello\")")
        @test tool isa AddCellTool
        @test tool.language == "julia"
        @test tool.content == "println(\"Hello\")"
        @test tool.metadata === nothing

        # Test with metadata
        tool_with_meta = AddCellTool("julia", "1+1", Dict{Symbol,Any}(:key => "value"))
        @test tool_with_meta.metadata[:key] == "value"
    end

    @testset "TodoList" begin
        # Test construction
        tool = TodoList("Test Plan", ["Step 1", "Step 2", "Step 3"])
        @test tool.title == "Test Plan"
        @test tool.items == ["Step 1", "Step 2", "Step 3"]
        @test tool.status == [false, false, false]

        # Test isdone
        @test isdone(tool) == false

        # Test with all completed
        tool_done = TodoList("Done Plan", ["Step 1"], [true])
        @test isdone(tool_done) == true
    end

    @testset "FileTool" begin
        # Test pwd
        tool_pwd = FileTool("pwd", Dict{String,Any}())
        result = execute_tool!(tool_pwd)
        @test result.success == true
        @test result.result == pwd()

        # Test ls
        test_dir = mktempdir()
        write(joinpath(test_dir, "test_file.txt"), "test")
        tool_ls = FileTool("ls", Dict{String,Any}("path" => test_dir))
        result_ls = execute_tool!(tool_ls)
        @test result_ls.success == true
        @test result_ls.result isa Vector
        @test "test_file.txt" in result_ls.result

        # Test glob
        tool_glob = FileTool("glob", Dict{String,Any}("pattern" => "*.txt", "path" => test_dir))
        result_glob = execute_tool!(tool_glob)
        @test result_glob.success == true

        # Test find
        tool_find = FileTool("find", Dict{String,Any}("pattern" => "test", "path" => test_dir))
        result_find = execute_tool!(tool_find)
        @test result_find.success == true
        @test length(result_find.result) >= 1

        # Test mkdir
        new_dir = joinpath(test_dir, "new_dir")
        tool_mkdir = FileTool("mkdir", Dict{String,Any}("path" => new_dir))
        execute_tool!(tool_mkdir)
        @test isdir(new_dir)

        # Test readdir with details
        tool_readdir = FileTool("readdir", Dict{String,Any}("path" => test_dir))
        result_readdir = execute_tool!(tool_readdir)
        @test result_readdir.success == true
        @test result_readdir.result isa Vector
        @test all(x -> x isa Dict, result_readdir.result)

        # Cleanup
        rm(test_dir, recursive=true, force=true)
    end

    @testset "Tool Metadata" begin
        # Test tool_name, tool_description, tool_input_schema for all tools
        for ToolType in [BashTool, FileReadTool, FileWriteTool, FileEditTool,
                         FileTool, HttpGetTool, AddCellTool, TodoList]
            @test tool_name(ToolType) isa String
            @test !isempty(tool_name(ToolType))
            @test tool_description(ToolType) isa String
            @test !isempty(tool_description(ToolType))
            @test tool_input_schema(ToolType) isa Dict
            @test haskey(tool_input_schema(ToolType), "type")
            @test haskey(tool_input_schema(ToolType), "properties")
            @test haskey(tool_input_schema(ToolType), "required")
        end
    end

    @testset "ToolExecution JSON Roundtrip" begin
        # Test serialization and deserialization of ToolExecution
        @testset "BashTool roundtrip" begin
            tool = BashTool("echo 'roundtrip'")
            result = execute_tool!(tool)
            execution = ToolExecution(tool, result)

            json = JSON3.write(execution)
            deserialized = JSON3.read(json, ToolExecution{BashTool})
            @test deserialized.tool.command == tool.command
            @test deserialized.result.success == result.success
        end

        @testset "FileReadTool roundtrip" begin
            test_file = tempname()
            write(test_file, "roundtrip content")
            tool = FileReadTool(test_file)
            result = execute_tool!(tool)
            execution = ToolExecution(tool, result)

            json = JSON3.write(execution)
            deserialized = JSON3.read(json, ToolExecution{FileReadTool})
            @test deserialized.tool.path == tool.path
            @test deserialized.result.success == true
            rm(test_file)
        end

        @testset "FileWriteTool roundtrip" begin
            test_file = tempname()
            tool = FileWriteTool(test_file, "roundtrip")
            result = execute_tool!(tool)
            execution = ToolExecution(tool, result)

            json = JSON3.write(execution)
            deserialized = JSON3.read(json, ToolExecution{FileWriteTool})
            @test deserialized.tool.path == tool.path
            @test deserialized.result.success == true
            rm(test_file)
        end

        @testset "FileEditTool roundtrip" begin
            test_file = tempname()
            write(test_file, "old text")
            tool = FileEditTool(test_file, "old", "new")
            result = execute_tool!(tool)
            execution = ToolExecution(tool, result)

            json = JSON3.write(execution)
            deserialized = JSON3.read(json, ToolExecution{FileEditTool})
            @test deserialized.tool.path == tool.path
            @test deserialized.result.success == true
            rm(test_file)
        end

        @testset "TodoList roundtrip" begin
            tool = TodoList("Roundtrip Plan", ["Task A", "Task B"])
            result = execute_tool!(tool)
            execution = ToolExecution(tool, result)

            json = JSON3.write(execution)
            deserialized = JSON3.read(json, ToolExecution{TodoList})
            @test deserialized.tool.title == tool.title
            @test deserialized.tool.items == tool.items
        end

        @testset "FileTool roundtrip" begin
            test_dir = mktempdir()
            tool = FileTool("readdir", Dict{String,Any}("path" => test_dir))
            result = execute_tool!(tool)
            execution = ToolExecution(tool, result)

            json = JSON3.write(execution)
            deserialized = JSON3.read(json, ToolExecution{FileTool})
            @test deserialized.tool.command == tool.command
            @test deserialized.result.success == true
            rm(test_dir, recursive=true, force=true)
        end
    end

    @testset "Output Limiting" begin
        # Test limit_output function
        @testset "String limiting" begin
            short_str = "short"
            @test limit_output(short_str, 100) == short_str

            long_str = repeat("a", 1000)
            limited = limit_output(long_str, 50)
            @test length(limited) < length(long_str)
            @test occursin("TRUNCATED", limited)
        end

        @testset "Array limiting" begin
            short_arr = [1, 2, 3]
            @test limit_output(short_arr, 1000) == short_arr

            long_arr = collect(1:100)
            limited = limit_output(long_arr, 10)
            @test length(limited) < length(long_arr)
        end
    end

    @testset "CompactingState" begin
        # Test compacting state creation and persistence
        test_dir = mktempdir()
        ai_dir = joinpath(test_dir, "ai")
        mkpath(ai_dir)

        # Create new state
        state = CompactingState(keep_last=3, min_size_to_compact=100)
        @test state.keep_last == 3
        @test state.min_size_to_compact == 100
        @test isempty(state.compacted_cells)

        # Add some compacted cells
        push!(state.compacted_cells, 1)
        push!(state.compacted_cells, 2)

        # Save state
        save_compacting_state(test_dir, state)
        @test isfile(joinpath(ai_dir, "compacting-state.json"))

        # Load state
        loaded = load_compacting_state(test_dir)
        @test loaded.keep_last == 3
        @test loaded.min_size_to_compact == 100
        @test 1 in loaded.compacted_cells
        @test 2 in loaded.compacted_cells

        # Test compact_tool_result
        short_result = ToolResult("short result")
        @test compact_tool_result(short_result) == short_result

        long_result = ToolResult(repeat("a", 1000))
        compacted = compact_tool_result(long_result)
        @test length(string(compacted.result)) < length(string(long_result.result))
        @test occursin("compacted for context efficiency", string(compacted.result))

        # Error results should not be compacted
        error_result = ToolResult(ErrorException("test error"))
        @test compact_tool_result(error_result) == error_result

        rm(test_dir, recursive=true, force=true)
    end

    @testset "HTTP Streaming Agent" begin
        # Only run if API key is available
        api_key = get(ENV, "ANTHROPIC_API_KEY", get(ENV, "CLAUDE_API_KEY", nothing))
        if api_key !== nothing
            @testset "Basic Streaming" begin
                api = ClaudeApi("https://api.anthropic.com/v1/messages", "claude-sonnet-4-20250514", api_key, "")
                agent = HTTPAgent(api)

                messages = [AgentMessage(:user, "Say hello in one word")]
                result_channel = prompt(agent, messages)
                results = collect(result_channel)

                @test length(results) >= 1
                @test any(x -> x isa String, results)
            end

            @testset "Tool Usage" begin
                api = ClaudeApi("https://api.anthropic.com/v1/messages", "claude-sonnet-4-20250514", api_key, "")
                agent = HTTPAgent(api; tools=[BashTool])

                messages = [AgentMessage(:user, "Use bash to echo 'test'")]
                result_channel = prompt(agent, messages)
                results = collect(result_channel)

                @test length(results) >= 1
                has_tool = any(x -> x isa BashTool, results)
                has_text = any(x -> x isa String, results)
                @test has_tool || has_text  # Either tool use or text response
            end
        else
            @warn "Skipping HTTP streaming tests - No API key found (ANTHROPIC_API_KEY or CLAUDE_API_KEY)"
        end
    end

    @testset "LLM Response Parsing" begin
        # Test Claude stream parsing
        @testset "ClaudeStreamState" begin
            state = ClaudeStreamState()
            @test state.current_block_index == -1
            @test state.text_buffer == ""
            @test state.tool_name == ""
            @test state.stop_reason === nothing
        end

        # Test OpenAI stream parsing
        @testset "OpenAIStreamState" begin
            state = OpenAIStreamState()
            @test isempty(state.tool_calls)
            @test state.text_buffer == ""
        end
    end
end
