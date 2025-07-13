
function SmallButton(icon_name::String; class = "", kw...)
    value = Observable(false)
    ic = icon(icon_name)
    button_dom = DOM.button(
        ic;
        onclick = js"event=> $(value).notify(true);",
        class = class,
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
    close_button, click = SmallButton("close")
    on(click) do click
        popup.show[] = !popup.show[]
    end
    # Create popup content wrapper
    popup_content = DOM.div(
        popup.content,
        close_button,
        class = "popup-content"
    )
    # Create overlay wrapper
    overlay = DOM.div(
        popup_content,
        class = "popup-overlay",
        style = "display: $(popup.show[] ? "flex" : "none")",

    )
    # JavaScript for showing/hiding and keyboard handling
    popup_js = js"""
        const show = $(popup.show);
        const overlay = $(overlay);
        // Handle ESC key
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && overlay.style.display !== 'none') {
                $(popup.show).notify(false);
            }
        });
        document.addEventListener('click', (event) => {
            // Hide popup when clicking outside
            if (event.target === overlay) {
                show.notify(false);
            }
        });
        // Handle show/hide
        show.on((isShown) => {
            overlay.style.display = isShown ? "flex" : "none";
        });
    """
    return Bonito.jsrender(session, DOM.div(popup_js, overlay))
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

const FileDialogStyle = Styles(
    CSS(
        ".file-dialog-container",
        "position" => "relative",
        "display" => "inline-block",
    ),
    CSS(
        ".file-dialog-dropdown",
        "position" => "relative",
        "background-color" => "var(--bg-primary)",
        "border-radius" => "5px",
        "width" => "500px",
        "max-width" => "90vw",
        "max-height" => "70vh",
        "display" => "flex",
        "flex-direction" => "column",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".file-dialog-content",
        "background-color" => "var(--bg-primary)",
        "border-radius" => "5px",
        "box-shadow" => "var(--shadow-soft)",
        "width" => "500px",
        "max-width" => "90vw",
        "max-height" => "70vh",
        "display" => "flex",
        "flex-direction" => "column",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".file-dialog-header",
        "display" => "flex",
        "justify-content" => "space-between",
        "align-items" => "center",
        "padding" => "16px",
        "border-bottom" => "1px solid var(--border-primary)",
        "font-weight" => "600",
        "font-size" => "16px",
    ),
    CSS(
        ".file-dialog-close",
        "background" => "none",
        "border" => "none",
        "font-size" => "20px",
        "color" => "var(--text-secondary)",
        "cursor" => "pointer",
        "padding" => "4px",
        "border-radius" => "4px",
        "width" => "28px",
        "height" => "28px",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
    ),
    CSS(
        ".file-dialog-close:hover",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-primary)",
    ),
    CSS(
        ".file-dialog-input",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 12px",
        "font-size" => "14px",
        "margin" => "0 16px 16px 16px",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "outline" => "none",
    ),
    CSS(
        ".file-dialog-input:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)",
    ),
    CSS(
        ".file-dialog-list",
        "max-height" => "400px",
        "overflow-y" => "auto",
        "padding" => "0 8px 16px 8px",
    ),
    CSS(
        ".file-dialog-item",
        "display" => "flex",
        "align-items" => "center",
        "padding" => "8px 12px",
        "cursor" => "pointer",
        "border-radius" => "6px",
        "margin" => "2px 0",
        "font-size" => "14px",
        "transition" => "background-color 0.2s ease",
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

    # Create the complete dialog content for popup usage
    dialog_content = DOM.div(
        DOM.div(
            DOM.h3("Open File", style = "margin: 0;"),
            DOM.button("×",
                class = "file-dialog-close",
                onclick = js"event => $(dialog.show_dialog).notify(false)"),
            class = "file-dialog-header"
        ),
        input_with_events,
        file_list_content,
        class = "file-dialog-content"
    )

    return Bonito.jsrender(
        session, DOM.div(
            FileDialogStyle,
            dialog_content
        )
    )
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
            tab_name = DOM.span(basename(file), class = "file-tab-name")

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

    # Wrap file dialog in a popup that only shows when dialog should be shown
    dialog_popup = PopUp(tabs.file_dialog; show = false)

    # Connect the file dialog show_dialog observable to the popup
    on(session, tabs.file_dialog.show_dialog) do show
        dialog_popup.show[] = show
    end

    return Bonito.jsrender(session, DOM.div(dialog_popup, tabs_content))
end
