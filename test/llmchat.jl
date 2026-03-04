using Test
using JSON3
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
        # Test execution (uses httpbin.org for testing, may fail without network)
        try
            tool = HttpGetTool("https://httpbin.org/status/200")
            result = execute_tool!(tool)
            @test result isa ToolResult
            @test result.success == true
            @test result.result isa Dict
            @test result.result["status"] == 200
        catch e
            @warn "Skipping HttpGetTool test - network unavailable" exception=e
        end
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

    @testset "Claude Code CLI Wrapper" begin
        @testset "ClaudeCodeConfig defaults" begin
            config = LLMChatBooks.ClaudeCodeConfig(; cwd="/tmp")
            @test config.model == "claude-sonnet-4-20250514"
            @test config.permission_mode == "acceptEdits"
            @test config.max_turns == 20
            @test config.cwd == "/tmp"
            @test "Read" in config.allowed_tools
            @test "Write" in config.allowed_tools
            @test "Bash" in config.allowed_tools
            @test config.continue_conversation == true
        end

        @testset "ClaudeCodeConfig custom" begin
            config = LLMChatBooks.ClaudeCodeConfig(;
                model="claude-haiku-4-5-20251001",
                max_turns=5,
                allowed_tools=["Read"],
                permission_mode="deny",
                cwd="/tmp",
                max_thinking_tokens=4000,
                continue_conversation=false,
            )
            @test config.model == "claude-haiku-4-5-20251001"
            @test config.max_turns == 5
            @test config.allowed_tools == ["Read"]
            @test config.permission_mode == "deny"
            @test config.max_thinking_tokens == 4000
            @test config.continue_conversation == false
        end

        @testset "ClaudeCodeAgent creation" begin
            # Only test if claude CLI is available
            cli_path = nothing
            try
                cli_path = LLMChatBooks.find_claude_cli()
            catch
                # CLI not installed, skip
            end

            if cli_path !== nothing
                config = LLMChatBooks.ClaudeCodeConfig(; cwd=pwd())
                agent = LLMChatBooks.ClaudeCodeAgent(config)
                @test agent isa LLMChatBooks.LLMChatAgent
                @test agent isa LLMChatBooks.ClaudeCodeAgent
                @test agent.cli_path == cli_path
                @test agent.last_item[] === nothing
                @test isempty(agent.needs_to_be_done)
            else
                @warn "Skipping ClaudeCodeAgent creation test - claude CLI not found"
            end
        end

        @testset "build_command" begin
            cli_path = nothing
            try
                cli_path = LLMChatBooks.find_claude_cli()
            catch end

            if cli_path !== nothing
                config = LLMChatBooks.ClaudeCodeConfig(;
                    model="test-model",
                    system_prompt="test prompt",
                    allowed_tools=["Read", "Write"],
                    permission_mode="acceptEdits",
                    max_turns=5,
                    cwd="/tmp",
                )
                agent = LLMChatBooks.ClaudeCodeAgent(config)
                cmd = LLMChatBooks.build_command(agent, "hello world")

                cmd_str = string(cmd)
                @test occursin("--output-format", cmd_str)
                @test occursin("stream-json", cmd_str)
                @test occursin("--verbose", cmd_str)
                @test occursin("--model", cmd_str)
                @test occursin("test-model", cmd_str)
                @test occursin("--system-prompt", cmd_str)
                @test occursin("--allowedTools", cmd_str)
                @test occursin("Read,Write", cmd_str)
                @test occursin("--max-turns", cmd_str)
                @test occursin("-p", cmd_str)
                @test occursin("hello world", cmd_str)
                # Check CLAUDECODE env is unset (for nested execution)
                @test occursin("CLAUDECODE", cmd_str)
            else
                @warn "Skipping build_command test - claude CLI not found"
            end
        end

        @testset "parse_stream_message" begin
            # System messages -> nothing
            @test LLMChatBooks.parse_stream_message(
                """{"type":"system","message":"init"}"""
            ) === nothing

            # Empty/invalid -> nothing
            @test LLMChatBooks.parse_stream_message("") === nothing
            @test LLMChatBooks.parse_stream_message("not json") === nothing
            @test LLMChatBooks.parse_stream_message("""{"type":"user"}""") === nothing

            # Result messages -> nothing (duplicates assistant text)
            @test LLMChatBooks.parse_stream_message(
                """{"type":"result","result":"Done!","cost_usd":0.01}"""
            ) === nothing

            # Assistant with text
            result = LLMChatBooks.parse_stream_message(
                """{"type":"assistant","message":{"content":[{"type":"text","text":"Hello!"}]}}"""
            )
            @test result isa Vector
            @test length(result) == 1
            @test result[1] == "Hello!"

            # Assistant with multiple content blocks
            result = LLMChatBooks.parse_stream_message(
                """{"type":"assistant","message":{"content":[{"type":"text","text":"Let me read."},{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/tmp/test.txt"}}]}}"""
            )
            @test result isa Vector
            @test length(result) == 2
            @test result[1] isa String
            @test result[1] == "Let me read."
            @test result[2] isa FileReadTool
            @test result[2].path == "/tmp/test.txt"

            # Empty text blocks are skipped
            result = LLMChatBooks.parse_stream_message(
                """{"type":"assistant","message":{"content":[{"type":"text","text":"   "}]}}"""
            )
            @test result isa Vector
            @test isempty(result)
        end

        @testset "parse_tool_use mappings" begin
            # Read
            block = JSON3.read("""{"name":"Read","input":{"file_path":"/tmp/a.txt"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa FileReadTool
            @test tool.path == "/tmp/a.txt"

            # Write
            block = JSON3.read("""{"name":"Write","input":{"file_path":"/tmp/b.txt","content":"hi"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa FileWriteTool
            @test tool.path == "/tmp/b.txt"
            @test tool.content == "hi"

            # Edit
            block = JSON3.read("""{"name":"Edit","input":{"file_path":"/tmp/c.txt","old_string":"a","new_string":"b"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa FileEditTool
            @test tool.path == "/tmp/c.txt"
            @test tool.old_text == "a"
            @test tool.new_text == "b"

            # Bash
            block = JSON3.read("""{"name":"Bash","input":{"command":"ls"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa BashTool
            @test tool.command == "ls"

            # Glob -> FileTool
            block = JSON3.read("""{"name":"Glob","input":{"pattern":"*.jl"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa FileTool
            @test tool.command == "glob"
            @test tool.arguments["pattern"] == "*.jl"

            # Grep -> BashTool
            block = JSON3.read("""{"name":"Grep","input":{"pattern":"hello","path":"."}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa BashTool
            @test occursin("grep", tool.command)
            @test occursin("hello", tool.command)

            # Julia exec -> AddCellTool
            block = JSON3.read("""{"name":"mcp__julia-server__julia_exec","input":{"code":"1+1"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa AddCellTool
            @test tool.language == "julia"
            @test tool.content == "1+1"

            # Unknown tool -> BashTool fallback
            block = JSON3.read("""{"name":"UnknownTool","input":{"foo":"bar"}}""")
            tool = LLMChatBooks.parse_tool_use(block)
            @test tool isa BashTool
            @test occursin("UnknownTool", tool.command)
        end

        @testset "isdone logic" begin
            config = LLMChatBooks.ClaudeCodeConfig(; cwd=pwd())
            try
                agent = LLMChatBooks.ClaudeCodeAgent(config)

                # Initially not done (last_item is nothing)
                @test LLMChatBooks.isdone(agent) == false

                # After text -> done
                agent.last_item[] = "response text"
                @test LLMChatBooks.isdone(agent) == true

                # After tool -> not done
                agent.last_item[] = FileReadTool("/tmp/test.txt")
                @test LLMChatBooks.isdone(agent) == false

                # Back to text -> done
                agent.last_item[] = "more text"
                @test LLMChatBooks.isdone(agent) == true
            catch e
                @warn "Skipping isdone test - claude CLI not found" exception=e
            end
        end

        @testset "load_claude_code_config" begin
            tmpdir = mktempdir()
            ai_dir = joinpath(tmpdir, "ai")
            mkpath(ai_dir)

            # Write config with claude-code backend
            write(joinpath(ai_dir, "llm-config.toml"), """
backend = "claude-code"
model = "claude-haiku-4-5-20251001"
max_turns = 10
permission_mode = "deny"
""")

            try
                agent = LLMChatBooks.load_agent_config(tmpdir)
                @test agent isa LLMChatBooks.ClaudeCodeAgent
                @test agent.config.model == "claude-haiku-4-5-20251001"
                @test agent.config.max_turns == 10
                @test agent.config.permission_mode == "deny"
            catch e
                @warn "Skipping config loading test - claude CLI not found" exception=e
            end

            # Test that HTTP backend still works (needs API key for ClaudeApi)
            api_key = get(ENV, "ANTHROPIC_API_KEY", get(ENV, "CLAUDE_API_KEY", nothing))
            if api_key !== nothing
                write(joinpath(ai_dir, "llm-config.toml"), """
backend = "http"
model = "claude-sonnet-4-20250514"
""")
                agent_http = LLMChatBooks.load_agent_config(tmpdir)
                @test agent_http isa LLMChatBooks.HTTPAgent
            end

            rm(tmpdir, recursive=true, force=true)
        end

        @testset "CLI integration" begin
            # Only test if claude CLI is available and API key is set
            cli_available = try
                LLMChatBooks.find_claude_cli()
                true
            catch
                false
            end

            api_key = get(ENV, "ANTHROPIC_API_KEY", nothing)

            if cli_available && api_key !== nothing
                config = LLMChatBooks.ClaudeCodeConfig(;
                    model="claude-sonnet-4-20250514",
                    system_prompt="Respond with exactly one word: PONG",
                    max_turns=1,
                    cwd=pwd(),
                    allowed_tools=String[],
                    max_thinking_tokens=0,
                )
                agent = LLMChatBooks.ClaudeCodeAgent(config)
                spinner = LLMChatBooks.TaskSpinner()
                messages = [AgentMessage(:user, "PING")]

                chan = LLMChatBooks.prompt(agent, messages; spinner=spinner)
                items = collect(chan)

                @test length(items) >= 1
                @test any(x -> x isa String, items)
            else
                @warn "Skipping CLI integration test - claude CLI not found or no API key"
            end
        end
    end
end
