# How to Create Presentations with BonitoBook Slideshow

Transform your BonitoBook notebooks into engaging presentations with the slideshow plugin - perfect for talks, lectures, and demonstrations.

## Quick Start

The slideshow plugin automatically turns your markdown notebook into a presentation:

1. **Create your content** in a regular markdown file
2. **Use `---` (horizontal rules)** to separate slides
3. **Place the file** next to a `.slideshow_example-bbook` directory
4. **Open in BonitoBook** - it will automatically use slideshow mode

## Navigation

### Keyboard Controls

  * **→ / Space**: Next slide
  * **← / Backspace**: Previous slide
  * **Escape**: Exit fullscreen (if used)

### Mouse Controls

  * **Click progress bar**: Jump to specific slide position
  * **Scroll**: Manual navigation (syncs with slide position)

## Styling Customization

The slideshow plugin supports custom themes. You can modify:

### Colors and Fonts

```julia
# In presentation-style.jl
MAKIE_PURPLE = "#6366F1"
MAKIE_BLUE = "#0EA5E9"
```

### Layout and Spacing

  * Large, readable fonts for presentations
  * Generous margins and padding
  * Optimized for viewing from distance

## Deployment Tips

### For Live Presentations

  * Use `BonitoBook.book()` for local presentations
  * Ensure stable internet for package loading
  * Test all code cells before presenting

### For Sharing

  * Export to static HTML for distribution
  * Include instructions for interactive features
  * Provide fallback static versions of plots

