# Tests for `export_md_with_results` and the helpers it now shares with
# `export_md` (`write_code_fence`, `cell_metadata_string`,
# `write_cell_output_md`). Drives the function with synthetic MIME types
# so we don't need Makie / WGLMakie / a real browser for the unit tests
# — the electron suite covers the live-browser branch separately.
using Test
using BonitoBook

# Synthetic outputs that implement the MIME types `cell_output_to_file`
# probes for in order: PNG → SVG → HTML → text. Each struct only
# supports the MIME it advertises so we can deterministically pick a
# branch by choosing the struct.

struct FakePNG
    bytes::Vector{UInt8}
end
Base.show(io::IO, ::MIME"image/png", p::FakePNG) = write(io, p.bytes)

struct FakeSVG
    body::String
end
Base.show(io::IO, ::MIME"image/svg+xml", s::FakeSVG) = write(io, s.body)

struct FakeHTML
    body::String
    plain::String
end
Base.show(io::IO, ::MIME"text/html",  h::FakeHTML) = write(io, h.body)
Base.show(io::IO, ::MIME"text/plain", h::FakeHTML) = write(io, h.plain)

struct FakeHTMLWithSVG
    body::String
end
Base.show(io::IO, ::MIME"text/html", h::FakeHTMLWithSVG) = write(io, h.body)

# A 1x1 transparent PNG (smallest valid PNG: 67 bytes).
const TINY_PNG_BYTES = UInt8[
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
    0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]

# Helper: build a Book and force-set a specific cell's output to a value.
# `cell_idx` is 1-based against `book.cells`.
function set_cell_output!(book, cell_idx::Int, value)
    book.cells[cell_idx].editor.output[] = value
    return book
end

# Helper: pick the unique julia cell with the given source content.
function julia_cell(book, contains::AbstractString)
    return book.cells[findfirst(c -> c.language == "julia" &&
                                 occursin(contains, c.editor.source[]),
                                 book.cells)]
end

@testset "export_md_with_results" begin

    @testset "shared helpers: cell_metadata_string + write_code_fence" begin
        # The fence helper must grow past any backtick run inside content.
        io = IOBuffer()
        BonitoBook.write_code_fence(io, "julia", "println(`hi`)")
        out = String(take!(io))
        @test occursin("```julia\n", out)
        @test endswith(rstrip(out), "```")

        # Triple-backtick inside content forces a 4-backtick fence.
        io = IOBuffer()
        BonitoBook.write_code_fence(io, "julia", "x = \"\"\"\n```\nfoo\n```\n\"\"\"")
        out = String(take!(io))
        @test occursin("````julia\n", out)
        @test occursin("\n````", out)
        # The "```" inside content must NOT be matched by the closing fence —
        # check that the longer fence is balanced (count of "````" >= 2).
        @test count("````", out) >= 2
    end

    @testset "round-trips markdown cells unmodified" begin
        mktempdir() do tmp
            src = joinpath(tmp, "src.md")
            write(src, """
            # Heading One

            A paragraph with **bold** and *italic*.

              - a
              - b

            ```julia (editor=true, logging=false, output=true)
            42
            ```
            """)
            book = BonitoBook.Book(src)
            set_cell_output!(book, findfirst(c -> c.language == "julia", book.cells), 42)

            out = joinpath(tmp, "out.md")
            BonitoBook.export_md_with_results(out, book)
            text = read(out, String)

            @test occursin("# Heading One", text)
            @test occursin("**bold**", text)
            @test occursin("```julia\n42\n```", text)
            # The integer scalar lands in a fenced text block via the
            # text/plain fallback.
            @test occursin("```text", text)
            @test occursin("42", text)

            close(book.runner)
        end
    end

    @testset "PNG output is saved as cell_<uuid>.png and referenced" begin
        mktempdir() do tmp
            src = joinpath(tmp, "png.md")
            write(src, """
            # PNG

            ```julia (editor=true, logging=false, output=true)
            plot()
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "plot()")
            cell.editor.output[] = FakePNG(TINY_PNG_BYTES)

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            png_file = joinpath(out_dir, "cell_$(cell.uuid).png")
            @test isfile(png_file)
            @test read(png_file) == TINY_PNG_BYTES
            # Reference uses a relative path.
            @test occursin("![Output](", text)
            @test occursin("cell_$(cell.uuid).png", text)

            close(book.runner)
        end
    end

    @testset "SVG output is saved + referenced" begin
        mktempdir() do tmp
            src = joinpath(tmp, "svg.md")
            write(src, """
            # SVG

            ```julia (editor=true, logging=false, output=true)
            plot_svg()
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "plot_svg()")
            cell.editor.output[] = FakeSVG(
                "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'/>")

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            svg_file = joinpath(out_dir, "cell_$(cell.uuid).svg")
            @test isfile(svg_file)
            @test occursin("<svg", read(svg_file, String))
            @test occursin("![Output](", text)
            @test occursin("cell_$(cell.uuid).svg", text)

            close(book.runner)
        end
    end

    @testset "HTML output (no inline SVG): writes link + plain-text block" begin
        # No book.session → the live-browser PNG capture path is skipped.
        # We expect: .html file saved, .txt sidecar saved, markdown
        # contains a `[Output (HTML)](…)` link AND a fenced text block.
        mktempdir() do tmp
            src = joinpath(tmp, "html.md")
            write(src, """
            # HTML

            ```julia (editor=true, logging=false, output=true)
            html_output()
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "html_output()")
            cell.editor.output[] = FakeHTML(
                "<div class='widget'>Hello <b>world</b></div>",
                "Hello world (plain)")

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            html_file = joinpath(out_dir, "cell_$(cell.uuid).html")
            txt_file  = joinpath(out_dir, "cell_$(cell.uuid).txt")
            @test isfile(html_file)
            @test isfile(txt_file)
            @test occursin("Hello world", read(txt_file, String))
            @test occursin("[Output (HTML)](", text)
            @test occursin("cell_$(cell.uuid).html", text)
            # The text sidecar is folded into the export as a ```text fence.
            @test occursin("```text", text)
            @test occursin("Hello world", text)
            # No PNG was captured since there's no live session.
            @test !isfile(joinpath(out_dir, "cell_$(cell.uuid).png"))

            close(book.runner)
        end
    end

    @testset "HTML output WITH inline SVG: SVG is extracted + referenced as image" begin
        mktempdir() do tmp
            src = joinpath(tmp, "svgih.md")
            write(src, """
            # SVG-in-HTML

            ```julia (editor=true, logging=false, output=true)
            mixed_output()
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "mixed_output()")
            cell.editor.output[] = FakeHTMLWithSVG("""
                <div>
                  Some prose.
                  <svg xmlns="http://www.w3.org/2000/svg" width="3" height="3">
                    <circle r="1" cx="1" cy="1"/>
                  </svg>
                </div>
                """)

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            # cell_output_to_file pulled the <svg>…</svg> out and saved it
            # as a real .svg, returning that as the rendered output. The
            # .html still gets saved as a side artifact.
            svg_file = joinpath(out_dir, "cell_$(cell.uuid).svg")
            @test isfile(svg_file)
            @test occursin("<circle", read(svg_file, String))
            # The markdown should reference the SVG, not the HTML.
            @test occursin("![Output](", text)
            @test occursin("cell_$(cell.uuid).svg", text)
            @test !occursin("[Output (HTML)](", text)

            close(book.runner)
        end
    end

    @testset "text output: plain string lands in a ```text fence" begin
        mktempdir() do tmp
            src = joinpath(tmp, "text.md")
            write(src, """
            # Text

            ```julia (editor=true, logging=false, output=true)
            "hi"
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "\"hi\"")
            cell.editor.output[] = "Multi-line\nstring\noutput"

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            @test occursin("```text", text)
            @test occursin("Multi-line", text)
            @test occursin("output", text)

            close(book.runner)
        end
    end

    @testset "no output value: cell still appears, no output block" begin
        mktempdir() do tmp
            src = joinpath(tmp, "noout.md")
            write(src, """
            # NoOut

            ```julia (editor=true, logging=false, output=true)
            42
            ```
            """)
            book = BonitoBook.Book(src)
            # Leave editor.output[] at its initial value (nothing).
            cell = julia_cell(book, "42")
            cell.editor.output[] = nothing

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            @test occursin("```julia\n42\n```", text)
            # The output dir might exist (mkpath in export_md_with_results)
            # but no per-cell file should have been created.
            @test !isfile(joinpath(out_dir, "cell_$(cell.uuid).png"))
            @test !isfile(joinpath(out_dir, "cell_$(cell.uuid).html"))
            @test !isfile(joinpath(out_dir, "cell_$(cell.uuid).txt"))

            close(book.runner)
        end
    end

    @testset "backticks in source: fence grows so closing isn't ambiguous" begin
        mktempdir() do tmp
            src = joinpath(tmp, "ticks.md")
            # Use a 4-tick fence so the source `\`\`\`` inside is unambiguous on input.
            write(src, """
            # Backticks

            ````julia (editor=true, logging=false, output=true)
            x = ```
            this is a literal triple-backtick line
            ```
            ````
            """)
            book = BonitoBook.Book(src)

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            # The export must use a fence longer than the longest tick
            # run in the content — at least 4 backticks here.
            @test occursin("````julia\n", text)
            @test occursin("\n````\n", text)

            close(book.runner)
        end
    end

    @testset "NoSplat-wrapped output is unwrapped before MIME dispatch" begin
        mktempdir() do tmp
            src = joinpath(tmp, "nosplat.md")
            write(src, """
            # NoSplat

            ```julia (editor=true, logging=false, output=true)
            wrapped()
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "wrapped()")
            # The runner wraps actual eval results in NoSplat — test that
            # cell_output_to_file unwraps before checking showable.
            cell.editor.output[] = BonitoBook.NoSplat(FakePNG(TINY_PNG_BYTES))

            out_dir = joinpath(tmp, "outputs")
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book; output_dir = out_dir)
            text = read(out, String)

            png_file = joinpath(out_dir, "cell_$(cell.uuid).png")
            @test isfile(png_file)
            @test read(png_file) == TINY_PNG_BYTES
            @test occursin("cell_$(cell.uuid).png", text)

            close(book.runner)
        end
    end

    @testset "default output_dir lives under book.folder/data/output" begin
        mktempdir() do tmp
            src = joinpath(tmp, "default.md")
            write(src, """
            # Default

            ```julia (editor=true, logging=false, output=true)
            42
            ```
            """)
            book = BonitoBook.Book(src)
            cell = julia_cell(book, "42")
            cell.editor.output[] = FakePNG(TINY_PNG_BYTES)

            # No output_dir passed → uses joinpath(book.folder, "data", "output").
            out = joinpath(tmp, "result.md")
            BonitoBook.export_md_with_results(out, book)
            text = read(out, String)

            default_dir = joinpath(book.folder, "data", "output")
            @test isfile(joinpath(default_dir, "cell_$(cell.uuid).png"))
            @test occursin("cell_$(cell.uuid).png", text)

            close(book.runner)
        end
    end

    @testset "round-trip parity: export_md still produces parseable cells" begin
        # The refactor shares helpers between export_md and
        # export_md_with_results; this guards against the round-trip
        # regressing.
        mktempdir() do tmp
            src = joinpath(tmp, "roundtrip.md")
            write(src, """
            # Hello

            Some text.

            ```julia (editor=true, logging=false, output=true)
            1 + 1
            ```

            ```python (editor=true, logging=false, output=true)
            print("hi")
            ```
            """)
            book = BonitoBook.Book(src)
            n_cells_before = length(book.cells)

            out = joinpath(tmp, "exported.md")
            BonitoBook.export_md(out, book)
            book2 = BonitoBook.Book(out)
            @test length(book2.cells) == n_cells_before
            @test [c.language for c in book2.cells] ==
                  [c.language for c in book.cells]
            @test [c.editor.source[] for c in book2.cells] ==
                  [c.editor.source[] for c in book.cells]

            close(book.runner)
            close(book2.runner)
        end
    end
end
