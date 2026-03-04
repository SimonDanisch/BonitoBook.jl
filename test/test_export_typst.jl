using Test
using BonitoBook
using CommonMark
using Bonito

@testset "Typst/PDF Export" begin
    @testset "CommonMark typst() writer" begin
        parser = Bonito.bonito_parser()

        # Basic text
        ast = parser("# Hello\n\nSome **bold** and *italic* text.\n")
        typst = CommonMark.typst(ast)
        @test occursin("= Hello", typst)
        @test occursin("#strong[bold]", typst)
        @test occursin("#emph[italic]", typst)

        # Code blocks
        ast = parser("```julia\nx = 1\n```\n")
        typst = CommonMark.typst(ast)
        @test occursin("```julia", typst)
        @test occursin("x = 1", typst)

        # Tables
        ast = parser("| A | B |\n|---|---|\n| 1 | 2 |\n")
        typst = CommonMark.typst(ast)
        @test occursin("#table", typst)

        # Lists
        ast = parser("1. First\n2. Second\n")
        typst = CommonMark.typst(ast)
        @test occursin("First", typst)
        @test occursin("Second", typst)

        # Links
        ast = parser("[Click](https://example.com)\n")
        typst = CommonMark.typst(ast)
        @test occursin("example.com", typst)

        # Blockquotes
        ast = parser("> Quoted text\n")
        typst = CommonMark.typst(ast)
        @test occursin("Quoted", typst)
    end

    @testset "style.typ template" begin
        # Check default template exists
        style_path, _ = BonitoBook.get_file_path(
            joinpath(dirname(pathof(BonitoBook)), "bbook"), "style.typ"
        )
        @test isfile(style_path)

        style = read(style_path, String)
        @test occursin("#set page", style)
        @test occursin("#set text", style)
        @test occursin("#set heading", style)
    end

    @testset "export_typst" begin
        # Create a minimal test book
        test_md = """
# Test Book

Some **bold** text and a code block:

```julia
x = 1 + 2
```

| Col A | Col B |
|-------|-------|
| 1     | 2     |
"""
        mktempdir() do tmpdir
            # Write test markdown
            md_path = joinpath(tmpdir, "test.md")
            write(md_path, test_md)

            # Create book from it
            book = BonitoBook.Book(md_path)

            # Export to Typst
            typ_path = joinpath(tmpdir, "output.typ")
            BonitoBook.export_typst(typ_path, book)
            @test isfile(typ_path)

            content = read(typ_path, String)
            # Should have style preamble
            @test occursin("#set page", content)
            # Should have content
            @test occursin("Test Book", content)
            @test occursin("#strong[bold]", content)
            @test occursin("```julia", content)
            @test occursin("#table", content)
        end
    end

    @testset "export_pdf" begin
        # Check Typst_jll is available
        typst_available = try
            using Typst_jll
            isfile(Typst_jll.typst_path)
        catch
            false
        end

        if typst_available
            test_md = "# PDF Test\n\nHello **world**.\n"
            mktempdir() do tmpdir
                md_path = joinpath(tmpdir, "test.md")
                write(md_path, test_md)

                book = BonitoBook.Book(md_path)

                pdf_path = joinpath(tmpdir, "output.pdf")
                BonitoBook.export_pdf(pdf_path, book)
                @test isfile(pdf_path)
                @test filesize(pdf_path) > 0

                # PDF magic bytes
                header = read(pdf_path, 4)
                @test header == UInt8['%', 'P', 'D', 'F']
            end
        else
            @warn "Skipping PDF export test - Typst_jll not available"
        end
    end
end
