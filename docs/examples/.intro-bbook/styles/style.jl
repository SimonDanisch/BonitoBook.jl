# BonitoBook Style Template
#
# This template demonstrates how to customize your BonitoBook's appearance.
# Copy this to your book's styles/style.jl file and customize as needed.
#
# For full documentation, see docs/howto/styling_guide.md

# Generate the base style with your customizations
style = BonitoBook.generate_style(current_book(),
    # Theme control (nothing = auto-detect, true = force light, false = force dark)
    light_theme = nothing,

    # Layout Variables
    editor_width = "90ch",
    editor_min_width = "25rem",
    editor_max_width = "95vw",
    max_height_large = "80vh",
    max_height_medium = "60vh",
    border_radius_small = "0.1875rem",
    border_radius_large = "0.3125rem",
    transition_fast = "0.1s ease-out",
    transition_slow = "0.2s ease-in",
    font_family_clean = "'Inter', 'Roboto', 'Arial', sans-serif",

    # Spacing
    spacing_xs = "0.25rem",
    spacing_sm = "0.5rem",
    spacing_md = "0.75rem",
    spacing_lg = "1rem",
    spacing_xl = "1.25rem",

    # Font sizes
    font_size_xs = "0.75rem",
    font_size_sm = "0.8125rem",
    font_size_base = "0.875rem",
    font_size_lg = "1rem",

    # Common widths
    width_xs = "1rem",
    width_sm = "1.25rem",
    width_md = "2.25rem",
    width_lg = "3rem",

    # Z-index layers
    z_behind = "-1",
    z_base = "1",
    z_dropdown = "10",
    z_overlay = "50",
    z_sidebar = "100",
    z_modal = "1000",
    z_menu = "1001",
    z_popup = "2000",
    z_popup_close = "2001",

    # Light Theme Colors
    bg_primary_light = "#ffffff",
    text_primary_light = "#24292e",
    text_secondary_light = "#555555",
    border_primary_light = "rgba(0, 0, 0, 0.1)",
    border_secondary_light = "#ccc",
    shadow_soft_light = "0 0 4px rgba(0, 0, 51, 0.2)",
    shadow_button_light = "0 1px 3px rgba(0, 0, 0, 0.2)",
    shadow_inset_light = "inset 1px 1px 3px rgba(0, 0, 0, 0.2)",
    hover_bg_light = "#ddd",
    menu_hover_bg_light = "rgba(0, 0, 0, 0.05)",
    accent_blue_light = "#0366d6",
    animation_glow_light = "0 0 10px rgba(0, 150, 51, 0.8)",
    icon_color_light = "#666666",
    icon_hover_color_light = "#333333",
    icon_filter_light = "none",
    icon_hover_filter_light = "brightness(0.7)",
    scrollbar_track_light = "#f1f1f1",
    scrollbar_thumb_light = "#c1c1c1",
    scrollbar_thumb_hover_light = "#a8a8a8",

    # Dark Theme Colors
    bg_primary_dark = "#1e1e1e",
    text_primary_dark = "rgb(212, 212, 212)",
    text_secondary_dark = "rgb(212, 212, 212)",
    border_primary_dark = "rgba(255, 255, 255, 0.1)",
    border_secondary_dark = "rgba(255, 255, 255, 0.1)",
    shadow_soft_dark = "0 0 4px rgba(255, 255, 255, 0.2)",
    shadow_button_dark = "0 1px 3px rgba(255, 255, 255, 0.2)",
    shadow_inset_dark = "inset 1px 1px 2px rgba(0, 0, 0, 0.5)",
    hover_bg_dark = "rgba(255, 255, 255, 0.1)",
    menu_hover_bg_dark = "rgba(255, 255, 255, 0.05)",
    accent_blue_dark = "#0366d6",
    animation_glow_dark = "0 0 20px rgba(10, 155, 55, 0.5)",
    icon_color_dark = "#cccccc",
    icon_hover_color_dark = "#ffffff",
    icon_filter_dark = "invert(1)",
    icon_hover_filter_dark = "invert(1) brightness(1.2)",
    scrollbar_track_dark = "#2d2d2d",
    scrollbar_thumb_dark = "#555555",
    scrollbar_thumb_hover_dark = "#777777",

    # Style section overrides - set to custom Styles() to replace entire sections
    layout_variables = Styles(),
    base_styles = Styles(),
    theme_styles = Styles(),
    print_export_styles = Styles(),
    mobile_styles = Styles(),
    monaco_styles = Styles(),
    editor_styles = Styles(),
    icon_styles = Styles(),
    markdown_styles = Styles(),
    data_styles = Styles(),
    ui_styles = Styles(),
)

# Custom styles for plugins or additional components
# Add CSS rules here using Styles(CSS(...), CSS(...))
custom_styles = Styles()

# Final combined style - this is what BonitoBook will use
Styles(style, custom_styles)
