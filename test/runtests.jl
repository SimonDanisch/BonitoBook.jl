using WGLMakie
using BonitoBook, Bonito

app = App(title="BonitoBook") do s
    return Book(joinpath(@__DIR__, "Sunny/01_LSWT_CoRh2O4.ipynb"));
end

BonitoBook.from_file(joinpath(@__DIR__, "Sunny/01_LSWT_CoRh2O4.ipynb"), nothing)
book = joinpath(@__DIR__, "Sunny/01_LSWT_CoRh2O4.ipynb")
name, ext = splitext(book)
if !(ext in (".md", ".ipynb"))
    error("File $book is not a markdown or ipynb file: $(ext)")
end
folder = joinpath(dirname(book), name)
if isdir(folder)
    from_folder(folder)
else
    mkpath(folder)
end
app = App(title="BonitoBook") do s
    return Book(joinpath(@__DIR__, "test.md"))
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
