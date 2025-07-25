# BonitoBook Overview

BonitoBook is a Julia-native interactive notebook system built on Bonito.jl that combines multi-language execution, AI integration, and modern web-based editing.

# Runs everywhere

  * VSCode Plot Pane
  * Browser
  * Server deployments
  * HTML displays (Documenter, Pluto)
  * Electron applications
  * JuliaHub
  * Google Colab

# Best Makie integration

```julia true false true
# Interactive 3D Visualization with LScene
using WGLMakie

# Create a beautiful wavy 3D surface
n = 80
x = range(-3, 3, length=n)
y = range(-3, 3, length=n)

# Mathematical surface with interesting topology
z = [sin(sqrt(xi^2 + yi^2)) * exp(-0.2 * sqrt(xi^2 + yi^2)) + 
     0.4 * cos(2*xi) * sin(2*yi) for xi in x, yi in y]

# Create the interactive 3D scene
fig = Figure(size=(700, 600))
lscene = LScene(fig[1, 1], show_axis=false)

# Add the surface with vibrant colors
surface!(lscene, x, y, z, 
         colormap=:plasma, 
         shading=NoShading)

# Add some 3D scatter points for extra visual interest
n_points = 200
scatter_x = 6 * (rand(n_points) .- 0.5)
scatter_y = 6 * (rand(n_points) .- 0.5) 
scatter_z = 2 * (rand(n_points) .- 0.5)

scatter!(lscene, scatter_x, scatter_y, scatter_z,
         color=scatter_z,
         colormap=:turbo,
         markersize=8,
         transparency=true)

fig

```
# Julia native

## All components written in Julia

BonitoBook is built entirely in Julia using Bonito.jl, providing native performance and seamless integration with the Julia ecosystem.

## Supports Julia commands

```julia true false true
]add DataFrames CSV # Package management
?println # Documentation lookup
;ls -la # Shell commands
```
# Ecosystem of Components vs Notebook

## Easy to create new components in Julia

```julia true false true
struct MyCheckbox
    value::Observable{Bool}
end

function MyCheckbox(default_value::Bool)
    return MyCheckbox(Observable(default_value))
end

function Bonito.jsrender(session::Session, checkbox::MyCheckbox)
    return Bonito.jsrender(
        session,
        DOM.input(;
            type="checkbox",
            checked=checkbox.value,
            onchange=js"event=> $(checkbox.value).notify(event.srcElement.checked);",
        ),
    )
end
MyCheckbox(true)
```
## All components work standalone and can be reused

```julia true false true
using BonitoBook
BonitoBook.EvalEditor("println(\"Hello World\")\n1+1")
```
## Simple to create new book types with different layouts

```julia true false true
# Properly Centered Row Example
using BonitoBook
using WGLMakie  # for Row

style = Styles( 
    CSS(".small-vertical .cell-editor-container",
        "width" => "200px !important",
        "min-width" => "0px !important"
    ),
    CSS(".small-vertical .cell-editor",
        "width" => "200px !important"),
    CSS(".small-vertical",
        "margin-top" => "20px",
        "margin-bottom" => "20px",
        "width" => "100%"
    )
)

# Create the properly centered Row
DOM.div(
    style,
    Centered(Row(
        BonitoBook.CellEditor("1+1", "julia", nothing), 
        BonitoBook.CellEditor("1+2", "julia", nothing),
        width="fit-content",
        gap="50px"
    )); 
    class="small-vertical"
)

```
## Full composability with existing Bonito apps

```julia true false true
using BonitoBook, Bonito
# Embed book components in larger applications
app = App() do
    DOM.div(
        book.global_logging_widget,
        Row(book.cells...)
    )
end
```
## Default components

### BonitoBook.Components

```julia true false true
# Create one of each component type
button = Components.Button("Submit")
slider = Components.Slider(1:100, value=50)
checkbox = Components.Checkbox(true)
dropdown = Components.Dropdown(["Option 1", "Option 2", "Option 3"], value="Option 2")
number_input = Components.NumberInput(42.0)

# Create clean layout with proper Styles
DOM.div(
    style=Styles("max-width" => "600px", "margin" => "20px auto", "padding" => "20px"),
    DOM.div(
        DOM.h3("Button"),
        button,
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Slider"),
        DOM.p("Range: 1-100, Value: 50"),
        slider,
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Checkbox"),
        DOM.div(checkbox, " Enabled", style=Styles("display" => "flex", "align-items" => "center")),
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Dropdown"),
        dropdown,
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Number Input"),
        number_input,
        style=Styles("margin-bottom" => "20px")
    )
)

```
## Bonito widgets

Bonito widgets are great, but don't nicely interact with the BonitoBook theme:

```julia true false true
# Create one of each component type
button = Bonito.Button("Submit")
slider = Bonito.Slider(1:100, value=50)
checkbox = Bonito.Checkbox(true)
dropdown = Bonito.Dropdown(["Option 1", "Option 2", "Option 3"], value="Option 2")
number_input = Bonito.NumberInput(42.0)

# Create clean layout with proper Styles
DOM.div(
    style=Styles("max-width" => "600px", "margin" => "20px auto", "padding" => "20px"),
    DOM.div(
        DOM.h3("Button"),
        button,
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Slider"),
        DOM.p("Range: 1-100, Value: 50"),
        slider,
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Checkbox"),
        DOM.div(checkbox, " Enabled", style=Styles("display" => "flex", "align-items" => "center")),
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Dropdown"),
        dropdown,
        style=Styles("margin-bottom" => "20px")
    ),
    DOM.div(
        DOM.h3("Number Input"),
        number_input,
        style=Styles("margin-bottom" => "20px")
    )
)

```
### @manipulate

```julia true false true
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
### LaTeX support

```latex
$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$

$$\mathbf{A} = \begin{pmatrix}
a_{11} & a_{12} \\
a_{21} & a_{22}
\end{pmatrix}$$
```

# Python integration

## Package management

```python true false true
]add numpy matplotlib pandas # Install Python packages via Conda
```
## Shared namespace

```python true false true
import numpy as np
data = np.random.randn(1000, 2)
labels = ["x", "y"]
```
```julia true false true
using WGLMakie
# Access Python variables directly in Julia
scatter(data[:, 1], data[:, 2], axis=(xlabel=labels[1], ylabel=labels[2]))
```
## Rich MIME support

```python true false true
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3, 4], [1, 4, 2, 3])
fig # Automatically displays in notebook
```
# Claude Code integration

BonitoBook includes first-class integration with Claude via the Claude Code CLI:

  * **MCP Server**: Julia RPC server for tool access
  * **File operations**: Claude can read/write project files
  * **Code execution**: Claude can run cells and see results
  * **Chat interface**: Built-in chat sidebar with image support

Example books demonstrating Claude integration:

  * `examples/juliacon25.md` - JuliaCon 25 video subtitle analysis
  * `examples/mario.md` - Interactive game
  * `examples/penguins.md` - Data analysis

# File editor included

## Integrated Monaco editor

  * Syntax highlighting for Julia, Python, Markdown, JSON, TOML
  * Code completion
  * Find/replace functionality
  * Multiple theme support (auto/light/dark)

## @edit compatibility

```julia true false true
@edit println("hello") # Opens function source in editor
```
## Revise.jl integration

Changes from e.g. `@edit` are automatically applied.

## Style customization

Edit `styles/style.jl` by pressing the paintcan icon to customize appearance:

```julia true false true
# Modify colors, fonts, layout dimensions
light_theme = true # Force light theme
editor_width = "800px" # Adjust editor width
```
# Export/import options

## Import formats

### Jupyter notebooks (.ipynb)

```julia true false true
book = Book("notebook.ipynb")
# Preserves cell metadata, outputs, and structure
```
### Markdown files (.md)

```julia true false true
book = Book("document.md")
# Converts code blocks to executable cells
# Supports cell visibility metadata:
# ```julia true false true
# # show_editor show_logging show_output
```
## Export formats

### HTML export

```julia true false true
export_html("mybook.html", book)
# Creates standalone HTML with embedded assets
# Preserves interactivity where possible
```
### Markdown export

```julia true false true
export_md("output.md", book)
# Maintains cell metadata and structure
# Compatible with re-import
```
### Julia script export

```julia true false true
export_jl("script.jl", book)
# Converts to plain Julia file
# Strips notebook metadata
```
## Folder structure

Each book creates a structured project:

```
mybook/
├── Project.toml         # Julia dependencies
├── Manifest.toml        # Dependency lock file
├── book.md              # Main content
├── styles/style.jl      # Custom styling
├── ai/
│   ├── config.toml      # AI configuration
│   └── system-prompt.md # Custom AI prompt
├── data/               # Data files
└── .versions/          # Automatic backups
```

This folder can be zipped and shared with all data, settings and style. With Project.toml and Manifest being part of the format, each notebook is reproducable.

# Advanced features

## Multi-language cells

Books support mixing Julia, Python, and Markdown cells seamlessly with shared variable namespaces.

## Asynchronous execution

Code runs in background threads without blocking the UI. Multiple cells can execute concurrently.

## Automatic backups

All changes are automatically saved to `.versions/` with timestamps for version recovery.

## Responsive design

UI adapts to different screen sizes and orientations. Works on desktop, tablet, and mobile browsers.

## Theme system

Automatic dark/light mode detection with manual override support. Consistent theming across all components.

## Sidebar system

Collapsible sidebars for tools, file browser, chat, and custom widgets. Configurable positioning and behavior.

## Live reloading

Files are watched for changes and automatically reloaded. Useful for development workflows with external editors.

