# BonitoBook Styling Guide

This guide explains the new composable styling system in BonitoBook, which allows you to customize your book's appearance with fine-grained control while maintaining compatibility with updates to the base styling system.

## Overview

The new styling system is built around the `generate_style()` function, which provides:

1. **Variable-level customization**: Override individual CSS variables (colors, spacing, dimensions)
2. **Section-level customization**: Replace entire style sections with custom implementations
3. **Composable styling**: Easily combine base styles with plugin or custom styles
4. **Update-safe customization**: Only copy/override what you actually change

## Basic Usage

### 1. Simple Variable Customization

The easiest way to customize your book is by overriding specific variables:

```julia
# In your book's styles/style.jl file
include(joinpath(dirname(pathof(BonitoBook)), "templates", "style.jl"))

style = generate_style(
    # Make editors wider
    editor_width = "100ch",

    # Use a warmer color scheme
    bg_primary_light = "#fefefe",
    accent_blue_light = "#2563eb",

    # Adjust spacing
    spacing_lg = "1.25rem"
)
```

### 2. Section-level Customization

For more complex changes, you can replace entire style sections:

```julia
# Create custom editor styles
custom_editor_styles = Styles(
    CSS(
        ".cell-editor",
        "border" => "2px solid var(--accent-blue)",
        "border-radius" => "12px"
    ),
    CSS(
        ".cell-editor.focused",
        "box-shadow" => "0 0 0 3px rgba(59, 130, 246, 0.1)"
    )
)

# Apply the custom section
style = generate_style(
    editor_styles = custom_editor_styles,
    accent_blue_light = "#2563eb"
)
```

### 3. Plugin and Extension Styles

Combine the base system with additional styles:

```julia
# Base customized style
base_style = generate_style(
    editor_width = "110ch",
    accent_blue_light = "#059669"
)

# Plugin-specific styles
plugin_styles = Styles(
    CSS(".my-plugin", "color" => "var(--accent-blue)"),
    CSS(".special-table th", "background" => "var(--accent-blue)")
)

# Combine them
final_style = Styles(base_style, plugin_styles)
```

## Available Customization Options

### Layout Variables

Control spacing, dimensions, and layout properties:

| Variable | Default | Description |
|----------|---------|-------------|
| `editor_width` | `"90ch"` | Width of code editors |
| `editor_min_width` | `"25rem"` | Minimum editor width |
| `editor_max_width` | `"95vw"` | Maximum editor width |
| `border_radius_small` | `"0.1875rem"` | Small border radius |
| `border_radius_large` | `"0.3125rem"` | Large border radius |
| `transition_fast` | `"0.1s ease-out"` | Fast transition duration |
| `transition_slow` | `"0.2s ease-in"` | Slow transition duration |
| `spacing_xs` through `spacing_xl` | `"0.25rem"` to `"1.25rem"` | Spacing values |
| `font_size_xs` through `font_size_lg` | `"0.75rem"` to `"1rem"` | Font sizes |
| `z_behind` through `z_popup_close` | `"-1"` to `"2001"` | Z-index layers |

### Theme Variables

Control colors and visual appearance for both light and dark themes:

| Variable Base | Light Default | Dark Default | Description |
|---------------|---------------|--------------|-------------|
| `bg_primary_*` | `"#ffffff"` | `"#1e1e1e"` | Primary background color |
| `text_primary_*` | `"#24292e"` | `"rgb(212, 212, 212)"` | Primary text color |
| `text_secondary_*` | `"#555555"` | `"rgb(212, 212, 212)"` | Secondary text color |
| `border_primary_*` | `"rgba(0, 0, 0, 0.1)"` | `"rgba(255, 255, 255, 0.1)"` | Primary border color |
| `hover_bg_*` | `"#ddd"` | `"rgba(255, 255, 255, 0.1)"` | Hover background |
| `accent_blue_*` | `"#0366d6"` | `"#0366d6"` | Accent blue color |
| `icon_color_*` | `"#666666"` | `"#cccccc"` | Default icon color |

*Note: Replace `*` with `_light` or `_dark` for theme-specific variables.*

### Style Section Overrides

Replace entire sections with custom implementations:

| Section | Description |
|---------|-------------|
| `layout_variables` | CSS custom properties for layout |
| `base_styles` | Basic element styling |
| `theme_styles` | Color theme definitions |
| `print_export_styles` | Print and export mode styles |
| `mobile_styles` | Mobile responsive styles |
| `monaco_styles` | Monaco editor styling |
| `editor_styles` | Cell editor styling |
| `icon_styles` | Icon system styling |
| `markdown_styles` | Markdown content styling |
| `data_styles` | Data visualization styling |
| `ui_styles` | UI component styling |


## Best Practices

### 1. Start Small
Begin with variable-level customizations before moving to section overrides.

### 2. Use CSS Variables
Leverage the CSS custom properties system for consistent theming:
```julia
CSS(".my-component",
    "background" => "var(--bg-primary)",
    "color" => "var(--text-primary)",
    "border" => "1px solid var(--border-primary)"
)
```

### 3. Maintain Accessibility
When customizing colors and spacing, ensure adequate contrast and touch targets:
```julia
generate_style(
    # Ensure good contrast ratios
    text_primary_light = "#1a1a1a",  # Dark enough for readability
    bg_primary_light = "#ffffff",    # Light enough for contrast

    # Maintain reasonable spacing for touch interfaces
    spacing_lg = "1rem"  # At least 16px for touch targets
)
```

### 4. Test Both Themes
Always test your customizations in both light and dark modes:
```julia
generate_style(
    # Customize both themes
    accent_blue_light = "#2563eb",
    accent_blue_dark = "#3b82f6"  # Brighter for dark mode
)
```

### 5. Document Your Changes
Comment your customizations to explain the reasoning:
```julia
style = generate_style(
    # Wider editors for better code readability
    editor_width = "110ch",

    # Brand colors from design system
    accent_blue_light = "#2563eb",
    accent_blue_dark = "#3b82f6",

    # Slightly tighter spacing for compact layout
    spacing_lg = "0.875rem"
)
```

## Examples

See the `style_template.jl` file for a complete template showing all customization options.

## Troubleshooting

### Issue: Styles not applying
- Ensure you're returning the generated style as the final value in your `styles/style.jl` file
- Check that variable names match exactly (underscore instead of dash)

### Issue: Breaking changes with updates
- The new system isolates your customizations from base template changes
- Only section-level overrides might need updates if the underlying CSS structure changes

### Issue: Complex styling needs
- For advanced customizations, combine `generate_style()` with additional `Styles()` objects
- Consider creating helper functions for reusable style patterns

## Advanced Topics

### Creating Reusable Themes

You can create theme presets by wrapping `generate_style()`:

```julia
function dark_theme()
    generate_style(
        light_theme = false,
        bg_primary_dark = "#0f1419",
        accent_blue_dark = "#3b82f6"
    )
end

function compact_theme()
    generate_style(
        editor_width = "85ch",
        spacing_lg = "0.75rem",
        font_size_base = "0.8125rem"
    )
end
```

### Plugin Development

Plugin authors can provide style helpers:

```julia
function my_plugin_styles(base_style; accent_color="#2563eb")
    plugin_styles = Styles(
        CSS(".my-plugin", "color" => accent_color)
    )
    return Styles(base_style, plugin_styles)
end
```

This new system provides much more flexibility while maintaining simplicity for common use cases. Start with basic variable customization and gradually explore more advanced features as needed.