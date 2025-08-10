using Test
using BonitoBook

path = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))
server = BonitoBook.book(joinpath(path, "intro.md"); replace_style=true, openbrowser=false)
BonitoBook.book(joinpath(path, "sunny.ipynb"); openbrowser=false)
# test new creation
BonitoBook.book(joinpath(path, "test.md"); openbrowser=false)

# Actually run all cells!
InlineBook(joinpath(path, "intro.md"), replace_style=true)
InlineBook(joinpath(path, "sunny.ipynb"), replace_style=true)
InlineBook(joinpath(path, "test.md"), replace_style=true)

@test isfile(joinpath(path, "test.md"))
@test isdir(joinpath(path, ".test-bbook"))
@test isdir(joinpath(path, ".test-bbook", "data"))

# Clean up
rm(joinpath(path, "test.md"), force=true)
rm(joinpath(path, ".test-bbook"), force=true, recursive=true)

# Include detailed book_display function tests
include("test_book_display.jl")
