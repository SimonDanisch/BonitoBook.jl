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

```julia (editor=true, logging=false, output=true)
import Makie.SpecApi as S
@manipulate for vis in (
        scatter = visual(BoxPlot),
        violin = visual(Violin),
    )
    data(penguins) * visual(QQPlot) *
    mapping(:species, :bill_depth_mm, color=:sex, dodge=:sex)
end
```
