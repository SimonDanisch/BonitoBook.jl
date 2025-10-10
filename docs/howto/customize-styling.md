# How to Customize Book Styling

Learn how to customize the appearance of your BonitoBook notebooks with custom CSS and styles.

## Quick Start

1. **Open the style editor**: Click the paint can icon (🎨) in the book's menu bar
2. **Edit the style.jl file**: This file will be created automatically when you click the icon
3. **Save and see changes**: Changes are applied live as you edit

## Understanding the Style System

BonitoBook uses a lazy-loading style system:

- **Default styles** are loaded from `BonitoBook/src/bbook/style.jl` (template)
- **Custom styles** are created only when you click the style editor button
- **Custom files** are stored in `.name-bbook/style.jl` next to your notebook

The custom `style.jl` file lets you override or extend the default styles.

## Basic Style Structure

The `style.jl` file returns a `Styles` object containing CSS rules:

```julia
using BonitoBook.Bonito: Styles, CSS

Styles(
    CSS(".my-custom-class",
        "background" => "#ff6b6b",
        "padding" => "10px",
        "border-radius" => "5px"
    ),
    CSS(".another-class",
        "color" => "white",
        "font-size" => "16px"
    )
)
```

## Common Customizations

### Changing Background Color

```julia
Styles(
    CSS("body",
        "background" => "#f0f0f0"
    )
)
```

### Styling Code Cells

```julia
Styles(
    CSS(".cell-editor",
        "background" => "#1e1e1e",
        "border" => "2px solid #0078d4",
        "border-radius" => "8px"
    )
)
```

### Custom Output Styling

```julia
Styles(
    CSS(".cell-output",
        "background" => "#ffffff",
        "padding" => "15px",
        "box-shadow" => "0 2px 4px rgba(0,0,0,0.1)"
    )
)
```

## Migrating from Old BonitoBook Versions

If you're upgrading from an older version of BonitoBook and see a migration warning:

### For Users Without Custom Styling

1. Delete your entire `.name-bbook/` folder
2. Restart BonitoBook
3. A fresh folder structure will be created automatically

### For Users With Custom Styling

1. **Backup your custom styles**:
   ```bash
   cp .my-notebook-bbook/styles/style.jl ~/my-custom-styles-backup.jl
   # Or wherever your old style.jl was located
   ```

2. **Delete the old folder**:
   ```bash
   rm -rf .my-notebook-bbook/
   ```

3. **Restart BonitoBook**: It will create a fresh folder structure

4. **Migrate your styles**:
   - Click the style editor button (🎨)
   - Use Claude Code or manual editing to port your styles:
     - Review your backup file
     - Extract the CSS customizations
     - Apply them to the new `style.jl` format (see examples above)

**Tip**: Use Claude Code to help with migration:
- Share your old `style.jl` backup
- Ask: "Help me migrate these custom styles to the new BonitoBook style.jl format"
- Claude will analyze and convert your styles

## CSS Class Reference

Key CSS classes you can customize:

| Class | Description |
|-------|-------------|
| `.cell-editor` | Code editor cells |
| `.cell-output` | Output display area |
| `.markdown-cell` | Markdown content cells |
| `.book-menu` | Top menu bar |
| `.run-button` | Cell run buttons |
| `.cell-controls` | Cell control buttons |

## Advanced: Dynamic Styles

You can use Julia code to generate styles dynamically:

```julia
using BonitoBook.Bonito: Styles, CSS

# Generate color palette
colors = ["#ff6b6b", "#4ecdc4", "#45b7d1"]

Styles(
    [CSS(".color-$i", "background" => color)
     for (i, color) in enumerate(colors)]...
)
```

## Plugin-Specific Styling

When creating a BonitoBook plugin, you can add custom styles in your `create_book` function:

```julia
function create_book(book::BonitoBook.Book; kwargs...)
    custom_style_path = joinpath(@__DIR__, "custom-style.jl")
    custom_style = BonitoBook.EvalFileOnChange(
        custom_style_path;
        module_context = book.runner.mod
    )
    notify(custom_style.file_watcher)

    return MyBook(book, custom_style)
end
```

See [bonitobook-plugin](/howto/bonitobook-plugin) for more details.

## Troubleshooting

### Styles not applying

- Ensure your `style.jl` returns a `Styles()` object
- Check for syntax errors in the Julia console
- Try saving the file again to trigger a reload

### Migration issues

- If you see warnings about old folder structure, follow the migration steps above
- Check that `meta.toml` exists in your `.name-bbook/` folder
- Ensure no old `styles/` subdirectory exists

## See Also

- [BonitoBook Plugin Guide](/howto/bonitobook-plugin) - Creating custom book formats
- [Examples](/examples) - Example notebooks with custom styling
