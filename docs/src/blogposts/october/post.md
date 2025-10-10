# Plugin System, Language Extensions & Simplified Styling

We're excited to announce a major update to BonitoBook that transforms it from a single-purpose notebook into an extensible platform. This release introduces a powerful plugin system, extensible language evaluators, and a completely redesigned styling architecture.

## 1. Plugin System: Transform Your Notebooks

The biggest new feature is a flexible plugin system that lets you completely customize how notebooks are rendered and behave. Plugins are modules that define custom book types and rendering logic.

### Creating a Plugin

Plugins live in `.name-bbook/book.jl` or a shared `.bbook/book.jl`:

```julia
module MyPlugin
using Bonito, BonitoBook

struct MyBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
end
# Plugin initialization with custom kwargs
create_book(book::BonitoBook.Book; kwargs...) = MyBook(book)

function Bonito.jsrender(session::Session, my_book::MyBook)
    # Custom rendering logic
    container = DOM.div(my_book.book.cells..., class="my-custom-layout")
    # Re-use any standard setup for e.g. autocomplete from BonitoBook (optional)
    elements = BonitoBook.standard_setup!(session, my_book.book)
    return Bonito.jsrender(session, DOM.div(elements, container))
end
end # module
```

From the [plugin guide](/howto/bonitobook-plugin):

### Built-in Plugin Examples

We've included three example plugins showcasing different use cases:

**Slideshow Plugin** - [Turn notebooks into presentations](../../examples/slideshow_example)

**Draggable Plugin** - [Interactive drag-and-drop layouts](../../examples/draggable_example)

**Book Plugin** - [Custom book formats with enhanced styling and table of content](../../examples/book-example)

## 2. Extensible Language Evaluators

BonitoBook now supports an extensible evaluator system for any language. We've moved language-specific code into extensions and made it easy to add new languages. Python support now needs using PythonCall.jl and CondaPkg:

```julia
# no-eval
using PythonCall, CondaPkg, BonitoBook # needs to be loaded first now
BonitoBook.book("book-with-python.md") # book now with enabled Python execution
```

Variables are automatically transferred between Python and Julia scopes, and the Python environment persists across cells.

### Creating Custom Language Evaluators

Adding a new language to BonitoBook is straightforward. From the [language evaluator guide](/howto/language-evaluator):

```julia
# ext/BonitoBookShellExt.jl
module BonitoBookShellExt
using BonitoBook
struct ShellEval <: BonitoBook.LanguageEval end
function BonitoBook.eval_code(::ShellEval, mod::Module, file::String, line::Int, source::String)
    return read(`bash -c $source`, String)
end
get_language_evaluator() = ShellEval()
end
```

### Dependency Reduction

As part of this refactoring, we've moved WGLMakie to an extension, significantly reducing BonitoBook's dependency footprint and load times. Makie is still fully supported but only loaded when needed.

## 3. Simplified Styling System

The styling system has been completely redesigned around a single `generate_style()` function with comprehensive CSS variables.

### Before and After

**Before**: Styles scattered across `styles/style.jl` with hardcoded values everywhere

**After**: Single `style.jl` file with 70+ optional parameters:

```julia
style = BonitoBook.generate_style(current_book(),
    light_theme = nothing,  # Auto-detect system preference

    # Override specific colors
    bg_primary_light = "#ffffff",
    accent_blue_light = "#0366d6",

    # Customize spacing
    spacing_lg = "1rem",
    spacing_xs = "0.25rem",
    # Shadow patterns
    shadow_color_soft_light = "rgba(0, 0, 51, 0.2)",
    shadow_blur_sm = "3px",
)
# still possible to completely overwrite anything not covered om the above function
Styles(style, YourCustomStyle) # file needs to return any Styles object
```

### Lazy File Loading

The new folder structure uses lazy initialization:

```
.name-bbook/
├── book.jl      # Plugin definition (optional)
├── style.jl     # Styling (lazy-loaded from template)
├── include.jl   # Optional include file, with code run on start
├── ai/          # AI configs (lazy-loaded)
├── data/        # Data files
└── meta.toml    # Version tracking
```

Files are only created when you edit them - until then, they're loaded from templates. This makes updates easier, keeps your repository clean while maintaining full customizability. We also fixed `include` and added an optional `include` file you can add to the notebook, which will run all code inside it on startup.

## 4. Usability Improvements

Beyond the major features, numerous small improvements enhance the daily experience:

  * **Inline slider values**: `@manipulate` now shows current values next to sliders using flexbox
  * **File tab tooltips**: Hover over tabs to see full file paths
  * **Better mobile styling**: Improved responsive design for tablets and phones
  * **Consistent spacing**: All UI components now use the CSS variable system
  * **New cell menu**: It was quite annoying that the new cell menu changed the whole layout, so now it's fixed and opens a non obstructive hover menu
  * **More Tooltips**: Added quite a few Tooltips to explain the UI
  * **fixed include**: include wasn't working which should be fixed now

## Migration Guide

Upgrading is straightforward:

### For Books Without Custom Styling

1. Delete your `.name-bbook/` folder
2. A fresh structure will be created automatically the next time you run the book

### For Books With Custom Styles/Plugins

1. Backup your `book.jl` and custom styles
2. Delete the old folder structure
3. Recreate using the new plugin system if needed
4. Use `generate_style()` for styling customization

The new `meta.toml` file tracks versions and helps detect when migration is needed.

## Looking Ahead

This release shows how BonitoBook can be an extensible platform rather than a single-purpose tool. The next feature we plan to work on is a plugin for an LLM agent dashboard and polish the LLM integration. The plugin system opens up exciting possibilities for specialized notebook formats - we can't wait to see what the community builds!
