# Slideshow Plugin

Presentation-style plugin for BonitoBook with:
- slide navigation via `---` separators
- progress bar and keyboard navigation
- slideshow-focused styling
- hidden new-cell controls in presentation mode

## Usage

```julia
using BonitoBook

book = BonitoBook.create_book("slides.md"; plugin=BonitoBook.SlideshowBooks)
```

Or run the server:

```julia
BonitoBook.book("slides.md"; plugin=BonitoBook.SlideshowBooks)
```
