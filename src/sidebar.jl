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
    current_widget::Bonito.Observable{String}
    visible::Bonito.Observable{Bool}
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
    current_widget = Bonito.Observable(isempty(widgets) ? "" : widgets[1][1])
    visible = Bonito.Observable(false)

    # Convert to the expected type
    typed_widgets = Vector{Tuple{String, Any, String, String}}(widgets)

    return Sidebar(typed_widgets, current_widget, visible, width)
end

function Bonito.jsrender(session::Bonito.Session, sidebar::Sidebar)
    # Create vertical tabs
    tabs = []
    widget_contents = []
    for (widget_id, widget, label, icon_name) in sidebar.widgets

        # Update active state when sidebar state changes
        tab_active = map(sidebar.visible) do visible
            return sidebar.current_widget[] == widget_id && visible
        end

        # Use ToggleButton for the tab
        tab_button = BonitoBook.ToggleButton(icon_name, tab_active)

        # Add sidebar-specific classes and tooltip
        Bonito.evaljs(session, js"""
            const btn = $(tab_button);
            btn.classList.add('sidebar-tab');
            btn.title = $(label);
        """)

        # Handle clicks
        Bonito.on(session, tab_active) do active
            if active
                # This tab was activated
                if !sidebar.visible[]
                    sidebar.visible[] = true
                end
                sidebar.current_widget[] = widget_id
            else
                # This tab was deactivated
                if sidebar.current_widget[] == widget_id && sidebar.visible[]
                    sidebar.visible[] = false
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
            class = widget_class[],
            data_widget_id = widget_id
        )
        onjs(session, widget_class, js"""(w_class) => {
            const container = $(widget_container);
            container.className = w_class;
        }""")

        push!(widget_contents, widget_container)
    end

    # Update toggle button class
    toggle_class = map(sidebar.visible) do visible
        return visible ? "sidebar-toggle-button hidden" : "sidebar-toggle-button"
    end
    toggle_button = DOM.button(
        BonitoBook.icon("layout-sidebar-right");
        class = toggle_class[],
    )

    onjs(session, toggle_class, js"""(c_class) => {
        const container = $(toggle_button);
        container.className = c_class;
    }""")

    # Vertical tab bar
    tab_bar = DOM.div(
        tabs...,
        toggle_button;
        class = "sidebar-tabs"
    )

    # Content area with all widgets (hidden by default)
    content_area = DOM.div(
        widget_contents...;
        class = "sidebar-content"
    )

    # Container with dynamic width based on visibility
    container_class = map(sidebar.visible) do visible
        return visible ? "sidebar-container expanded" : "sidebar-container collapsed"
    end

    container = DOM.div(
        tab_bar,
        content_area;
        class = container_class[],

    )
    onjs(session, container_class, js"""(c_class) => {
        const container = $(container);
        container.className = c_class;
    }""")

    global_style = Styles(
        CSS(":root", "--sidebar-width" => sidebar.width)
    )
    return Bonito.jsrender(session, DOM.div(global_style, container))
end
