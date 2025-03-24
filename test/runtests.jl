using WGLMakie
using BonitoBook, Bonito


app = App(title="BonitoBook") do s
    return BonitoBook.book(s, joinpath(@__DIR__, "Sunny/01_LSWT_CoRh2O4.ipynb"))
end

app = App(title="BonitoBook") do s
    return BonitoBook.book(s, joinpath(pwd(), "book.md"))
end
# TODO
#=
- [x] cleanup hover menu + delete
* global IO redirect
* AoG demo
* saving + versioning
* folder
* export
* display + plugins
=#


using Makie.SpecApi as S
@manipulate for vis = (
        contour=visual(Contour),
        scatter=visual(Scatter),
        violin=visual(Violin)
    )
    layer = AlgebraOfGraphics.density() * vis
    penguin_bill *  mapping(; color = :species)
end

using BonitoBook: Cell
using JSON
using Markdown
mm = md"$g$"
using Sunny, WGLMakie
units = Units(:meV, :angstrom);
a = 8.5031 # (Å)
latvecs = lattice_vectors(a, a, a, 90, 90, 90)
positions = [[1/8, 1/8, 1/8]]
cryst = Crystal(latvecs, positions, 227; types=["Co"])
sys = System(cryst, [1 => Moment(s=3/2, g=2)], :dipole)
J = +0.63 # (meV)
set_exchange!(sys, J, Bond(2, 3, [0, 0, 0]))
view_crystal(sys)
randomize_spins!(sys)
minimize_energy!(sys)
plot_spins(sys; color=[S[3] for S in sys.dipoles])
using GeometryBasics

f = QuadFace{Int64}(1,2,3,4) # Some face
indicesOther = f .!= 3
@edit f[indicesOther]

V = Point{3, Float64}[[-1.0, -1.0, -1.0], [-1.0, 1.0, -1.0], [1.0, 1.0, -1.0], [1.0, -1.0, -1.0]]
f = QuadFace{Int64}(1,2,3,4)
@edit V[f]
