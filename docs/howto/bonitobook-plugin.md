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

`book.jl` - return a module with a custom book type and `create_book` function:

```julia
module MyPlugin

using Bonito, BonitoBook

struct MyBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
end

"""
    create_book(book::BonitoBook.Book; kwargs...)

Create a MyBook instance from a BonitoBook.Book.
This is the entry point that the plugin system calls.

Plugin-specific keyword arguments can be passed via create_book:
- `create_book(file; theme="dark", custom_setting=true)`
  The Book constructor arguments (folder, replace_style, all_blocks_as_cell)
  are handled automatically, and only plugin-specific kwargs are forwarded here.
"""
function create_book(book::BonitoBook.Book; kwargs...)
    # Plugin initialization logic using kwargs
    # For example:
    # theme = get(kwargs, :theme, "auto")
    # custom_setting = get(kwargs, :custom_setting, false)

    return MyBook(book)
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
# Note: SomeExistingPlugin must export a create_book function
```

## Key Requirements

1. **Module Structure**: The `book.jl` file must return a module
2. **AbstractBook Subtype**: Define a struct that inherits from `BonitoBook.AbstractBook`
3. **create_book Function**: Define a `create_book(book::BonitoBook.Book; kwargs...)` function that returns your custom book instance
4. **Rendering**: Implement `Bonito.jsrender(session::Session, your_book::YourBookType)` for custom display logic

## Migration from Constructor-based Plugins

If you have an existing plugin using the constructor approach:

**Old (deprecated):**
```julia
struct MyBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book

    function MyBook(book::BonitoBook.Book)
        # initialization logic
        return new(book)
    end
end
```

**New (recommended):**
```julia
struct MyBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
end

function create_book(book::BonitoBook.Book; kwargs...)
    # initialization logic
    return MyBook(book)
end
```

## Adding Styles

Copy the main BonitoBook template for `styles/style.jl` (this gets done automatically if you start from a standard bonitobook), then add custom styles on top, by adding another style file:

```julia
# In your create_book function
custom_style_path = joinpath(@__DIR__, "styles", "custom-style.jl")
custom_style = BonitoBook.EvalFileOnChange(custom_style_path; module_context = book.runner.mod)
notify(custom_style.file_watcher)  # Important, to actually eval the style for the first time

# Store the style in your custom book type and include it in jsrender
struct MyBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    custom_style::BonitoBook.EvalFileOnChange
end

function create_book(book::BonitoBook.Book; kwargs...)
    # Set up custom styles
    custom_style_path = joinpath(@__DIR__, "styles", "custom-style.jl")
    custom_style = BonitoBook.EvalFileOnChange(custom_style_path; module_context = book.runner.mod)
    notify(custom_style.file_watcher)

    return MyBook(book, custom_style)
end

# In jsrender, include the style
function Bonito.jsrender(session::Session, my_book::MyBook)
    # ... other rendering logic ...
    return DOM.div(my_book.custom_style.last_valid_output, container)
end
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

  * [slideshow_example](/examples/slideshow_example) - Presentation mode with navigation
  * [draggable_example](/examples/draggable_example) - Rearrangeable cells
  * [book-example](/examples/book-example) - Alternative book layout

## Usage

Place your notebook next to the plugin directory:

```
my-project/
├── my-plugin.md              # Your content
└── .my-plugin-bbook/        # Your plugin
    └── book.jl
```

BonitoBook automatically detects and uses the plugin. You can also pass plugin-specific arguments:

```julia
# Using create_book directly with plugin arguments
create_book("my-plugin.md"; theme="dark", enable_animations=true)

# Using book() server with plugin arguments
book("my-plugin.md"; theme="dark", enable_animations=true)
```

The Book constructor arguments (`folder`, `replace_style`, `all_blocks_as_cell`) are handled automatically, while any additional kwargs are forwarded to your plugin's `create_book` function.

You can also use `Book`/`book(file; folder=plugin_folder)` to use a different bonitobook folder for a notebook file. This will likely get more streamlined in the future, making it easier to share plugins with the community.
