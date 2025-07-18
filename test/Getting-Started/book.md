# BonitoBook

Features of BonitBook

```julia
import Makie.SpecApi as S
@manipulate for vis in (
        scatter = visual(BoxPlot),
        violin = visual(Violin),
    )
    data(penguins) * visual(QQPlot) *
    mapping(:species, :bill_depth_mm, color=:sex, dodge=:sex)
end
```

```julia true false true
using AlgebraOfGraphics
penguins = AlgebraOfGraphics.penguins()
@manipulate for vis in (
        scatter = visual(BoxPlot),
        violin = visual(Violin),
    )
    p = data(penguins) * vis * mapping(:species, :bill_depth_mm, color=:sex, dodge=:sex)
    AlgebraOfGraphics.draw_to_spec(p)
end
```
```julia true true true
import Makie.SpecApi as S
funcs = (sqrt=sqrt, x_square=x->x^2, sin=sin, cos=cos)
colormaps = ["viridis", "heat", "blues"]
types = (scatter=S.Scatter, lines=S.Lines, linesegments=S.LineSegments)
sizes=10:0.1:100
checkbox = (true, false)
@manipulate for cmap=colormaps, func=funcs, Typ=types, size=sizes, show_legend=checkbox
    x = 0:0.3:10
    s = Typ == S.Scatter ? (; markersize=size) : (; linewidth=size)
    splot = Typ(x, func.(x); colormap=cmap, color=x, s...)
    ax = S.Axis(; plots=[splot])
    if show_legend
        cbar = S.Colorbar(splot)
        S.GridLayout([ax cbar])
    else
        S.GridLayout([ax])
    end
end
```
