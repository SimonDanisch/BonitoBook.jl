using Test
using BonitoBook

path = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))
server = BonitoBook.book(joinpath(path, "intro.md"); replace_style=true)
BonitoBook.book(joinpath(path, "sunny.ipynb"))
# test new creation
BonitoBook.book(joinpath(path, "test.md"))
@test isfile(joinpath(path, "test.md"))
@test isdir(joinpath(path, ".test-bbook"))
@test isdir(joinpath(path, ".test-bbook", "data"))
rm(joinpath(path, "test.md"), force=true)
rm(joinpath(path, ".test-bbook"), force=true, recursive=true)
