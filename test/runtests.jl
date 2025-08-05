using BonitoBook

path = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))
BonitoBook.book(joinpath(path, "intro.md"); replace_style=true)
BonitoBook.book(joinpath(path, "sunny.md"))
BonitoBook.book(joinpath(path, "juliacon25.md"))
