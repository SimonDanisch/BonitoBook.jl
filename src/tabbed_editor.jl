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
    TabbedFileEditor(editor::FileEditor, files::Vector{String})

Create a new tabbed file editor with the given file editor and initial files.
Sets up the connection between tabs and editor.
"""
function TabbedFileEditor(editor::FileEditor, files::Vector{String})
    # Create file tabs
    file_tabs = FileTabs(files)
    
    # Sync initial file from editor to tabs
    if editor.current_file[] != file_tabs.current_file[]
        file_tabs.current_file[] = editor.current_file[]
        idx = findfirst(==(editor.current_file[]), file_tabs.files[])
        if idx !== nothing
            file_tabs.current_file_index[] = idx
        end
    end
    
    # Connect file tabs to editor
    on(file_tabs.switch_file_obs) do index
        if 1 <= index <= length(file_tabs.files[])
            file = file_tabs.files[][index]
            if file != editor.current_file[]
                open_file!(editor, file)
            end
        end
    end
    
    # Connect editor to file tabs (sync current file)
    on(editor.current_file) do file
        if file != file_tabs.current_file[]
            file_tabs.current_file[] = file
            # Update index if file exists in tabs
            idx = findfirst(==(file), file_tabs.files[])
            if idx !== nothing
                file_tabs.current_file_index[] = idx
            end
        end
    end
    
    return TabbedFileEditor(file_tabs, editor)
end

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