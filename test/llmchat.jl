using Test
using JSON3
using HTTP
using Bonito
using Hyperscript
using BonitoBook.LLMChatBooks

@testset "LLMChat Tools" begin
    @testset "BashTool" begin
        # Test JSON deserialization
        tool_json = """{"command":"echo 'test'","result":null}"""
        tool = JSON3.read(tool_json, BashTool)
        @test tool isa BashTool
        @test tool.command == "echo 'test'"
        @test tool.result === nothing

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test occursin("test", result["output"])
        @test tool.result === result

        # Test jsrender with success
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("test", string(rendered))
        @test occursin("tool-container", string(rendered))

        # Test JSON roundtrip (execute -> serialize -> deserialize -> render)
        json = JSON3.write(tool)
        deserialized = JSON3.read(json, BashTool)
        @test deserialized.result isa Dict
        @test deserialized.result["success"] == true
        rendered_roundtrip = Bonito.jsrender(session, deserialized)
        @test occursin("test", string(rendered_roundtrip))
    end

    @testset "FileReadTool" begin
        # Create test file
        test_file = tempname()
        write(test_file, "Test content for FileReadTool")

        # Test JSON deserialization
        tool_json = """{"path":"$test_file","result":null}"""
        tool = JSON3.read(tool_json, FileReadTool)
        @test tool isa FileReadTool
        @test tool.path == test_file

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test result["content"] == "Test content for FileReadTool"
        @test result["path"] == test_file

        # Test jsrender with result
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("Test content", string(rendered))

        # Test non-existent file
        tool_json_bad = """{"path":"/nonexistent/file.txt","result":null}"""
        tool_bad = JSON3.read(tool_json_bad, FileReadTool)
        result_bad = execute_tool!(tool_bad)
        @test result_bad isa Dict
        @test result_bad["success"] == false
        @test occursin("not found", result_bad["error"])

        # Test error rendering (this was crashing before the fix)
        rendered_error = Bonito.jsrender(session, tool_bad)
        @test rendered_error isa Hyperscript.Node
        @test occursin("File not found", string(rendered_error))
        @test occursin("tool-error", string(rendered_error))

        # Test JSON roundtrip for error case
        json_error = JSON3.write(tool_bad)
        deserialized_error = JSON3.read(json_error, FileReadTool)
        @test deserialized_error.result["success"] == false
        rendered_error_roundtrip = Bonito.jsrender(session, deserialized_error)
        @test occursin("File not found", string(rendered_error_roundtrip))

        # Cleanup
        rm(test_file, force=true)
    end

    @testset "FileWriteTool" begin
        # Test JSON deserialization
        test_file = tempname()
        tool_json = """{"path":"$test_file","content":"Written by FileWriteTool","result":null}"""
        tool = JSON3.read(tool_json, FileWriteTool)
        @test tool isa FileWriteTool
        @test tool.path == test_file
        @test tool.content == "Written by FileWriteTool"

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test result["path"] == test_file
        @test result["bytes_written"] == 24
        @test isfile(test_file)
        @test read(test_file, String) == "Written by FileWriteTool"

        # Test jsrender
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("bytes", string(rendered))
        @test occursin("tool-container", string(rendered))

        # Test with subdirectory creation
        test_subdir = joinpath(tempdir(), "test_subdir_$(rand(1:10000))", "subdir", "file.txt")
        tool_json_sub = """{"path":"$test_subdir","content":"Test content","result":null}"""
        tool_sub = JSON3.read(tool_json_sub, FileWriteTool)
        result_sub = execute_tool!(tool_sub)
        @test result_sub["success"] == true
        @test isfile(test_subdir)

        # Cleanup
        rm(test_file, force=true)
        rm(dirname(dirname(test_subdir)), force=true, recursive=true)
    end

    @testset "FileEditTool" begin
        # Create test file
        test_file = tempname()
        write(test_file, "Hello World")

        # Test JSON deserialization
        tool_json = """{"path":"$test_file","old_text":"World","new_text":"Julia","result":null}"""
        tool = JSON3.read(tool_json, FileEditTool)
        @test tool isa FileEditTool
        @test tool.path == test_file
        @test tool.old_text == "World"
        @test tool.new_text == "Julia"

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test result["path"] == test_file
        @test read(test_file, String) == "Hello Julia"

        # Test jsrender
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("successfully", string(rendered))

        # Test with non-existent old_text
        tool_json_bad = """{"path":"$test_file","old_text":"NotFound","new_text":"Replacement","result":null}"""
        tool_bad = JSON3.read(tool_json_bad, FileEditTool)
        result_bad = execute_tool!(tool_bad)
        @test result_bad["success"] == false
        @test occursin("not found", result_bad["error"])

        # Test error rendering
        rendered_error = Bonito.jsrender(session, tool_bad)
        @test rendered_error isa Hyperscript.Node
        @test occursin("not found", string(rendered_error))
        @test occursin("tool-error", string(rendered_error))

        # Cleanup
        rm(test_file, force=true)
    end

    @testset "HttpGetTool" begin
        # Test JSON deserialization
        tool_json = """{"url":"https://httpbin.org/status/200","result":null}"""
        tool = JSON3.read(tool_json, HttpGetTool)
        @test tool isa HttpGetTool
        @test tool.url == "https://httpbin.org/status/200"

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test result["status"] == 200
        @test result["url"] == "https://httpbin.org/status/200"

        # Test jsrender
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("Status", string(rendered))
        @test occursin("200", string(rendered))
    end

    @testset "AddCellTool" begin
        # Test JSON deserialization without metadata
        tool_json = """{"language":"julia","content":"println(\\"Hello\\")","metadata":null,"result":null}"""
        tool = JSON3.read(tool_json, AddCellTool)
        @test tool isa AddCellTool
        @test tool.language == "julia"
        @test tool.content == "println(\"Hello\")"
        @test tool.metadata === nothing

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test result["language"] == "julia"
        @test result["content"] == "println(\"Hello\")"
        @test result["metadata"] == Dict{Symbol, Any}()

        # Test jsrender (NEW: AddCellTool now has proper rendering)
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("Hello", string(rendered))
        @test occursin("julia", string(rendered))
        @test occursin("tool-container", string(rendered))

        # Test with markdown
        tool_json_md = """{"language":"markdown","content":"# Title\\n\\nContent","metadata":null,"result":null}"""
        tool_md = JSON3.read(tool_json_md, AddCellTool)
        result_md = execute_tool!(tool_md)
        @test result_md["success"] == true
        @test result_md["language"] == "markdown"
    end

    @testset "TodoTool" begin
        # Test JSON deserialization
        tool_json = """{"title":"Test Plan","items":["Step 1","Step 2","Step 3"],"result":null}"""
        tool = JSON3.read(tool_json, TodoTool)
        @test tool isa TodoTool
        @test tool.title == "Test Plan"
        @test tool.items == ["Step 1", "Step 2", "Step 3"]

        # Test execution
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == true
        @test result["title"] == "Test Plan"
        @test result["items"] == ["Step 1", "Step 2", "Step 3"]
        @test occursin("## Test Plan", result["markdown"])
        @test occursin("- [ ] Step 1", result["markdown"])
        @test occursin("- [ ] Step 2", result["markdown"])
        @test occursin("- [ ] Step 3", result["markdown"])

        # Test jsrender
        session = Session()
        rendered = Bonito.jsrender(session, tool)
        @test rendered isa Hyperscript.Node
        @test occursin("Test Plan", string(rendered))
        @test occursin("Step 1", string(rendered))
        @test occursin("todo-container", string(rendered))
    end

    @testset "Tool Metadata" begin
        # Test tool_name, tool_description, tool_input_schema for all tools
        for ToolType in [BashTool, FileReadTool, FileWriteTool, FileEditTool,
                         HttpGetTool, AddCellTool, TodoTool]
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

    @testset "Error Handling" begin
        # Test execute_tool! error handling
        test_file = "/nonexistent/path/file.txt"
        tool_json = """{"path":"$test_file","result":null}"""
        tool = JSON3.read(tool_json, FileReadTool)
        result = execute_tool!(tool)
        @test result isa Dict
        @test result["success"] == false
        @test haskey(result, "error")
    end

    @testset "JSON Roundtrip (Execute -> Serialize -> Deserialize -> Render)" begin
        session = Session()

        # Test all tools with the full roundtrip workflow as used in agent_loop.jl
        @testset "BashTool roundtrip" begin
            tool = BashTool("echo 'roundtrip'")
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, BashTool)
            @test deserialized.result isa Dict
            @test deserialized.result["success"] == true
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("roundtrip", string(rendered))
        end

        @testset "FileReadTool roundtrip" begin
            test_file = tempname()
            write(test_file, "roundtrip content")
            tool = FileReadTool(test_file)
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, FileReadTool)
            @test deserialized.result["success"] == true
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("roundtrip content", string(rendered))
            rm(test_file)
        end

        @testset "FileWriteTool roundtrip" begin
            test_file = tempname()
            tool = FileWriteTool(test_file, "roundtrip")
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, FileWriteTool)
            @test deserialized.result["success"] == true
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("bytes", string(rendered))
            rm(test_file)
        end

        @testset "FileEditTool roundtrip" begin
            test_file = tempname()
            write(test_file, "old text")
            tool = FileEditTool(test_file, "old", "new")
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, FileEditTool)
            @test deserialized.result["success"] == true
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("successfully", string(rendered))
            rm(test_file)
        end

        @testset "HttpGetTool roundtrip" begin
            tool = HttpGetTool("https://httpbin.org/status/200")
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, HttpGetTool)
            @test deserialized.result["success"] == true
            @test deserialized.result["status"] == 200
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("Status", string(rendered))
        end

        @testset "AddCellTool roundtrip" begin
            tool = AddCellTool("julia", "println(\"roundtrip\")")
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, AddCellTool)
            @test deserialized.result["success"] == true
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("roundtrip", string(rendered))
        end

        @testset "TodoTool roundtrip" begin
            tool = TodoTool("Roundtrip Plan", ["Task A", "Task B"])
            execute_tool!(tool)
            json = JSON3.write(tool)
            deserialized = JSON3.read(json, TodoTool)
            @test deserialized.result["success"] == true
            rendered = Bonito.jsrender(session, deserialized)
            @test occursin("Roundtrip Plan", string(rendered))
            @test occursin("Task A", string(rendered))
        end
    end

    @testset "HTTP Streaming Agent" begin
        # Only run if API key is available
        if haskey(ENV, "ANTHROPIC_API_KEY")
            @testset "Basic Streaming" begin
                config = claude_config("claude-3-5-sonnet-20241022"; api_key=ENV["ANTHROPIC_API_KEY"])
                agent = HTTPAgent(config)

                messages = [AgentMessage(:user, "What is 2+2? Use bash to calculate: echo \$((2+2))")]
                result_channel = prompt(agent, messages, [BashTool])
                results = collect(result_channel)

                @test length(results) >= 1
                @test any(x -> x isa BashTool, results)

                tool_idx = findfirst(x -> x isa BashTool, results)
                @test tool_idx !== nothing
                @test results[tool_idx].command == "echo \$((2+2))"
            end

            @testset "Streaming with Execution" begin
                config = claude_config("claude-3-5-sonnet-20241022"; api_key=ENV["ANTHROPIC_API_KEY"])
                agent = HTTPAgent(config)

                messages = [AgentMessage(:user, "List files in /tmp using bash")]
                result_channel = prompt(agent, messages, [BashTool])

                for item in result_channel
                    if item isa BashTool
                        execute_tool!(item)
                        @test item.result !== nothing
                        @test haskey(item.result, "success")

                        # JSON roundtrip
                        json_str = JSON3.write(item)
                        deserialized = JSON3.read(json_str, BashTool)
                        @test deserialized.command == item.command
                        @test deserialized.result == item.result

                        # Test Dict with string keys
                        @test item.result isa Dict
                        @test all(k -> k isa String, keys(item.result))
                    end
                end
            end

            @testset "Text Response Only" begin
                config = claude_config("claude-3-5-sonnet-20241022"; api_key=ENV["ANTHROPIC_API_KEY"])
                agent = HTTPAgent(config)

                messages = [AgentMessage(:user, "Just say hello, don't use any tools")]
                result_channel = prompt(agent, messages, [BashTool])
                results = collect(result_channel)

                @test length(results) >= 1
                @test any(x -> x isa String, results)
                @test all(x -> !(x isa AbstractTool), results)
            end

            @testset "Complete Items Only" begin
                config = claude_config("claude-3-5-sonnet-20241022"; api_key=ENV["ANTHROPIC_API_KEY"])
                agent = HTTPAgent(config)

                messages = [AgentMessage(:user, "Use bash to run: echo 'hello world'")]
                result_channel = prompt(agent, messages, [BashTool])

                for item in result_channel
                    if item isa BashTool
                        @test !isempty(item.command)
                        @test_nowarn execute_tool!(item)
                    elseif item isa String
                        @test !isempty(strip(item))
                    end
                end
            end
        else
            @warn "Skipping HTTP streaming tests - ANTHROPIC_API_KEY not set"
        end
    end
end
