# BonitoBook Quickstart

This quickstart guide will walk you through the basics of using BonitoBook.

## Creating Cells

You can create Julia cells:

```julia
println("Hello from BonitoBook!")
```

And Markdown cells to document your work:

```markdown
# My Analysis

This is a **markdown** cell with *formatting*.
```

## Interactive Widgets

BonitoBook supports interactive widgets:

```julia
using BonitoBook.Bonito

slider = DOM.input(type="range", min=1, max=100, value=50)
output = DOM.div("Value: 50")

on(slider) do event
    output.content[] = "Value: $(event.target.value)"
end

DOM.div(slider, output)
```

## Plotting

You can create beautiful plots with Makie:

```julia
using WGLMakie

x = range(0, 2π, 100)
y = sin.(x)

lines(x, y, axis=(title="Sine Wave",))
```

## AI Assistance

Press `Ctrl+L` to open the AI assistant and get help with your code!