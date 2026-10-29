using Test
using BonitoBook

@testset "Jupyter notebook reader" begin
    mktempdir() do dir
        path = joinpath(dir, "saved.ipynb")
        sentinel = joinpath(dir, "must-not-run")
        source = "write($(repr(sentinel)), \"executed\")"
        outputs = [
            Dict("output_type" => "stream", "name" => "stdout", "text" => ["hello\n", "world"]),
            Dict("output_type" => "execute_result", "execution_count" => 7,
                 "metadata" => Dict(), "data" => Dict("text/plain" => "42", "application/json" => Dict("answer" => 42))),
            Dict("output_type" => "display_data", "metadata" => Dict(),
                 "data" => Dict("image/png" => ["aGVs", "bG8="], "image/svg+xml" => "<svg/>",
                                "text/html" => ["<b>plot</b>"], "text/plain" => ["plot"])),
            Dict("output_type" => "error", "ename" => "ErrorException", "evalue" => "oops",
                 "traceback" => ["line one", "line two"]),
        ]
        notebook = Dict(
            "nbformat" => 4, "nbformat_minor" => 5,
            "metadata" => Dict("kernelspec" => Dict("language" => "julia"), "custom" => 9),
            "cells" => [
                Dict("cell_type" => "markdown", "source" => ["# Héllo\n", "World"]),
                Dict("cell_type" => "code", "source" => source, "outputs" => outputs,
                     "metadata" => Dict("bonitobook" => Dict("id" => 11, "tag" => "demo"))),
                Dict("cell_type" => "code", "source" => String[], "outputs" => []),
                Dict("cell_type" => "raw", "source" => "raw content"),
                Dict("cell_type" => "code", "source" => ["1 + ", "1"],
                     "metadata" => Dict("bonitobook" => Dict("id" => 11))),
            ])
        text = BonitoBook.JSON3.write(notebook)
        write(path, text)
        parsed = BonitoBook.read_ipynb(path)
        @test parsed == BonitoBook.read_ipynb(IOBuffer(text))
        @test parsed.language == "julia"
        @test parsed.metadata["custom"] == 9
        @test length(parsed.cells) == 5
        @test parsed.cells[1].source == "# Héllo\nWorld"
        @test isempty(parsed.cells[1].outputs)
        @test parsed.cells[2].source == source
        @test parsed.cells[2].metadata["bonitobook"]["id"] == 11
        @test parsed.cells[2].outputs == outputs
        @test parsed.cells[3].source == ""
        @test parsed.cells[4].cell_type == "raw"
        @test parsed.cells[5].source == "1 + 1"
        @test !isfile(sentinel)

        # Runnable import keeps its existing rules: skip raw/empty cells,
        # retain BonitoBook metadata, assign unique ids and execute nothing.
        cells = BonitoBook.ipynb2book(path)
        @test [c.language for c in cells] == ["markdown", "julia", "julia"]
        @test [c.source for c in cells] == ["# Héllo\nWorld", source, "1 + 1"]
        @test cells[2].id == 11
        @test cells[2].metadata[:tag] == "demo"
        @test length(unique(c.id for c in cells)) == 3
        @test all(c -> c.output === nothing, cells)
        @test !isfile(sentinel)
    end

    @test BonitoBook.read_ipynb(IOBuffer("{}")) ==
          (language = "julia", metadata = Dict{String, Any}(), cells = [])
    @test BonitoBook.read_ipynb(IOBuffer("{}"); default_language = "python").language == "python"
    @test BonitoBook.read_ipynb(IOBuffer("{\"cells\":[{}]}")).cells[1].source == ""
    @test_throws ArgumentError BonitoBook.read_ipynb(IOBuffer("not json"))
end
