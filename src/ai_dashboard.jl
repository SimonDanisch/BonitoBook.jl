using Bonito
using Dates
using UUIDs

# Monaco is already defined in editor.jl, so we'll use it from there

"""
    TaskStatus

Enumeration for task status types.
"""
@enum TaskStatus queued started progress finished

"""
    TaskData

Represents a task with its current status and metadata.

# Fields
- `id::String`: Unique identifier for the task
- `name::String`: Display name of the task
- `description::String`: Detailed description/prompt for the task
- `status::TaskStatus`: Current status (queued, started, progress, finished)
- `created_at::DateTime`: When the task was created
- `modified_files::Vector{String}`: List of files that have been modified
- `file_diffs::Dict{String, Tuple{String, String}}`: Original and modified content for each file
- `chat_history::Vector{ChatMessage}`: Chat messages associated with this task
- `current_message::String`: Current message/task being worked on
"""
mutable struct TaskData
    id::String
    name::String
    description::String
    status::TaskStatus
    created_at::DateTime
    modified_files::Vector{String}
    file_diffs::Dict{String, Tuple{String, String}}
    chat_history::Vector{ChatMessage}
    current_message::String
end

"""
    TaskData(name::String, description::String)

Create a new task with queued status.
"""
function TaskData(name::String, description::String)
    return TaskData(
        string(UUIDs.uuid4()),
        name,
        description,
        queued,
        now(),
        String[],
        Dict{String, Tuple{String, String}}(),
        ChatMessage[],
        ""
    )
end

# Note: We don't create a Task alias because Task is already defined in Base Julia

"""
    AIDashboard

Main dashboard component for managing AI tasks.

# Fields
- `tasks::Observable{Vector{TaskData}}`: List of tasks
- `selected_task::Observable{Union{TaskData, Nothing}}`: Currently selected task
- `show_task_detail::Observable{Bool}`: Whether to show task detail view
- `active_tab::Observable{String}`: Active tab in detail view ("files" or "chat")
- `chat_component::Union{ChatComponent, Nothing}`: Chat component for the selected task
"""
struct AIDashboard
    tasks::Observable{Vector{TaskData}}
    selected_task::Observable{Union{TaskData, Nothing}}
    show_task_detail::Observable{Bool}
    active_tab::Observable{String}
    chat_component::Union{ChatComponent, Nothing}
end

"""
    AIDashboard(tasks::Vector{TaskData}; chat_agent=nothing, book=nothing)

Create a new AI dashboard with the given tasks.
"""
function AIDashboard(tasks::Vector{TaskData}; chat_agent=nothing, book=nothing)
    return AIDashboard(
        Observable(tasks),
        Observable{Union{TaskData, Nothing}}(nothing),
        Observable(false),
        Observable("files"),
        chat_agent === nothing ? nothing : ChatComponent(chat_agent; book=book)
    )
end

# Status indicator styles
const DASHBOARD_STYLES = Styles(
    CSS(
        ".ai-dashboard",
        "display" => "flex",
        "height" => "100vh",
        "background-color" => "var(--bg-primary)",
        "font-family" => "inherit"
    ),
    CSS(
        ".task-list-panel",
        "width" => "400px",
        "border-right" => "1px solid var(--border-secondary)",
        "background-color" => "var(--bg-primary)",
        "display" => "flex",
        "flex-direction" => "column"
    ),
    CSS(
        ".task-detail-panel",
        "flex" => "1",
        "background-color" => "var(--bg-primary)",
        "display" => "flex",
        "flex-direction" => "column"
    ),
    CSS(
        ".task-list-header",
        "padding" => "16px",
        "border-bottom" => "1px solid var(--border-secondary)",
        "background-color" => "var(--bg-primary)"
    ),
    CSS(
        ".task-list-title",
        "font-size" => "18px",
        "font-weight" => "600",
        "color" => "var(--text-primary)",
        "margin" => "0"
    ),
    CSS(
        ".task-list-container",
        "flex" => "1",
        "overflow-y" => "auto",
        "padding" => "8px"
    ),
    CSS(
        ".task-item",
        "padding" => "12px 16px",
        "margin" => "4px 0",
        "border-radius" => "8px",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "border" => "1px solid var(--border-secondary)"
    ),
    CSS(
        ".task-item:hover",
        "background-color" => "var(--hover-bg)",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".task-item.selected",
        "background-color" => "var(--accent-blue)",
        "color" => "white",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".task-item.selected .task-status",
        "color" => "rgba(255, 255, 255, 0.9)"
    ),
    CSS(
        ".task-name",
        "font-weight" => "600",
        "font-size" => "14px",
        "margin-bottom" => "4px",
        "color" => "inherit"
    ),
    CSS(
        ".task-preview",
        "font-size" => "12px",
        "color" => "var(--text-secondary)",
        "margin-bottom" => "8px",
        "overflow" => "hidden",
        "text-overflow" => "ellipsis",
        "white-space" => "nowrap"
    ),
    CSS(
        ".task-item.selected .task-preview",
        "color" => "rgba(255, 255, 255, 0.8)"
    ),
    CSS(
        ".task-status-row",
        "display" => "flex",
        "justify-content" => "space-between",
        "align-items" => "center"
    ),
    CSS(
        ".task-status",
        "padding" => "2px 8px",
        "border-radius" => "12px",
        "font-size" => "11px",
        "font-weight" => "500",
        "text-transform" => "uppercase",
        "letter-spacing" => "0.5px"
    ),
    CSS(
        ".task-status.queued",
        "background-color" => "#f0f0f0",
        "color" => "#666"
    ),
    CSS(
        ".task-status.started",
        "background-color" => "#fff3cd",
        "color" => "#856404"
    ),
    CSS(
        ".task-status.progress",
        "background-color" => "#d1ecf1",
        "color" => "#0c5460"
    ),
    CSS(
        ".task-status.finished",
        "background-color" => "#d4edda",
        "color" => "#155724"
    ),
    CSS(
        ".task-time",
        "font-size" => "10px",
        "color" => "var(--text-secondary)"
    ),
    CSS(
        ".task-item.selected .task-time",
        "color" => "rgba(255, 255, 255, 0.7)"
    ),
    CSS(
        ".detail-header",
        "padding" => "16px",
        "border-bottom" => "1px solid var(--border-secondary)",
        "background-color" => "var(--bg-primary)"
    ),
    CSS(
        ".detail-title",
        "font-size" => "20px",
        "font-weight" => "600",
        "color" => "var(--text-primary)",
        "margin" => "0 0 8px 0"
    ),
    CSS(
        ".detail-description",
        "font-size" => "14px",
        "color" => "var(--text-secondary)",
        "margin" => "0"
    ),
    CSS(
        ".detail-tabs",
        "display" => "flex",
        "border-bottom" => "1px solid var(--border-secondary)",
        "background-color" => "var(--bg-primary)"
    ),
    CSS(
        ".detail-tab",
        "padding" => "12px 24px",
        "cursor" => "pointer",
        "border-bottom" => "2px solid transparent",
        "font-size" => "14px",
        "font-weight" => "500",
        "color" => "var(--text-secondary)",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".detail-tab:hover",
        "color" => "var(--text-primary)",
        "background-color" => "var(--hover-bg)"
    ),
    CSS(
        ".detail-tab.active",
        "color" => "var(--accent-blue)",
        "border-bottom-color" => "var(--accent-blue)"
    ),
    CSS(
        ".detail-content",
        "flex" => "1",
        "overflow" => "hidden",
        "display" => "flex",
        "flex-direction" => "column"
    ),
    CSS(
        ".empty-state",
        "flex" => "1",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "color" => "var(--text-secondary)",
        "font-size" => "16px"
    ),
    CSS(
        ".file-list",
        "flex" => "1",
        "overflow-y" => "auto",
        "padding" => "16px"
    ),
    CSS(
        ".file-item",
        "padding" => "8px 12px",
        "margin" => "4px 0",
        "border-radius" => "6px",
        "cursor" => "pointer",
        "border" => "1px solid var(--border-secondary)",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".file-item:hover",
        "background-color" => "var(--hover-bg)",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".file-path",
        "font-family" => "monospace",
        "font-size" => "13px",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".file-status",
        "font-size" => "11px",
        "color" => "var(--text-secondary)",
        "margin-top" => "2px"
    ),
    CSS(
        ".files-diff-container",
        "display" => "flex",
        "height" => "100%",
        "gap" => "1px"
    ),
    CSS(
        ".files-sidebar",
        "width" => "300px",
        "border-right" => "1px solid var(--border-secondary)",
        "background-color" => "var(--bg-primary)",
        "display" => "flex",
        "flex-direction" => "column"
    ),
    CSS(
        ".files-header",
        "padding" => "12px 16px",
        "font-weight" => "600",
        "font-size" => "14px",
        "border-bottom" => "1px solid var(--border-secondary)",
        "color" => "var(--text-primary)"
    ),
    CSS(
        ".files-list-sidebar",
        "flex" => "1",
        "overflow-y" => "auto",
        "padding" => "8px"
    ),
    CSS(
        ".diff-editor-panel",
        "flex" => "1",
        "background-color" => "var(--bg-primary)"
    ),
    CSS(
        ".diff-editor-container",
        "width" => "100%",
        "height" => "100%",
        "min-height" => "400px"
    ),
    CSS(
        ".file-item.selected",
        "background-color" => "var(--accent-blue)",
        "color" => "white"
    ),
    CSS(
        ".file-item.selected .file-path",
        "color" => "white"
    ),
    CSS(
        ".file-item.selected .file-status",
        "color" => "rgba(255, 255, 255, 0.8)"
    )
)

function render_task_status(status::TaskStatus)
    status_name = string(status)
    return DOM.span(status_name, class="task-status $status_name")
end

function render_task_item(task::TaskData, selected::Bool)
    # Format the preview message
    preview = if !isempty(task.current_message)
        task.current_message
    elseif !isempty(task.description)
        task.description
    else
        "No description"
    end

    # Truncate preview if too long
    if length(preview) > 60
        preview = preview[1:57] * "..."
    end

    time_str = Dates.format(task.created_at, "HH:MM")

    class = selected ? "task-item selected" : "task-item"

    return DOM.div(
        DOM.div(task.name, class="task-name"),
        DOM.div(preview, class="task-preview"),
        DOM.div(
            render_task_status(task.status),
            DOM.div(time_str, class="task-time"),
            class="task-status-row"
        ),
        class=class
    )
end

"""
    DiffEditor

Monaco diff editor component for showing file changes.

# Fields
- `original::Observable{String}`: Original file content
- `modified::Observable{String}`: Modified file content
- `language::String`: Programming language for syntax highlighting
"""
struct DiffEditor
    original::Observable{String}
    modified::Observable{String}
    language::String
    visible::Observable{Bool}
end

function DiffEditor(original::String="", modified::String=""; language="julia")
    return DiffEditor(
        Observable(original),
        Observable(modified),
        language,
        Observable(false)
    )
end

function Bonito.jsrender(session::Session, diff_editor::DiffEditor)
    editor_div = DOM.div(class="monaco-diff-editor")

    # Create the diff editor using Monaco
    init_script = js"""
    $(Monaco).then(mod => {
        const diffContainer = $(editor_div);

        // Create diff editor
        const diffEditor = new mod.MonacoDiffEditor(
            diffContainer,
            {
                language: $(diff_editor.language),
                original: $(diff_editor.original[]),
                modified: $(diff_editor.modified[]),
                readOnly: true,
                minimap: { enabled: true },
                scrollBeyondLastLine: false,
                renderSideBySide: true,
                enableSplitViewResizing: false,
                automaticLayout: true
            }
        );

        // Update content when observables change
        $(diff_editor.original).on(content => {
            diffEditor.setOriginalContent(content);
        });

        $(diff_editor.modified).on(content => {
            diffEditor.setModifiedContent(content);
        });

        return diffEditor;
    });
    """

    style = Styles(
        "width" => "100%",
        "height" => "100%",
        "min-height" => "400px"
    )

    return Bonito.jsrender(session, DOM.div(
        editor_div,
        init_script,
        style=style,
        class="diff-editor-container"
    ))
end

function render_file_diff_tab(task::TaskData)
    if isempty(task.modified_files)
        return DOM.div("No files modified yet.", class="empty-state")
    end

    # Selected file observable (this creates a stateful component)
    selected_file = Observable(task.modified_files[1])

    # Create diff editor
    diff_editor = DiffEditor("", "", language="julia")

    # File list
    file_items = map(task.modified_files) do filepath
        is_selected = selected_file[] == filepath
        item_class = is_selected ? "file-item selected" : "file-item"

        # Check if we have diff data for this file
        status = if haskey(task.file_diffs, filepath)
            "Modified"
        else
            "New file"
        end

        DOM.div(
            DOM.div(filepath, class="file-path"),
            DOM.div(status, class="file-status"),
            class=item_class,
            onclick=js"""() => {
                $(selected_file).notify($filepath);

                // Update diff editor content
                const diffData = $(get(task.file_diffs, filepath, ("", "")));
                $(diff_editor.original).notify(diffData[0]);
                $(diff_editor.modified).notify(diffData[1]);
                $(diff_editor.visible).notify(true);
            }"""
        )
    end

    # Initialize diff editor with first file if available
    if !isempty(task.modified_files)
        first_file = task.modified_files[1]
        diff_data = get(task.file_diffs, first_file, ("", ""))
        diff_editor.original[] = diff_data[1]
        diff_editor.modified[] = diff_data[2]
        diff_editor.visible[] = true
    end

    # Layout: file list on left, diff editor on right
    return DOM.div(
        DOM.div(
            DOM.div("Files", class="files-header"),
            DOM.div(file_items..., class="files-list-sidebar"),
            class="files-sidebar"
        ),
        DOM.div(
            diff_editor,
            class="diff-editor-panel"
        ),
        class="files-diff-container",
        style="display: flex; height: 100%;"
    )
end

function render_chat_tab(dashboard::AIDashboard, task::TaskData)
    if dashboard.chat_component === nothing
        return DOM.div("Chat functionality not available. No AI agent configured.", class="empty-state")
    end

    # Update chat component with task-specific messages
    dashboard.chat_component.messages[] = task.chat_history

    return DOM.div(dashboard.chat_component, style="flex: 1; display: flex; flex-direction: column;")
end

function render_task_detail(dashboard::AIDashboard, task::Union{TaskData, Nothing}, active_tab::String)
    if task === nothing
        return DOM.div("Select a task to view details", class="empty-state")
    end

    # Tabs
    files_tab_class = active_tab == "files" ? "detail-tab active" : "detail-tab"
    chat_tab_class = active_tab == "chat" ? "detail-tab active" : "detail-tab"

    tabs = DOM.div(
        DOM.div("Files", class=files_tab_class, onclick=js"() => $(dashboard.active_tab).notify('files')"),
        DOM.div("Chat", class=chat_tab_class, onclick=js"() => $(dashboard.active_tab).notify('chat')"),
        class="detail-tabs"
    )

    # Content based on active tab
    content = if active_tab == "files"
        render_file_diff_tab(task)
    elseif active_tab == "chat"
        render_chat_tab(dashboard, task)
    else
        DOM.div("Unknown tab", class="empty-state")
    end

    return DOM.div(
        DOM.div(
            DOM.h2(task.name, class="detail-title"),
            DOM.p(task.description, class="detail-description"),
            class="detail-header"
        ),
        tabs,
        DOM.div(content, class="detail-content"),
        class="task-detail-panel"
    )
end

function Bonito.jsrender(session::Session, dashboard::AIDashboard)
    # Create a simple observable for selected task ID
    selected_task_id = Observable{String}("")

    # When the task ID changes, find and set the corresponding task
    on(selected_task_id) do task_id
        if !isempty(task_id)
            tasks = dashboard.tasks[]
            selected_task = findfirst(t -> t.id == task_id, tasks)
            if selected_task !== nothing
                dashboard.selected_task[] = tasks[selected_task]
                dashboard.show_task_detail[] = true
            end
        end
    end

    # Task list panel
    task_list_items = map(dashboard.tasks, dashboard.selected_task) do tasks, selected_task
        items = []
        for task in tasks
            is_selected = selected_task !== nothing && selected_task.id == task.id

            # Format the preview message
            preview = if !isempty(task.current_message)
                task.current_message
            elseif !isempty(task.description)
                task.description
            else
                "No description"
            end

            # Truncate preview if too long
            if length(preview) > 60
                preview = preview[1:57] * "..."
            end

            time_str = Dates.format(task.created_at, "HH:MM")
            task_class = is_selected ? "task-item selected" : "task-item"

            item = DOM.div(
                DOM.div(task.name, class="task-name"),
                DOM.div(preview, class="task-preview"),
                DOM.div(
                    render_task_status(task.status),
                    DOM.div(time_str, class="task-time"),
                    class="task-status-row"
                ),
                class=task_class,
                onclick=js"""() => {
                    $(selected_task_id).notify($(task.id));
                }"""
            )

            push!(items, item)
        end
        return DOM.div(items..., class="task-list-container")
    end

    task_list_panel = DOM.div(
        DOM.div(
            DOM.h1("AI Tasks", class="task-list-title"),
            class="task-list-header"
        ),
        task_list_items,
        class="task-list-panel"
    )

    # Task detail panel (reactive based on selected task and active tab)
    detail_panel = map(dashboard.selected_task, dashboard.active_tab) do selected_task, active_tab
        return render_task_detail(dashboard, selected_task, active_tab)
    end

    # Main dashboard container
    dashboard_div = DOM.div(
        DASHBOARD_STYLES,
        task_list_panel,
        detail_panel,
        class="ai-dashboard"
    )

    return Bonito.jsrender(session, dashboard_div)
end