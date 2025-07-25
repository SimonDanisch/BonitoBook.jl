# BonitoBook Overview

BonitoBook is a Julia-native interactive notebook system built on Bonito.jl that combines multi-language execution, AI integration, and modern web-based editing.

# Runs everywhere

- VSCode Plot Pane
- Browser
- Server deployments
- HTML displays (Documenter, Pluto)
- Electron applications
- JuliaHub
- Google Colab

# Best Makie integration

```julia
using WGLMakie
# Interactive 3D plots with LScene preserve interactivity after export
mesh(Sphere(Point3f(0), 1f0), color=:red)
```

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

```julia
using BonitoBook.Components
slider = Slider(1:100, value=50)
button = Button("Click me")
DOM.div(slider, button)
```

## All components work standalone and can be reused

```julia
using BonitoBook
App() do
    runner = BonitoBook.AsyncRunner()
    BonitoBook.CellEditor("println(\"Hello World\")", "julia", )
end
```

## Simple to create new layouts or books

```julia
book = @Book() # Access current notebook
Row(book.cells[1:3]...) # Custom layout with first 3 cells
```

## Full composability with existing Bonito apps

```julia
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

```julia
using BonitoBook.Components
# UI Controls
Button("Submit")
Slider(1:100, value=25)
Checkbox(false, "Enable feature")
TextInput("Enter text")
Dropdown(["Option 1", "Option 2"], value="Option 1")

# Layout
Row(elem1, elem2, elem3)
Column(elem1, elem2, elem3)
Card("Title", content)
```

## Bonito widgets

```julia
using Bonito
# Native Bonito components work seamlessly
input = Bonito.Input("")
output = map(input) do text
    "You typed: $text"
end
DOM.div(input, output)
```

### @manipulate

```julia
using BonitoBook.Components
@manipulate for n in 1:100, color in ["red", "blue", "green"]
    scatter(rand(n), color=color)
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

```python
]add numpy matplotlib pandas # Install Python packages via Conda
```

## Shared namespace

```python
import numpy as np
data = np.random.randn(1000, 2)
labels = ["x", "y"]
```

```julia
using WGLMakie
# Access Python variables directly in Julia
scatter(data[:, 1], data[:, 2], axis=(xlabel=labels[1], ylabel=labels[2]))
```

## Rich MIME support

```python
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3, 4], [1, 4, 2, 3])
fig # Automatically displays in notebook
```

# Claude Code integration

BonitoBook includes first-class integration with Claude via the Claude Code CLI:

- **MCP Server**: Julia RPC server for tool access
- **File operations**: Claude can read/write project files
- **Code execution**: Claude can run cells and see results
- **Chat interface**: Built-in chat sidebar with image support

Example books demonstrating Claude integration:
- `examples/juliacon25.md` - JuliaCon 25 video subtitle analysis
- `examples/mario.md` - Interactive game
- `examples/penguins.md` - Data analysis

# File editor included

## Integrated Monaco editor

- Syntax highlighting for Julia, Python, Markdown, JSON, TOML
- Code completion
- Find/replace functionality
- Multiple theme support (auto/light/dark)



## @edit compatibility

```julia
@edit println("hello") # Opens function source in editor
```
## Revise.jl integration

Changes from e.g. `@edit` are automatically applied.

## Style customization

Edit `styles/style.jl` by pressing the paintcan icon to customize appearance:
```julia
# Modify colors, fonts, layout dimensions
light_theme = true # Force light theme
editor_width = "800px" # Adjust editor width
```

# Export/import options

## Import formats

### Jupyter notebooks (.ipynb)
```julia
book = Book("notebook.ipynb")
# Preserves cell metadata, outputs, and structure
```

### Markdown files (.md)
```julia
book = Book("document.md")
# Converts code blocks to executable cells
# Supports cell visibility metadata:
# ```julia true false true
# # show_editor show_logging show_output
```

## Export formats

### HTML export
```julia
export_html("mybook.html", book)
# Creates standalone HTML with embedded assets
# Preserves interactivity where possible
```

### Markdown export
```julia
export_md("output.md", book)
# Maintains cell metadata and structure
# Compatible with re-import
```

### Julia script export
```julia
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
This folder can be zipped and shared with all data, settings and style.
With Project.toml and Manifest being part of the format, each notebook is reproducable.



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
