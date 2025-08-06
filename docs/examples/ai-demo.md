# New Book

```julia (editor=true, logging=false, output=true)
using WGLMakie, Bonito, Colors
import BonitoBook.Components

# 3D Saddle Surface
x = range(-2, 2, length=40)
y = range(-2, 2, length=40)
z = [xi^2 - yi^2 for xi in x, yi in y]

fig = Figure(size=(700, 500))
ax = Axis3(fig[1, 1], title="3D Saddle Surface", xlabel="X", ylabel="Y", zlabel="Z")
surface!(ax, x, y, z, colormap=:cool, shading=true)
fig
```
```julia (editor=true, logging=false, output=true)
# Interactive Rose Pattern Dashboard using BonitoBook.Components
# Create controls
size_slider = Components.Slider(10:5:100, value=50)
rotation_slider = Components.Slider(0:10:360, value=0)
color_dropdown = Components.Dropdown(["red", "blue", "green", "orange"], index=2)
show_grid = Components.Checkbox(true)

# Reactive scatter plot
scatter_data = map(size_slider.value, rotation_slider.value) do n, rot
    θ = range(0, 2π, length=n)
    r = 2 .+ 0.5 .* sin.(5 .* θ)
    x = r .* cos.(θ .+ deg2rad(rot))
    y = r .* sin.(θ .+ deg2rad(rot))
    return (x, y)
end

# Create plot
fig = Figure(size=(500, 400))
ax = Axis(fig[1, 1], title="Interactive Rose Pattern", aspect=DataAspect())

# Plot with reactive properties
scatter!(ax, 
    map(d -> d[1], scatter_data), 
    map(d -> d[2], scatter_data),
    color=map(color_dropdown.value) do c
        return c == "red" ? :red : c == "blue" ? :blue : c == "green" ? :green : :orange
    end,
    markersize=8
)

# Grid toggle
on(show_grid.value) do show
    ax.xgridvisible = show
    ax.ygridvisible = show
end

# Layout
controls = Components.Card(
    Col(
        DOM.h4("Pattern Controls", style=Styles(CSS("margin" => "0 0 15px 0", "text-align" => "center"))),
        DOM.div(DOM.label("Points: "), size_slider),
        DOM.div(DOM.label("Rotation: "), rotation_slider), 
        DOM.div(DOM.label("Color: "), color_dropdown),
        DOM.div(DOM.label("Show Grid: "), show_grid)
    ),
    padding="20px",
    backgroundcolor=RGBA(0.95, 0.95, 1.0, 1.0),
    border_radius="12px"
)

plot_card = Components.Card(
    fig,
    padding="15px",
    backgroundcolor=RGBA(1, 1, 1, 1.0),
    border_radius="12px"
)

Row(controls, plot_card, style=Styles(CSS("gap" => "20px", "padding" => "20px")))
```
