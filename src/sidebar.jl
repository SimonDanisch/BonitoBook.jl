"""
    Sidebar

A vertical sidebar container that holds multiple widgets with tab navigation.
Supports showing/hiding and switching between different widgets.

# Fields
- `widgets::Vector{Tuple{String, Any, String, String}}`: Vector of (id, widget, label, icon)
- `current_widget::Observable{String}`: Currently active widget ID
- `visible::Observable{Bool}`: Whether sidebar is visible
- `width::String`: Width when expanded (default "400px")
"""
struct Sidebar
    widgets::Vector{Tuple{String, Any, String, String}}
    current_widget::Observable{String}
    visible::Observable{Bool}
    width::String
end

"""
    Sidebar(widgets; width = "400px")

Create a new sidebar with static widgets.

# Arguments
- `widgets`: Vector of tuples (widget_id, widget, label, icon_name)
- `width`: Width when expanded (default "400px")

# Example
```julia
sidebar = Sidebar([
    ("editor", file_editor, "File Editor", "file-code"),
    ("search", search_widget, "Search", "search")
])
```
"""
function Sidebar(widgets::Vector{<:Tuple{String, Any, String, String}}; width = "400px")
    # Set first widget as current if any exist
    current_widget = Observable(isempty(widgets) ? "" : widgets[1][1])
    visible = Observable(false)

    # Convert to the expected type
    typed_widgets = Vector{Tuple{String, Any, String, String}}(widgets)

    return Sidebar(typed_widgets, current_widget, visible, width)
end


function ToggleButton2(icon_name::String, is_active, on_click::Observable{Bool})
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
    # Create vertical tabs
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
            on(session, widget.visible) do show
                if show
                    sidebar.current_widget[] = widget_id
                    sidebar.visible[] = true
                end
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
    # Vertical tab bar
    tab_bar = DOM.div(tabs...; class = "sidebar-tabs")

    # Add resize handle
    resize_handle = DOM.div(class = "sidebar-resize-handle")

    # Content area with all widgets (hidden by default)
    content_area = DOM.div(
        resize_handle,
        widget_contents...;
        class = "sidebar-content"
    )

    # Content container that adapts to content height
    content_container_class = map(sidebar.visible) do visible
        return visible ? "sidebar-content-container expanded" : "sidebar-content-container collapsed"
    end

    content_container = DOM.div(
        content_area;
        class = content_container_class
    )
    # Main container that holds both tabs and content
    main_container = DOM.div(
        tab_bar,
        content_container;
        class = "sidebar-main-container"
    )

    # Add resize functionality
    resize_script = js"""
        const handle = $(resize_handle);
        const contentContainer = $(content_container);
        let isResizing = false;
        let startX = 0;
        let startWidth = 0;

        handle.addEventListener('mousedown', (e) => {
            isResizing = true;
            startX = e.clientX;
            const contentWidth = contentContainer.querySelector('.sidebar-content').offsetWidth;
            startWidth = contentWidth;
            document.body.style.cursor = 'ew-resize';
            e.preventDefault();
        });

        document.addEventListener('mousemove', (e) => {
            if (!isResizing) return;
            const dx = startX - e.clientX;
            const newWidth = Math.max(300, Math.min(800, startWidth + dx));
            document.documentElement.style.setProperty('--sidebar-width', newWidth + 'px');
        });

        document.addEventListener('mouseup', () => {
            isResizing = false;
            document.body.style.cursor = '';
        });
    """

    global_style = Styles(
        CSS(":root", "--sidebar-width" => sidebar.width)
    )
    return Bonito.jsrender(session, DOM.div(global_style, main_container, resize_script))
end
