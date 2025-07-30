"""
    Sidebar

A sidebar container that holds multiple widgets with tab navigation.
Supports showing/hiding and switching between different widgets.
Can be oriented vertically (default) or horizontally.

# Fields
- `widgets::Vector{Tuple{String, Any, String, String}}`: Vector of (id, widget, label, icon)
- `current_widget::Observable{String}`: Currently active widget ID
- `visible::Observable{Bool}`: Whether sidebar is visible
- `width::String`: Width when expanded (default "400px")
- `orientation::String`: Orientation ("vertical" or "horizontal")
"""
struct Sidebar
    widgets::Vector{Tuple{String, Any, String, String}}
    current_widget::Observable{String}
    visible::Observable{Bool}
    width::String
    orientation::String
end

"""
    Sidebar(widgets; width = "400px", orientation = "vertical")

Create a new sidebar with static widgets.

# Arguments
- `widgets`: Vector of tuples (widget_id, widget, label, icon_name)
- `width`: Width when expanded (default "400px")
- `orientation`: Orientation ("vertical" or "horizontal", default "vertical")

# Example
```julia
sidebar = Sidebar([
    ("editor", file_editor, "File Editor", "file-code"),
    ("search", search_widget, "Search", "search")
])
```
"""
function Sidebar(widgets::Vector{<:Tuple{String, Any, String, String}}; width = "400px", orientation = "vertical")
    # Set first widget as current if any exist
    current_widget = Observable(isempty(widgets) ? "" : widgets[1][1])
    visible = Observable(false)

    # Convert to the expected type
    typed_widgets = Vector{Tuple{String, Any, String, String}}(widgets)

    return Sidebar(typed_widgets, current_widget, visible, width, orientation)
end


function ToggleButton2(icon_name::String, is_active, on_click::Observable{Bool}, has_new_content::Observable{Bool} = Observable(false))
    button_icon = icon(icon_name)
    # Set initial class based on observable value
    initial_class = is_active[] ? "small-button toggle-button active" : "small-button toggle-button"

    butt = DOM.button(
        button_icon;
        class = initial_class,

    )
    jsss = js"""
        const butt = $(butt);
        butt.addEventListener('click',  event=> {
            const button = event.target.closest('button');
            $(on_click).notify(!$(on_click).value);
        });

        $(is_active).on(isactive => {
            // Update button class based on new value
            if (isactive) {
                butt.classList.add('active');
            } else {
                butt.classList.remove('active');
            }
        });
    """

    return DOM.div(butt, jsss)
end

function Bonito.jsrender(session::Bonito.Session, sidebar::Sidebar)
    # Create tabs
    tabs = []
    widget_contents = []

    for (widget_id, widget, label, icon_name) in sidebar.widgets
        # Update active state when sidebar state changes
        tab_active = Observable(false; ignore_equal_values=true)
        onany(sidebar.current_widget, sidebar.visible) do current, visible
            tab_active[] = current == widget_id && visible
        end
        on_toggle = Observable(false)

        tab_button = ToggleButton2(icon_name, tab_active, on_toggle)

        on(session, on_toggle) do clicked
            toggled = !tab_active[]
            if toggled && sidebar.current_widget[] != widget_id
                sidebar.current_widget[] = widget_id
            else sidebar.current_widget[] == widget_id
                sidebar.visible[] = !sidebar.visible[]
            end
        end

        if hasproperty(widget, :visible)
            # Sync widget visibility with sidebar visibility
            on(session, widget.visible) do show
                if show
                    sidebar.current_widget[] = widget_id
                    sidebar.visible[] = true
                end
            end
            # Also sync sidebar visibility to widget visibility
            on(session, tab_active) do active
                widget.visible[] = active
            end
        end

        push!(tabs, tab_button)

        # Create widget container that shows/hides based on current selection
        widget_class = map(tab_active) do visible
            visible ? "sidebar-widget-content show" : "sidebar-widget-content hide"
        end
        widget_container = DOM.div(
            widget;
            class = widget_class,
            data_widget_id = widget_id
        )
        push!(widget_contents, widget_container)
    end

    on(sidebar.current_widget) do id
        sidebar.visible[] = true
    end

    # Tab bar with orientation class
    tab_bar = DOM.div(tabs...; class = "sidebar-tabs $(sidebar.orientation)")

    # Add resize handle with unified resize functionality
    resize_handle = DOM.div(
        class = "sidebar-resize-handle $(sidebar.orientation)"
    )
    resize_js = js"""
    const handle = $(resize_handle);
    const sidebar = handle.closest('.sidebar-main-container');
    const container = handle.closest('.sidebar-content-container');
    const orientation = $(sidebar.orientation);

    let isResizing = false;
    let startPos = 0;
    let startSize = 0;

    handle.addEventListener('mousedown', (e) => {
        isResizing = true;
        startPos = orientation === 'vertical' ? e.clientX : e.clientY;

        if (orientation === 'vertical') {
            startSize = parseInt(getComputedStyle(container).width, 10);
        } else {
            startSize = parseInt(getComputedStyle(container).height, 10);
        }

        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mouseup', handleMouseUp);
        e.preventDefault();
    });

    const handleMouseMove = (e) => {
        if (!isResizing) return;

        let newSize;
        if (orientation === 'vertical') {
            // For vertical sidebar: drag LEFT to make wider
            const deltaX = startPos - e.clientX;
            const maxWidth = window.innerWidth * 0.8;
            newSize = Math.max(200, Math.min(maxWidth, startSize + deltaX));
            container.style.setProperty('--sidebar-width', newSize + 'px');
            container.style.width = newSize + 'px';
        } else {
            // For horizontal sidebar: drag UP to make taller
            const deltaY = startPos - e.clientY;
            const maxHeight = window.innerHeight * 0.8;
            newSize = Math.max(100, Math.min(maxHeight, startSize + deltaY));
            container.style.setProperty('--sidebar-height', newSize + 'px');
            container.style.height = newSize + 'px';
        }
    };

    const handleMouseUp = () => {
        isResizing = false;
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
    };
    """


    # Content area with all widgets (hidden by default)
    content_area = DOM.div(
        resize_handle,
        resize_js,
        widget_contents...;
        class = "sidebar-content"
    )

    # Content container that adapts to content height/width based on orientation
    content_container_class = map(sidebar.visible) do visible
        state = visible ? "expanded" : "collapsed"
        return "sidebar-content-container $(sidebar.orientation) $state"
    end

    content_container = DOM.div(
        content_area;
        class = content_container_class
    )

    # Main container that holds both tabs and content with orientation class
    main_container = DOM.div(
        tab_bar,
        content_container;
        class = "sidebar-main-container $(sidebar.orientation)"
    )

    # Scoped style - set CSS variables on the specific sidebar container
    scoped_style = Styles(
        CSS(
            ".sidebar-main-container.$(sidebar.orientation)",
            "--sidebar-width" => sidebar.width,
            "--sidebar-height" => "300px"
        )
    )

    return Bonito.jsrender(session, DOM.div(scoped_style, main_container))
end
