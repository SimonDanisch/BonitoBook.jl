# Runs everywhere

This should show a gallery of screenshots with the below points as title

- VSCode Plotpane
- Browser
- Server
- anything with a html display (Documenter, Pluto etc)
- Electron
- JuliaHub
- Colab

# Best Makie integration

```julia
# Show off nice makie plot best with LScene so stays interactive after export
```

# Julia native

## All components written in Julia

## Suports julia commands

```julia
]add Package # adding packages
?println #docs
;ls # shell
```

# Ecosystem of Components vs Notebook

## Easy to create new components in Julia
```julia
# Slider example
```

## All components can work standalone and can be re-used

```julia
App() do
    Cell(...) # correctly use Cell constructor
end
```

## Simple to create new Layouts or Books (e.g. presentation mode, dashboard)

Just a demo for the notebook, but can be used on e.g. a server with `App`
```julia
book = @Book() # You can access the current notebook
Row(book.cells[1:3]...) #
```


## Full composability with existing Bonito apps

```julia
using NDViewer
```

## Lots of default components


### BonitoBook.Components

```julia
... # all components
```

## Bonito widgets

```julia
```

### @manipulate

```julia
... # @manipulate example
```

### Latex support

```latex
...
```

# Great Python integration

## Package management like in Julia

```python
]add numpy # use some other interesting package
```

## Shared namespace

```python
# create something fun in python with the above package
```

```julia
# Plot that variable with Makie
```

## Rich mime support for Python

Based on PythonCall.jl

```python
import matplotlib
... # plot something and return the figure
```

# First class claude code integration

- julia-rpc


... link claude code examples
hots.md
juliacon25.md
mario.md
penguins.md

# File Editor included

## Revise

## @edit works

## modifying styles

## modifying settings

# Rich export/import options

## import

- .ipynb
- .markdown


## Export
### Folder structure

### HTML

### ZIP (.book)

### Binary
Via juliac

### PDF

### Markdown
