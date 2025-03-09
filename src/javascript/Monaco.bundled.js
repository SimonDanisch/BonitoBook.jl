// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

function add_command(editor, label, keybinding, callback) {
    editor.addAction({
        id: label,
        label: label,
        keybindings: keybinding,
        contextMenuGroupId: "navigation",
        contextMenuOrder: 1.5,
        run: callback
    });
}
function setup_cell_editor(editor, monaco, editor_div, output_div, editor_container, logging_div, source_obs, get_source_obs, set_source_obs, show_output, show_editor, show_logging) {
    function updateEditorHeight() {
        const lineHeight = editor.getOption(monaco.editor.EditorOption.lineHeight);
        const lineCount = editor.getModel().getLineCount();
        const height = lineHeight * lineCount;
        editor_div.style.height = height + "px";
        editor.layout();
    }
    editor.onDidChangeModelContent(updateEditorHeight);
    updateEditorHeight();
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, function() {
        editor.trigger("keyboard", "editor.action.quickCommand", null);
    });
    const set_source = ()=>source_obs.notify(editor.getValue());
    add_command(editor, "Eval cell", [
        monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter
    ], set_source);
    add_command(editor, "Eval cell + add new cell", [
        monaco.KeyMod.Shift | monaco.KeyCode.Enter
    ], set_source);
    get_source_obs.on((x)=>set_source());
    const toggle_elem = (show, elem)=>{
        elem.style.display = show ? "block" : "none";
    };
    toggle_elem(show_output.value, output_div);
    toggle_elem(show_editor.value, editor_container);
    show_output.on((x)=>toggle_elem(x, output_div));
    show_editor.on((x)=>toggle_elem(x, editor_container));
    set_source_obs.on((x)=>editor.setValue(x));
    show_logging.on((x)=>{
        if (x) {
            logging_div.classList.add("show");
        } else {
            logging_div.classList.remove("show");
        }
    });
    return [
        monaco,
        editor
    ];
}
function setup_editor(editor_div, options, language_obs, init_callback) {
    return import("https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm").then((monaco)=>{
        const editor = monaco.editor.create(editor_div, options);
        init_callback(editor, monaco, editor_div);
        language_obs.on((x)=>{
            editor.updateOptions({
                language: x
            });
        });
        return [
            monaco,
            editor
        ];
    });
}
export { add_command as add_command };
export { setup_cell_editor as setup_cell_editor };
export { setup_editor as setup_editor };

