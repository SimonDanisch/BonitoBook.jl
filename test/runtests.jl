using Test
using BonitoBook

examples_src = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))

# Work on a copy so we don't mutate the source examples
mktempdir() do path
    # Copy all example files (not hidden dirs) to temp
    for f in readdir(examples_src; join=true)
        name = basename(f)
        startswith(name, '.') && continue
        dest = joinpath(path, name)
        if isdir(f)
            cp(f, dest)
        else
            cp(f, dest)
        end
    end

    mktempdir() do temppath
        for f in readdir(path; join=true)
            if endswith(f, ".md")
                name = basename(splitext(f)[1])
                replace_style = name in ["book-example", "draggable_example", "slideshow_example"]
                b = BonitoBook.Book(f; replace_style=!replace_style)
                zip_path = joinpath(temppath, "$(name).zip")
                BonitoBook.export_zip(b, zip_path)
                b2 = BonitoBook.Book(zip_path)
                @test b2 isa Book
                rm(zip_path, force=true)
                rm(joinpath(path, name); force=true, recursive=true)
            end
        end
    end

    # Actually run all cells in the book!
    InlineBook(joinpath(path, "intro.md"))
    InlineBook(joinpath(path, "sunny.ipynb"))
    InlineBook(joinpath(path, "test.md"))

    @test isfile(joinpath(path, "test.md"))
    @test isdir(joinpath(path, ".test-bbook"))
    @test isdir(joinpath(path, ".test-bbook", "data"))
end

include("test_export_md_with_results.jl")
include("test_export_typst.jl")
