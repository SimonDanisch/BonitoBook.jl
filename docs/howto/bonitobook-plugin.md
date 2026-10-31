# How to Create a BonitoBook Plugin

Create custom book formats that transform how your markdown notebooks are rendered and behave.

## Basic Structure

BonitoBook plugins are directories with the pattern `.name-bbook/` (per-file) or `.bbook/` (shared) containing a `book.jl` file that returns a module:

```
.my-plugin-bbook/        # or .bbook/ for shared configs
├── book.jl              # Must return a module
├── include.jl           # Will run any code included here
├── style.jl             # custom styling
├── ai/                  # Optional AI configs (lazy-loaded)
├── data/                # Optional data files
└── meta.toml            # Version tracking (auto-created)
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

## Adding Styles

BonitoBook automatically loads `style.jl` from your plugin folder. The file is lazy-loaded from a template if not present, so you only create it when you need custom styling.

### Simple Approach: Customize with `generate_style()`

Use the built-in `generate_style()` function with 70+ customization parameters:

```julia
# .my-plugin-bbook/style.jl

# Generate base style with custom colors
custom_style = BonitoBook.generate_style(current_book();
    light_theme = true,  # or false, or nothing for auto-detect

    # Override specific colors
    bg_primary_light = "#F8FAFC",
    accent_blue_light = "#6366F1",
    text_primary_light = "#1E293B",

    # Customize spacing
    spacing_lg = "1.5rem",
    spacing_xs = "0.5rem",
)

# Return the style (BonitoBook expects this)
custom_style
```

### Advanced Approach: Combine Base + Custom CSS

For complete control, combine the base style with your custom CSS:

```julia
# .my-plugin-bbook/style.jl
# Define custom colors
MY_PRIMARY = "#6366F1"
MY_SECONDARY = "#0EA5E9"

# Create plugin-specific styles
plugin_style = Styles(
    CSS(
        ".my-custom-layout",
        "background" => "linear-gradient(135deg, $(MY_PRIMARY), $(MY_SECONDARY))"
    ),
    CSS(
        ".my-custom-layout h1",
        "color" => MY_PRIMARY,
        "font-size" => "3rem"
    )
)

# Generate base BonitoBook styles
base_style = BonitoBook.generate_style(current_book(); light_theme=true)

# Merge and return
Styles(base_style, plugin_style)
```

### Scoping Styles to Your Plugin

Use higher-specificity selectors to scope styles to your plugin. The slideshow example wraps everything in `.presentation-themed-slideshow`:

```julia
# Generate base style
base_style = BonitoBook.generate_style(current_book())

# Scope global elements to your plugin container
scoped_style = Styles(
    CSS(
        ".my-plugin-container",
        "font-family" => "'Inter', sans-serif",
        "background-color" => "var(--bg-primary)"
    ),
    CSS(
        ".my-plugin-container h1",
        "font-size" => "3.5rem",
        "color" => "var(--text-primary)"
    )
)

# Combine
Styles(base_style, scoped_style, your_custom_styles)
```

**Important:** The `style.jl` file must return a `Styles` object (or something that can be rendered as styles).

See the [slideshow_example](../../examples/slideshow_example) for a complete real-world example.

## Examples

See existing plugins for reference:

  * [slideshow_example](../../examples/slideshow_example) - Presentation mode with navigation
  * [draggable_example](../../examples/draggable_example) - Rearrangeable cells
  * [book-example](../../examples/book-example) - Alternative book layout

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

