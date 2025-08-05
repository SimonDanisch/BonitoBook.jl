# BonitoBook

BonitoBook is a Julia-native interactive notebook system built on [Bonito.jl](https://simondanisch.github.io/Bonito.jl/stable/) that combines multi-language execution, AI integration, and modern web-based editing.

# Getting started

```julia
using Pkg
Pkg.add("https://github.com/SimonDanisch/BonitoBook.jl/")
using BonitoBook
BonitoBook.book("path-to-notebook-file")
```

This will start a server which adds the notebook under the route "/notebook-name" and opens a browser with the url. For using the Display system, e.g. in another notebook or VSCode plotpane, one can directly display the notebook:

```julia
display(App(Book("path-to-notebook-file")))
```

Both run in the same Julia process as the parent, and therefore can also edit and re-eval any file there.

# Runs everywhere

Thanks to Bonito.jl, which was build to run anywhere, BonitoBook can be viewed in many ways:

  * VSCode Plot Pane
  * Browser
  * Electron applications
  * Static Site (e.g. this site via Bonito.jl, or Documenter).
  * Server deployments
  * HTML displays (Pluto, Jupyter, etc...)
  * [JuliaHub](https://github.com/SimonDanisch/BonitoBook.jl/blob/main/bin/main.jl)
  * [Google Colab](https://colab.research.google.com/drive/1Bux_x7wIaNBgXCD9NDqD_qmo_UMmtSR4?usp=sharing)

# Best Makie integration

It has been hard to fully support all features of WGLMakie in other notebook platforms for various reasons. With BonitoBook, this is changing. As the name suggest, it's based on Bonito.jl, which is also the framework used to implement WGLMakie. With this, all features like offline export, interactivity, observables and widgets are supported.

```julia (editor=false, logging=false, output=true)
# Create sliders for different parameters
time_slider = Components.Slider(1:360; value=1)
spiral_factor = Components.Slider(1:50; value=20)
explosion = Components.Slider(1:100; value=50)
markersize = Components.Slider(LinRange(0.08, 2.0, 100); value=0.08)

# Generate initial 3D galaxy data
n_points = 1000
radii = sqrt.(LinRange(0.1, 1, n_points)) * 8
angles = LinRange(0, 4π, n_points) .+ radii * 0.3

points = Point3f.(radii .* cos.(angles), radii .* sin.(angles), 0) .+ randn(Point3f, n_points) .* (Point3f(0.3, 0.3, 2),)

# Create figure and scatter plot
fig, ax, mplot = meshscatter(points;
    color=first.(points),
    markersize=markersize.value[],
    figure=(; backgroundcolor=:black),
    axis=(; show_axis=false)
)

jss = js"""
$(mplot).then(plots=>{
    const time = $(time_slider.value);
    const spiral = $(spiral_factor.value);
    const explosion = $(explosion.value);
    const markersize = $(markersize.value);

    const scatter_plot = plots[0];
    const plot = scatter_plot.plot_object;
    const initial_pos = $(points);
    console.log(initial_pos);

    // Function to generate galaxy positions
    function update_galaxy() {
        const time_val = time.value;
        const spiral_val = spiral.value;
        const explosion_val = explosion.value;
        const new_pos = [];
        const num_points = initial_pos.length;
        for (let i = 0; i < num_points; i++) {
            const idx = i * 3;
            const [x, y, z] = initial_pos[i];
            // Apply time rotation
            const angle = Math.atan2(y, x) + time_val * 0.02;
            const radius = Math.sqrt(x*x + y*y);
            // Apply spiral effect
            const spiralAngle = angle + radius * spiral_val * 0.05;
            // Apply explosion
            const scale = explosion_val / 50;
            new_pos.push(
                radius * Math.cos(spiralAngle) * scale,
                radius * Math.sin(spiralAngle) * scale,
                z * scale
            );
        }
        plot.update([['positions_transformed_f32c', new_pos]]);
    }
    // Update positions based on time slider
    time.on(update_galaxy);
    spiral.on(update_galaxy);
    explosion.on(update_galaxy);
    // Update marker size
    markersize.on(size => {
        plot.update([['markersize', [size, size, size]]]);
    });

});
"""

# Layout
DOM.div(
    DOM.div(
        style="display: flex; gap: 20px; align-items: center; justify-content: center; padding: 15px; background: #1a1a2e; border-radius: 10px; margin: 10px;",
        DOM.div([DOM.label("Time: ", style="color: white; margin-right: 5px;"), time_slider]),
        DOM.div([DOM.label("Spiral: ", style="color: white; margin-right: 5px;"), spiral_factor]),
        DOM.div([DOM.label("Explosion: ", style="color: white; margin-right: 5px;"), explosion]),
        DOM.div([DOM.label("Size: ", style="color: white; margin-right: 5px;"), markersize])
    ),
    fig, jss
)
```
## Folder structure

Each book creates a structured project with a hidden folder structure:

### For Markdown files (`.md`)

```
mybook.md                # Main content file
.mybook-bbook/           # Hidden folder structure
├── styles/
│   └── style.jl         # Custom styling
├── ai/
│   ├── config.toml      # AI configuration
│   └── system-prompt.md # Custom AI prompt
└── .versions/           # Automatic backups
    └── mybook-*.md      # Timestamped backups
└── data/             # Write out to `./data` to get included into the zip
    └── data.csv      # Any data needed for the notebook
```

For ipynb, notebooks are first converted to a markdown file with the same name and then that notebook is used.

### Project structure

Each book folder can contain additional files and multiple notebooks sharing the same environment, which means you can have notebooks next to your VSCode julia project:

```
myproject/
├── Project.toml        # Julia dependencies
├── Manifest.toml       # Dependency lock file
├── mybook.md           # Book content
├──── .mybook-bbook/    # Hidden book structure
├── another-book.md     # Another book with same project
├──── .another-bbook/
```

The zip export allows to zip everything into a reproducable, shareable archive, the project of the process that was used to run the notebook and with any data.

# Julia native

## All components written in Julia

BonitoBook is built entirely in Julia using Bonito.jl, providing native performance and seamless integration with the Julia ecosystem.

## Supports Julia commands

```julia
]add DataFrames CSV # Package management
?println # Documentation lookup
;ls -la # Shell commands
```

# Ecosystem of Components vs Notebook

## Easy to create new components in Julia

```julia (editor=true, logging=false, output=true)
struct MyCheckbox
    value::Observable{Bool}
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

```julia (editor=true, logging=false, output=true)
using BonitoBook
BonitoBook.EvalEditor("println(\"Hello World\")\n1+1")
```
## Simple to create new book types with different layouts

```julia (editor=true, logging=false, output=true)
# Properly Centered Row Example
using BonitoBook
using WGLMakie  # for Row

style = Styles(
    CSS(".small-vertical .cell-editor-container",
        "width" => "200px",
        "min-width" => "0px"
    ),
    CSS(".small-vertical .cell-editor", "width" => "200px"),
    CSS(".small-vertical",
        "margin-top" => "20px",
        "margin-bottom" => "20px",
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

Any package defining Bonito Apps are working inside BonitoBook. This includes custom widgets, or whole applications.

## BonitoBook.Components

BonitoBook comes with it's own Components, which are basically just the default Bonito components, but with a default style that integrates better with the book.

```julia (editor=true, logging=false, output=true)
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
### @manipulate

BonitoBook brings back the beloved `@manipulate` macro from [Interact.jl](https://github.com/JuliaGizmos/Interact.jl) in a modern way. It works pretty much the same way, albeit may have missing features or differences in detail. You can also manually create it with `ManipulateWidgets(Pair{Symbol, Any}[...], callback)`.

```julia (editor=true, logging=false, output=true)
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

Great LaTeX support via MathTex.

```latex
$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$

$$\mathbf{A} = \begin{pmatrix}
a_{11} & a_{12} \\
a_{21} & a_{22}
\end{pmatrix}$$
```

# Python integration

Python support comes via PythonCall and CondaPkg, allowing to manage dependencies just like in Julia. Also, the cells share the same process and variables, allowing for seamless interaction.

## Package management

```python (editor=true, logging=false, output=true)
]add numpy matplotlib pandas
```
## Shared namespace

With the shared namespace, it becomes trivial to e.g. use WGLMakie for plotting python results.

```python (editor=true, logging=false, output=true)
import numpy as np
data = np.random.randn(1000, 2)
labels = ["x", "y"]
```
```julia (editor=true, logging=false, output=true)
using WGLMakie
# Access Python variables directly in Julia
scatter(data[:, 1], data[:, 2], axis=(xlabel=labels[1], ylabel=labels[2]))
```
## Rich MIME support

PythonCall has implemented some basic MIME support. Because Bonito supports MIME's in it's rendering as well, this means e.g. matplotlib output works without any addentional work, making it possible ot use e.g. matplotlib directly to visualize Julia results. This is true for most other Julia plotting libraries.

```python (editor=true, logging=false, output=true)
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3, 4], [1, 4, 2, 3])
fig # Automatically displays in notebook
```
## Sidebar system

Collapsible sidebars for tools, file browser, chat, and custom widgets.  Configurable positioning and behavior.

## @edit and Revise.jl support

You can use @bedit in the notebook, to open and edit files, which, if you have loaded Revise, should get picked up and re-evaluated.

```julia
BonitoBook.@bedit Book("intro.md") # Opens function source in editor
```

## Style customization

Edit `.name-bbook/styles/style.jl` by pressing the paintcan icon to customize the books appearance:

```julia (editor=true, logging=false, output=true)
# Modify colors, fonts, layout dimensions
light_theme = true # Force light theme
editor_width = "800px" # Adjust editor width;
```
# Export/import options

## Import formats

  * Jupyter notebooks (.ipynb)
  * Markdown files (.md)

## Export formats

  * export to standalone HTML file
  * Markdown export
  * Quarto export
  * IPynb
  * PDF

