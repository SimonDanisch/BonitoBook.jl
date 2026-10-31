# BonitoBook Demo

* Supports Markdown
* And latex:


```latex
\begin{aligned}
\cos 3\theta & = \cos (2 \theta + \theta) \\
& = \cos 2 \theta \cos \theta - \sin 2 \theta \sin \theta \\
& = (2 \cos ^2 \theta -1) \cos \theta - (2 \sin \theta\cos \theta ) \sin \theta \\
& = 2 \cos ^3 \theta - \cos \theta - 2 \sin ^2 \theta \cos \theta \\
& = 2 \cos ^3 \theta - \cos \theta - 2 (1 - \cos ^2 \theta )\cos \theta \\
& = 4 \cos ^3 \theta -3 \cos \theta
\end{aligned}
```

Makie support and Bonito dashboards are first class citizens:

```julia (editor=true, logging=true, output=false)
using WGLMakie, Bonito
colormaps = Dropdown(["viridis", "heat", "blues"])
funcs = Dropdown([sqrt, x->x^2, sin, cos])

ys = lift(funcs.value) do f
    f.(0:0.3:10)
end
f, ax, pl = scatter(ys, markersize=10, color=ys, colormap=colormaps.value)
cb = Colorbar(f[1, 2], pl)
on(funcs.value) do s
    autolimits!(ax)
end
DOM.div(funcs, colormaps, f)
```



## Support for any Bonito App from other Packages

```julia (editor=true, logging=true, output=false)
using NDViewer
layers = [
    Dict(
        "type" => "Axis",
        "position" => [1, 1],
        "plots" => [
            Dict(
                "type" => "image",
                "args" => [[1, 2]]
            )
        ]
    )
]

data = NDViewer.load_data("speedyweather.nc")
f = NDViewer.wgl_create_plot(data, layers)
```

# More latex

```latex
\begin{aligned}
\cos 3\theta & = \cos (2 \theta + \theta) \\
& = \cos 2 \theta \cos \theta - \sin 2 \theta \sin \theta \\
& = (2 \cos ^2 \theta -1) \cos \theta - (2 \sin \theta\cos \theta ) \sin \theta \\
& = 2 \cos ^3 \theta - \cos \theta - 2 \sin ^2 \theta \cos \theta \\
& = 2 \cos ^3 \theta - \cos \theta - 2 (1 - \cos ^2 \theta )\cos \theta \\
& = 4 \cos ^3 \theta -3 \cos \theta
\end{aligned}
```


```julia (editor=true, logging=true, output=false)
scatter(1:4)
```
