export function add_command(editor, label, keybinding, callback) {
    editor.addAction({
        // An unique identifier of the contributed action.
        id: label,
        // A label of the action that will be presented to the user.
        label: label,
        // An optional array of keybindings for the action.
        keybindings: keybinding,
        contextMenuGroupId: "navigation",
        contextMenuOrder: 1.5,
        // Method that will be executed when the action is triggered.
        // @param editor The editor instance is passed in as a convenience
        run: callback,
    });

}


export function resize_to_lines(editor, monaco, editor_div) {
    // Resize editor based on content
    function updateEditorHeight() {
        const lineHeight = editor.getOption(
            monaco.editor.EditorOption.lineHeight
        );
        const lineCount = editor.getModel().getLineCount();
        const height = lineHeight * lineCount;
        editor_div.style.height = height + "px";
        editor.layout();
    }

    // Update height on content change
    editor.onDidChangeModelContent(updateEditorHeight);
    // Initial resize
    updateEditorHeight();
}


export function register_source_updates(source_obs, editor, monaco) {
    const set_source = () => source_obs.notify(editor.getValue());
    add_command(
        editor,
        "Eval cell",
        [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter],
        set_source
    );
    add_command(
        editor,
        "Eval cell + add new cell",
        [monaco.KeyMod.Shift | monaco.KeyCode.Enter],
        set_source
    );
    add_command(
        editor,
        "Save File",
        [monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS],
        set_source
    );
}

export function setup_cell_editor(
    editor,
    monaco,
    editor_div,
    output_div,
    logging_div,
    source_obs,
    get_source_obs,
    set_source_obs,
    show_output,
    show_logging,
) {
    resize_to_lines(editor, monaco, editor_div);
    editor.addCommand(
        monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, // Ctrl+P or Cmd+P
        function () {
            // Trigger the built-in command palette command
            editor.trigger("keyboard", "editor.action.quickCommand", null);
        }
    );
    const set_source = () => source_obs.notify(editor.getValue());

    add_command(
        editor,
        "Eval cell",
        [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter],
        set_source
    );
    add_command(
        editor,
        "Eval cell + add new cell",
        [monaco.KeyMod.Shift | monaco.KeyCode.Enter],
        set_source
    );
    add_command(
        editor,
        "Save",
        [monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS],
        set_source
    );
    // requests to fetch the latest source from editor
    get_source_obs.on((x) => set_source());

    const toggle_elem = (show, elem) => {
        elem.style.display = show ? "block" : "none";
    };

    toggle_elem(show_output.value, output_div);
    show_output.on((x) => toggle_elem(x, output_div));

    set_source_obs.on((x) => editor.setValue(x));
    show_logging.on((x) => {
        if (x) {
            logging_div.classList.add("show");
        } else {
            logging_div.classList.remove("show");
        }
    });
    return [monaco, editor];
}


export function setup_editor(
    editor_div,
    editor_container,
    options,
    language_obs,
    init_callback,
    show_editor,
    hiding_direction,
) {
    return import(
        "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm"
    ).then((monaco) => {
        const editor = monaco.editor.create(editor_div, options);
        editor._editor_instance = editor;
        init_callback(editor, monaco, editor_div);
        language_obs.on((x) => {
            editor.updateOptions({ language: x });
        });
        const toggle_elem = (show, elem) => {
            if (show) {
                elem.classList.remove(`hide-${hiding_direction}`);
                elem.classList.add(`show-${hiding_direction}`);
            } else {
                elem.classList.add(`hide-${hiding_direction}`);
                elem.classList.remove(`show-${hiding_direction}`);
            }
        };
        toggle_elem(show_editor.value, editor_container);
        show_editor.on((x) => toggle_elem(x, editor_container));

        return [monaco, editor];
    });
}
