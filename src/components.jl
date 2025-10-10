
function SmallButton(icon_name::String; class = "", inactive = false, kw...)
    value = Observable(false)
    ic = icon(icon_name)
    final_class = inactive ? "small-button inactive $(class)" : "small-button $(class)"
    onclick_action = inactive ? js"event=> {}" : js"event=> $(value).notify(true);"
    button_dom = DOM.button(
        ic;
        onclick = onclick_action,
        class = final_class,
        kw...,
    )
    return button_dom, value
end

"""
    SmallToggle(active, args...; class="", kw...)

Create a small toggle button that reflects and controls a boolean observable.

# Arguments
- `active`: Observable{Bool} that controls the toggle state
- `args...`: Additional arguments passed to the button
- `class`: CSS class string
- `kw...`: Additional keyword arguments

# Returns
DOM element with toggle functionality.
"""
function SmallToggle(active, args...; class = "", kw...)
    class = active[] ? class : "toggled $class"
    value = Observable(false)
    button_dom = DOM.button(args...; class = "small-button $(class)", kw...)
    toggle_script = js"""
        const elem = $(button_dom);
        $(active).on((x) => {
            if (!x) {
                elem.classList.add("toggled");
            } else {
                elem.classList.remove("toggled");
            }
        })
        elem.addEventListener("click", event=> {
            $(value).notify(true);
        })
    """
    on(value) do click
        active[] = !active[]
    end
    return DOM.span(button_dom, toggle_script)
end


"""
    PopUp

Modal popup component with show/hide functionality.

# Fields
- `content::Observable{Any}`: Content to display in the popup
- `show::Observable{Bool}`: Whether the popup is visible
"""
struct PopUp
    content::Observable{Any}
    show::Observable{Bool}
end

"""
    PopUp(content; show=true)

Create a popup with the given content.

# Arguments
- `content`: Content to display (can be any renderable object)
- `show`: Whether the popup starts visible (default: true)

# Returns
`PopUp` instance.
"""
function PopUp(content; show = true)
    return PopUp(Observable(content), Observable(show))
end

function Bonito.jsrender(session::Session, popup::PopUp)
    # Create proper close button with correct styling
    close_button = DOM.button("×",
        class = "popup-close-button",
    )

    # Create popup content wrapper
    popup_content = DOM.div(
        close_button,
        popup.content,
        class = "popup-content"
    )

    # Create a container that will hold the content and handle the portal
    container = DOM.div(popup_content, style = "display: none;")

    # JavaScript for portal rendering and popup behavior
    popup_js = js"""
        const close_button = $(close_button);
        const show = $(popup.show);
        const content_container = $(container);

        // Create the overlay element in JavaScript and portal it to document.body
        const overlay = document.createElement('div');
        overlay.className = 'popup-overlay';
        overlay.style.display = 'none';

        // Move the content from the container to the overlay
        overlay.appendChild(content_container.firstElementChild);
        content_container.style.display = 'none';

        // Add overlay to document.body for proper positioning
        document.body.appendChild(overlay);

        // Clean up when the container is removed from DOM
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.removedNodes.forEach((node) => {
                    if (node.contains && node.contains(content_container)) {
                        if (overlay.parentNode === document.body) {
                            document.body.removeChild(overlay);
                        }
                        observer.disconnect();
                    }
                });
            });
        });
        observer.observe(document.body, { childList: true, subtree: true });

        close_button.addEventListener('click', () => {
            show.notify(false);
        });

        // Handle ESC key
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && overlay.style.display !== 'none') {
                show.notify(false);
            }
        });

        // Hide popup when clicking outside
        overlay.addEventListener('click', (event) => {
            if (event.target === overlay) {
                show.notify(false);
            }
        });

        // Handle show/hide
        show.on((show) => {
            overlay.style.display = show ? "flex" : "none";
        });

        // Initialize with current state
        overlay.style.display = $(popup.show).value ? "flex" : "none";
    """

    return Bonito.jsrender(session, DOM.div(popup_js, container))
end

"""
    OpenFileDialog

A reusable file picker component with autocomplete functionality.

# Fields
- `base_folder::Observable{String}`: Base directory for file browsing
- `current_path::Observable{String}`: Current input path
- `file_selected::Observable{String}`: Selected file path (output)
- `show_dialog::Observable{Bool}`: Whether dialog is visible
- `available_files::Observable{Vector{String}}`: Files/folders in current directory
"""
struct OpenFileDialog
    base_folder::Observable{String}
    current_path::Observable{String}
    file_selected::Observable{String}
    show_dialog::Observable{Bool}
    available_files::Observable{Vector{String}}

    function OpenFileDialog(base_folder::String = pwd())
        base_folder_obs = Observable(base_folder)
        current_path = Observable("")
        file_selected = Observable("")
        show_dialog = Observable(false)
        available_files = Observable{Vector{String}}([])

        # Update available files when base folder or current path changes
        function update_files(base, path)
            if isempty(path)
                # Show files in base folder
                target_dir = base
            else
                # Relative path
                target_dir = joinpath(base, dirname(path))
            end

            try
                if isdir(target_dir)
                    # Get all files and directories
                    items = readdir(target_dir, join=false, sort=true)
                    # Filter and format items
                    formatted_items = String[]

                    for item in items
                        full_path = joinpath(target_dir, item)
                        if isdir(full_path)
                            # Add trailing slash for directories
                            push!(formatted_items, item * "/")
                        else
                            # Add files as-is
                            push!(formatted_items, item)
                        end
                    end

                    available_files[] = formatted_items
                else
                    available_files[] = String[]
                end
            catch
                available_files[] = String[]
            end
        end

        # Update files when base folder or path changes
        onany(update_files, base_folder_obs, current_path; update=true)

        return new(base_folder_obs, current_path, file_selected, show_dialog, available_files)
    end
end

function show_dialog!(dialog::OpenFileDialog)
    dialog.show_dialog[] = true
    dialog.current_path[] = ""
end

function hide_dialog!(dialog::OpenFileDialog)
    dialog.show_dialog[] = false
end

function select_file!(dialog::OpenFileDialog, filepath::String)
    base = dialog.base_folder[]
    # Resolve the full path
    full_path = if isabspath(filepath)
        filepath
    else
        joinpath(base, filepath)
    end

    if isfile(full_path)
        dialog.file_selected[] = full_path
        hide_dialog!(dialog)
    elseif isdir(full_path)
        # If it's a directory, update the current path
        rel_path = relpath(full_path, base)
        dialog.current_path[] = rel_path == "." ? "" : rel_path * "/"
    end
end

# File dialog styles - simplified since PopUp handles outer container
const FileDialogStyle = Styles(
    CSS(
        ".file-dialog-content",
        # Remove container styling (PopUp handles this)
        "width" => "31.25rem", # 500px in rem
        "max-width" => "90vw",
        "max-height" => "70vh",
        "display" => "flex",
        "flex-direction" => "column",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".file-dialog-input",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "var(--border-radius-large)",
        "padding" => "var(--spacing-sm) var(--spacing-md)",
        "font-size" => "var(--font-size-base)",
        "margin" => "0 0 var(--spacing-lg) 0",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "outline" => "none",
        "transition" => "all var(--transition-slow)",
    ),
    CSS(
        ".file-dialog-input:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)",
    ),
    CSS(
        ".file-dialog-list",
        "max-height" => "25rem",
        "overflow-y" => "auto",
        "padding" => "0",
    ),
    CSS(
        ".file-dialog-item",
        "display" => "flex",
        "align-items" => "center",
        "padding" => "var(--spacing-sm) var(--spacing-md)",
        "cursor" => "pointer",
        "border-radius" => "var(--border-radius-large)",
        "margin" => "var(--spacing-xs) 0",
        "font-size" => "var(--font-size-base)",
        "transition" => "background-color var(--transition-slow)",
        "user-select" => "none",
    ),
    CSS(
        ".file-dialog-item:hover",
        "background-color" => "var(--hover-bg)",
    ),
    CSS(
        ".file-dialog-folder",
        "font-weight" => "500",
        "color" => "var(--accent-blue)",
    ),
    CSS(
        ".file-dialog-file",
        "color" => "var(--text-primary)",
    )
)

function Bonito.jsrender(session::Session, dialog::OpenFileDialog)
    # Create file list
    file_list_content = map(dialog.available_files, dialog.current_path) do files, current
        list_items = []

        # Add parent directory option if not at base
        if !isempty(current)
            parent_item = DOM.div(
                "📁 ../",
                class = "file-dialog-item file-dialog-folder",
                onclick = js"""event => {
                    const parts = $(current).split('/').filter(p => p);
                    parts.pop();
                    const newPath = parts.length > 0 ? parts.join('/') + '/' : '';
                    $(dialog.current_path).notify(newPath);
                }"""
            )
            push!(list_items, parent_item)
        end

        # Add files and folders
        for file in files
            is_folder = endswith(file, "/")
            icon = is_folder ? "📁" : "📄"
            item_class = is_folder ? "file-dialog-item file-dialog-folder" : "file-dialog-item file-dialog-file"

            item = DOM.div(
                "$icon $file",
                class = item_class,
                onclick = js"""event => {
                    const filename = $(file);
                    const currentPath = $(current);
                    let newPath;

                    if (filename.endsWith('/')) {
                        // Directory - navigate into it
                        newPath = currentPath + filename;
                        $(dialog.current_path).notify(newPath);
                    } else {
                        // File - select it
                        newPath = currentPath + filename;
                        $(dialog.file_selected).notify(newPath);
                        $(dialog.show_dialog).notify(false);
                    }
                }"""
            )
            push!(list_items, item)
        end

        return DOM.div(list_items..., class = "file-dialog-list")
    end

    # Handle input changes and enter key
    input_with_events = DOM.input(
        type = "text",
        placeholder = "Enter file path...",
        class = "file-dialog-input",
        value = dialog.current_path,
        onkeydown = js"""event => {
            if (event.key === 'Enter') {
                event.preventDefault();
                const path = event.target.value;

                // Check if it's a valid file or directory
                const base = $(dialog.base_folder).value;
                const fullPath = path.startsWith('/') ? path : base + '/' + path;

                $(dialog.current_path).notify(path);

                // Try to select as file
                setTimeout(() => {
                    if (!path.endsWith('/')) {
                        $(dialog.file_selected).notify(path);
                        $(dialog.show_dialog).notify(false);
                    }
                }, 100);
            }
        }""",
        oninput = js"event => $(dialog.current_path).notify(event.target.value)"
    )

    # Create dialog content without header/close button (PopUp handles that)
    dialog_content = DOM.div(
        DOM.h3("Open File", style = "margin: 0 0 var(--spacing-lg) 0; font-size: var(--font-size-lg); font-weight: 600;"),
        input_with_events,
        file_list_content,
        class = "file-dialog-content"
    )

    # Use the PopUp component properly - it will add its own close button and popup styling
    popup = PopUp(DOM.div(FileDialogStyle, dialog_content); show = false)

    # Connect the dialog's show_dialog observable to the popup's show observable
    on(session, dialog.show_dialog) do show
        popup.show[] = show
    end

    return Bonito.jsrender(session, popup)
end

"""
    FileTabs

A reusable file tabs component for multi-file editing interfaces.

# Fields
- `files::Observable{Vector{String}}`: List of file paths
- `current_file::Observable{String}`: Currently active file path
- `current_file_index::Observable{Int}`: Index of currently active file
- `switch_file_obs::Observable{Int}`: Observable for switching files
- `close_file_obs::Observable{Int}`: Observable for closing files
- `open_file_obs::Observable{String}`: Observable for opening new files
- `file_dialog::OpenFileDialog`: File dialog for opening files
"""
struct FileTabs
    files::Observable{Vector{String}}
    current_file::Observable{String}
    current_file_index::Observable{Int}
    switch_file_obs::Observable{Int}
    close_file_obs::Observable{Int}
    open_file_obs::Observable{String}
    file_dialog::OpenFileDialog
end


"""
    FileTabs(files::Vector{String})

Create a FileTabs component with the given initial files.
"""
function FileTabs(files::Vector{String})
    files_obs = Observable(files)
    current_file = Observable(isempty(files) ? "" : files[1])
    current_file_index = Observable(isempty(files) ? 0 : 1)
    switch_file_obs = Observable(0)
    close_file_obs = Observable(0)
    open_file_obs = Observable("")
    file_dialog = OpenFileDialog()

    tabs = FileTabs(files_obs, current_file, current_file_index, switch_file_obs, close_file_obs, open_file_obs, file_dialog)

    # Set up file management logic
    on(tabs.current_file_index) do idx
        files = tabs.files[]
        if idx > 0 && idx <= length(files)
            tabs.current_file[] = files[idx]
        end
    end
    return tabs
end

function open_file!(tabs::FileTabs, filepath::String)
    if isfile(filepath)
        files = tabs.files[]
        # Check if file is already open
        existing_index = findfirst(f -> f == filepath, files)
        if !isnothing(existing_index)
            # Switch to existing file
            tabs.current_file_index[] = existing_index
        else
            # Add new file to list
            push!(tabs.files[], filepath)
            tabs.current_file_index[] = length(files)
        end
        @info "Opened file: $filepath"
    else
        @warn "Could not find file: $filepath"
    end
end

function switch_file!(tabs::FileTabs, file_index::Integer)
    files = tabs.files[]
    if file_index > 0 && file_index <= length(files) && file_index != tabs.current_file_index[]
        tabs.current_file_index[] = file_index
    end
end

function close_file!(tabs::FileTabs, file_index::Integer)
    files = tabs.files[]
    if file_index > 0 && file_index <= length(files)
        if length(files) == 1
            # Can't close the last file
            @warn "Cannot close the last file"
            return
        end
        # Remove file from list
        splice!(files, file_index)
        # Adjust current file index if necessary
        current_idx = tabs.current_file_index[]
        if file_index == current_idx
            # If closing current file, switch to previous or first file
            new_idx = min(current_idx, length(files))
            if new_idx == 0
                new_idx = 1
            end
            tabs.current_file_index[] = new_idx
        elseif file_index < current_idx
            # If closing a file before current, adjust index
            tabs.current_file_index[] = current_idx - 1
        end
        notify(tabs.files)
    end
end


function Bonito.jsrender(session::Session, tabs::FileTabs)
    # Handle file switching
    on(session, tabs.switch_file_obs) do file_index
        switch_file!(tabs, file_index)
    end

    # Handle file closing
    on(session, tabs.close_file_obs) do file_index
        close_file!(tabs, file_index)
    end

    # Handle opening new files
    on(session, tabs.open_file_obs) do filepath
        open_file!(tabs, filepath)
    end

    # Connect file dialog selection to file opening
    on(session, tabs.file_dialog.file_selected) do filepath
        open_file!(tabs, filepath)
    end
    open_files = map(tuple, tabs.files, tabs.current_file_index; ignore_equal_values=true)
    # Create reactive tabs content
    tabs_content = map(open_files) do (files, current_idx)
        tab_elements = []

        # Create tabs for each file
        for (i, file) in enumerate(files)
            is_active = i == current_idx
            tab_class = is_active ? "file-tab active" : "file-tab"

            # Tab content with file name and close button
            # TODO, tooltip wont be readable for long paths + many tabs
            tab_name = Tooltip(DOM.span(basename(file), class = "file-tab-name"), file; position="right")

            # Close button (only show if more than one file)
            if length(files) > 1
                close_btn = DOM.button("×",
                    class = "file-tab-close",
                    onclick = js"event => { event.stopPropagation(); $(tabs.close_file_obs).notify($(i)); }")
                tab_content = DOM.div(tab_name, close_btn, class = "file-tab-content")
            else
                tab_content = DOM.div(tab_name, class = "file-tab-content")
            end

            # Full tab element
            tab = DOM.div(tab_content,
                class = tab_class,
                onclick = js"event => $(tabs.switch_file_obs).notify($(i))")

            push!(tab_elements, tab)
        end

        # Add "open file" button
        open_btn = DOM.button("+",
            class = "file-tab-add",
            onclick = js"event => $(tabs.file_dialog.show_dialog).notify(true)")
        push!(tab_elements, open_btn)

        return DOM.div(tab_elements..., class = "file-tabs-container")
    end

    # The file dialog now handles its own popup overlay, so just render it directly
    return Bonito.jsrender(session, DOM.div(tabs.file_dialog, tabs_content))
end

"""
    Collapsible

A collapsible widget that can be expanded/collapsed to show/hide content using pure CSS and JavaScript.

# Fields
- `title::String`: The title shown in the collapsed state
- `content::Any`: The content to show when expanded
- `expanded::Bool`: Whether the widget starts expanded (default: false)
"""
struct Collapsible
    title::String
    content::Any
    expanded::Bool
end

"""
    Collapsible(title::String, content; expanded=false)

Create a collapsible widget with the given title and content.

# Arguments
- `title`: Title shown in the collapsed state
- `content`: Content to display when expanded
- `expanded`: Whether the widget starts expanded (default: false)

# Returns
`Collapsible` instance.
"""
function Collapsible(title::String, content; expanded::Bool = false)
    return Collapsible(title, content, expanded)
end

function Bonito.jsrender(session::Session, collapsible::Collapsible)
    # Create unique ID for this collapsible instance
    widget_id = "collapsible-$(hash(collapsible.title * string(collapsible.content)))"

    # Create the header with toggle functionality
    header = DOM.div(
        DOM.span(collapsible.expanded ? "▼" : "▶", class = "collapsible-toggle"),
        DOM.span(" $(collapsible.title)", style = "margin-left: 5px; color: var(--text-secondary); font-size: 0.9em;"),
        class = "collapsible-header",
        style = "cursor: pointer; padding: 2px 4px; user-select: none; display: flex; align-items: center;",
    )

    # Create content container
    content_container = DOM.div(
        collapsible.content,
        class = "collapsible-content",
        style = "margin-top: 4px; padding-left: 16px; display: $(collapsible.expanded ? "block" : "none");"
    )

    widget = DOM.div(
        header,
        content_container,
        class = "collapsible-widget",
        id = widget_id
    )
    jss = js"""
        const header = $(header);
        const content = $(content_container);
        const toggle = header.querySelector(".collapsible-toggle")
        header.addEventListener("click", () => {
            const is_expanded = content.style.display === "block";
            content.style.display = is_expanded ? "none" : "block";
            toggle.textContent = is_expanded ? "▶" : "▼";
        });
    """
    return Bonito.jsrender(session, DOM.div(widget, jss))
end

"""
    BookSpinner

A horizontal progress spinner component for displaying task progress.

# Fields
- `visible::Observable{Bool}`: Controls visibility of the spinner
- `message::Observable{String}`: Optional text message to display
"""
struct BookSpinner
    visible::Observable{Bool}
    message::Observable{String}
end

"""
    BookSpinner()

Create a new book spinner with pulsing animation.

# Returns
A `BookSpinner` instance with default hidden state.
"""
function BookSpinner()
    visible = Observable(false)
    message = Observable("")
    return BookSpinner(visible, message)
end

function Bonito.jsrender(session::Session, spinner::BookSpinner)
    # Main spinner container with visibility control
    spinner_class = map(spinner.visible) do visible
        visible ? "book-spinner" : "book-spinner hidden"
    end

    spinner_container = DOM.div(
        class = spinner_class
    )
    return Bonito.jsrender(session, spinner_container)
end

function show_spinner!(spinner::BookSpinner, task; message = "")
    # Set the message if provided
    if !isempty(message)
        spinner.message[] = message
    end

    # Show the spinner
    spinner.visible[] = true

    # Monitor the task and hide spinner when complete
    Threads.@spawn begin
        try
            # Wait for the task to complete
            wait(task)
        catch e
            # Task failed, but we still want to hide the spinner
            @debug "Task failed with error: $e"
        finally
            # Hide the spinner regardless of task outcome
            spinner.visible[] = false
            spinner.message[] = ""
        end
    end

    return task
end

"""
    Tooltip

A tooltip widget that displays explanatory text when hovering over an element.

# Fields
- `element::Any`: The element to attach the tooltip to
- `text::String`: The tooltip text to display
- `position::String`: Position of the tooltip ("top", "bottom", "left", "right")
"""
struct Tooltip
    element::Any
    text::String
    position::String
end

"""
    Tooltip(element, text; position="top")

Create a tooltip that displays text when hovering over the element.

# Arguments
- `element`: The DOM element to attach the tooltip to
- `text`: The text to display in the tooltip
- `position`: Position of the tooltip relative to the element (default: "top")

# Returns
`Tooltip` instance that renders as a wrapper around the element.

# Example
```julia
button, click = SmallButton("save")
tooltip_button = Tooltip(button, "Save the current document"; position="top")
```
"""
function Tooltip(element, text::String; position::String = "top")
    return Tooltip(element, text, position)
end

# Tooltip styles - uses global variables from book_style
const TooltipStyles = Styles(
    CSS(
        ".tooltip-container",
        "position" => "relative",
        "display" => "inline-flex",
        "margin" => "0",
        "padding" => "0",
        "vertical-align" => "top"
    ),
    CSS(
        ".tooltip-text",
        "visibility" => "hidden",
        "opacity" => "0",
        "position" => "absolute",
        "z-index" => "var(--z-popup)",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-primary)",
        "border-radius" => "var(--border-radius-large)",
        "padding" => "var(--spacing-sm) var(--spacing-md)",
        "font-size" => "var(--font-size-xs)",
        "white-space" => "nowrap",
        "box-shadow" => "var(--shadow-soft)",
        "transition" => "opacity var(--transition-slow), visibility var(--transition-slow)",
        "transition-delay" => "0s",
        "pointer-events" => "none"
    ),
    CSS(
        ".tooltip-container:hover .tooltip-text",
        "visibility" => "visible",
        "opacity" => "1",
        "transition-delay" => "0.5s"
    ),
    CSS(
        ".tooltip-top",
        "bottom" => "100%",
        "left" => "50%",
        "transform" => "translateX(-50%)",
        "margin-bottom" => "var(--spacing-sm)"
    ),
    CSS(
        ".tooltip-bottom",
        "top" => "100%",
        "left" => "50%",
        "transform" => "translateX(-50%)",
        "margin-top" => "var(--spacing-sm)"
    ),
    CSS(
        ".tooltip-left",
        "right" => "100%",
        "top" => "50%",
        "transform" => "translateY(-50%)",
        "margin-right" => "var(--spacing-sm)"
    ),
    CSS(
        ".tooltip-right",
        "left" => "100%",
        "top" => "50%",
        "transform" => "translateY(-50%)",
        "margin-left" => "var(--spacing-sm)"
    )
)

function Bonito.jsrender(session::Session, tooltip::Tooltip)
    # Create the tooltip text element
    tooltip_element = DOM.div(
        tooltip.text,
        class = "tooltip-text tooltip-$(tooltip.position)"
    )

    # Wrap the original element with tooltip container
    container = DOM.div(
        tooltip.element,
        tooltip_element,
        class = "tooltip-container"
    )

    return Bonito.jsrender(session, DOM.div(TooltipStyles, container))
end
