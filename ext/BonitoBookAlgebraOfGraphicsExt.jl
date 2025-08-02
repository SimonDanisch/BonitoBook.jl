module BonitoBookAlgebraOfGraphicsExt

using BonitoBook
using AlgebraOfGraphics
using Bonito
using Observables
using Makie

function Bonito.jsrender(s::Bonito.Session, value::AlgebraOfGraphics.Layers)
    spec = AlgebraOfGraphics.draw_to_spec(value)
    f, ax, pl = plot(spec)
    return Bonito.jsrender(s, f)
end

function Bonito.jsrender(s::Bonito.Session, value::AlgebraOfGraphics.FigureGrid)
    return Bonito.jsrender(s, value.figure)
end

function Bonito.jsrender(s::Bonito.Session, value::Observable{AlgebraOfGraphics.Layers})
    spec_obs = map(AlgebraOfGraphics.draw_to_spec, value)
    return Bonito.jsrender(s, spec_obs)
end


end
