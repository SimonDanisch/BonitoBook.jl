using WGLMakie
using BonitoBook, Bonito
using PythonCall, Observables
rm(BonitoBook.Monaco.bundle_file)
rm(joinpath("dev", "BonitoBook", "test", "Sunny", "01_LSWT_CoRh2O4"), recursive = true, force = true)

begin
    close(app.session[])
    app = App(title = "BonitoBook") do s
        return Book(joinpath(@__DIR__, "Sunny", "01_LSWT_CoRh2O4.ipynb"))
    end
end
1235
xx = Bonito.root_session(app.session.x).session_objects["1235"]

app = App(title = "BonitoBook") do s
    return Book(joinpath(@__DIR__, "Getting-Started.md"))
end
app = App(title = "BonitoBook") do s
    return BonitoBook.PopUp(DOM.div(Observable(DOM.div("heyyy"))))
end

App() do
    x = BonitoBook.OpenFileDialog()
    on(x.file_selected) do file
        @show file
    end
    DOM.div(x)
end
using WGLMakie
using BonitoBook, Bonito, WGLMakie
styles = include("../src/templates/style.jl")
app = App() do
    DOM.div(styles, BonitoBook.FileTabs(["file1.txt", "file2.txt", "file3.txt"]))
end
# TODO
#=
- [x] cleanup hover menu + delete
* saving + versioning
* global IO redirect
* display + plugins
* export
* AoG demo
* folder
=#

import Makie.SpecApi as S
@manipulate for vis in (
        contour = visual(Contour),
        scatter = visual(Scatter),
        violin = visual(Violin),
    )
    layer = AlgebraOfGraphics.density() * vis
    penguin_bill * mapping(; color = :species)
end
