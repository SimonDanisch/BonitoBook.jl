using Bonito

"""
    TabbedFileEditor

A combined widget that displays file tabs on top of a file editor.
This combines the functionality of FileTabs and FileEditor into a single widget.

# Fields
- `file_tabs::FileTabs`: The file tabs component
- `file_editor::FileEditor`: The file editor component
"""
struct TabbedFileEditor
    file_tabs::FileTabs
    file_editor::FileEditor
end

"""
    TabbedFileEditor(files::Vector{String}; initial_file=nothing)

Create a new tabbed file editor with the given files.
Creates and manages its own FileEditor instance.

# Arguments
- `files`: Vector of file paths to display in tabs
- `initial_file`: Optional initial file to display (defaults to first file)
"""
function TabbedFileEditor(files::Vector{String}; initial_file=nothing)
    # Determine initial file
    if initial_file === nothing
        initial_file = isempty(files) ? "" : files[1]
    end
    
    # Create file editor
    file_editor = FileEditor(initial_file, nothing; 
        editor_classes = ["styling file-editor"], 
        show_editor = true
    )
    
    # Create file tabs
    file_tabs = FileTabs(files)
    
    # Sync initial file from editor to tabs
    if file_editor.current_file[] != file_tabs.current_file[]
        file_tabs.current_file[] = file_editor.current_file[]
        idx = findfirst(==(file_editor.current_file[]), file_tabs.files[])
        if idx !== nothing
            file_tabs.current_file_index[] = idx
        end
    end
    
    # Connect file tabs to editor
    on(file_tabs.switch_file_obs) do index
        if 1 <= index <= length(file_tabs.files[])
            file = file_tabs.files[][index]
            if file != file_editor.current_file[]
                open_file!(file_editor, file)
            end
        end
    end
    
    # Connect editor to file tabs (sync current file)
    on(file_editor.current_file) do file
        if file != file_tabs.current_file[]
            file_tabs.current_file[] = file
            # Update index if file exists in tabs
            idx = findfirst(==(file), file_tabs.files[])
            if idx !== nothing
                file_tabs.current_file_index[] = idx
            end
        end
    end
    
    # Handle new files opened via file dialog
    on(file_tabs.open_file_obs) do filepath
        if !isempty(filepath) && isfile(filepath)
            # Add to tabs if not already there
            if !(filepath in file_tabs.files[])
                push!(file_tabs.files[], filepath)
                notify(file_tabs.files)
            end
            # Open in editor
            open_file!(file_editor, filepath)
        end
    end
    
    return TabbedFileEditor(file_tabs, file_editor)
end

"""
    get_current_file(editor::TabbedFileEditor)

Get the currently selected file path.
"""
get_current_file(editor::TabbedFileEditor) = editor.file_editor.current_file[]

function Bonito.jsrender(session::Session, widget::TabbedFileEditor)
    # Create container with tabs on top and editor below
    container = DOM.div(
        widget.file_tabs,
        widget.file_editor;
        class = "tabbed-file-editor"
    )
    
    # Add styles for the container
    styles = Styles(
        CSS(
            ".tabbed-file-editor",
            "display" => "flex",
            "flex-direction" => "column",
            "height" => "100%",
            "width" => "100%",
            "overflow" => "hidden"
        ),
        CSS(
            ".tabbed-file-editor .file-tabs-container",
            "flex-shrink" => "0",
            "border-bottom" => "1px solid var(--border-primary)"
        ),
        CSS(
            ".tabbed-file-editor .editor-container",
            "flex" => "1",
            "overflow" => "hidden",
            "min-height" => "0"
        )
    )
    
    return Bonito.jsrender(session, DOM.div(styles, container))
end