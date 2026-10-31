function generate_style(book;
        light_theme = nothing,
        # All layout/theme parameters with defaults...
        editor_width = "90ch",
        editor_min_width = "25rem",
        editor_max_width = "95vw",
        max_height_large = "80vh",
        max_height_medium = "60vh",
        border_radius_small = "0.1875rem",
        border_radius_large = "0.3125rem",
        transition_fast = "0.1s ease-out",
        transition_slow = "0.2s ease-in",
        text_font = "'Inter', 'Roboto', 'Arial', sans-serif",
        mono_font = "SFMono-Regular, Consolas, Liberation Mono, Menlo, Courier, monospace",
        spacing_xxs = "0.125rem",
        spacing_xs = "0.25rem",
        spacing_sm = "0.5rem",
        spacing_md = "0.75rem",
        spacing_lg = "1rem",
        spacing_xl = "1.25rem",
        shadow_blur_sm = "3px",
        shadow_blur_md = "10px",
        font_size_xs = "0.75rem",
        font_size_sm = "0.8125rem",
        font_size_base = "0.875rem",
        font_size_lg = "1rem",
        width_xs = "1rem",
        width_sm = "1.25rem",
        width_md = "2.25rem",
        width_lg = "3rem",
        z_behind = "-1",
        z_base = "1",
        z_dropdown = "10",
        z_overlay = "50",
        z_sidebar = "100",
        z_modal = "1000",
        z_menu = "1001",
        z_popup = "2000",
        z_popup_close = "2001",
        bg_primary_light = "#ffffff",
        text_primary_light = "#24292e",
        text_secondary_light = "#555555",
        border_primary_light = "rgba(0, 0, 0, 0.1)",
        border_secondary_light = "#ccc",
        shadow_color_soft_light = "rgba(0, 0, 51, 0.2)",
        shadow_color_button_light = "rgba(0, 0, 0, 0.2)",
        shadow_color_inset_light = "rgba(0, 0, 0, 0.2)",
        glow_color_light = "rgba(0, 150, 51, 0.8)",
        hover_bg_light = "#ddd",
        menu_hover_bg_light = "rgba(0, 0, 0, 0.05)",
        accent_blue_light = "#0366d6",
        icon_color_light = "#666666",
        icon_hover_color_light = "#333333",
        icon_filter_light = "none",
        icon_hover_filter_light = "brightness(0.7)",
        scrollbar_track_light = "#f1f1f1",
        scrollbar_thumb_light = "#c1c1c1",
        scrollbar_thumb_hover_light = "#a8a8a8",
        bg_primary_dark = "#1e1e1e",
        text_primary_dark = "rgb(212, 212, 212)",
        text_secondary_dark = "rgb(212, 212, 212)",
        border_primary_dark = "rgba(255, 255, 255, 0.1)",
        border_secondary_dark = "rgba(255, 255, 255, 0.1)",
        shadow_color_soft_dark = "rgba(255, 255, 255, 0.2)",
        shadow_color_button_dark = "rgba(255, 255, 255, 0.2)",
        shadow_color_inset_dark = "rgba(0, 0, 0, 0.5)",
        glow_color_dark = "rgba(10, 155, 55, 0.5)",
        hover_bg_dark = "rgba(255, 255, 255, 0.1)",
        menu_hover_bg_dark = "rgba(255, 255, 255, 0.05)",
        accent_blue_dark = "#0366d6",
        icon_color_dark = "#cccccc",
        icon_hover_color_dark = "#ffffff",
        icon_filter_dark = "invert(1)",
        icon_hover_filter_dark = "invert(1) brightness(1.2)",
        scrollbar_track_dark = "#2d2d2d",
        scrollbar_thumb_dark = "#555555",
        scrollbar_thumb_hover_dark = "#777777",
        # Section overrides
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
        ui_styles = Styles()
    )

    # Set Makie theme and Monaco editor based on system preference

    # Define theme media queries based on light_theme setting
    light_media_query = if light_theme === nothing
        BonitoBook.monaco_theme!(book, "default")  # Auto-detect in JS
        "@media (prefers-color-scheme: light)"
    elseif light_theme === true
        BonitoBook.monaco_theme!(book, "vs")  # Force light Monaco theme
        "@media screen"  # Apply directly to root
    else
        BonitoBook.monaco_theme!(book, "vs-dark")  # Force dark Monaco theme
        "@media (max-width: 0px)"  # Never apply
    end

    dark_media_query = if light_theme === nothing
        "@media (prefers-color-scheme: dark)"
    elseif light_theme === false
        "@media screen" # Apply directly to root
    else
        "@media (max-width: 0px)"  # Never apply
    end

    on(book.theme_preference) do browser_preference
        Makie = MakieModule()
        Makie === nothing && return
        theme = light_theme === nothing ? browser_preference : (light_theme ? "light" : "dark")
        if theme == "light"
            Makie.set_theme!(size = (650, 450))
        else
            Makie.set_theme!(Makie.theme_dark(), size = (650, 450))
        end
    end

    # Build layout variables section
    _layout_variables = Styles(
        Styles(
            CSS(
                ":root",
                # Layout dimensions
                "--editor-width" => editor_width,
                "--editor-min-width" => editor_min_width,
                "--editor-max-width" => editor_max_width,
                "--max-height-large" => max_height_large,
                "--max-height-medium" => max_height_medium,
                "--border-radius-small" => border_radius_small,
                "--border-radius-large" => border_radius_large,
                "--transition-fast" => transition_fast,
                "--transition-slow" => transition_slow,
                "--text-font" => text_font,
                "--mono-font" => mono_font,
                # Common spacing
                "--spacing-xxs" => spacing_xxs,
                "--spacing-xs" => spacing_xs,
                "--spacing-sm" => spacing_sm,
                "--spacing-md" => spacing_md,
                "--spacing-lg" => spacing_lg,
                "--spacing-xl" => spacing_xl,
                # Shadow-specific blur sizes
                "--shadow-blur-sm" => shadow_blur_sm,
                "--shadow-blur-md" => shadow_blur_md,
                # Typography
                "--font-size-xs" => font_size_xs,
                "--font-size-sm" => font_size_sm,
                "--font-size-base" => font_size_base,
                "--font-size-lg" => font_size_lg,
                # Common dimensions
                "--width-xs" => width_xs,
                "--width-sm" => width_sm,
                "--width-md" => width_md,
                "--width-lg" => width_lg,
                # Z-index layers
                "--z-behind" => z_behind,
                "--z-base" => z_base,
                "--z-dropdown" => z_dropdown,
                "--z-overlay" => z_overlay,
                "--z-sidebar" => z_sidebar,
                "--z-modal" => z_modal,
                "--z-menu" => z_menu,
                "--z-popup" => z_popup,
                "--z-popup-close" => z_popup_close,
                # Reusable box-shadow patterns (use theme-specific color variables)
                "--shadow-soft" => "0 0 var(--spacing-xs) 0 var(--shadow-color-soft)",
                "--shadow-button" => "0 1px var(--shadow-blur-sm) 0 var(--shadow-color-button)",
                "--shadow-inset" => "inset 1px 1px var(--shadow-blur-sm) 0 var(--shadow-color-inset)",
                "--shadow-focus" => "0 0 0 var(--spacing-xss) var(--shadow-color-soft)",
                "--shadow-glow" => "0 0 var(--spacing-xs) 0 var(--accent-blue)",
                "--shadow-glow-animation" => "0 0 var(--shadow-blur-md) 0 var(--glow-color)",
            )
        ),
        layout_variables
    )

    # Base element styles
    _base_styles = Styles(
        Styles(
            # Global box-sizing and inheritance
            CSS(
                "*",
                "box-sizing" => "border-box",
                "-webkit-tap-highlight-color" => "transparent"
            ),
            CSS(
                "html",
                "background-color" => "var(--bg-primary)",
                "color" => "var(--text-primary)",
                "-webkit-text-size-adjust" => "100%",
                "text-size-adjust" => "100%"
            ),
            CSS(
                "body",
                "margin" => "0",
                "-webkit-font-smoothing" => "antialiased",
                "-moz-osx-font-smoothing" => "grayscale",
                "font-family" => "var(--text-font)"
            ),
            CSS("pre",
                "margin-block" => "var(--spacing-xs) 0px",
                "font-family" => "'Consolas', 'Monaco', 'Courier New', monospace"
            ),
            # Fix for Markdown list
            CSS("li p", "display" => "inline"),
            CSS(
                "mjx-container[jax='CHTML'][display='true']",
                "display" => "inline"
            ),
        ),
        base_styles
    )

    # Theme color variables
    _theme_styles = Styles(
        Styles(
            # Light theme colors
            CSS(
                light_media_query,
                CSS(
                    ":root",
                    "--bg-primary" => bg_primary_light,
                    "--text-primary" => text_primary_light,
                    "--text-secondary" => text_secondary_light,
                    "--border-primary" => border_primary_light,
                    "--border-secondary" => border_secondary_light,
                    "--shadow-color-soft" => shadow_color_soft_light,
                    "--shadow-color-button" => shadow_color_button_light,
                    "--shadow-color-inset" => shadow_color_inset_light,
                    "--glow-color" => glow_color_light,
                    "--hover-bg" => hover_bg_light,
                    "--menu-hover-bg" => menu_hover_bg_light,
                    "--accent-blue" => accent_blue_light,
                    "--icon-color" => icon_color_light,
                    "--icon-hover-color" => icon_hover_color_light,
                    "--icon-filter" => icon_filter_light,
                    "--icon-hover-filter" => icon_hover_filter_light,
                    "--scrollbar-track" => scrollbar_track_light,
                    "--scrollbar-thumb" => scrollbar_thumb_light,
                    "--scrollbar-thumb-hover" => scrollbar_thumb_hover_light,
                )
            ),

            # Dark theme colors
            CSS(
                dark_media_query,
                CSS(
                    ":root",
                    "--bg-primary" => bg_primary_dark,
                    "--text-primary" => text_primary_dark,
                    "--text-secondary" => text_secondary_dark,
                    "--border-primary" => border_primary_dark,
                    "--border-secondary" => border_secondary_dark,
                    "--shadow-color-soft" => shadow_color_soft_dark,
                    "--shadow-color-button" => shadow_color_button_dark,
                    "--shadow-color-inset" => shadow_color_inset_dark,
                    "--glow-color" => glow_color_dark,
                    "--hover-bg" => hover_bg_dark,
                    "--menu-hover-bg" => menu_hover_bg_dark,
                    "--accent-blue" => accent_blue_dark,
                    "--icon-color" => icon_color_dark,
                    "--icon-hover-color" => icon_hover_color_dark,
                    "--icon-filter" => icon_filter_dark,
                    "--icon-hover-filter" => icon_hover_filter_dark,
                    "--scrollbar-track" => scrollbar_track_dark,
                    "--scrollbar-thumb" => scrollbar_thumb_dark,
                    "--scrollbar-thumb-hover" => scrollbar_thumb_hover_dark,
                )
            ),
        ),
        theme_styles
    )

    # Print and export mode styles
    _print_export_styles = Styles(
        Styles(
        CSS(
            "@media print",
            # Preserve all colors and styles
            CSS(
                "*",
                "-webkit-print-color-adjust" => "exact !important",
                "print-color-adjust" => "exact !important",
                "color-adjust" => "exact !important",
                "filter" => "none !important"
            ),
            CSS(
                "@page",
                "margin" => "0.5in",
                "size" => "A4"
            ),
            CSS(
                "@page :first",
                "margin-top" => "0.3in"
            ),

            # Hide non-essential elements, but keep the content path visible
            CSS(
                ".book-main-menu, .cell-logging, .sidebar-main-container, .sidebar-tabs, .sidebar-content-container, .book-bottom-panel, .new-cell-menu, .hover-buttons",
                "display" => "none !important"
            ),
            # Ensure main structure is visible and flows properly, eliminating empty space
            CSS(
                ".book-wrapper, .book-document, .book-main-content, .book-content",
                "display" => "block !important",
                "height" => "auto !important",
                "max-height" => "none !important",
                "overflow" => "visible !important",
                "position" => "static !important",
                "flex" => "none !important",
                "margin" => "0 !important",
                "padding" => "0 !important"
            ),
        ),

        # Export mode styles - hide interactive elements when BONITO_EXPORT_MODE is true
        CSS(
            "body.bonito-export-mode .hover-buttons, body.bonito-export-mode .cell-menu-proximity-area, body.bonito-export-mode .new-cell-menu",
            "display" => "none !important"
        ),
        ),
        print_export_styles
    )

    # Mobile responsive styles
    _mobile_styles = Styles(
        Styles(
        # Tablet breakpoint (768px and below)
            CSS(
                "@media (max-width: 768px)",
                CSS(
                    ":root",
                    "--editor-width" => "95vw",
                )
            ),

            # Mobile breakpoint (480px and below)
            CSS(
                "@media (max-width: 480px)",
                CSS(
                    ":root",
                    "--border-radius-large" => "3px",
                    "--border-radius-small" => "2px"
                ),
                # Mobile-specific layout adjustments
                CSS(
                    ".markdown-body",
                    "overflow-wrap" => "break-word",
                    "word-break" => "break-word"
                ),

                # Reposition new cell plus button to avoid cutoff
                CSS(
                    ".new-cell-plus",
                    "left" => "-0.5rem",
                ),
                CSS(
                    ".new-cell-buttons",
                    "left" => "-0.5rem",
                ),
            ),
        ),
        mobile_styles
    )

    # Monaco editor and widgets
    _monaco_styles = Styles(
        Styles(
        # Monaco Widgets (find/command palette)
        CSS(
            ".quick-input-widget, .find-widget",
            "position" => "fixed !important",
            "top" => "10px !important"
        ),
        CSS(
            ".monaco-list",
            "max-height" => "var(--max-height-medium)",
            "overflow-y" => "auto !important",
            "-webkit-overflow-scrolling" => "touch"
        ),
        CSS(
            ".monaco-editor-div",
            "padding" => "0",
            "margin" => "0",
            "width" => "var(--editor-width)",
        ),
        CSS(
            ".sidebar-widget-content .monaco-editor-div.hide-horizontal",
            "display" => "block !important"
        ),
        ),
        monaco_styles
    )

    # Cell editor styles
    _editor_styles = Styles(
        Styles(
        # Editor containers
        CSS(
            ".cell-editor-container",
            "position" => "relative",
        ),
        CSS(
            ".cell-menu-proximity-area",
            "position" => "absolute",
            "top" => "-20px",
            "left" => "0",
            "height" => "20px",
            "width" => "100%",
            "background-color" => "transparent",
            "pointer-events" => "auto",
            "z-index" => "var(--z-behind)"
        ),
        # Special styling for collapsed editors - use container-level class
        CSS(
            ".cell-editor-container.editor-collapsed .cell-menu-proximity-area",
            "position" => "absolute",
            "top" => "0",
            "left" => "0",
            "height" => "6px",
            "width" => "100%",
            "background-color" => "transparent",
            "border" => "none",
            "border-radius" => "2px",
            "pointer-events" => "auto",
            "z-index" => "var(--z-base)",
            "transition" => "all var(--transition-slow)",
            "opacity" => "0"
        ),
        # Add visual feedback on hover for collapsed state
        CSS(
            ".cell-editor-container.editor-collapsed .cell-menu-proximity-area:hover",
            "background-color" => "var(--hover-bg)",
            "border-style" => "solid",
            "opacity" => "1",
            "transform" => "scaleY(1.2)"
        ),
        CSS(
            ".cell-editor",
            "width" => "fit-content",
            "position" => "relative",
            "padding" => "var(--spacing-sm) 0px var(--spacing-sm) 0px",
            "border-radius" => "var(--border-radius-large)",
            "box-shadow" => "var(--shadow-soft)"
        ),
        # Cell editor focus highlight - target elements that have both classes
        CSS(
            ".cell-editor.focused",
            "box-shadow" => "var(--shadow-glow)",
        ),

        # Logging output
        CSS(
            ".cell-logging",
            "max-height" => "500px",
            "max-width" => "var(--editor-width)",
            "overflow-y" => "auto",
            "margin" => "0",
            "padding" => "0",
        ),

        CSS(
            ".logging-widget",
            "height" => "100%",
            "width" => "100%",
            "overflow-y" => "auto",
            "margin" => "0",
            "padding" => "var(--spacing-sm)",
            "font-family" => "var(--mono-font)",
            "font-size" => "var(--font-size-xs)",
            "line-height" => "1.4",
            "white-space" => "pre-wrap",
            "word-wrap" => "break-word"
        ),
        CSS(
            ".logging-widget pre",
            "margin" => "0",
            "padding" => "0",
            "font" => "inherit",
            "white-space" => "pre-wrap",
            "word-wrap" => "break-word"
        ),

        # Hover buttons
        CSS(
            ".hover-buttons",
            "position" => "absolute",
            "right" => "-10px",
            "top" => "-23px",
            "z-index" => "var(--z-overlay)",
            "opacity" => 0.0,
            "pointer-events" => "auto",
        ),

        # Drag handle
        CSS(
            ".drag-handle",
            "cursor" => "grab",
            "opacity" => "0.7",
            "transition" => "all var(--transition-fast)",
        ),
        CSS(
            ".drag-handle:hover",
            "opacity" => "1",
            "background-color" => "var(--hover-bg)",
            "transform" => "scale(1.1)",
        ),
        CSS(
            ".drag-handle:active",
            "cursor" => "grabbing",
        ),
        # Dragging state
        CSS(
            ".dragging",
            "opacity" => "0.2 !important",
            "transform" => "scale(0.98)",
            "transition" => "transform var(--transition-fast)",
        ),
        # Drop indicator line
        CSS(
            ".drop-indicator",
            "height" => "4px",
            "background" => "var(--accent-blue)",
            "border-radius" => "2px",
            "margin" => "4px 0",
            "box-shadow" => "0 0 8px var(--accent-blue)",
            "z-index" => "var(--z-overlay)",
            "position" => "relative",
            "transition" => "all 0.1s ease",
        ),
        # Highlights for target cells
        CSS(
            ".drop-target-before",
            "border-top" => "2px solid var(--accent-blue) !important",
            "transition" => "border-top 0.1s ease",
        ),
        CSS(
            ".drop-target-after",
            "border-bottom" => "2px solid var(--accent-blue) !important",
            "transition" => "border-bottom 0.1s ease",
        ),

        # Cell output
        CSS(
            ".cell-output",
            "margin" => "var(--spacing-xs)",
            "overflow-y" => "auto",
            "overflow-x" => "visible",
            "width" => "var(--editor-width)",
            "-webkit-overflow-scrolling" => "touch",
            "font-family" => "var(--mono-font)"
        ),
        # Remove max-height for markdown outputs and use clean font
        CSS(
            ".cell-output-markdown.cell-output",
            "max-height" => "none",
            "overflow-y" => "visible",
            "font-family" => "var(--text-font)"
        ),
        # Visibility controls
        CSS(".hide-vertical", "display" => "none"),
        CSS(".show-vertical", "display" => "block"),

        # `book.logging_mode` is mirrored onto the body element as one
        # of these classes by a JS bridge in `standard_setup!`. The CSS
        # rules below force inline cell-logging visibility regardless
        # of the per-cell `editor.show_logging` setting — the runner
        # always captures the data; mode only affects whether you see
        # it inline.
        #   :respect_cell — no override; default behaviour wins.
        #   :hide_all     — force-hide every inline logging div.
        #   :show_all     — force-show every inline logging div.
        #   :console      — hide inline; the bottom-panel console
        #                   widget renders the attributed history.
        CSS("body.logmode-hide_all .cell-logging",
            "display" => "none !important"),
        CSS("body.logmode-show_all .cell-logging",
            "display" => "block !important",
            "height" => "auto !important",
            "overflow" => "visible !important"),
        CSS("body.logmode-console .cell-logging",
            "display" => "none !important"),
        # The bottom-panel "global logging" widget is only useful when
        # the user is actually pointing the console there. In every
        # other mode the attributed history is either hidden (`hide_all`)
        # or displayed inline alongside its cell (`show_all`,
        # `respect_cell`), so showing the panel as well would just
        # eat screen real estate.
        CSS("body:not(.logmode-console) .book-bottom-panel",
            "display" => "none"),

        # ── Logging-mode picker (inside the settings popup) ──────────
        CSS(".logmode-picker",
            "display" => "flex",
            "flex-direction" => "column",
            "gap" => "var(--spacing-xs)",
            "min-width" => "320px",
            "padding" => "var(--spacing-sm)"),
        CSS(".logmode-picker-title",
            "font-weight" => "600",
            "font-size" => "var(--font-size-base)",
            "margin-bottom" => "var(--spacing-xs)"),
        CSS(".logmode-option",
            "border" => "1px solid var(--border-secondary)",
            "border-radius" => "var(--border-radius-small)",
            "padding" => "var(--spacing-sm) var(--spacing-md)",
            "cursor" => "pointer",
            "transition" => "background-color var(--transition-fast)"),
        CSS(".logmode-option:hover",
            "background-color" => "var(--hover-bg)"),
        CSS(".logmode-option.active",
            "border-color" => "var(--accent-blue)",
            "background-color" => "var(--menu-hover-bg)"),
        CSS(".logmode-option-label",
            "font-weight" => "500",
            "font-size" => "var(--font-size-sm)"),
        CSS(".logmode-option-desc",
            "color" => "var(--text-secondary)",
            "font-size" => "var(--font-size-xs)",
            "margin-top" => "2px"),

        # ── Attributed console-log widget (bottom panel) ─────────────
        CSS(".console-log-widget",
            "display" => "flex",
            "flex-direction" => "column",
            "height" => "100%"),
        CSS(".console-entries",
            "flex" => "1",
            "overflow-y" => "auto",
            "padding" => "var(--spacing-xs) var(--spacing-sm)",
            "font-family" => "var(--mono-font)",
            "font-size" => "var(--font-size-sm)"),
        CSS(".console-entry",
            "display" => "flex",
            "gap" => "var(--spacing-sm)",
            "padding" => "2px 0",
            "align-items" => "baseline"),
        # The cell-id badge is the only attribution surface; keep it
        # narrow + monospaced so prose output to the right doesn't
        # ragged-edge across rows.
        CSS(".console-cell-id",
            "color" => "var(--text-secondary)",
            "font-size" => "var(--font-size-xs)",
            "min-width" => "4.5rem",
            "text-align" => "right",
            "user-select" => "none"),
        CSS(
            ".hide-horizontal",
            "height" => "6px",
            "overflow" => "hidden",
            "position" => "relative"
        ),
        CSS(
            ".show-horizontal",
            "display" => "block",
        ),

        # Loading animation
        CSS(
            ".loading-cell",
            "box-shadow" => "var(--shadow-soft)",
            "animation" => "shadow-pulse 1.5s ease-in-out infinite",
        ),
        CSS(
            "@keyframes shadow-pulse",
            CSS("0%", "box-shadow" => "var(--shadow-soft)"),
            CSS("50%", "box-shadow" => "var(--shadow-glow-animation)"),
            CSS("100%", "box-shadow" => "var(--shadow-soft)")
        ),

        # Language icon - fixed size to prevent unexpected sizing issues
        CSS(
            ".small-language-icon",
            "position" => "absolute",
            "bottom" => "4px",
            "right" => "8px",
            "opacity" => "0.8",
            "pointer-events" => "none",
            "color" => "var(--icon-color)",
            "filter" => "var(--icon-filter)",
            "width" => "10px !important",
            "height" => "10px !important",
            "max-width" => "10px !important",
            "max-height" => "10px !important"
        ),
        # Ensure language icon images don't grow
        CSS(
            ".small-language-icon img",
            "width" => "10px !important",
            "height" => "10px !important",
            "max-width" => "10px !important",
            "max-height" => "10px !important",
            "object-fit" => "contain"
        ),
        ),
        editor_styles
    )

    # Icon system styles
    _icon_styles = Styles(
        Styles(
        # Codicon system
        CSS(
            ".codicon",
            "display" => "inline-block",
            "text-decoration" => "none",
            "text-rendering" => "auto",
            "text-align" => "center",
            "text-transform" => "none",
            "-webkit-font-smoothing" => "antialiased",
            "-moz-osx-font-smoothing" => "grayscale",
            "user-select" => "none",
            "-webkit-user-select" => "none",
            "-moz-user-select" => "none",
            "-ms-user-select" => "none",
            "flex-shrink" => "0",
            "color" => "var(--icon-color)",
            "filter" => "var(--icon-filter)"
        ),
        CSS(
            ".codicon svg",
            "display" => "block",
            "fill" => "currentColor"
        ),
        CSS(
            ".codicon:hover",
            "color" => "var(--icon-hover-color)",
            "filter" => "var(--icon-hover-filter)"
        ),

        # Only apply filters to specific icon contexts, not general content
        CSS(
            ".small-button img:not([src*='python-logo']):not([src*='julia-logo']), .small-button svg",
            "filter" => "var(--icon-filter)"
        ),
        CSS(
            ".small-button:hover img:not([src*='python-logo']):not([src*='julia-logo']), .small-button:hover svg",
            "filter" => "var(--icon-hover-filter)"
        ),
        # Only apply filter to small icons in codicon system, not content SVGs
        CSS(
            ".codicon svg, .small-language-icon svg, .codicon img",
            "filter" => "var(--icon-filter)"
        ),

        # Colored icons - handle separately for dark theme
        CSS(
            dark_media_query,
            CSS(
                "img[src*='python-logo'], img[src*='julia-logo']",
                "filter" => "brightness(1.3) contrast(1.1)"
            )
        ),
        ),
        icon_styles
    )

    # Markdown and content styling
    _markdown_styles = Styles(
        Styles(
        # Markdown styling
        CSS(
            ".markdown-body",
            "-ms-text-size-adjust" => "100%",
            "-webkit-text-size-adjust" => "100%",
            "text-size-adjust" => "100%",
            "color" => "var(--text-primary)",
            "line-height" => "1.5",
            "font-family" => "var(--text-font)",
            "font-size" => "16px",
            "word-wrap" => "break-word"
        ),
        CSS(
            ".markdown-body .octicon",
            "display" => "inline-block",
            "fill" => "currentColor",
            "vertical-align" => "text-bottom"
        ),
        CSS(
            ".markdown-body .anchor",
            "float" => "left",
            "line-height" => "1",
            "margin-left" => "-20px",
            "padding-right" => "4px"
        ),
        CSS(".markdown-body .anchor:focus", "outline" => "none"),
        CSS(
            ".markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6",
            "margin-bottom" => "0", "margin-top" => "0"
        ),
        CSS(".markdown-body h1", "font-size" => "32px", "font-weight" => "600"),
        CSS(".markdown-body h2", "font-size" => "24px", "font-weight" => "600"),
        CSS(".markdown-body h3", "font-size" => "20px", "font-weight" => "600"),
        CSS(".markdown-body h4", "font-size" => "16px", "font-weight" => "600"),
        CSS(".markdown-body h5", "font-size" => "14px", "font-weight" => "600"),
        CSS(".markdown-body h6", "font-size" => "12px", "font-weight" => "600"),
        CSS(".markdown-body a", "color" => "var(--accent-blue)", "text-decoration" => "none"),
        CSS(".markdown-body a:hover", "text-decoration" => "underline"),
        CSS(".markdown-body strong", "font-weight" => "600"),
        CSS(
            ".markdown-body hr",
            "background" => "transparent",
            "border" => "0",
            "border-bottom" => "1px solid #dfe2e5",
            "height" => "0",
            "margin" => "var(--spacing-lg) 0",
            "overflow" => "hidden"
        ),
        CSS(
            ".markdown-body table",
            "border-collapse" => "collapse",
            "border-spacing" => "0"
        ),
        CSS(".markdown-body td, .markdown-body th", "padding" => "0"),
        CSS(
            ".markdown-body blockquote",
            "border-left" => ".25em solid #dfe2e5",
            "color" => "#6a737d",
            "padding" => "0 1em"
        ),
        CSS(
            ".markdown-body code, .markdown-body pre",
            "font-family" => "SFMono-Regular,Consolas,Liberation Mono,Menlo,Courier,monospace",
            "font-size" => "12px"
        ),
        CSS(".markdown-body pre", "margin-bottom" => "0", "margin-top" => "0"),
        CSS(".markdown-body img", "border-style" => "none"),
        CSS(".markdown-body input", "font" => "inherit", "overflow" => "visible"),
        ),
        markdown_styles
    )

    # Data visualization and output styles
    _data_styles = Styles(
        Styles(
        # DataFrame styling
        CSS(
            ".data-frame",
            "margin" => "1rem 0"
        ),
        CSS(
            ".data-frame table",
            "border-collapse" => "collapse",
            "font-size" => "13px",
            "font-family" => "var(--mono-font)"
        ),
        CSS(
            ".data-frame th",
            "padding" => "8px 12px",
            "background-color" => "var(--hover-bg)",
            "font-weight" => "500",
            "border-bottom" => "1px solid var(--border-primary)",
            "font-family" => "var(--mono-font)"
        ),
        CSS(
            ".data-frame td",
            "padding" => "6px 12px",
            "border-bottom" => "1px solid var(--border-primary)",
            "font-family" => "var(--mono-font)"
        ),
        CSS(
            ".data-frame .rowLabel",
            "background-color" => "var(--hover-bg)",
            "font-family" => "var(--mono-font)",
            "text-align" => "right"
        ),
        ),
        data_styles
    )

    # UI component styles (scrollbars, buttons, menus, etc.)
    _ui_styles = Styles(
        Styles(
        # Utility classes
        CSS(".flex-row", "display" => "flex", "flex-direction" => "row"),
        CSS(".flex-column", "display" => "flex", "flex-direction" => "column"),
        CSS(".center-content", "justify-content" => "center", "align-items" => "center"),
        CSS(".inline-block", "display" => "inline-block"),
        CSS(".fit-content", "width" => "fit-content"),
        CSS(".max-width-90ch", "max-width" => "90ch"),
        CSS(".gap-10", "gap" => "10px"),
        CSS(".full-width", "width" => "100%"),

        # Scrollbar styling
        CSS(
            "::-webkit-scrollbar",
            "width" => "12px",
            "height" => "12px"
        ),
        CSS(
            "::-webkit-scrollbar-track",
            "background" => "var(--scrollbar-track)"
        ),
        CSS(
            "::-webkit-scrollbar-thumb",
            "background-color" => "var(--scrollbar-thumb)",
            "border-radius" => "6px",
            "border" => "2px solid var(--scrollbar-track)"
        ),
        CSS(
            "::-webkit-scrollbar-thumb:hover",
            "background-color" => "var(--scrollbar-thumb-hover)"
        ),
        # Firefox scrollbar
        CSS(
            "*",
            "scrollbar-width" => "thin",
            "scrollbar-color" => "var(--scrollbar-thumb) var(--scrollbar-track)"
        ),

        # Menu and Buttons
        CSS(
            ".small-menu-bar",
            "z-index" => "var(--z-menu)",
            "border" => "1px solid var(--border-primary)",
            "border-radius" => "var(--spacing-sm)",
            "box-shadow" => "var(--shadow-soft)",
            "padding" => "6px",
            "display" => "flex",
            "gap" => "4px",
            "align-items" => "center"
        ),
        CSS(
            ".small-button.toggled",
            "color" => "var(--text-primary)",
            "border" => "none",
            "filter" => "grayscale(100%)",
            "opacity" => "0.5",
            "box-shadow" => "var(--shadow-inset)",
        ),
        CSS(
            ".small-button",
            "background-color" => "var(--bg-primary)",
            "border" => "none",
            "border-radius" => "var(--spacing-sm)",
            "color" => "var(--text-secondary)",
            "cursor" => "pointer",
            "box-shadow" => "var(--shadow-button)",
            "transition" => "background-color var(--transition-slow)",
            "padding" => "var(--spacing-sm)",
            "margin-right" => "var(--spacing-xs)",
            "display" => "inline-flex",
            "align-items" => "center",
            "justify-content" => "center"
        ),
        CSS(
            ".toggle-button.active",
            "box-shadow" => "var(--shadow-inset)",
            "color" => "var(--text-primary)",
        ),
        CSS(
            ".small-button:hover",
            "background-color" => "var(--hover-bg)",
        ),
        CSS(
            ".small-button.inactive",
            "opacity" => "0.4",
            "cursor" => "not-allowed",
        ),
        CSS(
            ".small-button.inactive:hover",
            "background-color" => "inherit"
        ),

        CSS(
            ".file-tabs-container",
            "display" => "flex",
            "border-bottom" => "1px solid var(--border-primary)",
            "overflow-x" => "auto",
            "flex-shrink" => "0"
        ),
        CSS(
            ".file-tab",
            "display" => "flex",
            "align-items" => "center",
            "padding" => "8px 4px",
            "border-bottom" => "2px solid transparent",
            "color" => "var(--text-secondary)",
            "cursor" => "pointer",
            "transition" => "all var(--transition-slow)",
            "border-radius" => "6px 6px 0 0",
            "margin-right" => "2px",
            "user-select" => "none"
        ),
        CSS(
            ".file-tab:hover",
            "background-color" => "var(--hover-bg)",
            "color" => "var(--text-primary)",
        ),
        CSS(
            ".file-tab.active",
            "color" => "var(--text-primary)",
            "border-bottom-color" => "var(--accent-blue)",
            "font-weight" => "500"
        ),
        CSS(
            ".file-tab-content",
            "display" => "flex",
            "align-items" => "center",
            "gap" => "6px",
        ),
        CSS(
            ".file-tab-name",
            "font-size" => "var(--font-size-sm)",
            "max-width" => "150px",
            "overflow" => "hidden",
            "text-overflow" => "ellipsis",
            "white-space" => "nowrap",
        ),
        CSS(
            ".file-tab-close",
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center",
            "width" => "var(--width-xs)",
            "height" => "var(--width-xs)",
            "border-radius" => "50%",
            "background-color" => "transparent",
            "border" => "none",
            "color" => "var(--text-secondary)",
            "cursor" => "pointer",
            "font-size" => "var(--font-size-xs)",
            "line-height" => "1",
            "transition" => "all var(--transition-slow)",
        ),
        CSS(
            ".file-tab-close:hover",
            "background-color" => "var(--hover-bg)",
            "color" => "var(--text-primary)",
        ),
        CSS(
            ".file-tab-add",
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center",
            "padding" => "8px 12px",
            "background-color" => "transparent",
            "border" => "none",
            "color" => "var(--text-secondary)",
            "cursor" => "pointer",
            "font-size" => "16px",
            "line-height" => "1",
            "transition" => "all var(--transition-slow)",
            "border-radius" => "6px",
        ),
        CSS(
            ".file-tab-add:hover",
            "background-color" => "var(--hover-bg)",
            "color" => "var(--text-primary)",
        ),

        CSS(
            ".file-editor",
            "padding" => "0",
            "margin" => "0",
            "width" => "100%",
            "min-width" => "var(--editor-width)",
            # 100% of `.editor-container` (which is `flex: 1; min-height: 0`
            # inside `.tabbed-file-editor`). Sourcing height from the flex
            # chain rather than viewport units removes a redundant ResizeObserver
            # path: when the URL bar slides, only `.tabbed-file-editor` reflows
            # — Monaco's wrapper no longer self-recomputes from `dvh` on top
            # of that.
            "height" => "100%"
        ),

        CSS(
            ".sidebar-widget-content .monaco-editor-div.hide-horizontal",
            "display" => "block !important",
        ),

        # New Cell Menu - Redesigned
        CSS(
            ".new-cell-menu",
            "position" => "relative",
            "width" => "100%",
            "height" => "0.5rem", # Reduced space between cells
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center", # Center content to help with alignment
            "padding-left" => "0", # Remove padding to position plus further left
        ),
        CSS(
            ".new-cell-plus",
            "position" => "absolute",
            "left" => "-1rem",
            "top" => "0",
            "transform" => "translate(0, -50%)", # Center vertically
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center",
            "opacity" => "0.3",
            "transition" => "opacity 0.2s",
            "cursor" => "pointer",
            "font-size" => "1.2em",
            "font-weight" => "1000",
        ),
        CSS(
            ".new-cell-menu:hover .new-cell-plus",
            "opacity" => "1",
        ),
        CSS(
            ".new-cell-buttons",
            "position" => "absolute",
            "left" => "0",
            "top" => "0",
            "transform" => "translate(0, -50%)", # Center vertically
            "display" => "flex",
            "opacity" => "0",
            "visibility" => "hidden",
            "transition" => "opacity 0.2s, visibility 0.2s",
            "z-index" => "var(--z-modal)", # Above other content
            "padding" => "4px 4px",
        ),
        CSS(
            ".new-cell-menu:hover .new-cell-buttons",
            "opacity" => "1",
            "visibility" => "visible",
        ),

        # Popup styling for file dialogs
        CSS(
            ".popup-overlay",
            "position" => "fixed",
            "top" => "0",
            "left" => "0",
            "width" => "100vw",
            "height" => "100dvh",
            "background-color" => "rgba(0, 0, 0, 0.5)",
            "z-index" => "var(--z-popup)",
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center",
        ),
        CSS(
            ".popup-content",
            "position" => "relative",
            "background-color" => "var(--bg-primary)",
            "border-radius" => "var(--border-radius-large)",
            "box-shadow" => "var(--shadow-soft)",
            "border" => "1px solid var(--border-primary)",
            "max-width" => "90vw",
            "max-height" => "90vh",
            "overflow" => "auto",
            "color" => "var(--text-primary)",
            "padding" => "16px",
            "margin" => "20px",
            "width" => "fit-content",
            "height" => "fit-content",
        ),
        CSS(
            ".popup-close-button",
            "position" => "absolute",
            "top" => "4px",
            "right" => "4px",
            "background" => "none",
            "border" => "none",
            "font-size" => "18px",
            "color" => "var(--text-secondary)",
            "cursor" => "pointer",
            "padding" => "2px",
            "border-radius" => "50%",
            "width" => "var(--width-sm)",
            "height" => "var(--width-sm)",
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center",
            "transition" => "all var(--transition-slow)",
            "z-index" => "var(--z-popup-close)",
            "line-height" => "1",
        ),
        CSS(
            ".popup-close-button:hover",
            "background-color" => "var(--hover-bg)",
            "color" => "var(--text-primary)",
        ),

        # Book layout classes
        CSS(
            ".book-main-menu",
            "position" => "relative",
            "display" => "flex",
            "flex-direction" => "row",
            "width" => "100%",
            "justify-content" => "center"
        ),
        CSS(
            ".book-main-menu .file-tabs-container",
            "justify-content" => "center",
            "border-bottom" => "none" # Remove border from tabs in menu
        ),
        CSS(
            ".book-menu-container",
            "position" => "sticky",
            "top" => "0",
            "width" => "100%",
            "display" => "flex",
            "flex-direction" => "column",
            "align-items" => "center",
            "background-color" => "var(--bg-primary)",
            "z-index" => "var(--z-menu)",
            "padding" => "var(--spacing-sm) 0",
        ),
        CSS(
            ".book-content",
            "overflow" => "hidden", # Prevent the container from scrolling
        ),
        CSS(
            ".book-cells",
            "width" => "fit-content", # Prevent the container from scrolling
            "padding-bottom" => "200px", # Add space at bottom for last cell's output and menu
        ),
        CSS(
            ".book-cells-area",
            "flex" => "1",
            "overflow-y" => "auto",
            "overflow-x" => "hidden",
            "width" => "100%",
            "display" => "flex",
            "flex-direction" => "column",
            "align-items" => "center",
            "-webkit-overflow-scrolling" => "touch"
        ),
        CSS(
            ".book-main-content",
            "overflow" => "hidden",
            "flex" => "1",
            "display" => "flex",
            "flex-direction" => "column",
            "height" => "100%",
        ),
        CSS(
            ".book-document",
            "display" => "flex",
            "flex-direction" => "column",
            "height" => "100dvh",
            "width" => "100vw",
            "overflow" => "hidden"
        ),
        CSS(
            ".book-wrapper",
            "overflow" => "hidden",
            "height" => "100dvh",
            "width" => "100vw",
            "display" => "flex",
            "flex-direction" => "column"
        ),
        CSS(
            ".book-bottom-panel",
            "position" => "fixed",
            "bottom" => "0",
            "left" => "0",
            "right" => "0",
            "z-index" => "var(--z-modal)"
        ),


        # Sidebar styles
        CSS(
            ".sidebar-main-container",
            "position" => "fixed",  # Use fixed positioning
            "right" => "0",
            "display" => "flex",
            "z-index" => "var(--z-sidebar)",
            "pointer-events" => "none",
        ),
        # Vertical sidebar - center and size to content
        CSS(
            ".sidebar-main-container.vertical",
            "top" => "50%",
            "transform" => "translateY(-50%)",
            "align-items" => "center",
            "height" => "fit-content",
            "max-height" => "90vh",
            "flex-direction" => "row-reverse",  # Keep tabs on the right
        ),
        # Horizontal sidebar - fill width at bottom
        CSS(
            ".sidebar-main-container.horizontal",
            "bottom" => "0",
            "left" => "0",
            "right" => "0",
            "width" => "100%",
            "align-items" => "flex-end",
        ),
        CSS(
            ".sidebar-content-container",
            "transition" => "width 0.3s ease, opacity 0.3s ease",
            "overflow" => "hidden",
            "pointer-events" => "auto"
        ),
        # Vertical sidebar specific - resize to content and stay connected
        CSS(
            ".sidebar-content-container.vertical",
            "height" => "fit-content",
            "max-height" => "80vh",
            "display" => "flex",
            "flex-direction" => "column",
            "border-left" => "1px solid var(--border-primary)",
            "border-radius" => "8px 0 0 8px",
            "box-shadow" => "-var(--spacing-xs) 0 var(--spacing-sm) 0 var(--shadow-color-soft)"
        ),
        CSS(
            ".sidebar-content-container.collapsed",
            "width" => "0",
            "opacity" => "0",
            "visibility" => "hidden",
        ),
        CSS(
            ".sidebar-content-container.expanded",
            "opacity" => "1",
            "visibility" => "visible",
        ),
        # Vertical expanded state - use sidebar width
        CSS(
            ".sidebar-content-container.vertical.expanded",
            "width" => "var(--sidebar-width, 400px)",
        ),
        # Horizontal sidebar styles
        CSS(
            ".sidebar-content-container.horizontal.expanded",
            "opacity" => "1",
            "visibility" => "visible",
            "height" => "var(--sidebar-height, 300px)",
        ),
        CSS(
            ".sidebar-content-container.horizontal",
            "border-top" => "1px solid var(--border-primary)",
            "transition" => "height 0.3s ease, opacity 0.3s ease",
            "overflow" => "hidden",
            "width" => "100%",
            "opacity" => "1",
            "visibility" => "visible"
        ),
        CSS(
            ".sidebar-content-container.horizontal.collapsed",
            "height" => "0",
            "opacity" => "0",
            "visibility" => "hidden",
        ),
        CSS(
            ".sidebar-main-container.horizontal",
            "position" => "relative",
            "width" => "100%",
            "display" => "flex",
            "flex-direction" => "column-reverse",
            "height" => "auto",
        ),
        CSS(
            ".sidebar-tabs.horizontal",
            "display" => "flex",
            "flex-direction" => "row",
            "justify-content" => "center",
            "background-color" => "var(--bg-primary)",
            "border-top" => "1px solid var(--border-primary)",
            "padding" => "var(--spacing-xs)",
            "width" => "100%",
            "height" => "auto",
        ),
        CSS(
            ".sidebar-tabs",
            "width" => "48px",
            "border-left" => "1px solid var(--border-primary)",
            "border-radius" => "0 8px 8px 0",
            "display" => "flex",
            "flex-direction" => "column",
            "align-items" => "center",
            "padding-top" => "var(--spacing-sm)",
            "gap" => "var(--spacing-xs)",
            "flex-shrink" => "0",
            "pointer-events" => "auto",
            "height" => "fit-content"
        ),
        CSS(
            ".sidebar-tab",
            "position" => "relative",
        ),
        CSS(
            ".sidebar-tab.active::before",
            "content" => "''",
            "position" => "absolute",
            "left" => "0",
            "top" => "50%",
            "transform" => "translateY(-50%)",
            "width" => "3px",
            "height" => "18px",
            "background-color" => "var(--accent-blue)",
            "border-radius" => "0 3px 3px 0",
        ),
        CSS(
            ".sidebar-toggle-button",
            "width" => "var(--width-md)",
            "height" => "var(--width-md)",
            "border" => "none",
            "background-color" => "transparent",
            "color" => "var(--icon-color)",
            "cursor" => "pointer",
            "border-radius" => "var(--spacing-xs)",
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center",
            "transition" => "all var(--transition-slow)",
            "margin-top" => "auto",
            "margin-bottom" => "var(--spacing-sm)",
        ),
        CSS(
            ".sidebar-toggle-button:hover",
            "background-color" => "var(--hover-bg)",
            "color" => "var(--icon-hover-color)",
        ),
        CSS(
            ".sidebar-toggle-button.hidden",
            "display" => "none",
        ),
        CSS(
            ".sidebar-content",
            "overflow-y" => "auto",
            "overflow-x" => "hidden",
            "padding" => "0",
            "width" => "100%",
            "position" => "relative",
            "height" => "100%",
            "-webkit-overflow-scrolling" => "touch"
        ),
        # Vertical sidebar content - adapt height to content
        CSS(
            ".sidebar-content-container.vertical .sidebar-content",
            "height" => "fit-content",
            "min-height" => "200px",  # Minimum height for usability
            "overflow-y" => "visible",
        ),
        CSS(
            ".sidebar-widget-content",
            "width" => "100%",
            "height" => "fit-content",
        ),
        CSS(
            ".sidebar-widget-content.hide",
            "display" => "none",
        ),
        CSS(
            ".sidebar-widget-content.show",
            "display" => "block",
        ),

        # Resize handle - base styles
        CSS(
            ".sidebar-resize-handle",
            "position" => "absolute",
            "background-color" => "transparent",
            "z-index" => "var(--z-dropdown)",
            "transition" => "background-color 0.2s ease",
        ),
        CSS(
            ".sidebar-resize-handle:hover",
            "background-color" => "var(--accent-blue)",
            "opacity" => "0.5",
        ),
        # Vertical sidebar resize handle (drag left/right)
        CSS(
            ".sidebar-resize-handle.vertical",
            "left" => "0",
            "top" => "0",
            "bottom" => "0",
            "width" => "4px",
            "cursor" => "ew-resize",
        ),
        # Horizontal sidebar resize handle (drag up/down)
        CSS(
            ".sidebar-resize-handle.horizontal",
            "top" => "0",
            "left" => "0",
            "right" => "0",
            "height" => "4px",
            "cursor" => "ns-resize",
        ),

        # Adjust book content to account for sidebar
        CSS(
            ".book-content",
            "display" => "flex",
            "flex-direction" => "row",
            "width" => "100%",
            "height" => "100%",
            "flex" => "1",
            "overflow" => "hidden",
            "position" => "relative",
        ),

        # BonitoBook Components Styling
        CSS(
            ".bonitobook-button",
            "border" => "1px solid var(--border-secondary)",
            "border-radius" => "var(--spacing-xs)",
            "padding" => "var(--spacing-sm) var(--spacing-lg)",
            "font-size" => "var(--font-size-base)",
            "font-weight" => "500",
            "cursor" => "pointer",
            "transition" => "all var(--transition-slow)",
            "box-shadow" => "var(--shadow-button)",
            "min-width" => "80px",
            "display" => "inline-flex",
            "align-items" => "center",
            "justify-content" => "center",
            "background-color" => "var(--bg-primary)",
            "color" => "var(--text-primary)"
        ),
        CSS(
            ".bonitobook-button:hover",
            "background-color" => "var(--hover-bg)",
            "border-color" => "var(--accent-blue)",
        ),
        CSS(
            ".bonitobook-button:focus",
            "outline" => "none",
            "border-color" => "var(--accent-blue)",
            "box-shadow" => "var(--shadow-focus)"
        ),
        CSS(
            ".bonitobook-button:active",
            "transform" => "translateY(1px)",
            "box-shadow" => "0 var(--spacing-xs) var(--spacing-sm) 0 var(--shadow-color-button)"
        ),

        # Input field styling
        CSS(
            ".bonitobook-input",
            "border" => "1px solid var(--border-secondary)",
            "border-radius" => "var(--spacing-xs)",
            "padding" => "var(--spacing-sm) var(--spacing-md)",
            "font-size" => "var(--font-size-base)",
            "transition" => "all var(--transition-slow)",
            "outline" => "none",
            "width" => "100%",
            "background-color" => "var(--bg-primary)",
            "color" => "var(--text-primary)"
        ),
        CSS(
            ".bonitobook-input:hover",
            "border-color" => "var(--accent-blue)"
        ),
        CSS(
            ".bonitobook-input:focus",
            "border-color" => "var(--accent-blue)",
            "box-shadow" => "var(--shadow-focus)"
        ),
        CSS(
            ".bonitobook-input:disabled",
            "background-color" => "var(--hover-bg)",
            "color" => "var(--text-secondary)",
            "cursor" => "not-allowed"
        ),

        # Checkbox styling
        CSS(
            ".bonitobook-checkbox",
            "width" => "var(--width-xs)",
            "height" => "var(--width-xs)",
            "border" => "1px solid var(--border-secondary)",
            "border-radius" => "var(--spacing-xxs)",
            "cursor" => "pointer",
            "transition" => "all var(--transition-slow)",
            "appearance" => "none",
            "-webkit-appearance" => "none",
            "-moz-appearance" => "none",
            "position" => "relative",
            "margin" => "0 var(--spacing-sm) 0 0",
            "flex-shrink" => "0"
        ),
        CSS(
            ".bonitobook-checkbox:hover",
            "border-color" => "var(--accent-blue)"
        ),
        CSS(
            ".bonitobook-checkbox:focus",
            "outline" => "none",
            "border-color" => "var(--accent-blue)",
            "box-shadow" => "var(--shadow-focus)"
        ),
        CSS(
            ".bonitobook-checkbox:checked",
            "background-color" => "var(--accent-blue)",
            "border-color" => "var(--accent-blue)"
        ),
        CSS(
            ".bonitobook-checkbox:checked::after",
            "content" => "\"✓\"",
            "position" => "absolute",
            "top" => "50%",
            "left" => "50%",
            "transform" => "translate(-50%, -50%)",
            "color" => "white",
            "font-size" => "var(--font-size-xs)",
            "line-height" => "1"
        ),

        # Dropdown styling
        CSS(
            ".bonitobook-dropdown",
            "border" => "1px solid var(--border-secondary)",
            "border-radius" => "var(--spacing-xs)",
            "padding" => "var(--spacing-sm) var(--spacing-md)",
            "font-size" => "var(--font-size-base)",
            "cursor" => "pointer",
            "transition" => "all var(--transition-slow)",
            "outline" => "none",
            "width" => "100%",
            "appearance" => "none",
            "-webkit-appearance" => "none",
            "-moz-appearance" => "none",
            "background-repeat" => "no-repeat",
            "background-position" => "right var(--spacing-md) center",
            "background-size" => "var(--spacing-md)",
            "padding-right" => "36px",
            "background-color" => "var(--bg-primary)",
            "color" => "var(--text-primary)"
        ),
        CSS(
            ".bonitobook-dropdown:hover",
            "border-color" => "var(--accent-blue)"
        ),
        CSS(
            ".bonitobook-dropdown:focus",
            "border-color" => "var(--accent-blue)",
            "box-shadow" => "var(--shadow-focus)"
        ),

        # Light theme dropdown arrow
        CSS(
            light_media_query,
            CSS(
                ".bonitobook-dropdown",
                "background-image" => "url('data:image/svg+xml;charset=US-ASCII,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 5\"><path fill=\"%23666\" d=\"M2 0L0 2h4zm0 5L0 3h4z\"/></svg>')"
            )
        ),

        # Dark theme dropdown arrow
        CSS(
            dark_media_query,
            CSS(
                ".bonitobook-dropdown",
                "background-image" => "url('data:image/svg+xml;charset=US-ASCII,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 5\"><path fill=\"%23ccc\" d=\"M2 0L0 2h4zm0 5L0 3h4z\"/></svg>')"
            )
        ),
        CSS(
            ".bonitobook-card",
            "background-color" => "var(--bg-primary)",
            "color" => "var(--text-primary)",
            "padding" => "var(--spacing-sm)",
            "margin" => "var(--spacing-sm)",
            "border" => "1px solid var(--border-secondary)",
            "border-radius" => "var(--spacing-sm)",
            "box-shadow" => "var(--shadow-soft)",
            "overflow" => "hidden"
        ),
        # Slider styling
        CSS(
            ".bonitobook-slider",
            "width" => "100%",
            "height" => "6px",
            "border-radius" => "var(--spacing-xxs)",
            "background" => "var(--border-secondary)",
            "outline" => "none",
            "appearance" => "none",
            "-webkit-appearance" => "none",
            "-moz-appearance" => "none",
            "cursor" => "pointer",
            "transition" => "all 0.2s ease"
        ),
        CSS(
            ".bonitobook-slider::-webkit-slider-thumb",
            "appearance" => "none",
            "-webkit-appearance" => "none",
            "-moz-appearance" => "none",
            "width" => "var(--width-sm)",
            "height" => "var(--width-sm)",
            "border-radius" => "50%",
            "background" => "var(--accent-blue)",
            "cursor" => "pointer",
            "border" => "1px solid var(--bg-primary)",
            "box-shadow" => "0 var(--spacing-xxs) var(--spacing-xxs) 0 var(--shadow-color-button)",
            "transition" => "all 0.2s ease"
        ),
        CSS(
            ".bonitobook-slider::-webkit-slider-thumb:hover",
            "transform" => "scale(1.1)",
            "box-shadow" => "0 var(--spacing-xxs) var(--spacing-xs) 0 var(--shadow-color-button)"
        ),
        CSS(
            ".bonitobook-slider::-moz-range-thumb",
            "width" => "var(--width-sm)",
            "height" => "var(--width-sm)",
            "border-radius" => "50%",
            "background" => "var(--accent-blue)",
            "cursor" => "pointer",
            "border" => "2px solid var(--bg-primary)",
            "box-shadow" => "0 var(--spacing-xxs) 6px 0 var(--shadow-color-button)",
            "transition" => "all 0.2s ease"
        ),
        CSS(
            ".bonitobook-slider::-moz-range-track",
            "width" => "100%",
            "height" => "6px",
            "border-radius" => "var(--spacing-xxs)",
            "background" => "var(--border-secondary)",
            "border" => "none"
        ),
        CSS(
            ".bonitobook-slider:focus",
            "outline" => "none"
        ),
        CSS(
            ".bonitobook-slider:focus::-webkit-slider-thumb",
            "box-shadow" => "var(--shadow-focus), 0 var(--spacing-xxs) 6px 0 var(--shadow-color-button)"
        ),

        # Manipulate widget styling
        CSS(
            ".manipulate-container",
            "border" => "1px solid var(--border-primary)",
            "border-radius" => "var(--spacing-sm)",
            "padding" => "var(--spacing-lg)",
            "margin" => "var(--spacing-lg) 0",
            "display" => "flex",
            "flex-direction" => "column",
            "gap" => "var(--spacing-lg)"
        ),
        CSS(
            ".manipulate-controls",
            "padding" => "var(--spacing-md)",
            "display" => "flex",
            "flex-direction" => "column",
            "gap" => "var(--spacing-md)"
        ),
        CSS(
            ".manipulate-control-row",
            "display" => "flex",
            "align-items" => "center",
            "gap" => "var(--spacing-md)"
        ),
        CSS(
            ".manipulate-label",
            "font-size" => "var(--font-size-sm)",
            "font-weight" => "500",
            "color" => "var(--text-secondary)",
            "min-width" => "120px",
            "text-align" => "left",
            "flex-shrink" => "0"
        ),
        CSS(
            ".manipulate-widget",
            "flex" => "1",
            "min-width" => "0"
        ),
        CSS(
            ".manipulate-output",
            "border-radius" => "var(--spacing-xs)",
            "padding" => "var(--spacing-md)",
            "min-height" => "100px",
            "display" => "flex",
            "align-items" => "center",
            "justify-content" => "center"
        ),

        # Spinner component for export tasks
        CSS(
            ".book-spinner",
            "width" => "100%",
            "height" => "8px",
            "position" => "relative",
            "overflow" => "hidden",
            "pointer-events" => "none",
            "display" => "block",
            "background" => "repeating-linear-gradient(45deg, var(--accent-blue) 0px, var(--accent-blue) 10px, var(--border-primary) 10px, var(--border-primary) 20px)",
            "background-size" => "40px 100%",
            "animation" => "spinner-stripes 1.5s linear infinite",
            "border-radius" => "4px",
            "box-shadow" => "0 0 var(--spacing-sm) 0 var(--shadow-color-soft)"
        ),
        CSS(
            "@keyframes spinner-stripes",
            CSS("0%", "background-position" => "0 0"),
            CSS("100%", "background-position" => "40px 0")
        ),
        CSS(
            ".book-spinner.hidden",
            "opacity" => "0"
        ),

        # Cell editor focus highlight - target elements that have both classes
        CSS(
            ".cell-editor.focused",
            "box-shadow" => "var(--shadow-glow)",
        ),

        # Interactive Error Display Styling
        CSS(
            ".interactive-error-widget",
            "border" => "1px solid #dc3545",
            "border-radius" => "var(--spacing-sm)",
            "padding" => "var(--spacing-lg)",
            "margin" => "var(--spacing-sm) 0",
            "box-shadow" => "0 var(--spacing-xxs) var(--spacing-sm) 0 var(--shadow-color-soft)"
        ),

        # Error message styling
        CSS(
            ".interactive-error-widget h4",
            "color" => "#dc3545",
            "margin" => "0 0 var(--spacing-sm) 0",
            "font-size" => "1.1em",
            "font-weight" => "600"
        ),

        CSS(
            ".interactive-error-widget pre",
            "font-family" => "SFMono-Regular, Consolas, Liberation Mono, Menlo, Courier, monospace",
            "font-size" => "var(--font-size-sm)",
            "line-height" => "1.4",
            "white-space" => "pre-wrap",
            "word-wrap" => "break-word",
            "margin" => "var(--spacing-sm) 0",
            "padding" => "var(--spacing-md)",
            "border-radius" => "var(--spacing-xs)",
            "border" => "1px solid rgba(220, 53, 69, 0.2)"
        ),

        # Light theme error styling
        CSS(
            light_media_query,
            CSS(
                ".interactive-error-widget pre",
                "background-color" => "#f8d7da",
                "color" => "#721c24"
            )
        ),

        # Dark theme error styling
        CSS(
            dark_media_query,
            CSS(
                ".interactive-error-widget pre",
                "background-color" => "rgba(220, 53, 69, 0.1)",
                "color" => "#ffccd5"
            )
        ),

        # Stacktrace frame styling
        CSS(
            ".interactive-error-widget .collapsible-content > div > div",
            "margin" => "2px 0",
            "padding" => "4px 8px",
            "border-left" => "3px solid var(--border-primary)",
            "font-family" => "SFMono-Regular, Consolas, Liberation Mono, Menlo, Courier, monospace",
            "font-size" => "var(--font-size-xs)",
            "line-height" => "1.4",
            "border-radius" => "0 4px 4px 0",
            "transition" => "background-color 0.2s ease"
        ),

        # Light theme stacktrace frame
        CSS(
            light_media_query,
            CSS(
                ".interactive-error-widget .collapsible-content > div > div",
                "background-color" => "rgba(0, 0, 0, 0.05)"
            ),
            CSS(
                ".interactive-error-widget .collapsible-content > div > div:hover",
                "background-color" => "rgba(0, 0, 0, 0.08)"
            )
        ),

        # Dark theme stacktrace frame
        CSS(
            dark_media_query,
            CSS(
                ".interactive-error-widget .collapsible-content > div > div",
                "background-color" => "rgba(255, 255, 255, 0.05)"
            ),
            CSS(
                ".interactive-error-widget .collapsible-content > div > div:hover",
                "background-color" => "rgba(255, 255, 255, 0.08)"
            )
        ),

        # Clickable file link styling
        CSS(
            ".error-file-link",
            "color" => "var(--accent-blue)",
            "text-decoration" => "none",
            "cursor" => "pointer",
            "font-family" => "SFMono-Regular, Consolas, Liberation Mono, Menlo, Courier, monospace",
            "transition" => "all var(--transition-slow)",
            "border-radius" => "3px",
            "padding" => "1px 3px"
        ),

        CSS(
            ".error-file-link:hover",
            "text-decoration" => "underline",
            "background-color" => "rgba(3, 102, 214, 0.1)"
        ),

        # Function name styling in stacktrace
        CSS(
            ".interactive-error-widget span[style*='font-weight: bold']",
            "color" => "var(--text-primary)",
            "font-weight" => "600"
        ),

        ),
        ui_styles
    )

    # Combine all modular styles
    return Styles(
        _layout_variables, _base_styles, _theme_styles,
        _print_export_styles, _monaco_styles, _editor_styles,
        _icon_styles, _markdown_styles, _data_styles,
        _ui_styles, _mobile_styles
    )
end
