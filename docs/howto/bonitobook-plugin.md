# How to Create a BonitoBook Plugin

Create custom book formats that transform how your markdown notebooks are rendered and behave.

## Basic Structure

BonitoBook plugins are directories with the pattern `.name-bbook/` containing a `book.jl` file that returns a module:

```
.my-plugin-bbook/
├── book.jl              # Must return a module
└── styles/              # Optional styling
    └── style.jl
```

## Minimal Example

`book.jl` - return a module with a custom book type:

```julia
module MyPlugin

using Bonito, BonitoBook

struct MyBook <: BonitoBook.AbstractBook
    # Must have a constructor that accepts a BonitoBook.Book
    book::BonitoBook.Book
end

function Bonito.jsrender(session::Session, my_book::MyBook)
    # Custom rendering logic
    container = DOM.div(
        my_book.book.cells...,
        class="my-custom-layout"
    )

    elements = BonitoBook.standard_setup!(session, my_book.book)
    return Bonito.jsrender(session, DOM.div(elements, container))
end

end # module
```

Alternatively, just use an existing module:

```julia
# book.jl can simply be:
using SomeExistingPlugin
```

## Adding Styles

Copy the main BonitoBook template for `styles/style.jl` (this gets done automatically if you start from a standard bonitobook), then add custom styles on top:

```julia
# In your book constructor
custom_style_path = joinpath(dirname(@__FILE__), "styles", "custom-style.jl")
custom_style = BonitoBook.EvalFileOnChange(custom_style_path; module_context = book.runner.mod)
notify(custom_style.file_watcher)  # Important, to actually include the style for the first time
# include the style into your dom inside jsrender
DOM.div(custom_style.last_valid_output)
```

`styles/custom-style.jl`:
```julia
using BonitoBook.Bonito: Styles, CSS

Styles(
    CSS(".my-custom-layout", "background" => "#ff6b6b")
)
```
The best plugin to look at for this is the slideshow_example!

## Examples

See existing plugins for reference:
- [slideshow_example](/examples/slideshow_example) - Presentation mode with navigation
- [draggable_example](/examples/draggable_example) - Rearrangeable cells
- [book-example](/examples/book-example) - Alternative book layout

## Usage

Place your notebook next to the plugin directory:

```
my-project/
├── my-plugin.md              # Your content
└── .my-plugin-bbook/        # Your plugin
    └── book.jl
```

BonitoBook automatically detects and uses the plugin.
You can use `Book`/`book(file; folder=plugin_folder)`, to use a different bonitobook folder for a notebook file.
This will likely get more streamlined in the feature, making it easier to share plugins with the community.
