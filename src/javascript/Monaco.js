const MONACO = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm";
const monaco = import(MONACO);

// Function to check if we're in export mode
function is_export_mode() {
    return window.BONITO_EXPORT_MODE === true;
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
        this.theme = theme.value;
        this.monaco = monaco;
        theme.on((new_theme) => {
            this.set_theme(new_theme);
        });
        this.editor = new Promise((resolve) => {
            this.resolve_setup = resolve;
        });
        if (visible) {
            this.initialize();
        }
        init_callback(this);
    }
    set_theme(theme) {
        this.theme = theme;
        monaco.then((m) => {
            let effectiveTheme = theme;
            if (theme === "default") {
                effectiveTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'vs-dark' : 'vs';
            }
            m.editor.setTheme(effectiveTheme);
        });
    }
    update_options(options) {
        this.editor.then((x) => x.updateOptions(options));
    }
    initialize() {
        monaco.then((monaco) => {
            const div = this.editor_div;
            const editor = monaco.editor.create(div, this.options);
            div._editor_instance = this.editor;
            this.set_theme(this.theme);
            this.initialized = true;

            // Prevent scroll events from being captured by the editor
            // This allows page scrolling to work when mouse is over the editor
            const editorDomNode = editor.getDomNode();
            if (editorDomNode) {
                editorDomNode.addEventListener('wheel', (e) => {
                    // Prevent Monaco from handling the wheel event
                    e.stopPropagation();
                    e.preventDefault();

                    // Find the scrollable parent (could be book-cells-area or window)
                    const scrollParent = document.querySelector(".book-cells-area");

                    if (scrollParent) {
                        // Use scrollBy for smoother scrolling with proper delta handling
                        scrollParent.scrollBy({
                            top: e.deltaY,
                            left: e.deltaX,
                            behavior: 'auto' // Use 'auto' for immediate scrolling like native
                        });
                    } else {
                        // Fallback to window scrolling
                        window.scrollBy(e.deltaX, e.deltaY);
                    }
                }, { passive: false });
            }

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
    }
}

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
        show_logging,
        do_resize_to_lines = true
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
            this.process_message(message);
        });
        monaco.then((monaco) => {
            monaco_editor.editor.then((editor) => {
                if (do_resize_to_lines) {
                    resize_to_lines(editor, monaco, this.editor.editor_div);
                }
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
                        this.set_source(editor);
                        this.run();
                        this.send();
                    }
                );
                add_command(
                    editor,
                    "Eval cell + add new cell",
                    [monaco.KeyMod.Shift | monaco.KeyCode.Enter],
                    () => {
                        this.set_source(editor);
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
                        this.set_source(editor);
                        this.send();
                    }
                );
            });
        });
    }
    run() {
        this.message_queue.push({ type: "run" });
    }
    set_source(editor) {
        this.message_queue.push({
            type: "new-source",
            data: editor.getValue(),
        });
    }
    send() {
        if (this.message_queue.length === 0) return;
        if (this.message_queue.length === 1) {
            this.js_to_julia.notify(this.message_queue[0]);
        } else {
            console.log(this.message_queue);
            this.js_to_julia.notify({
                type: "multi",
                data: this.message_queue,
            });
        }
        this.message_queue = [];
    }
    process_message(message) {
        console.log(message);
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
        } else if (message.type === "goto-line") {
            this.editor.editor.then((editor) => {
                const lineNumber = Math.max(1, message.line);
                const model = editor.getModel();
                const totalLines = model.getLineCount();

                // Ensure line number is within bounds
                const targetLine = Math.max(1, Math.min(lineNumber, totalLines));

                // Set cursor position and reveal line
                editor.setPosition({
                    lineNumber: targetLine,
                    column: 1
                });
                editor.revealLineInCenter(targetLine);
                editor.focus();
            });
        } else if (message.type === "multi") {
            message.data.forEach(this.process_message.bind(this));
        } else {
            console.warn("Unknown message type:", message.type);
        }
    }
    toggle_editor(show) {
        this.editor.toggle_editor(show);
        this.js_to_julia.notify({
            type: "toggle-editor",
            data: show,
        });
    }
    toggle_output(show) {
        this.show_output = show;
        this.js_to_julia.notify({
            type: "toggle-output",
            data: show,
        });
        toggle_elem(show, this.output_div, this.direction);
    }
    toggle_logging(show) {
        this.show_logging = show;
        this.js_to_julia.notify({
            type: "toggle-logging",
            data: show,
        });
        toggle_elem(show, this.logging_div, this.direction);
    }
}

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

export function resize_to_lines(editor, monaco, editor_div, retryCount = 0) {
    // Check if editor and required methods exist
    // Resize editor based on content
    function updateEditorHeight() {
        try {
            const model = editor.getModel();
            if (!model) {
                console.warn('Editor model not available yet');
                return;
            }
            const lineHeight = editor.getOption(
                monaco.editor.EditorOption.lineHeight
            );
            const lineCount = model.getLineCount();
            const height = lineHeight * lineCount;
            editor_div.style.height = height + "px";
            editor.layout();
        } catch (error) {
            console.error('Error updating editor height:', error);
        }
    }

    // Update height on content change
    try {
        // Initial resize
        editor.onDidChangeModelContent(updateEditorHeight);
        updateEditorHeight();
    } catch (error) {
        console.error('Error setting up resize_to_lines:', error);
    }
}

export function toggle_elem(show, elem, direction) {
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

export function setup_cell_editor(
    eval_editor,
    buttons_id,
    container_id,
    card_content_id,
    loading_obs,
    all_visible_obs,
    // Markdown unhiding behavior
    hide_on_focus_obs,
    focused,
) {
    const buttons = document.getElementById(buttons_id);
    const container = document.getElementById(container_id);
    const card_content = document.getElementById(card_content_id);

    if (!eval_editor) {
        console.warn("No editor found for uuid:", uuid);
        console.log(BOOK.editors);
    }
    eval_editor.focused = focused;
    const make_visible = () => {
        buttons.style.opacity = 1.0;
    };
    const hide = () => {
        buttons.style.opacity = 0.0;
    };

    // Only add hover behavior if not in export mode
    if (!is_export_mode()) {
        container.addEventListener("mouseover", make_visible);
        container.addEventListener("mouseout", hide);
    }
    // Track focus events on the Monaco editor
    eval_editor.editor.editor.then((editor) => {
        editor.onDidFocusEditorWidget(() => {
            // Clear focus from all other cells first
            Object.entries(BOOK.editors).forEach(([uuid, other]) => {
                if (other !== editor) {
                    other.focused.notify(false);
                }
            });
            // Set this cell as focused
            focused.notify(true);
        });
    });
    // Track loading state with minimum 1 second visibility
    focused.on((x) => {
        if (x) {
            card_content.classList.add("focused");
        } else {
            card_content.classList.remove("focused");
        }
    });

    let loadingTimeout = null;
    let loadingStartTime = null;

    loading_obs.on((x) => {
        if (x) {
            // Starting to load
            card_content.classList.add("loading-cell");
            loadingStartTime = Date.now();
            // Clear any existing timeout
            if (loadingTimeout) {
                clearTimeout(loadingTimeout);
                loadingTimeout = null;
            }
        } else {
            // Loading finished
            const currentTime = Date.now();
            const elapsedTime = currentTime - (loadingStartTime || currentTime);
            const remainingTime = Math.max(0, 1000 - elapsedTime); // Ensure at least 1000ms

            if (remainingTime > 0) {
                // Wait for the remaining time before removing the class
                loadingTimeout = setTimeout(() => {
                    card_content.classList.remove("loading-cell");
                    loadingTimeout = null;
                }, remainingTime);
            } else {
                // Already been 1 second or more, remove immediately
                card_content.classList.remove("loading-cell");
            }
        }
    });
    all_visible_obs.on((x) => {
        toggle_elem(x, card_content, "vertical");
    });
    // Only add markdown click-to-edit behavior if not in export mode
    if (!is_export_mode()) {
        container.addEventListener("focus", (e) => {
            if (hide_on_focus_obs.value) {
                eval_editor.toggle_editor(true);
                eval_editor.toggle_output(false);
            }
        });
        container.addEventListener("click", (e) => {
            if (hide_on_focus_obs.value) {
                // Only trigger if click is on output area, not on the Monaco editor
                const monacoEditor = container.querySelector(".monaco-editor");
                if (!monacoEditor || !monacoEditor.contains(e.target)) {
                    eval_editor.toggle_editor(true);
                    eval_editor.toggle_output(false);
                    // Request current source from Julia to ensure editor has the right content
                    eval_editor.js_to_julia.notify({
                        type: "get-source",
                    });
                    // Focus the editor once it's ready
                    eval_editor.editor.editor.then((editor) => {
                        editor.focus();
                    });
                }
            }
        });
        container.addEventListener("focusout", (e) => {
            console.log("Focus out!");
            if (hide_on_focus_obs.value) {
                if (!container.contains(e.relatedTarget)) {
                    eval_editor.editor.editor.then((editor) => {
                        eval_editor.toggle_editor(false);
                        eval_editor.toggle_output(true);
                        eval_editor.set_source(editor);
                        eval_editor.run();
                        eval_editor.send();
                    });
                }
            }
        });
    }
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
    const upper_editor = BOOK.get_up(editor);
    if (upper_editor) {
        const upper = upper_editor.editor.editor;
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
}

function move_down(editor) {
    const lower_editor = BOOK.get_down(editor);
    if (lower_editor) {
        const lower = lower_editor.editor.editor;
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
}

export function register_cell_editor(eval_editor, uuid) {
    monaco.then((monaco) => {
        eval_editor.editor.editor.then((editor) => {
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
