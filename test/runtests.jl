using WGLMakie
using BonitoBook, Bonito
begin
    app = App(title="MakieBook") do s
        return BonitoBook.book(s, joinpath(@__DIR__, "test.md"))
    end
end
