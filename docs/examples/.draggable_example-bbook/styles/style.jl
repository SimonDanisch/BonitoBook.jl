# Generate base style with default settings
style = BonitoBook.generate_style(current_book())

# Create plugin-specific styles for draggable canvas layout
draggable_styles = Styles(
    # Canvas workspace - full screen with absolute positioning
    CSS(
        ".draggable-canvas",
        "position" => "relative",
        "width" => "100vw",
        "height" => "100vh",
        "background-color" => "var(--bg-primary)",
        "overflow" => "hidden"
    ),

    # Draggable cell wrapper
    CSS(
        ".draggable-cell",
        "position" => "absolute",
        "z-index" => "10",
        "transition" => "box-shadow 0.2s ease",
        "border-radius" => "8px"
    ),

    # Drag handle for cells
    CSS(
        ".drag-handle",
        "position" => "absolute",
        "top" => "-15px",
        "left" => "50%",
        "transform" => "translateX(-50%)",
        "width" => "40px",
        "height" => "20px",
        "background-color" => "var(--accent-blue)",
        "border-radius" => "10px 10px 3px 3px",
        "cursor" => "grab",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "opacity" => "0.7",
        "transition" => "opacity 0.2s ease",
        "z-index" => "100"
    ),

    CSS(
        ".drag-handle:hover",
        "opacity" => "1",
        "cursor" => "grab"
    ),

    CSS(
        ".drag-handle:active, .drag-handle.dragging",
        "cursor" => "grabbing",
        "opacity" => "1"
    ),

    CSS(
        ".drag-handle::before",
        "content" => "\"⋮⋮\"",
        "color" => "white",
        "font-size" => "12px",
        "line-height" => "1",
        "letter-spacing" => "2px"
    ),

    # Draggable cell hover/active states
    CSS(
        ".draggable-cell:hover",
        "box-shadow" => "0 8px 25px rgba(0, 0, 0, 0.15)",
        "z-index" => "20"
    ),

    CSS(
        ".draggable-cell.dragging",
        "box-shadow" => "0 12px 35px rgba(0, 0, 0, 0.25)",
        "z-index" => "30",
        "cursor" => "grabbing"
    ),

    # Grid background for visual reference
    CSS(
        ".canvas-grid",
        "position" => "absolute",
        "top" => "0",
        "left" => "0",
        "width" => "100%",
        "height" => "100%",
        "opacity" => "0.1",
        "background-image" => "radial-gradient(circle, var(--border-primary) 1px, transparent 1px)",
        "background-size" => "20px 20px",
        "pointer-events" => "none",
        "z-index" => "1"
    ),

    # Cell editor overrides for canvas mode
    CSS(
        ".draggable-canvas .cell-editor-container",
        "position" => "relative",
        "max-width" => "none",
        "width" => "auto"
    ),
    CSS(
        "body",
        "margin" => "0px",
    ),
    CSS("pre",
        "margin-block" => "5px 0px",
        "font-family" => "'Consolas', 'Monaco', 'Courier New', monospace"
    ),
)
# Combine with main BonitoBook styles
Styles(style, draggable_styles)
