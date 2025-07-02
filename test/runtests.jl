using Revise
using WGLMakie
using BonitoBook, Bonito
using PythonCall
rm(BonitoBook.Monaco.bundle_file)
rm(joinpath("dev", "BonitoBook", "test", "Sunny", "01_LSWT_CoRh2O4"), recursive=true, force=true)

app = App(title="BonitoBook") do s
    return Book(joinpath("dev", "BonitoBook", "test", "Sunny/01_LSWT_CoRh2O4.ipynb"));
end

getfield(BonitoBook, Symbol("#502"))

BonitoBook.var"#502#505" |> methods
cd(dirname(file)) do
    Base.include_string(m, "println(@__source__)", file)
end

bookfile, folder, style_paths = BonitoBook.from_file(joinpath(@__DIR__, "Sunny/01_LSWT_CoRh2O4.ipynb"), "./Sunny/Test")
runner = BonitoBook.AsyncRunner()
style_editor = BonitoBook.FileEditor(style_paths, runner; editor_classes = ["styling file-editor"], show_editor = false)


BonitoBook.run!(style_editor.editor)
style_editor.current_file
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
