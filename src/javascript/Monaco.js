const MONACO = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm";
const monaco = import(MONACO);

class Book {
    constructor() {
        this.cells = []; // Ordered list of cell uuids
        this.editors = {}; // Map of editors by id
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
        for (let i = index - 1; i >= 0; i--) {
            // skip hidden cells
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
        for (let i = index + 1; i < this.cells.length; i++) {
            // skip hidden cells
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
        // Remove the editor element from the DOM
        // Needs to be parent since the cell div is wrapped in another with the add menu
        document.getElementById(uuid).parentElement.remove();
    }
}

export const BOOK = new Book();

export class EvalEditor {
    constructor(
        monaco_editor,
        output_div,
        logging_div,
        direction,
        js_to_julia,
        julia_to_js,
        source_obs,
        show_output,
        show_logging
    ) {
        this.message_queue = [];
        this.editor = monaco_editor;
        this.output_div = output_div;
        this.logging_div = logging_div;
        this.direction = direction;
        this.source_obs = source_obs;

        this.show_output = show_output;
        this.show_logging = show_logging;

        this.js_to_julia = js_to_julia;
        julia_to_js.on((message) => {
            console.log(message)
            this.process_message(message);
        });
        monaco.then((monaco) => {
            console.log(monaco_editor)
            monaco_editor.editor.then((editor) => {
                resize_to_lines(editor, monaco, this.editor.editor_div);
                editor.addCommand(
                    monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, // Ctrl+P or Cmd+P
                    () => {
                        // Trigger the built-in command palette command
                        editor.trigger(
                            "keyboard",
                            "editor.action.quickCommand",
                            null
                        );
                    }
                );
                add_command(
                    editor,
                    "Eval cell",
                    [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter],
                    () => {
                        this.set_source();
                        this.run();
                        this.send();
                    }
                );
                add_command(
                    editor,
                    "Eval cell + add new cell",
                    [monaco.KeyMod.Shift | monaco.KeyCode.Enter],
                    () => {
                        this.set_source();
                        this.run();
                        this.send();
                        move_down(editor);
                    }
                );
                add_command(
                    editor,
                    "Save",
                    [monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS],
                    () => {
                        this.set_source();
                        this.send();
                    }
                );
            });
        });
    }
    run() {
        this.message_queue.push({ type: "run" });
    }
    set_source() {
        this.editor.editor.then((editor => {
            this.message_queue.push({
                type: "new-source",
                data: editor.getValue(),
            });
        }));
    }
    send() {
        if (this.message_queue.length === 0) return;
        if (this.message_queue.length === 1) {
            this.js_to_julia.notify(this.message_queue[0]);
        } else {
            this.js_to_julia.notify({
                type: "multi",
                data: this.message_queue,
            });
        }
        this.message_queue = [];
    }
    process_message(message) {
        if (message.type === "get-source") {
            this.editor.editor.then((editor) => {
                this.js_to_julia.notify({
                    type: "new-source",
                    data: editor.getValue(),
                });
            });
        } else if (message.type === "set-source") {
            this.editor.editor.then((editor) => {
                editor.setValue(message.data);
            });
        } else if (message.type === "run-from-newest") {
            this.editor.editor.then((editor) => {
                const newest_source = editor.getValue();
                if (this.source_obs.value != newest_source) {
                    this.message_queue.push({
                        type: "new-source",
                        data: newest_source,
                    });
                }
                this.run();
                this.send();
            });
        } else if (message.type === "toggle-editor") {
            this.editor.toggle_editor(message.data);
        } else if (message.type === "toggle-output") {
            this.show_output = message.data;
            toggle_elem(message.data, this.output_div, this.direction);
        } else if (message.type === "toggle-logging") {
            this.show_logging = message.data;
            toggle_elem(message.data, this.logging_div, this.direction);
        } else if (message.type === "multi") {
            message.data.forEach(this.process_message.bind(this));
        } else {
            console.warn("Unknown message type:", message.type);
        }
    }
}

export function add_editor_below(above_editor_uuid, elem, uuid) {
    const editor_div = document.getElementById(above_editor_uuid); // Correct function
    const parent1 = editor_div.parentElement; // Parent of editor_div
    // Append elem just below parent of editor_div
    parent1.insertAdjacentElement("afterend", elem);
    BOOK.add_below(above_editor_uuid, uuid);
}

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

export function toggle_elem(show, elem, direction) {
    console.log("Toggling element", elem, "to", show);
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

export function setup_cell_interactions(
    buttons,
    container,
    card_content,
    loading_obs,
    all_visible_obs,

    // Markdown unhiding behavior
    hide_on_focus_obs,
    show_editor_obs,
    show_output_obs,
    get_source_obs
) {
    const make_visible = () => {
        buttons.style.opacity = 1.0;
    };
    const hide = () => {
        buttons.style.opacity = 0.0;
    };
    container.addEventListener("mouseover", make_visible);
    container.addEventListener("mouseout", hide);

    loading_obs.on((x) => {
        if (x) {
            card_content.classList.add("loading-cell");
        } else {
            card_content.classList.remove("loading-cell");
        }
    });
    all_visible_obs.on((x) => {
        toggle_elem(x, card_content, "vertical");
    });
    container.addEventListener("focus", (e) => {
        if (hide_on_focus_obs.value) {
            show_editor_obs.notify(true);
            show_output_obs.notify(false);
        }
    });
    container.addEventListener("focusout", (e) => {
        if (hide_on_focus_obs.value) {
            if (!container.contains(e.relatedTarget)) {
                show_editor_obs.notify(false);
                show_output_obs.notify(true);
                get_source_obs.notify(true);
            }
        }
    });
}

export class MonacoEditor {
    constructor(
        editor_div,
        options,
        init_callback,
        hiding_direction,
        visible,
        theme
    ) {
        this.editor_div = editor_div;
        this.options = options;
        this.initialized = false;
        this.hiding_direction = hiding_direction;
        this.theme = theme;
        this.editor = new Promise((resolve) => {
            this.resolve_setup = resolve;
        })
        if (visible) {
            this.initialize();
        }
        init_callback(this);
    }
    set_theme(theme) {
        monaco.then((m) => m.editor.setTheme(theme));
    }
    update_options(options) {
        this.editor.then(x=> x.updateOptions(options));
    }
    initialize() {
        monaco.then((monaco) => {
            const div = this.editor_div;
            const editor = monaco.editor.create(div, this.options);
            div._editor_instance = this.editor;
            monaco.editor.setTheme(this.theme);
            this.initialized = true;
            this.resolve_setup(editor);
        });
    }
    toggle_editor(show) {
        const div = this.editor_div;
        toggle_elem(show, div, this.hiding_direction);
        if (show && !this.initialized) {
            // if just toggled visibility, we need to wait for the transition to end
            // to have the width/height on the final value
            const callback = () => {
                this.initialize();
                // Remove listener to prevent multiple calls
                div.removeEventListener("transitionend", callback);
            };
            const transition_str = getComputedStyle(div).transitionDuration;
            const transition = parseFloat(transition_str) * 1000;
            if (transition === 0) {
                callback();
            } else {
                div.addEventListener("transitionend", callback);
                setTimeout(callback, transition);
            }
        }
    };
}

class Connection {
    constructor(inbox, outbox) {
        this.inbox = inbox;
        this.outbox = outbox;
        this.message_id = 0;
        this.promises = {};

        inbox.on((msg) => {
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
        // Send the data with the current message_id
        this.outbox.notify([id, data]);
        // Create a new promise and store it
        const promise = new Promise((resolve, reject) => {
            // Add resolve function to the promises object with the message_id as key
            this.promises[id] = { resolve, reject };
        });
        // Return the promise for the caller to await
        return promise;
    }
}

export function register_completions(inbox, outbox) {
    const comm = new Connection(inbox, outbox);
    return monaco.then((monaco) => {
        // Register the completion provider
        monaco.languages.registerCompletionItemProvider("julia", {
            triggerCharacters: [".", "/", ":", "@", "(", "[", '"'],
            provideCompletionItems: (model, position) => {
                return new Promise((resolve) => {
                    const line = position.lineNumber;
                    const column = position.column;
                    const text = model.getValueInRange({
                        startLineNumber: line,
                        startColumn: 1,
                        endLineNumber: line,
                        endColumn: column,
                    });
                    // Send request to Julia backend
                    const request = {
                        text: text,
                        line: line,
                        column: column,
                    };
                    comm.send(request).then((response) => {
                        const suggestions = response.map((item) => {
                            return {
                                kind: item.kind,
                                insertText: item.insertText,
                                label: item.insertText,
                            };
                        });
                        resolve({ suggestions: suggestions });
                    });
                });
            },
        });
    });
}

function move_to_editor(editor) {
    const editorElement = editor.getDomNode();
    if (editorElement) {
        // I think centering is a bit extreme, so we use nearest
        editorElement.scrollIntoView({
            behavior: "smooth", // smooth scrolling
            block: "nearest", // only scroll as much as needed
        });
    }
}

function move_up(editor) {
    const upper = BOOK.get_up(editor).editor;
    if (upper) {
        upper.then((upper) => {
            const lastLine = upper.getModel().getLineCount();
            upper.focus();
            upper.setPosition({
                lineNumber: lastLine,
                column: 1,
            });
            move_to_editor(upper);
        })
    }
}

function move_down(editor) {
    const lower = BOOK.get_down(editor).editor;
    if (lower) {
        lower.then(lower => {
            lower.focus();
            lower.setPosition({
                lineNumber: 1,
                column: 1,
            });
            move_to_editor(lower);
        });
    }
}

export function register_cell_editor(eval_editor, uuid) {
    monaco.then((monaco) => {
        eval_editor.editor.then(editor => {
            BOOK.add_editor(eval_editor, uuid);
            editor.cell_uuid = uuid;
            const cursorAtBottomKey = editor.createContextKey(
                "editorCursorAtBottom",
                false
            );
            const cursorAtTopKey = editor.createContextKey(
                "editorCursorAtTop",
                false
            );
            const update_corsor_context = () => {
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
                precondition:
                    "editorTextFocus && !suggestWidgetVisible && editorCursorAtTop",
                keybindings: [monaco.KeyCode.UpArrow],
                run: move_up,
                contextMenuGroupId: "navigation",
            });

            editor.addAction({
                id: `move-down-${uuid}`,
                label: "Move down",
                keybindings: [monaco.KeyCode.DownArrow],
                precondition:
                    "editorTextFocus && !suggestWidgetVisible && editorCursorAtBottom",
                run: move_down,
                contextMenuGroupId: "navigation",
            });
        });
    });
}
