"""
    SmallButton(; class="", kw...)

Create a small interactive button component.

# Arguments
- `class`: CSS class string to apply to the button
- `kw...`: Additional keyword arguments passed to the DOM button

# Returns
Tuple of (button_dom, click_observable) where click_observable fires when clicked.
"""
function SmallButton(; class = "", kw...)
    value = Observable(false)
    button_dom = DOM.button(
        "";
        onclick = js"event=> $(value).notify(true);",
        class = "small-button $(class)",
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
    button_style = Styles("position" => "absolute", "top" => "1px", "right" => "1px", "background-color" => "red")
    close_icon = icon("close")
    click = Observable(false)
    button = DOM.button(
        close_icon;
        class = "small-button",
        style = button_style,
        onclick = js"event=> $(click).notify(true);"
    )
    on(click) do click
        popup.show[] = !popup.show[]
    end
    popup_style = Styles(
        "position" => "absolute", "top" => "100px",
        "left" => "50%", "transform" => "translateX(-50%)",
        "z-index" => "1000",
        "background-color" => "white",
        "display" => popup.show[] ? "block" : "none",
    )
    card = Card(
        Col(popup.content, button),
        style = popup_style
    )
    close_js = js"""
        const show = $(popup.show);
        const card = $(card);
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && card.style.display !== 'none') {
                $(popup.show).notify(false);
            }
        });
        show.on((show) => {
            console.log("Popup visibility changed")
            console.log(show);
            card.style.display = show ? "block" : "none";
        })
    """
    return Bonito.jsrender(session, DOM.div(card, close_js))
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
        function update_files()
            path = current_path[]
            base = base_folder_obs[]

            if isempty(path)
                # Show files in base folder
                target_dir = base
            elseif isabs(path)
                # Absolute path
                target_dir = dirname(path)
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
        on(update_files, base_folder_obs)
        on(update_files, current_path)

        # Initialize
        update_files()

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
    full_path = if isabs(filepath)
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

    # Create dialog content
    dialog_header = DOM.div(
        "Select File",
        DOM.button("×",
            class = "file-dialog-close",
            onclick = js"event => $(dialog.show_dialog).notify(false)"),
        class = "file-dialog-header"
    )

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

    dialog_content = DOM.div(
        dialog_header,
        input_with_events,
        file_list_content,
        class = "file-dialog-content"
    )

    # Create overlay
    dialog_class = map(dialog.show_dialog) do show
        show ? "file-dialog-overlay visible" : "file-dialog-overlay hidden"
    end

    return Bonito.jsrender(
        session, DOM.div(
            dialog_content,
            class = dialog_class,
            onclick = js"""event => {
                if (event.target === event.currentTarget) {
                    $(dialog.show_dialog).notify(false);
                }
            }"""
        )
    )
end
