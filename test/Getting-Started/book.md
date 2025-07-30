# BonitoBook

Features of BonitBook

```python true false true

```
```julia true false true
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
]st
```
```julia true false true
]st
```
```julia true false true
for i in 1:10 
    println("1+1")
end
```
