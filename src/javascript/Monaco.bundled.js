// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

const MONACO = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm";
class Book {
    constructor(){
        this.cells = [];
        this.editors = {};
    }
    update_order(uuids) {
        this.cells = uuids;
    }
    add_editor(editor, uuid) {
        this.editors[uuid] = editor;
    }
    add_below(uuid_above, uuid) {
        const index = this.cells.indexOf(uuid_above);
        if (index === -1) {
            throw new Error("Cell not found in the book.");
        }
        this.cells.splice(index + 1, 0, uuid);
    }
    get_up(editor) {
        const uuid = editor.cell_uuid;
        const index = this.cells.indexOf(uuid);
        if (index <= 0) return null;
        for(let i = index - 1; i >= 0; i--){
            const up_uuid = this.cells[i];
            if (this.editors[up_uuid]) {
                return this.editors[up_uuid];
            }
        }
        return null;
    }
    get_down(editor) {
        const uuid = editor.cell_uuid;
        const index = this.cells.indexOf(uuid);
        if (index === -1 || index >= this.cells.length - 1) return null;
        for(let i = index + 1; i < this.cells.length; i++){
            const down_uuid = this.cells[i];
            if (this.editors[down_uuid]) {
                return this.editors[down_uuid];
            }
        }
        return null;
    }
    remove_editor(uuid) {
        delete this.editors[uuid];
        const index = this.cells.indexOf(uuid);
        if (index !== -1) {
            this.cells.splice(index, 1);
        }
        document.getElementById(uuid).parentElement.remove();
    }
}
function add_editor_below(above_editor_uuid, elem, uuid) {
    console.log(`inserting ${uuid} below ${above_editor_uuid}`);
    const editor_div = document.getElementById(above_editor_uuid);
    const parent1 = editor_div.parentElement;
    parent1.insertAdjacentElement("afterend", elem);
    BOOK.add_below(above_editor_uuid, uuid);
}
const BOOK = new Book();
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
function resize_to_lines(editor, monaco, editor_div) {
    function updateEditorHeight() {
        const lineHeight = editor.getOption(monaco.editor.EditorOption.lineHeight);
        const lineCount = editor.getModel().getLineCount();
        const height = lineHeight * lineCount;
        editor_div.style.height = height + "px";
        editor.layout();
    }
    editor.onDidChangeModelContent(updateEditorHeight);
    updateEditorHeight();
}
function toggle_elem(show, elem, direction) {
    const hide_class = `hide-${direction}`;
    const show_class = `show-${direction}`;
    if (!elem) {
        console.warn("No element to toggle");
        return;
    }
    if (show) {
        elem.classList.remove(hide_class);
        elem.classList.add(show_class);
    } else {
        elem.classList.add(hide_class);
        elem.classList.remove(show_class);
    }
}
function setup_cell_editor(editor, monaco, editor_div, output_div, logging_div, source_obs, get_source_obs, set_source_obs, show_output, show_logging, direction) {
    editor.setValue(source_obs.value);
    resize_to_lines(editor, monaco, editor_div);
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, function() {
        editor.trigger("keyboard", "editor.action.quickCommand", null);
    });
    const set_source = ()=>source_obs.notify(editor.getValue());
    add_command(editor, "Eval cell", [
        monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter
    ], set_source);
    add_command(editor, "Eval cell + add new cell", [
        monaco.KeyMod.Shift | monaco.KeyCode.Enter
    ], (editor)=>{
        console.log("HEY!!!");
        set_source();
        console.log(editor);
        move_down(editor);
    });
    add_command(editor, "Save", [
        monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS
    ], set_source);
    get_source_obs.on((x)=>set_source());
    set_source_obs.on((x)=>{
        editor.setValue(x);
    });
    show_output.on((x)=>{
        toggle_elem(x, output_div, direction);
    });
    toggle_elem(show_output.value, output_div, direction);
    show_logging.on((x)=>toggle_elem(x, logging_div, direction));
    toggle_elem(show_logging.value, logging_div, direction);
    return [
        monaco,
        editor
    ];
}
function setup_cell_interactions(buttons, container, card_content, loading_obs, all_visible_obs, hide_on_focus_obs, show_editor_obs, show_output_obs, get_source_obs) {
    const make_visible = ()=>{
        buttons.style.opacity = 1.0;
    };
    const hide = ()=>{
        buttons.style.opacity = 0.0;
    };
    container.addEventListener("mouseover", make_visible);
    container.addEventListener("mouseout", hide);
    loading_obs.on((x)=>{
        if (x) {
            card_content.classList.add("loading-cell");
        } else {
            card_content.classList.remove("loading-cell");
        }
    });
    all_visible_obs.on((x)=>{
        toggle_elem(x, card_content, "vertical");
    });
    container.addEventListener("focus", (e)=>{
        if (hide_on_focus_obs.value) {
            show_editor_obs.notify(true);
            show_output_obs.notify(false);
        }
    });
    container.addEventListener("focusout", (e)=>{
        if (hide_on_focus_obs.value) {
            if (!container.contains(e.relatedTarget)) {
                show_editor_obs.notify(false);
                show_output_obs.notify(true);
                get_source_obs.notify(true);
            }
        }
    });
}
function setup_editor(editor_div, options, language_obs, init_callback, show_editor, hiding_direction, monaco_theme_obs) {
    return import(MONACO).then((monaco)=>{
        let initialized = false;
        function init_editor() {
            const editor = monaco.editor.create(editor_div, options);
            monaco.editor.setTheme(monaco_theme_obs.value);
            monaco_theme_obs.on((x)=>{
                monaco.editor.setTheme(x);
            });
            editor_div._editor_instance = editor;
            language_obs.on((x)=>{
                editor.updateOptions({
                    language: x
                });
            });
            initialized = true;
            return Promise.resolve(init_callback(editor, monaco, editor_div));
        }
        return new Promise((resolve)=>{
            const toggle = (show)=>{
                if (!editor_div) {
                    console.warn("No element to toggle");
                    return;
                }
                const already_visible = editor_div.classList.contains(`show-${hiding_direction}`);
                toggle_elem(show, editor_div, hiding_direction);
                if (show && !initialized) {
                    if (already_visible) {
                        init_editor().then(resolve);
                    } else {
                        const on_transition_end = ()=>{
                            init_editor().then(resolve);
                            initialized = true;
                            editor_div.removeEventListener("transitionend", on_transition_end);
                        };
                        const transition_str = getComputedStyle(editor_div).transitionDuration;
                        const transition = parseFloat(transition_str) * 1000;
                        if (transition === 0) {
                            on_transition_end();
                        } else {
                            editor_div.addEventListener("transitionend", on_transition_end);
                            setTimeout(()=>{
                                if (!initialized) {
                                    on_transition_end();
                                }
                            }, transition);
                        }
                    }
                }
            };
            if (show_editor.value) {
                init_editor().then(resolve);
                initialized = true;
            }
            show_editor.on(toggle);
            return monaco;
        });
    });
}
class Connection {
    constructor(inbox, outbox){
        this.inbox = inbox;
        this.outbox = outbox;
        this.message_id = 0;
        this.promises = {};
        inbox.on((msg)=>{
            const [id, data] = msg;
            const promise = this.promises[id];
            if (promise) {
                delete this.promises[id];
                promise.resolve(data);
            }
        });
    }
    send(data) {
        const id = crypto.randomUUID();
        this.outbox.notify([
            id,
            data
        ]);
        const promise = new Promise((resolve, reject)=>{
            this.promises[id] = {
                resolve,
                reject
            };
        });
        return promise;
    }
}
function register_completions(inbox, outbox) {
    const comm = new Connection(inbox, outbox);
    return import(MONACO).then((monaco)=>{
        monaco.languages.registerCompletionItemProvider("julia", {
            triggerCharacters: [
                ".",
                "/",
                ":",
                "@",
                "(",
                "[",
                '"'
            ],
            provideCompletionItems: (model, position)=>{
                return new Promise((resolve)=>{
                    const line = position.lineNumber;
                    const column = position.column;
                    const text = model.getValueInRange({
                        startLineNumber: line,
                        startColumn: 1,
                        endLineNumber: line,
                        endColumn: column
                    });
                    const request = {
                        text: text,
                        line: line,
                        column: column
                    };
                    comm.send(request).then((response)=>{
                        const suggestions = response.map((item)=>{
                            return {
                                kind: item.kind,
                                insertText: item.insertText,
                                label: item.insertText
                            };
                        });
                        resolve({
                            suggestions: suggestions
                        });
                    });
                });
            }
        });
    });
}
function move_to_editor(editor) {
    const editorElement = editor.getDomNode();
    if (editorElement) {
        editorElement.scrollIntoView({
            behavior: "smooth",
            block: "nearest"
        });
    }
}
function move_up(editor) {
    const upper = BOOK.get_up(editor);
    if (upper) {
        const lastLine = upper.getModel().getLineCount();
        upper.focus();
        upper.setPosition({
            lineNumber: lastLine,
            column: 1
        });
        move_to_editor(upper);
    }
}
function move_down(editor) {
    const lower = BOOK.get_down(editor);
    if (lower) {
        lower.focus();
        lower.setPosition({
            lineNumber: 1,
            column: 1
        });
        move_to_editor(lower);
    }
}
function register_editor(editor, monaco, uuid) {
    console.log(`registering editor ${uuid}`);
    BOOK.add_editor(editor, uuid);
    editor.cell_uuid = uuid;
    const cursorAtBottomKey = editor.createContextKey("editorCursorAtBottom", false);
    const cursorAtTopKey = editor.createContextKey("editorCursorAtTop", false);
    const update_corsor_context = ()=>{
        const position = editor.getPosition();
        const lastLine = editor.getModel().getLineCount();
        cursorAtBottomKey.set(position.lineNumber === lastLine);
        cursorAtTopKey.set(position.lineNumber === 1);
    };
    editor.onDidChangeCursorPosition(update_corsor_context);
    update_corsor_context();
    editor.addAction({
        id: `move-up-${uuid}`,
        label: "Move up",
        precondition: "editorTextFocus && !suggestWidgetVisible && editorCursorAtTop",
        keybindings: [
            monaco.KeyCode.UpArrow
        ],
        run: move_up,
        contextMenuGroupId: "navigation"
    });
    editor.addAction({
        id: `move-down-${uuid}`,
        label: "Move down",
        keybindings: [
            monaco.KeyCode.DownArrow
        ],
        precondition: "editorTextFocus && !suggestWidgetVisible && editorCursorAtBottom",
        run: move_down,
        contextMenuGroupId: "navigation"
    });
}
export { add_editor_below as add_editor_below };
export { BOOK as BOOK };
export { add_command as add_command };
export { resize_to_lines as resize_to_lines };
export { toggle_elem as toggle_elem };
export { setup_cell_editor as setup_cell_editor };
export { setup_cell_interactions as setup_cell_interactions };
export { setup_editor as setup_editor };
export { register_completions as register_completions };
export { register_editor as register_editor };

