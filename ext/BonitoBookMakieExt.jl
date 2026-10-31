module BonitoBookMakieExt

using BonitoBook
using Bonito
using Makie

function BonitoBook._MakieModule()
    return Makie
end

function Bonito.jsrender(s::Bonito.Session, value::Makie.GridLayoutSpec)
    f, ax, pl = plot(value)
    return Bonito.jsrender(s, f)
end

function Bonito.jsrender(s::Bonito.Session, value::Observable{Makie.GridLayoutSpec})
    f, ax, pl = plot(value)
    return Bonito.jsrender(s, f)
end


end
