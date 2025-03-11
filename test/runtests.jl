using WGLMakie
using BonitoBook, Bonito
app = App(title="BonitoBook") do s
    return BonitoBook.book(s, joinpath(@__DIR__, "test.md"))
end
