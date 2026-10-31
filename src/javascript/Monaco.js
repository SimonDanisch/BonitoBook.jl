const MONACO = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/+esm";
const monaco = import(MONACO);
const HTML_TO_IMAGE = "https://cdnjs.cloudflare.com/ajax/libs/html-to-image/1.10.10/html-to-image.min.js";
let htmlToImagePromise = null;

function get_html_to_image() {
    if (typeof htmlToImage !== "undefined") {
        return Promise.resolve(htmlToImage);
    }
    if (!htmlToImagePromise) {
        htmlToImagePromise = new Promise((resolve, reject) => {
            const existing = document.querySelector('script[data-bonitobook-html-to-image="1"]');
            if (existing) {
                existing.addEventListener("load", () => resolve(htmlToImage));
                existing.addEventListener("error", reject);
                return;
            }
            const script = document.createElement("script");
            script.src = HTML_TO_IMAGE;
            script.async = true;
            script.dataset.bonitobookHtmlToImage = "1";
            script.onload = () => resolve(htmlToImage);
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }
    return htmlToImagePromise;
}

// Configure Julia language support with auto-indentation
monaco.then((m) => {
    m.languages.setLanguageConfiguration('julia', {
        brackets: [
            ['(', ')'],
            ['[', ']'],
            ['{', '}']
        ],
        autoClosingPairs: [
            { open: '(', close: ')' },
            { open: '[', close: ']' },
            { open: '{', close: '}' },
            { open: '"', close: '"' },
            { open: "'", close: "'" }
        ],
        surroundingPairs: [
            { open: '(', close: ')' },
            { open: '[', close: ']' },
            { open: '{', close: '}' },
            { open: '"', close: '"' },
            { open: "'", close: "'" }
        ],
        indentationRules: {
            increaseIndentPattern: /^(\s*|.*=\s*|.*@\w*\s*)[\w\s]*(?:["'`][^"'`]*["'`])*[\w\s]*\b(if|while|for|function|macro|(mutable\s+)?struct|abstract\s+type|primitive\s+type|let|quote|try|begin|.*\)\s*do|else|elseif|catch|finally)\b(?!(?:.*\bend\b(\s*|\s*#.*$)|(?:[^\[\]]*\].*)).*)$/,
            decreaseIndentPattern: /^\s*(end|else|elseif|catch|finally)\b.*$/
        },
        onEnterRules: [
            {
                beforeText: /^\s*(begin|for|if|while|function|macro|let|try|struct|mutable\s+struct|abstract\s+type|primitive\s+type|module|baremodule|quote|do)\b.*$/,
                action: { indentAction: m.languages.IndentAction.Indent }
            },
            {
                beforeText: /^\s*(end|else|elseif|catch|finally)\b.*$/,
                action: { indentAction: m.languages.IndentAction.Outdent }
            }
        ]
    });
});

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
        } else if (message.type === "capture-output") {
            this.capture_output(message.format || "png", message.request_id);
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
    async capture_output(format, request_id) {
        try {
            const lib = await get_html_to_image();
            const node = this.output_div;
            if (!node) {
                this.js_to_julia.notify({
                    type: "captured-output",
                    ok: false,
                    request_id,
                    error: "No output node found"
                });
                return;
            }
            const hidden_h = node.classList.contains("hide-horizontal");
            const hidden_v = node.classList.contains("hide-vertical");
            if (hidden_h) node.classList.remove("hide-horizontal");
            if (hidden_v) node.classList.remove("hide-vertical");

            // Let layout settle after potential class changes.
            await new Promise((r) => requestAnimationFrame(() => r()));
            const filter = (domNode) => domNode.tagName !== "SCRIPT";
            let data_url;
            if (format === "svg") {
                data_url = await lib.toSvg(node, { filter, cacheBust: true });
            } else {
                data_url = await lib.toPng(node, { filter, cacheBust: true, pixelRatio: 2 });
            }

            if (hidden_h) node.classList.add("hide-horizontal");
            if (hidden_v) node.classList.add("hide-vertical");

            this.js_to_julia.notify({
                type: "captured-output",
                ok: true,
                request_id,
                format: format === "svg" ? "svg" : "png",
                data_url
            });
        } catch (e) {
            this.js_to_julia.notify({
                type: "captured-output",
                ok: false,
                request_id,
                error: String(e)
            });
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

    setup_drag_drop(move_cell_obs) {
        this.move_cell_obs = move_cell_obs;
        this.drag_state = null;
        this.drop_indicator = null;
        this.scroll_parent = document.querySelector(".book-cells-area");
        this.auto_scroll_speed = 0;
        this.scroll_interval = null;

        // Ensure we only add listeners once globally
        if (window._BONITO_DRAG_LISTENERS_SET) return;
        window._BONITO_DRAG_LISTENERS_SET = true;

        // Use document-level listeners to handle dragging over sticky menus and off-screen
        document.addEventListener("dragover", (e) => {
            if (this.drag_state) this.handle_drag_over(e);
        });
        document.addEventListener("drop", (e) => {
            if (this.drag_state) this.handle_drop(e);
        });
        document.addEventListener("dragenter", (e) => {
            if (this.drag_state) e.preventDefault();
        });
    }

    start_auto_scroll(speed) {
        this.auto_scroll_speed = speed;
        if (!this.scroll_interval) {
            this.scroll_interval = setInterval(() => {
                if (this.scroll_parent && this.auto_scroll_speed !== 0) {
                    this.scroll_parent.scrollTop += this.auto_scroll_speed;
                }
            }, 16); // ~60fps
        }
    }

    stop_auto_scroll() {
        if (this.scroll_interval) {
            clearInterval(this.scroll_interval);
            this.scroll_interval = null;
        }
        this.auto_scroll_speed = 0;
    }

    get_cell_wrapper(uuid) {
        const el = document.getElementById(uuid);
        return el ? el.parentElement : null;
    }

    start_drag(uuid, event) {
        const wrapper = this.get_cell_wrapper(uuid);
        if (!wrapper) return;
        this.drag_state = { uuid, wrapper };
        this.drag_start_y = event.clientY; // Track starting position
        wrapper.classList.add("dragging");

        // Create drop indicator line
        if (!this.drop_indicator) {
            this.drop_indicator = document.createElement("div");
            this.drop_indicator.className = "drop-indicator";
        }

        // Use a custom data type to prevent browser from navigating if dropped on URL bar
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.setData("application/x-bonitobook-cell", String(uuid));
        
        // Use a transparent drag image to avoid the "ghost" text follow
        const img = new Image();
        img.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
        event.dataTransfer.setDragImage(img, 0, 0);
    }

    end_drag() {
        this.stop_auto_scroll();
        if (this.drag_state) {
            this.drag_state.wrapper.classList.remove("dragging");
            this.drag_state = null;
        }
        if (this.drop_indicator && this.drop_indicator.parentElement) {
            this.drop_indicator.remove();
        }
        // Clear all drop target highlights
        document.querySelectorAll(".drop-target-before, .drop-target-after").forEach(el => {
            el.classList.remove("drop-target-before", "drop-target-after");
        });
    }

    handle_drag_over(event) {
        if (!this.drag_state) return;
        event.preventDefault(); // Always prevent default to allow drop
        event.dataTransfer.dropEffect = "move";

        // Find scroll parent if missing or detached
        if (!this.scroll_parent || !this.scroll_parent.isConnected) {
            this.scroll_parent = document.querySelector(".book-cells-area");
        }

        // Handle auto-scrolling
        if (this.scroll_parent) {
            // Use viewport-relative boundaries for perfect symmetry and menu handling
            const threshold = 180;
            const topDist = event.clientY; // relative to viewport top
            const bottomDist = window.innerHeight - event.clientY; // relative to viewport bottom

            // Directional lock: only scroll if moving towards edge or already at extreme edge
            const movedTop = event.clientY < this.drag_start_y - 5 || event.clientY < 40;
            const movedBottom = event.clientY > this.drag_start_y + 5 || (window.innerHeight - event.clientY) < 40;

            // Symmetry check: use the same formula for both directions
            const calculateSpeed = (dist) => {
                if (dist >= threshold) return 0;
                // intensity: 0 at threshold, 1 at edge
                const intensity = (threshold - dist) / threshold;
                // Quadratic ramp (0 to ~12px per frame)
                return Math.pow(Math.min(1.1, intensity), 2) * 12.0;
            };

            const sTop = calculateSpeed(topDist);
            const sBottom = calculateSpeed(bottomDist);

            if (sTop > 0 && movedTop) {
                this.start_auto_scroll(-sTop);
            } else if (sBottom > 0 && movedBottom) {
                this.start_auto_scroll(sBottom);
            } else {
                this.stop_auto_scroll();
            }
        }

        // Find closest cell wrapper
        const target = this.find_closest_cell(event.clientY);
        if (!target) return;

        const rect = target.wrapper.getBoundingClientRect();
        const midY = rect.top + rect.height / 2;
        const before = event.clientY < midY;

        // Visual feedback: drop indicator and highlights
        if (before) {
            target.wrapper.insertAdjacentElement("beforebegin", this.drop_indicator);
            target.wrapper.classList.add("drop-target-before");
            target.wrapper.classList.remove("drop-target-after");
        } else {
            target.wrapper.insertAdjacentElement("afterend", this.drop_indicator);
            target.wrapper.classList.add("drop-target-after");
            target.wrapper.classList.remove("drop-target-before");
        }

        // Remove highlights from other cells
        for (const uuid of this.cells) {
            if (uuid === target.uuid) continue;
            const wrapper = this.get_cell_wrapper(uuid);
            if (wrapper) {
                wrapper.classList.remove("drop-target-before", "drop-target-after");
            }
        }

        this.drop_indicator.dataset.targetUuid = String(target.uuid);
        this.drop_indicator.dataset.before = String(before);
    }

    handle_drop(event) {
        event.preventDefault();
        if (!this.drag_state || !this.drop_indicator) return;

        const from_uuid = this.drag_state.uuid;
        const target_uuid = parseInt(this.drop_indicator.dataset.targetUuid);
        const before = this.drop_indicator.dataset.before === "true";

        if (isNaN(target_uuid) || from_uuid === target_uuid) {
            this.end_drag();
            return;
        }

        // Calculate new 1-based index for Julia
        let target_idx = this.cells.indexOf(target_uuid);
        if (target_idx === -1) { this.end_drag(); return; }

        // Adjust for before/after
        if (!before) target_idx += 1;
        // Convert to 1-based
        const to_index = target_idx + 1;

        // Reorder in JS cells array
        const from_idx = this.cells.indexOf(from_uuid);
        this.cells.splice(from_idx, 1);
        const adjusted = from_idx < target_idx ? target_idx - 1 : target_idx;
        this.cells.splice(adjusted, 0, from_uuid);

        // Reorder in DOM
        const wrapper = this.drag_state.wrapper;
        const target_wrapper = this.get_cell_wrapper(target_uuid);
        if (target_wrapper) {
            if (before) {
                target_wrapper.insertAdjacentElement("beforebegin", wrapper);
            } else {
                target_wrapper.insertAdjacentElement("afterend", wrapper);
            }
        }

        // Notify Julia
        this.move_cell_obs.notify({ uuid: from_uuid, to_index: to_index });
        this.end_drag();
    }

    find_closest_cell(clientY) {
        let closest = null;
        let closestDist = Infinity;
        for (const uuid of this.cells) {
            if (this.drag_state && uuid === this.drag_state.uuid) continue;
            const wrapper = this.get_cell_wrapper(uuid);
            if (!wrapper) continue;
            const rect = wrapper.getBoundingClientRect();
            const mid = rect.top + rect.height / 2;
            const dist = Math.abs(clientY - mid);
            if (dist < closestDist) {
                closestDist = dist;
                closest = { uuid, wrapper };
            }
        }
        return closest;
    }
}

export const BOOK = new Book();

/**
 * Insert editor at a specific index (1-based)
 * @param {HTMLElement} elem - The editor element to insert
 * @param {number} uuid - The unique ID for the editor
 * @param {number} index - The 1-based index where to insert (1 = beginning)
 */
export function insert_editor_at_index(elem, uuid, index) {
    // Handle empty book (index 1)
    if (BOOK.cells.length === 0) {
        const container = document.querySelector(".inline-block");
        if (container) {
            container.appendChild(elem);
        }
        BOOK.cells.push(uuid);
        return;
    }

    // Convert to 0-based for array operations
    const arrayIndex = index - 1;

    // Insert at beginning
    if (arrayIndex === 0) {
        const first_uuid = BOOK.cells[0];
        const first_editor_div = document.getElementById(first_uuid);
        if (first_editor_div) {
            first_editor_div.parentElement.insertAdjacentElement("beforebegin", elem);
        }
        BOOK.cells.unshift(uuid);
        return;
    }

    // Insert at end
    if (arrayIndex >= BOOK.cells.length) {
        const last_uuid = BOOK.cells[BOOK.cells.length - 1];
        const last_editor_div = document.getElementById(last_uuid);
        if (last_editor_div) {
            last_editor_div.parentElement.insertAdjacentElement("afterend", elem);
        }
        BOOK.cells.push(uuid);
        return;
    }

    // Insert in middle - after element at arrayIndex - 1
    const after_uuid = BOOK.cells[arrayIndex - 1];
    const after_editor_div = document.getElementById(after_uuid);
    if (after_editor_div) {
        after_editor_div.parentElement.insertAdjacentElement("afterend", elem);
    }
    BOOK.cells.splice(arrayIndex, 0, uuid);
}

// Backwards compatibility wrappers
export function add_editor_at_beginning(elem, uuid) {
    insert_editor_at_index(elem, uuid, 1);
}

export function add_editor_below(above_editor_uuid, elem, uuid) {
    const idx = BOOK.cells.indexOf(above_editor_uuid);
    if (idx !== -1) {
        insert_editor_at_index(elem, uuid, idx + 2); // +1 for 0->1 based, +1 for after
    }
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
    let ignoreEvent = false;
    const update_height = () => {
        const contentHeight = editor.getContentHeight();
        editor_div.style.height = `${contentHeight}px`;
        try {
            ignoreEvent = true;
            // Get the current width of the editor div to maintain it
            const currentWidth = editor_div.offsetWidth;
            editor.layout({ width: currentWidth, height: contentHeight });
        } finally {
            ignoreEvent = false;
        }
    };
    editor.onDidContentSizeChange(update_height);
    update_height();
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
    } else {
        elem.classList.add(hide_class);
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

    // Drag & drop: wire up drag handle and cell wrapper
    const drag_handle = buttons.querySelector(".drag-handle");
    if (drag_handle) {
        // The cell wrapper is the outermost parent with the cell id
        const cell_div = container.closest("[id]");
        const cell_wrapper = cell_div ? cell_div.parentElement : null;
        const uuid = cell_div ? parseInt(cell_div.id) : null;
        if (cell_wrapper && uuid !== null) {
            drag_handle.addEventListener("dragstart", (e) => {
                BOOK.start_drag(uuid, e);
            });
            drag_handle.addEventListener("dragend", () => {
                BOOK.end_drag();
            });
        }
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
        monaco.languages.registerCompletionItemProvider("julia", {
            triggerCharacters: [".", "/", ":", "@", "(", "[", '"', "\\"],
            provideCompletionItems: (model, position, context, token) => {
                return new Promise((resolve) => {
                    const line = position.lineNumber;
                    const column = position.column;
                    const text = model.getValueInRange({
                        startLineNumber: line,
                        startColumn: 1,
                        endLineNumber: line,
                        endColumn: column,
                    });
                    const request = { text };
                    const word = model.getWordUntilPosition(position);
                    // Determine if this is a backslash completion
                    let need_to_remove_trigger = false;
                    let prev_char = null;
                    if (word.startColumn > 1) {
                        prev_char = model.getValueInRange({
                            startLineNumber: line,
                            startColumn: word.startColumn - 1,
                            endLineNumber: line,
                            endColumn: word.startColumn,
                        });
                        need_to_remove_trigger = prev_char === "\\";
                    }
                    comm.send(request).then((response) => {
                        const suggestions = response.map((item) => {
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
                                    endColumn: word.endColumn,
                                },
                            };
                        });
                        resolve({ suggestions });
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

export class MonacoDiffEditor {
    constructor(editor_div, original_obs, modified_obs, language, options, theme,
                max_height_obs, min_height) {
        this.editor_div = editor_div;
        this.options = options;
        this.language = language;
        this.theme = theme.value;
        this.original_obs = original_obs;
        this.modified_obs = modified_obs;
        // Height bounds: `min_height` is static (passed as a number); `max_height`
        // is an Observable so the host can swap compact/full without re-mounting.
        // `setMaxHeight` (below) is the imperative entry point any pure-JS toggle
        // (e.g. the chat's Collapsable) can use without round-tripping through
        // the Observable bridge.
        this.min_height = (min_height != null) ? min_height : 100;
        this.max_height = (max_height_obs && max_height_obs.value != null)
                          ? max_height_obs.value : 600;
        // Expose the instance on the container so a sibling JS module (e.g. the
        // BonitoTeam Collapsable for edit-tool bodies) can look it up via the
        // DOM and call `setMaxHeight` without touching the Observable.
        editor_div.__btMonacoDiff = this;

        theme.on((new_theme) => {
            this.set_theme(new_theme);
        });

        if (max_height_obs && max_height_obs.on) {
            max_height_obs.on((h) => this.setMaxHeight(h));
        }

        this.editor = monaco.then((m) => {
            const diffEditor = m.editor.createDiffEditor(editor_div, {
                ...options,
                language: language,
            });
            // Cache the models so `setMaxHeight` can re-run `updateHeight`
            // without needing the diffEditor's model accessor.
            this.diffEditor = diffEditor;

            // Set initial theme
            this.set_theme(this.theme);

            // Set the original and modified models
            const originalModel = m.editor.createModel(original_obs.value, language);
            const modifiedModel = m.editor.createModel(modified_obs.value, language);
            this.originalModel = originalModel;
            this.modifiedModel = modifiedModel;

            diffEditor.setModel({
                original: originalModel,
                modified: modifiedModel
            });

            // Initial sizing — same content-based algorithm as `updateHeight`,
            // but explicit here so the first layout happens BEFORE any scroll
            // events the wheel listener below would otherwise capture.
            this.updateHeight(diffEditor, originalModel, modifiedModel);
            editor_div.style.width = '100%';
            // Monaco's `createDiffEditor` + initial `layout()` can resolve
            // BEFORE the host's `dom_in_js` mount has fully attached this
            // editor_div to its final parent. Monaco then measures a
            // 0-height container and never paints (the editor_div has the
            // right style.height, but the rendered diff is empty). A
            // double-RAF reschedule guarantees we re-layout after the
            // browser has done at least one paint pass, so Monaco picks
            // up the real geometry and renders the diff on the first
            // frame the user sees — no expand-toggle needed.
            requestAnimationFrame(() => requestAnimationFrame(() => {
                this.updateHeight(diffEditor, originalModel, modifiedModel);
            }));

            // Prevent scroll events from being captured by the diff editor
            // This allows page scrolling to work when mouse is over the editor
            const editorDomNode = diffEditor.getContainerDomNode();
            if (editorDomNode) {
                editorDomNode.addEventListener('wheel', (e) => {
                    // Prevent Monaco from handling the wheel event
                    e.stopPropagation();
                    e.preventDefault();

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

            // Update models when observables change
            original_obs.on((text) => {
                originalModel.setValue(text);
                this.updateHeight(diffEditor, originalModel, modifiedModel);
            });

            modified_obs.on((text) => {
                modifiedModel.setValue(text);
                this.updateHeight(diffEditor, originalModel, modifiedModel);
            });

            return diffEditor;
        });
    }

    // Imperative compact↔full toggle. Storing the diffEditor + models on
    // `this` (set inside the monaco.then) means we can re-layout without a
    // second `monaco.then` round trip; if called before the editor finished
    // initializing (rare race during fast mount + toggle), this is a no-op
    // and the initial `updateHeight` inside the constructor picks up
    // `this.max_height` then.
    setMaxHeight(h) {
        this.max_height = h;
        if (this.diffEditor && this.originalModel && this.modifiedModel) {
            this.updateHeight(this.diffEditor, this.originalModel, this.modifiedModel);
        }
    }

    updateHeight(diffEditor, originalModel, modifiedModel) {
        const originalLineCount = originalModel.getLineCount();
        const modifiedLineCount = modifiedModel.getLineCount();
        const maxLines = Math.max(originalLineCount, modifiedLineCount);
        const lineHeight = 19;
        const contentHeight = Math.min(
            Math.max(maxLines * lineHeight + 20, this.min_height),
            this.max_height
        );

        this.editor_div.style.height = `${contentHeight}px`;
        // Pass dimensions explicitly. `diffEditor.layout()` without args
        // *should* read the container size, but in inline-diff mode Monaco
        // sometimes keeps its inner scroll viewport pinned at the
        // construction-time size — passing the new height makes it actually
        // grow its visible viewport. The `offsetWidth || 800` fallback
        // covers the construction-race case where the container hasn't
        // measured yet (the double-RAF up in the constructor catches up).
        diffEditor.layout({
            width: this.editor_div.offsetWidth || 800,
            height: contentHeight,
        });
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
}
