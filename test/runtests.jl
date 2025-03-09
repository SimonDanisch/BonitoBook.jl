using WGLMakie
using Kiri, Bonito
begin
    app = App(title="MakieBook") do s
        return Kiri.book(s, joinpath(@__DIR__, "test.md"))
    end
end
