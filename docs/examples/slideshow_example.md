# Interactive Data Visualization with Makie & Bonito

**Makie.jl** + **BonitoBook** = Interactive visualizations in your browser!

```julia (editor=true, logging=false, output=true)
using WGLMakie
set_theme!(size=(1000, 400))

x = range(0, 2π, length=50)
lines(x, sin.(x),
      axis=(xlabel="x", ylabel="sin(x)", title="Welcome to Makie!"),
      color=:steelblue, linewidth=3)
```
---

## Basic Plot Types

**Figure** and **Axis** are Makie's building blocks. Multiple plots in one figure:

```julia (editor=true, logging=false, output=true)
x = 1:20
y1 = x .+ 2 * randn(20)
y2 = 2 * x .+ randn(20)

fig = Figure()
scatter(fig[1, 1], x, y1,
        axis=(title="Scatter Plot",), color=:red, markersize=12)
lines(fig[1, 2], x, y2,
      axis=(title="Line Plot",), color=:blue, linewidth=3)
fig
```
---

## Statistical Visualizations

Histograms, densities, and time series:

```julia (editor=true, logging=false, output=true)
using Statistics, Distributions

data1 = randn(1000)
data2 = rand(Gamma(2, 1), 1000)

fig = Figure()
hist(fig[1, 1], data1, bins=30,
     axis=(title="Histogram",), color=(:steelblue, 0.7))
density(fig[1, 2], data2,
        axis=(title="Density",), color=(:orange, 0.6))

t = 1:100
values = cumsum(randn(100)) .+ 0.1 * t
ax, pl = lines(fig[2, 1:2], t, values,
                  axis=(title="Time Series",), color=:darkgreen)
scatter!(ax, t[1:5:end], values[1:5:end], color=:red, markersize=8)
fig
```
---

## Interactive 3D with WGLMakie

Click and drag to rotate, scroll to zoom!

```julia (editor=true, logging=false, output=true)
x = range(-3, 3, length=50)
y = range(-3, 3, length=50)
z = [sin(sqrt(x^2+y^2)) / sqrt(x^2+y^2) for x in x, y in y]

surface(x, y, z, colormap=:plasma)
```
---

## Themes & Styling

Apply themes and customize styling:

```julia (editor=true, logging=false, output=true)
set_theme!(theme_dark())

x = 0:0.1:4π
f, ax, l1 = lines(x, sin.(x), label="sin(x)",
                  axis=(title="Dark Theme", xlabel="x"),
                  color=:cyan, linewidth=3)
lines!(ax, x, cos.(x), label="cos(x)",
       color=:magenta, linewidth=3, linestyle=:dash)
axislegend(ax)
f
```
---

## Thank You!

**BonitoBook** + **Makie** = Interactive data visualization in your browser

  * Real-time code execution
  * Publication-quality plots
  * Interactive exploration

```julia (editor=true, logging=true, output=true)
set_theme!(size=(1000,400))

t = range(0, 20π, length=1000)
x = sin.(t) .* cos.(t/3)
y = cos.(t) .* sin.(t/2)

lines(x, y, color=t, colormap=:rainbow,
      axis=(;title="Thank You!"))
```
**Next:** Explore [docs.makie.org](https://docs.makie.org)

