# Slideshow Book Style Template
#
# This style delegates to the Slideshow plugin defaults.

style = SlideshowBooks.generate_style(current_book())

# Add custom CSS rules here if needed:
custom_styles = Bonito.Styles()

Bonito.Styles(style, custom_styles)
