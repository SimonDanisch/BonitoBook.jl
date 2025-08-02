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
    visible::Observable{Bool}
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
    on(file_editor.editor.source) do source
        write(file_editor.current_file[], source)
    end

    # Create file tabs
    file_tabs = FileTabs(files)

    # Handle new files opened via file dialog
    on(file_tabs.current_file) do filepath
        open_file!(file_editor, filepath)
    end

    return TabbedFileEditor(file_tabs, file_editor, Observable(true))
end

function open_file!(editor::TabbedFileEditor, filepath::String; line::Union{Int, Nothing} = nothing)
    editor.visible[] = true
    # Set the current file in the tabs
    open_file!(editor.file_tabs, filepath)
    # Open the file in the editor with optional line positioning
    open_file!(editor.file_editor, filepath; line=line)
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
            "height" => "calc(100vh - 20px)",
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


using InteractiveUtils

bedit(func, types) =  (func, types)

macro bedit(expr)
    quote
        func, types = $(InteractiveUtils.gen_call_with_extracted_types(__module__, bedit, expr))
        book = $(__module__).@Book()
        fe = BonitoBook.get_file_editor(book)
        file, line = InteractiveUtils.functionloc(func, types)
        BonitoBook.open_file!(fe, file; line=Int64(line))
    end
end
