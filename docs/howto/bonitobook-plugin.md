# How to Create a BonitoBook Plugin

Create custom book formats that transform how your markdown notebooks are rendered and behave.

## Basic Structure

BonitoBook plugins are directories with the pattern `.name-bbook/` (per-file) or `.bbook/` (shared) containing a `book.jl` file that returns a module:

```
.my-plugin-bbook/        # or .bbook/ for shared configs
├── book.jl              # Must return a module
├── style.jl             # Optional custom styling (lazy-loaded from template if not present)
├── ai/                  # Optional AI configs (lazy-loaded)
│   ├── claude-config.toml
│   └── promptingtools-config.toml
├── data/                # Optional data files
└── meta.toml            # Version tracking (auto-created)
```

**Note:** Files are lazily initialized - they're only created when you edit them. Until then, they're loaded from BonitoBook templates.

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

Styles are lazy-loaded: the base `style.jl` comes from templates. Add custom styles on top:

```julia
# In your create_book function
custom_style_path = joinpath(@__DIR__, "custom-style.jl")
custom_style = BonitoBook.EvalFileOnChange(custom_style_path; module_context = book.runner.mod)
notify(custom_style.file_watcher)  # Important!

# Store in your book type
struct MyBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    custom_style::BonitoBook.EvalFileOnChange
end

function create_book(book::BonitoBook.Book; kwargs...)
    custom_style_path = joinpath(@__DIR__, "custom-style.jl")
    custom_style = BonitoBook.EvalFileOnChange(custom_style_path; module_context = book.runner.mod)
    notify(custom_style.file_watcher)
    return MyBook(book, custom_style)
end

# Include in jsrender
function Bonito.jsrender(session::Session, my_book::MyBook)
    # ... rendering ...
    return DOM.div(my_book.custom_style.last_valid_output, container)
end
```

`custom-style.jl`:
```julia
using BonitoBook.Bonito: Styles, CSS

Styles(
    CSS(".my-custom-layout", "background" => "#ff6b6b")
)
```

See [slideshow_example](/examples/slideshow_example) for a complete example.

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

