# Test-ooo

* potat-ooo
* coooolaaaa


```julia
using WGLMakie, Bonito
m = Bonito.Slider(1:100)
```
```julia
scatter(1:5, markersize=m)
```

## PLOT THE CAT

```julia
using WGLMakie, FileIO
catmesh = load(assetpath("cat.obj"))
mesh(catmesh, color=load(assetpath("diffusemap.png")))
```

## Plot something else

```julia
scatter(1:4)
```
