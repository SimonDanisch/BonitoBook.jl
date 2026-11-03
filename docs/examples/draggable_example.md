```julia (editor=true, logging=false, output=true, id=1)
# First Julia cell - click and drag to move around
using WGLMakie
x = 1:10
y = x.^2
fig = Figure(size=(400, 300))
ax = Axis(fig[1, 1], xlabel="x", ylabel="y", title="Quadratic Function")
lines!(ax, x, y, linewidth=3, color=:blue)
scatter!(ax, x, y, color=:red, markersize=8)
fig
```
```julia (editor=true, logging=false, output=true, id=2)
# Second Julia cell - also draggable
using WGLMakie, Statistics
data = randn(100)
fig = Figure(size=(400, 300))
ax = Axis(fig[1, 1], xlabel="Value", ylabel="Frequency", title="Random Data Distribution")
hist!(ax, data, bins=20, color=(:blue, 0.7), strokewidth=1, strokecolor=:black)
fig
```
```julia (editor=true, logging=false, output=true, id=3)
# Interactive drawing canvas - also draggable!
DraggableBooks.DrawingWidget(200, 200)
```
