# LLM Chat Book Template

This folder contains templates for LLM Chat Books that are automatically discovered by BonitoBook.

## How It Works

When you use an LLM Chat Book, BonitoBook automatically detects this plugin template folder by:
1. Reading your `.llm-chat-*-bbook/book.jl` file
2. Detecting that it loads the `LLMChatBooks` plugin
3. Using this template folder for any lazy-loaded files (like `style.jl`)

## Customizing Styles

Files from this template are lazy-loaded - they're only copied to your book folder when you edit them:

**Option 1: Using the UI (Recommended)**
1. Click the style/settings button in your book's menu bar
2. This will automatically copy `style.jl` to your `.llm-chat-*-bbook` folder
3. Edit the file with your customizations

**Option 2: Manual Copy**
1. Copy `style.jl` from this template folder to your `.llm-chat-*-bbook` folder
2. Edit the style.jl file with your customizations
3. Restart your book server

The `style.jl` template provides access to:
- All BonitoBook styling parameters (colors, spacing, fonts, etc.)
- LLM Chat-specific styles (chat bubbles, input, spinners, etc.)

## Example Customization

```julia
# In your .llm-chat-*-bbook/style.jl
style = LLMChatBooks.generate_style(current_book(),
    # Change theme
    light_theme = false,  # Force dark mode

    # Customize colors
    accent_blue_dark = "#00ff00",  # Green accent in dark mode

    # Adjust spacing
    spacing_lg = "2rem"  # More spacious layout
)

# Add your own custom CSS
custom_styles = Bonito.Styles(
    Bonito.CSS(
        ".cell-from-user .cell-output",
        "background" => "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
    )
)

Bonito.Styles(style, custom_styles)
```

## Files in this Template

- **style.jl**: Main styling template with all customization options
- **README.md**: This file

## Learn More

- See `dev/BonitoBook/docs/howto/styling_guide.md` for detailed styling documentation
- See `dev/BonitoBook/src/style.jl` for all available style parameters
