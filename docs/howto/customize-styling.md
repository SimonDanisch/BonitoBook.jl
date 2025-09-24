# How to Customize BonitoBook Styling

BonitoBook uses a composable styling system that lets you customize your book's appearance by only changing what you need.

## Quick Start

1. **Copy the template** to your book's `styles/style.jl`:
   ```bash
   cp BonitoBook/src/templates/style_template.jl your_book/styles/style.jl
   ```

2. **Edit variables** in the `generate_style()` call:
   ```julia
   style = BonitoBook.generate_style(current_book(),
       # Make editors wider
       editor_width = "100ch",

       # Use custom colors
       bg_primary_light = "#fafafa",
       accent_blue_light = "#2563eb",
   )
   ```

3. **Add custom CSS** if needed:
   ```julia
   custom_styles = Styles(
       CSS(".my-component", "color" => "var(--accent-blue)")
   )
   ```

## What You Can Customize

### Layout & Spacing
- **Editor size**: `editor_width`, `editor_min_width`, `editor_max_width`
- **Spacing**: `spacing_xs` through `spacing_xl`
- **Borders**: `border_radius_small`, `border_radius_large`
- **Animations**: `transition_fast`, `transition_slow`

### Colors (Light/Dark Themes)
- **Backgrounds**: `bg_primary_light/dark`
- **Text**: `text_primary_light/dark`, `text_secondary_light/dark`
- **Accents**: `accent_blue_light/dark`
- **Borders**: `border_primary_light/dark`, `border_secondary_light/dark`

### Advanced: Section Overrides
Replace entire style sections by setting them to custom `Styles()`:
```julia
custom_editor = Styles(
    CSS(".cell-editor", "border" => "2px solid blue")
)

style = BonitoBook.generate_style(current_book(),
    editor_styles = custom_editor
)
```

## Common Examples

### Wider Editors
```julia
style = BonitoBook.generate_style(current_book(),
    editor_width = "120ch"
)
```

### Custom Color Scheme
```julia
style = BonitoBook.generate_style(current_book(),
    bg_primary_light = "#fefefe",
    accent_blue_light = "#059669",    # Green accent
    accent_blue_dark = "#10b981"
)
```

### Compact Layout
```julia
style = BonitoBook.generate_style(current_book(),
    spacing_lg = "0.75rem",
    font_size_base = "0.8125rem"
)
```

## Tips

- **Use CSS variables** in custom styles: `"color" => "var(--accent-blue)"`
- **Test both themes** by changing `light_theme = true/false/nothing`
- **Start simple** with variable changes before section overrides

For complete documentation, see [styling_guide.md](styling_guide.md).