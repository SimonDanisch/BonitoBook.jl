# Getting Started

BonitoBook is a Julia-native interactive notebook system built on [Bonito.jl](https://simondanisch.github.io/Bonito.jl/stable/) that seamlessly combines multi-language execution, AI integration, and modern web-based editing in one powerful platform.

# Installation

```julia
using Pkg
Pkg.add(url="https://github.com/SimonDanisch/BonitoBook.jl/")
using BonitoBook
BonitoBook.book("path-to-notebook-file") # existing book
BonitoBook.book("new-book.md") # Create a new book under that file
```

This starts a server that hosts the notebook under the route "/notebook-name" and automatically opens it in your browser. You can also display the notebook directly in other environments like VSCode's plot pane:

```julia
display(App(()-> Book("path-to-notebook-file")))
```

Both methods run in the same Julia process as the parent, allowing you to edit and re-evaluate any file seamlessly.

# Motivation

As the author of [Makie.jl](www.makie.org), I've faced challenges integrating its advanced features—like offline export, widgets, and interactions—across different notebook platforms in a stable and efficient way.

Over the years, as [Bonito.jl](https://simondanisch.github.io/Bonito.jl/stable/) (the Julia framework for creating HTML/JavaScript in Julia) has matured, I decided to build a completely Julia-native notebook system with a sharp focus on plotting and dashboards.

Bonito.jl brings significant advantages: all widgets are reusable, and notebooks can be easily rearranged into different formats, making the transition from notebook to polished dashboard effortless.

Another big motivation was to have a simple markdown file format which is human readable and can be checked into git without problems, so one doesn't even need to edit the notebook with bonitobook.

# Comparison to Pluto

I love the team behind Pluto and the attention to detail that has been put into it, but Pluto itself has never appealed to me.  The Pkg integration and reactive workflow isn't working for me and that most of Pluto is implemented in Javascript instead of Julia doesn't fit my approach of "ecosystem first, notebook second" which I imagine for BonitoBook.

The final issue is, that the Makie integration has stalled - you can use Makie in Pluto, but WGLMakie isn't working as well as it could due to several reasons.

On the positive side, I think there's lots to share, we've been wanting to create a shared websocket serialization implementation and it should actually be easy to bring Pluto's reactive execution model to BonitoBook thanks to Pluto's modular approach in that regard.

# Runs everywhere

Thanks to Bonito.jl's universal design, BonitoBook can be viewed across multiple platforms:

  * VSCode Plot Pane
  * Browser
  * Electron applications
  * Static Site (e.g. this site via Bonito.jl, or Documenter).
  * Server deployments
  * HTML displays (Pluto, Jupyter, etc...)
  * [JuliaHub](https://github.com/SimonDanisch/BonitoBook.jl/blob/main/bin/main.jl)
  * [Google Colab](https://colab.research.google.com/drive/1Bux_x7wIaNBgXCD9NDqD_qmo_UMmtSR4?usp=sharing)

# Plotting with Makie

Since WGLMakie is also based on Bonito.jl, the Makie integration is seamless and supports all WGLMakie features including interactive widgets, observables and JavaScript integration. Here's a live example of an interactive 3D galaxy visualization, with the animation done in Javascript so it stays interactive without running Julia. The other plots shown in this notebook are not interactive in that way, and can only be interacted with when actually running the notebook with Julia.

```julia (editor=true, logging=true, output=true)
using WGLMakie
# Interactive 3D galaxy with real-time JavaScript integration
time_slider = Components.Slider(1:360; value=1)
spiral_factor = Components.Slider(1:50; value=20)
explosion = Components.Slider(1:100; value=50)
markersize = Components.Slider(LinRange(0.08, 2.0, 100); value=0.08)

# Generate 3D galaxy data
n_points = 1000
radii = sqrt.(LinRange(0.1, 1, n_points)) * 8
angles = LinRange(0, 4π, n_points) .+ radii * 0.3
points = Point3f.(radii .* cos.(angles), radii .* sin.(angles), 0) .+ randn(Point3f, n_points) .* (Point3f(0.3, 0.3, 2),)

fig, ax, mplot = meshscatter(points;
    color=first.(points), markersize=markersize.value[],
    figure=(; backgroundcolor=:black), axis=(; show_axis=false)
)

# Direct JavaScript integration with Julia observables
jss = js"""
$(mplot).then(plots=>{
    const time = $(time_slider.value);
    const spiral = $(spiral_factor.value);
    const explosion = $(explosion.value);
    const markersize = $(markersize.value);
    const plot = plots[0].plot_object;
    const initial_pos = $(points);

    function update_galaxy() {
        const new_pos = [];
        for (let i = 0; i < initial_pos.length; i++) {
            const [x, y, z] = initial_pos[i];
            const angle = Math.atan2(y, x) + time.value * 0.02;
            const radius = Math.sqrt(x*x + y*y);
            const spiralAngle = angle + radius * spiral.value * 0.05;
            const scale = explosion.value / 50;
            new_pos.push(
                radius * Math.cos(spiralAngle) * scale,
                radius * Math.sin(spiralAngle) * scale, z * scale
            );
        }
        plot.update([['positions_transformed_f32c', new_pos]]);
    }

    [time, spiral, explosion].forEach(obs => obs.on(update_galaxy));
    markersize.on(size => plot.update([['markersize', [size, size, size]]]));
});
"""

DOM.div(
    Grid(
        ["Time: ", time_slider],
        ["Spiral: ", spiral_factor],
        ["Explosion: ", explosion],
        ["Size: ", markersize];
        columns="auto 1fr", gap="10px 20px"
    ),
    fig, jss;
    style=Styles("padding" => "20px")
)
```
## Notebook format

The format is a simple markdown file with more config options and data stored in a separate folder. This keeps the notebook format fully compatible with markdown and makes it easy to edit it with other editors.

The hidden folder structure looks like this:

```
mybook.md                # Main content file
.mybook-bbook/           # Hidden folder structure (or .bbook/ for shared)
├── style.jl             # Custom styling (lazy-loaded from template)
├── ai/                  # AI configs (lazy-loaded from template)
│   ├── claude-config.toml
│   ├── claude-system-prompt.md
│   ├── promptingtools-config.toml
│   └── promptingtools-system-prompt.md
├── data/                # Store data files here
│   └── data.csv
├── meta.toml            # Version tracking (auto-created)
└── .versions/           # Automatic backups
    └── mybook-*.md      # Timestamped backups
```

Jupyter notebooks (.ipynb) are automatically converted to markdown files with the same name before setting up the notebook and creating the folderer structure.

**Note:** Files are only created when edited. Until then, they're loaded from BonitoBook templates.

### Accessing data files

Use the `data""` string macro to reference files in your notebook's data folder:

```julia
# Load a CSV file from the data folder
using CSV, DataFrames
df = CSV.read(data"data.csv", DataFrame)

# Display an image
DOM.img(src=Asset(data"plot.png"))

# Load a video
DOM.video(src=Asset(data"demo.mp4"), autoplay=true, loop=true)
```

The `data""` macro automatically resolves to the correct path in `.mybook-bbook/data/`, regardless of your working directory. All files in the data folder are included when exporting to ZIP.

### Project compatibility

The parent folder of a notebook can contain additional files like a Julia project. This allows that multiple notebooks can share the same environment, which makes it perfect for integrating with your existing VSCode Julia projects and running a notebook alongside a VSCode setup:

```
MyJuliaProject/
├── dev/                # Any Julia package checked out for development
├── Project.toml        # Julia dependencies
├── Manifest.toml       # Dependency lock file
├── mybook.md           # Book file
├──── .mybook-bbook/    # Hidden book structure
├── another-book.md     # Another book using the same project
├──── .another-bbook/
```

The zip export feature packages everything into a reproducible, shareable archive including the project environment and all associated data, which can be directly loaded by using `book("path/to/zipfile")`.

## AI Integration

The current implementation is based on a generic chat, which can use different chat agents to talk with. Those agents are currently installed as Package extensions on [ClaudeCodeSDK](https://github.com/AtelierArith/ClaudeCodeSDK.jl/) and on [PromptingTools](https://github.com/svilupp/PromptingTools.jl). Install those and use them, to activate them. By default, if both are loaded, Claude Code is preferred, since the integration is better and the agentic features are just more mature.

```julia (editor=false, logging=false, output=true)
DOM.video(src=Asset(data"ai-demo.mp4"), autoplay=true, loop=true, muted=true,
    style=Styles("width" => "100%"))
```
## Supports the common commandline modes

```julia
]add DataFrames CSV # Package management
?println # Documentation lookup
;ls -la # Shell commands
```

# Julia native ecosystem

BonitoBook is built entirely in Julia using Bonito.jl, providing native performance and seamless integration with the Julia ecosystem.

With Bonito it's easy to [create and share components](https://simondanisch.github.io/Bonito.jl/stable/components.html).  All BonitoBook components can be used outside the notebook, which will further extend the Bonito ecosystem for building interactive web applications Here is a quick example how one can make a simple checkbox widget in Bonito:

```julia (editor=true, logging=true, output=true)
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
```
Note, you can include any css or javascript dependency in your widgets and Bonito will make sure they'll get included only once.

This is why we can e.g. use the editor widget in the notebook itself:

```julia (editor=true, logging=true, output=true)
using BonitoBook
BonitoBook.EvalEditor("println(\"Hello World\")\n1+1")
```
And why we can easily re-arrange any notebook into a completely different layout/form:

```julia (editor=true, logging=true, output=true)
style = Styles(
    CSS(".small-vertical .cell-editor-container",
        "width" => "250px",
    ),
    CSS(".small-vertical .monaco-editor-div", "width" => "250px"),
    CSS(".small-vertical",
        "overflow" => "hidden",
        "padding" => "10px",
    )
)
# Load notebook we shipped in the data folder
cells = Book(data"test.md"; all_blocks_as_cell=true).cells
# Execute code in the cell
foreach(x-> BonitoBook.run_sync!(x.editor), cells)
DOM.div(
    style,
    Row(cells...);
    class="small-vertical"
)
```
## Full composability with existing Bonito apps

Any package defining Bonito Apps are working inside BonitoBook. This includes custom widgets, or whole applications.

## BonitoBook.Components

BonitoBook includes its own component library—essentially the standard Bonito components with enhanced styling that integrates seamlessly with the notebook interface.

```julia (editor=true, logging=true, output=true)
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
## @manipulate

BonitoBook revives the beloved `@manipulate` macro from [Interact.jl](https://github.com/JuliaGizmos/Interact.jl) with modern enhancements. It works great together with Makie's SpecApi, which is the [new declarative API](https://docs.makie.org/stable/explanations/specapi#SpecApi) for Makie.

```julia (editor=true, logging=true, output=true)
import Makie.SpecApi as S
@manipulate for cmap=["viridis", "heat", "blues"],
                func=(sqrt=sqrt, square=x->x^2, sin=sin, cos=cos),
                plot_type=(scatter=S.Scatter, lines=S.Lines, segments=S.LineSegments),
                size=10:0.1:100,
                show_legend=(true, false)
    x = 0:0.3:10
    style = plot_type == S.Scatter ? (; markersize=size) : (; linewidth=size)
    plot = plot_type(x, func.(x); colormap=cmap, color=x, style...)
    if show_legend
        S.GridLayout([S.Axis(; plots=[plot]) S.Colorbar(plot)])
    else
        S.GridLayout([S.Axis(; plots=[plot])])
    end
end
```
## LaTeX support

Excellent LaTeX support powered by KaTeX.

```latex
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}

\mathbf{A} = \begin{pmatrix}
a_{11} & a_{12} \\
a_{21} & a_{22}
\end{pmatrix}
```

# Python integration

Python support is powered by PythonCall and CondaPkg, enabling Julia-like dependency management. Cells share the same process and variables, creating seamless cross-language interaction.

## Package management

```python (editor=true, logging=true, output=true)
]add numpy matplotlib pandas
```
## Shared namespace

The shared namespace enables seamless cross-language workflows:

```python (editor=true, logging=true, output=true)
import numpy as np
data = np.random.randn(1000, 2)  # Generate data in Python
labels = ["x", "y"]
```
```julia (editor=true, logging=true, output=true)
# Directly use Python variables in Julia with full Makie features
scatter(data[:, 1], data[:, 2], axis=(xlabel=labels[1], ylabel=labels[2]))
```
## Rich MIME support

MIME support enables matplotlib plots to display automatically, perfect for mixed-language visualizations:

```python (editor=true, logging=true, output=true)
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3, 4], [1, 4, 2, 3])
fig # Automatically displays in notebook
```
## Sidebar system

Features collapsible sidebars for tools, file browser, chat, and custom widgets with configurable positioning and behavior.

## @edit and Revise.jl support

Use `@bedit` in the notebook to open and edit files. With Revise.jl loaded, changes are automatically detected and re-evaluated.

```julia
BonitoBook.@bedit Book("intro.md") # Opens function source in editor
```

## Style customization

Customize your book's appearance by editing `.name-bbook/style.jl` (accessible via the paint can icon):

```julia (editor=true, logging=true, output=true)
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
  * Ipynb
  * PDF

## Future

There are lots of plans for what can be done in the future.

  * While I've been working quite a bit with BonitoBook to make sure everything works well, it's obviously still not battle tested and it will take a while to become rock solid.
  * Rich markdown export for e.g. readme's (inlining output as image/svg)
  * drag & dropping cells and changing their language
  * Overview function for navigation
  * Notebook store, where one can easily share their research
  * Run notebook in another process for stability and interrupt.
  * fixes for mobile CSS
  * More config options for export
  * Exe building of a notebook
  * Better model agnostic agent tools implementation, so one isn't locked into an AI provider, while not loosing any features.
  * Support `display(...)` inside for loop and have more examples on how to customize display behavior

