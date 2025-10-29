// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

const MONACO = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm";
const monaco = import(MONACO);
monaco.then((m)=>{
    m.languages.setLanguageConfiguration('julia', {
        brackets: [
            [
                '(',
                ')'
            ],
            [
                '[',
                ']'
            ],
            [
                '{',
                '}'
            ]
        ],
        autoClosingPairs: [
            {
                open: '(',
                close: ')'
            },
            {
                open: '[',
                close: ']'
            },
            {
                open: '{',
                close: '}'
            },
            {
                open: '"',
                close: '"'
            },
            {
                open: "'",
                close: "'"
            }
        ],
        surroundingPairs: [
            {
                open: '(',
                close: ')'
            },
            {
                open: '[',
                close: ']'
            },
            {
                open: '{',
                close: '}'
            },
            {
                open: '"',
                close: '"'
            },
            {
                open: "'",
                close: "'"
            }
        ],
        indentationRules: {
            increaseIndentPattern: /^(\s*|.*=\s*|.*@\w*\s*)[\w\s]*(?:["'`][^"'`]*["'`])*[\w\s]*\b(if|while|for|function|macro|(mutable\s+)?struct|abstract\s+type|primitive\s+type|let|quote|try|begin|.*\)\s*do|else|elseif|catch|finally)\b(?!(?:.*\bend\b(\s*|\s*#.*$)|(?:[^\[\]]*\].*)).*)$/,
            decreaseIndentPattern: /^\s*(end|else|elseif|catch|finally)\b.*$/
        },
        onEnterRules: [
            {
                beforeText: /^\s*(begin|for|if|while|function|macro|let|try|struct|mutable\s+struct|abstract\s+type|primitive\s+type|module|baremodule|quote|do)\b.*$/,
                action: {
                    indentAction: m.languages.IndentAction.Indent
                }
            },
            {
                beforeText: /^\s*(end|else|elseif|catch|finally)\b.*$/,
                action: {
                    indentAction: m.languages.IndentAction.Outdent
                }
            }
        ]
    });
});
function is_export_mode() {
    return window.BONITO_EXPORT_MODE === true;
}
class MonacoEditor {
    constructor(editor_div, options, init_callback, hiding_direction, visible, theme){
        this.editor_div = editor_div;
        this.options = options;
        this.initialized = false;
        this.hiding_direction = hiding_direction;
        this.theme = theme.value;
        this.monaco = monaco;
        theme.on((new_theme)=>{
            this.set_theme(new_theme);
        });
        this.editor = new Promise((resolve)=>{
            this.resolve_setup = resolve;
        });
        if (visible) {
            this.initialize();
        }
        init_callback(this);
    }
    set_theme(theme) {
        this.theme = theme;
        monaco.then((m)=>{
            let effectiveTheme = theme;
            if (theme === "default") {
                effectiveTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'vs-dark' : 'vs';
            }
            m.editor.setTheme(effectiveTheme);
        });
    }
    update_options(options) {
        this.editor.then((x)=>x.updateOptions(options));
    }
    initialize() {
        monaco.then((monaco)=>{
            const div = this.editor_div;
            const editor = monaco.editor.create(div, this.options);
            div._editor_instance = this.editor;
            this.set_theme(this.theme);
            this.initialized = true;
            const editorDomNode = editor.getDomNode();
            if (editorDomNode) {
                editorDomNode.addEventListener('wheel', (e)=>{
                    e.stopPropagation();
                    e.preventDefault();
                    const scrollParent = document.querySelector(".book-cells-area");
                    if (scrollParent) {
                        scrollParent.scrollBy({
                            top: e.deltaY,
                            left: e.deltaX,
                            behavior: 'auto'
                        });
                    } else {
                        window.scrollBy(e.deltaX, e.deltaY);
                    }
                }, {
                    passive: false
                });
            }
            this.resolve_setup(editor);
        });
    }
    toggle_editor(show) {
        const div = this.editor_div;
        toggle_elem(show, div, this.hiding_direction);
        if (show && !this.initialized) {
            const callback = ()=>{
                this.initialize();
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
class EvalEditor {
    constructor(monaco_editor, output_div, logging_div, direction, js_to_julia, julia_to_js, source_obs, show_output, show_logging, do_resize_to_lines = true){
        this.message_queue = [];
        this.editor = monaco_editor;
        this.output_div = output_div;
        this.logging_div = logging_div;
        this.direction = direction;
        this.source_obs = source_obs;
        this.show_output = show_output;
        this.show_logging = show_logging;
        this.js_to_julia = js_to_julia;
        julia_to_js.on((message)=>{
            this.process_message(message);
        });
        monaco.then((monaco)=>{
            monaco_editor.editor.then((editor)=>{
                if (do_resize_to_lines) {
                    resize_to_lines(editor, monaco, this.editor.editor_div);
                }
                editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, ()=>{
                    editor.trigger("keyboard", "editor.action.quickCommand", null);
                });
                add_command(editor, "Eval cell", [
                    monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter
                ], ()=>{
                    this.set_source(editor);
                    this.run();
                    this.send();
                });
                add_command(editor, "Eval cell + add new cell", [
                    monaco.KeyMod.Shift | monaco.KeyCode.Enter
                ], ()=>{
                    this.set_source(editor);
                    this.run();
                    this.send();
                    move_down(editor);
                });
                add_command(editor, "Save", [
                    monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS
                ], ()=>{
                    this.set_source(editor);
                    this.send();
                });
            });
        });
    }
    run() {
        this.message_queue.push({
            type: "run"
        });
    }
    set_source(editor) {
        this.message_queue.push({
            type: "new-source",
            data: editor.getValue()
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
                data: this.message_queue
            });
        }
        this.message_queue = [];
    }
    process_message(message) {
        if (message.type === "get-source") {
            this.editor.editor.then((editor)=>{
                this.js_to_julia.notify({
                    type: "new-source",
                    data: editor.getValue()
                });
            });
        } else if (message.type === "set-source") {
            this.editor.editor.then((editor)=>{
                editor.setValue(message.data);
            });
        } else if (message.type === "run-from-newest") {
            this.editor.editor.then((editor)=>{
                const newest_source = editor.getValue();
                if (this.source_obs.value != newest_source) {
                    this.message_queue.push({
                        type: "new-source",
                        data: newest_source
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
            this.editor.editor.then((editor)=>{
                const lineNumber = Math.max(1, message.line);
                const model = editor.getModel();
                const totalLines = model.getLineCount();
                const targetLine = Math.max(1, Math.min(lineNumber, totalLines));
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
            data: show
        });
    }
    toggle_output(show) {
        this.show_output = show;
        this.js_to_julia.notify({
            type: "toggle-output",
            data: show
        });
        toggle_elem(show, this.output_div, this.direction);
    }
    toggle_logging(show) {
        this.show_logging = show;
        this.js_to_julia.notify({
            type: "toggle-logging",
            data: show
        });
        toggle_elem(show, this.logging_div, this.direction);
    }
}
class Book {
    constructor(){
        this.cells = [];
        this.editors = {};
    }
    update_order(uuids) {
        this.cells = uuids;
    }
    add_editor(editor, uuid1) {
        this.editors[uuid1] = editor;
    }
    add_below(uuid_above, uuid1) {
        const index = this.cells.indexOf(uuid_above);
        if (index === -1) {
            throw new Error("Cell not found in the book.");
        }
        this.cells.splice(index + 1, 0, uuid1);
    }
    get_up(editor) {
        const uuid1 = editor.cell_uuid;
        const index = this.cells.indexOf(uuid1);
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
        const uuid1 = editor.cell_uuid;
        const index = this.cells.indexOf(uuid1);
        if (index === -1 || index >= this.cells.length - 1) return null;
        for(let i = index + 1; i < this.cells.length; i++){
            const down_uuid = this.cells[i];
            if (this.editors[down_uuid]) {
                return this.editors[down_uuid];
            }
        }
        return null;
    }
    remove_editor(uuid1) {
        delete this.editors[uuid1];
        const index = this.cells.indexOf(uuid1);
        if (index !== -1) {
            this.cells.splice(index, 1);
        }
        document.getElementById(uuid1).parentElement.remove();
    }
}
const BOOK = new Book();
function add_editor_at_beginning(elem, uuid1) {
    if (BOOK.cells.length === 0) {
        const inline_block = document.querySelector(".inline-block");
        if (inline_block) {
            inline_block.appendChild(elem);
        }
        BOOK.cells.unshift(uuid1);
    } else {
        const first_uuid = BOOK.cells[0];
        const first_editor_div = document.getElementById(first_uuid);
        if (first_editor_div) {
            const parent = first_editor_div.parentElement;
            parent.insertAdjacentElement("beforebegin", elem);
        }
        BOOK.cells.unshift(uuid1);
    }
}
function add_editor_below(above_editor_uuid, elem, uuid1) {
    const editor_div = document.getElementById(above_editor_uuid);
    const parent1 = editor_div.parentElement;
    parent1.insertAdjacentElement("afterend", elem);
    BOOK.add_below(above_editor_uuid, uuid1);
}
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
function resize_to_lines(editor, monaco, editor_div, retryCount = 0) {
    const update_height = ()=>{
        const contentHeight = editor.getContentHeight();
        editor_div.style.height = `${contentHeight}px`;
        try {
            true;
            const currentWidth = editor_div.offsetWidth;
            editor.layout({
                width: currentWidth,
                height: contentHeight
            });
        } finally{
            false;
        }
    };
    editor.onDidContentSizeChange(update_height);
    update_height();
}
function toggle_elem(show, elem, direction) {
    const hide_class = `hide-${direction}`;
    `show-${direction}`;
    if (!elem) {
        console.warn("No element to toggle");
        return;
    }
    if (show) {
        elem.classList.remove(hide_class);
    } else {
        elem.classList.add(hide_class);
    }
}
function setup_cell_editor(eval_editor, buttons_id, container_id, card_content_id, loading_obs, all_visible_obs, hide_on_focus_obs, focused) {
    const buttons = document.getElementById(buttons_id);
    const container = document.getElementById(container_id);
    const card_content = document.getElementById(card_content_id);
    if (!eval_editor) {
        console.warn("No editor found for uuid:", uuid);
        console.log(BOOK.editors);
    }
    eval_editor.focused = focused;
    const make_visible = ()=>{
        buttons.style.opacity = 1.0;
    };
    const hide = ()=>{
        buttons.style.opacity = 0.0;
    };
    if (!is_export_mode()) {
        container.addEventListener("mouseover", make_visible);
        container.addEventListener("mouseout", hide);
    }
    eval_editor.editor.editor.then((editor)=>{
        editor.onDidFocusEditorWidget(()=>{
            Object.entries(BOOK.editors).forEach(([uuid1, other])=>{
                if (other !== editor) {
                    other.focused.notify(false);
                }
            });
            focused.notify(true);
        });
    });
    focused.on((x)=>{
        if (x) {
            card_content.classList.add("focused");
        } else {
            card_content.classList.remove("focused");
        }
    });
    let loadingTimeout = null;
    let loadingStartTime = null;
    loading_obs.on((x)=>{
        if (x) {
            card_content.classList.add("loading-cell");
            loadingStartTime = Date.now();
            if (loadingTimeout) {
                clearTimeout(loadingTimeout);
                loadingTimeout = null;
            }
        } else {
            const currentTime = Date.now();
            const elapsedTime = currentTime - (loadingStartTime || currentTime);
            const remainingTime = Math.max(0, 1000 - elapsedTime);
            if (remainingTime > 0) {
                loadingTimeout = setTimeout(()=>{
                    card_content.classList.remove("loading-cell");
                    loadingTimeout = null;
                }, remainingTime);
            } else {
                card_content.classList.remove("loading-cell");
            }
        }
    });
    all_visible_obs.on((x)=>{
        toggle_elem(x, card_content, "vertical");
    });
    if (!is_export_mode()) {
        container.addEventListener("focus", (e)=>{
            if (hide_on_focus_obs.value) {
                eval_editor.toggle_editor(true);
                eval_editor.toggle_output(false);
            }
        });
        container.addEventListener("click", (e)=>{
            if (hide_on_focus_obs.value) {
                const monacoEditor = container.querySelector(".monaco-editor");
                if (!monacoEditor || !monacoEditor.contains(e.target)) {
                    eval_editor.toggle_editor(true);
                    eval_editor.toggle_output(false);
                    eval_editor.js_to_julia.notify({
                        type: "get-source"
                    });
                    eval_editor.editor.editor.then((editor)=>{
                        editor.focus();
                    });
                }
            }
        });
        container.addEventListener("focusout", (e)=>{
            if (hide_on_focus_obs.value) {
                if (!container.contains(e.relatedTarget)) {
                    eval_editor.editor.editor.then((editor)=>{
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
    return monaco.then((monaco)=>{
        monaco.languages.registerCompletionItemProvider("julia", {
            triggerCharacters: [
                ".",
                "/",
                ":",
                "@",
                "(",
                "[",
                '"',
                "\\"
            ],
            provideCompletionItems: (model, position, context, token)=>{
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
                        text
                    };
                    const word = model.getWordUntilPosition(position);
                    let need_to_remove_trigger = false;
                    let prev_char = null;
                    if (word.startColumn > 1) {
                        prev_char = model.getValueInRange({
                            startLineNumber: line,
                            startColumn: word.startColumn - 1,
                            endLineNumber: line,
                            endColumn: word.startColumn
                        });
                        need_to_remove_trigger = prev_char === "\\";
                    }
                    comm.send(request).then((response)=>{
                        const suggestions = response.map((item)=>{
                            let offset = need_to_remove_trigger ? 1 : 0;
                            if (prev_char === "." && item.insertText.startsWith(".") && item.kind == 16) {
                                offset = 1;
                            }
                            return {
                                kind: item.kind,
                                insertText: item.insertText,
                                label: item.label || item.insertText,
                                range: {
                                    startLineNumber: line,
                                    endLineNumber: line,
                                    startColumn: word.startColumn - offset,
                                    endColumn: word.endColumn
                                }
                            };
                        });
                        resolve({
                            suggestions
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
    const upper_editor = BOOK.get_up(editor);
    if (upper_editor) {
        const upper = upper_editor.editor.editor;
        if (upper) {
            upper.then((upper)=>{
                const lastLine = upper.getModel().getLineCount();
                upper.focus();
                upper.setPosition({
                    lineNumber: lastLine,
                    column: 1
                });
                move_to_editor(upper);
            });
        }
    }
}
function move_down(editor) {
    const lower_editor = BOOK.get_down(editor);
    if (lower_editor) {
        const lower = lower_editor.editor.editor;
        if (lower) {
            lower.then((lower)=>{
                lower.focus();
                lower.setPosition({
                    lineNumber: 1,
                    column: 1
                });
                move_to_editor(lower);
            });
        }
    }
}
function register_cell_editor(eval_editor, uuid1) {
    monaco.then((monaco)=>{
        eval_editor.editor.editor.then((editor)=>{
            BOOK.add_editor(eval_editor, uuid1);
            editor.cell_uuid = uuid1;
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
                id: `move-up-${uuid1}`,
                label: "Move up",
                precondition: "editorTextFocus && !suggestWidgetVisible && editorCursorAtTop",
                keybindings: [
                    monaco.KeyCode.UpArrow
                ],
                run: move_up,
                contextMenuGroupId: "navigation"
            });
            editor.addAction({
                id: `move-down-${uuid1}`,
                label: "Move down",
                keybindings: [
                    monaco.KeyCode.DownArrow
                ],
                precondition: "editorTextFocus && !suggestWidgetVisible && editorCursorAtBottom",
                run: move_down,
                contextMenuGroupId: "navigation"
            });
        });
    });
}
export { MonacoEditor as MonacoEditor };
export { EvalEditor as EvalEditor };
export { BOOK as BOOK };
export { add_editor_at_beginning as add_editor_at_beginning };
export { add_editor_below as add_editor_below };
export { add_command as add_command };
export { resize_to_lines as resize_to_lines };
export { toggle_elem as toggle_elem };
export { setup_cell_editor as setup_cell_editor };
export { register_completions as register_completions };
export { register_cell_editor as register_cell_editor };

