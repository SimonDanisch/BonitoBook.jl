using WGLMakie
using BonitoBook, Bonito
using PythonCall
rm(BonitoBook.Monaco.bundle_file)
rm(joinpath("dev", "BonitoBook", "test", "Sunny", "01_LSWT_CoRh2O4"), recursive = true, force = true)

app = App(title = "BonitoBook") do s
    return Book(joinpath("dev", "BonitoBook", "test", "Sunny/01_LSWT_CoRh2O4.ipynb"))
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
