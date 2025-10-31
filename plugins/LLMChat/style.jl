# LLM Chat Book Style Template
#
# This template demonstrates how to customize your LLM Chat Book's appearance.
# Copy this to your .llm-chat-*-bbook/style.jl file and customize as needed.
#
# All BonitoBook style parameters are available and can be customized.

# Generate the style with LLM Chat specific styling
style = LLMChatBooks.generate_style(current_book(),
    # Theme control (nothing = auto-detect, true = force light, false = force dark)
    light_theme = nothing,

    # # Layout Variables - all BonitoBook parameters available
    # editor_width = "90ch",
    # editor_min_width = "25rem",
    # editor_max_width = "95vw",
    # max_height_large = "80vh",
    # max_height_medium = "60vh",
    # border_radius_small = "0.1875rem",
    # border_radius_large = "0.3125rem",
    # transition_fast = "0.1s ease-out",
    # transition_slow = "0.2s ease-in",
    # font_family_clean = "'Inter', 'Roboto', 'Arial', sans-serif",

    # # Spacing
    # spacing_xxs = "0.125rem",
    # spacing_xs = "0.25rem",
    # spacing_sm = "0.5rem",
    # spacing_md = "0.75rem",
    # spacing_lg = "1rem",
    # spacing_xl = "1.25rem",

    # # Light/Dark Theme Colors
    # # See BonitoBook template for full list of color parameters
    # bg_primary_light = "#ffffff",
    # text_primary_light = "#24292e",
    # accent_blue_light = "#0366d6",
    # # ... (all other color parameters available)

    # # Style section overrides
    # # Uncomment to completely replace specific style sections
    # layout_variables = Bonito.Styles(),
    # base_styles = Bonito.Styles(),
    # theme_styles = Bonito.Styles(),
    # ui_styles = Bonito.Styles(),
)

# Custom styles for additional chat-specific components
# Add CSS rules here using Bonito.Styles(Bonito.CSS(...), Bonito.CSS(...))
custom_styles = Bonito.Styles()

# Final combined style - this is what your LLM Chat Book will use
Bonito.Styles(style, custom_styles)
