using PromptingTools
using BonitoBook

path = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))
server = BonitoBook.book(joinpath(path, "intro.md"); replace_style=true)
BonitoBook.book(joinpath(path, "sunny.ipynb"))
b = BonitoBook.Book(joinpath(path, "sunny.ipynb"))

BonitoBook.create_claude_agent(b)
