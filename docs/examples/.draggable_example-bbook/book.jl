module DraggableBooks

using Bonito, BonitoBook

# Draggable Canvas Book - demonstrates freely positionable CellEditors

struct DraggableBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
end

create_book(book::BonitoBook.Book; kw...) = DraggableBook(book)

# Drawing widget using Fabric.js for simple shapes
const FabricJS = Asset("https://cdnjs.cloudflare.com/ajax/libs/fabric.js/5.3.0/fabric.min.js")

# Drawing widget component
struct DrawingWidget
    width::Int
    height::Int

    function DrawingWidget(width::Int=400, height::Int=300)
        new(width, height)
    end
end

export DrawingWidget

function Bonito.jsrender(session::Session, widget::DrawingWidget)
    canvas_elem = DOM.canvas(
        width=widget.width,
        height=widget.height,
    )

    rect_button = DOM.button("Rectangle",
        class="bonitobook-button",
        style=Styles("margin-right" => "8px")
    )

    circle_button = DOM.button("Circle",
        class="bonitobook-button",
        style=Styles("margin-right" => "8px")
    )

    line_button = DOM.button("Line",
        class="bonitobook-button",
        style=Styles("margin-right" => "8px")
    )

    controls = DOM.div(
        rect_button, circle_button, line_button;
        style=Styles("margin-bottom" => "12px")
    )

    # JavaScript to initialize Fabric.js canvas
    init_js = js"""
        // Wait for Fabric.js to load and be available globally
        function initFabricCanvas() {
            if (typeof fabric === 'undefined') {
                console.log('Waiting for Fabric.js to load...');
                setTimeout(initFabricCanvas, 100);
                return;
            }
            console.log('Fabric.js loaded successfully');
            const canv_elem = $(canvas_elem);
            const canvas = new fabric.Canvas(canv_elem);
            canvas.setWidth($(widget.width));
            canvas.setHeight($(widget.height));

            // Get button references
            const rect_btn = $(rect_button);
            const circle_btn = $(circle_button);
            const line_btn = $(line_button);

            // Add shapes using simple button clicks
            function add_rectangle() {
                const rect = new fabric.Rect({
                    left: 100,
                    top: 100,
                    fill: 'red',
                    width: 20,
                    height: 20
                });
                canvas.add(rect);
            }

            function add_circle() {
                const circle = new fabric.Circle({
                    left: 50,
                    top: 50,
                    radius: 50,
                    fill: 'rgba(46, 204, 113, 0.3)',
                    stroke: '#2ecc71',
                    strokeWidth: 2
                });
                canvas.add(circle);
            }

            function add_line() {
                const line = new fabric.Line([50, 50, 150, 150], {
                    stroke: '#e74c3c',
                    strokeWidth: 2
                });
                canvas.add(line);
                canvas.setActiveObject(line);
                canvas.requestRenderAll();
            }
            // Register event listeners
            rect_btn.addEventListener('click', add_rectangle);
            circle_btn.addEventListener('click', add_circle);
            line_btn.addEventListener('click', add_line);
        }

        // Start initialization
        initFabricCanvas();
    """

    return Bonito.jsrender(session, DOM.div(
        FabricJS,
        DOM.div(
            DOM.h4("Drawing Canvas", style=Styles("color" => "var(--text-primary)", "margin-bottom" => "12px")),
            controls,
            canvas_elem,
            init_js,
            style=Styles("padding" => "16px", "border" => "1px solid var(--border-primary)", "border-radius" => "8px", "background-color" => "var(--bg-primary)")
        )
    ))
end

function make_draggable_cell(cell_editor, initial_x::Int, initial_y::Int)
    # Create drag handle
    drag_handle = DOM.div(class="drag-handle")
    # Wrap the cell editor in a draggable container
    draggable_cell = DOM.div(
        drag_handle,
        cell_editor;
        class="draggable-cell",
        style=Styles(
            "left" => "$(initial_x)px",
            "top" => "$(initial_y)px"
        )
    )
    # Add drag behavior with JavaScript - only responds to drag handle
    drag_js = js"""
        (function() {
            const cell = $(draggable_cell);
            const handle = $(drag_handle);
            let isDragging = false;
            let startX, startY, initialX, initialY;

            function onMouseDown(e) {
                // Only allow dragging when clicking the drag handle
                if (e.target !== handle && !handle.contains(e.target)) return;

                isDragging = true;
                cell.classList.add('dragging');
                handle.classList.add('dragging');

                startX = e.clientX;
                startY = e.clientY;

                // Get current position more reliably
                const rect = cell.getBoundingClientRect();
                const containerRect = cell.parentElement.getBoundingClientRect();
                initialX = rect.left - containerRect.left;
                initialY = rect.top - containerRect.top;

                e.preventDefault();
                e.stopPropagation();
            }

            function onMouseMove(e) {
                if (!isDragging) return;

                const deltaX = e.clientX - startX;
                const deltaY = e.clientY - startY;

                const newX = Math.max(0, initialX + deltaX);
                const newY = Math.max(20, initialY + deltaY); // Ensure handle stays visible

                cell.style.left = newX + 'px';
                cell.style.top = newY + 'px';
            }

            function onMouseUp() {
                if (isDragging) {
                    isDragging = false;
                    cell.classList.remove('dragging');
                    handle.classList.remove('dragging');
                }
            }

            // Only attach mousedown to the handle
            handle.addEventListener('mousedown', onMouseDown);
            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        })();
    """

    return DOM.div(draggable_cell, drag_js)
end

function Bonito.jsrender(session::Session, canvas::DraggableBook)
    book = canvas.book
    # Create initial positions for cells in a rough grid
    cols = 2
    cell_width = 500
    cell_height = 500
    margin = 50

    draggable_cells = []
    for (i, cell) in enumerate(book.cells)
        row = div(i-1, cols)
        col = (i-1) % cols

        x = margin + col * (cell_width + margin)
        y = margin + row * (cell_height + margin)

        draggable_cell = make_draggable_cell(cell, x, y)
        push!(draggable_cells, draggable_cell)
    end

    # Canvas with grid background and draggable cells
    canvas_workspace = DOM.div(
        # Grid background
        DOM.div(class="canvas-grid"),
        # All draggable cells
        draggable_cells...;
        class="draggable-canvas"
    )
    elements = BonitoBook.standard_setup!(session, book)
    return Bonito.jsrender(session, DOM.div(elements, canvas_workspace))
end

end
