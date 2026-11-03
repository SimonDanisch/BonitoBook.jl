# Shared scaffolding for BonitoBook's Electron end-to-end tests. Mirrors the
# BonitoTeam pattern but targets `Book`/`InlineBook` and the
# `.book-cells-area` / `.cell-editor-container` DOM surface produced by
# `Bonito.jsrender(session, ::Book)`.
#
# Usage from each test file:
#     include("helpers.jl")
#     ctx = TH.open_book(...)        # boots an Electron window over a Book
#     ...                            # eval_js / dom_count / wait_for assertions
#     TH.shutdown(ctx)
#
# All helpers are JSON-safe: every selector is serialised through `JSON.json`
# rather than interpolated, so quotes / special chars in tests can't break the
# generated JS.

module TestHelpers

using Bonito, BonitoBook, JSON, Base64, Dates
using ElectronCall  # registers the electron backend Bonito picks up

# ── Markdown fixtures ────────────────────────────────────────────────────────

"""
    julia_cell(source; show_editor=true, show_output=true, show_logging=false, id=nothing)

Return the source text for one fenced Julia cell. `id` is optional —
if provided the loader will reuse it, otherwise BonitoBook assigns one.
"""
function julia_cell(source::AbstractString;
                    show_editor::Bool=true,
                    show_output::Bool=true,
                    show_logging::Bool=false,
                    id::Union{Nothing,Int}=nothing)
    pieces = ["editor=$(show_editor)",
              "logging=$(show_logging)",
              "output=$(show_output)"]
    id === nothing || push!(pieces, "id=$id")
    return string("```julia (", join(pieces, ", "), ")\n", source, "\n```\n")
end

"""
    markdown_cell(text; id=nothing)

Return raw markdown text (no fence) — BonitoBook turns each paragraph /
heading into a markdown cell on load.
"""
markdown_cell(text::AbstractString) = string(text, "\n\n")

"""
    write_book(dir, name; body)

Write a markdown book to `joinpath(dir, "\$(name).md")` and return its
absolute path. `body` is the full document content (you compose it from
`julia_cell` + `markdown_cell` or supply it directly).
"""
function write_book(dir::AbstractString, name::AbstractString; body::AbstractString)
    file = joinpath(dir, "$(name).md")
    write(file, body)
    return file
end

"""
    big_book_body(n_julia, n_markdown; mix=true)

Generate a long body that mixes Julia and markdown blocks. The Julia
cells evaluate fast (just an integer) so loading the book doesn't take
forever, but there are enough of them to exercise virtual layout.
"""
function big_book_body(n_julia::Int, n_markdown::Int; mix::Bool=true)
    io = IOBuffer()
    println(io, "# Stress book\n")
    n_total = n_julia + n_markdown
    julia_left, md_left = n_julia, n_markdown
    for i in 1:n_total
        do_julia = mix ? (julia_left > 0 && (md_left == 0 || iseven(i))) : (i <= n_julia)
        if do_julia && julia_left > 0
            print(io, julia_cell("$(i)  # cell-$(i)"))
            julia_left -= 1
        else
            print(io, markdown_cell("## Section $(i)\n\nSome **bold** text with a list:\n\n- alpha-$(i)\n- beta-$(i)\n- gamma-$(i)"))
            md_left -= 1
        end
    end
    return String(take!(io))
end

# ── Electron window lifecycle ────────────────────────────────────────────────

"""
    open_book(file; folder=nothing, devtools=false, width=1280, height=900) -> ctx

Boot a fresh Electron window pointed at `Book(file)`. Returns a
NamedTuple `(disp, app, session, book)` for the assertion helpers.

`folder` lets a caller force the bbook folder (so two windows can share a
book on disk). `devtools=true` opens Chromium devtools — useful when
debugging a failing assertion locally; never check in.
"""
function open_book(file::AbstractString;
                   folder::Union{Nothing,AbstractString}=nothing,
                   devtools::Bool=false,
                   width::Int=1280,
                   height::Int=900)
    book = BonitoBook.Book(file; folder=folder)
    return open_book(book; devtools=devtools, width=width, height=height)
end

"""
    open_book(book::Book; devtools=false, width=1280, height=900)

Same as the file variant, but reuses an already-constructed Book. Useful
when a test needs to manipulate `book.cells` before display, or share a
Book across two electron windows.
"""
function open_book(book::BonitoBook.Book;
                   devtools::Bool=false,
                   width::Int=1280,
                   height::Int=900)
    # `show: false` keeps the suite headless. `--ozone-platform=x11` is the
    # same workaround the BonitoTeam tests use: Electron 28+ defaults to
    # Wayland in a Wayland session, but offscreen `capturePage` on a
    # `show:false` window returns a never-resolving Promise after the first
    # call on Wayland. X11 (via XWayland when needed) gives a stable
    # offscreen surface so repeat screenshots work.
    disp = Bonito.use_electron_display(;
        devtools,
        options = Dict{String,Any}(
            "show"   => false,
            "width"  => width,
            "height" => height,
        ),
        electron_args = ["--ozone-platform=x11"],
    )
    app = Bonito.App(() -> book; title = "BonitoBook test")
    display(disp, app)
    session = app.session[]
    # Install an error sink so a test can assert "no JS errors fired".
    run(disp.window, """
        window.__errs = [];
        window.addEventListener('error', e => window.__errs.push(String(e.message)));
        window.addEventListener('unhandledrejection',
            e => window.__errs.push('unhandled: ' + (e.reason && e.reason.message || e.reason)));
    """)
    # The Book mounts asynchronously (Monaco loads via ES6Module promise).
    # Wait for the cells area or at least one cell container to appear so
    # subsequent assertions don't race the initial render.
    wait_for_native(disp.window, """
        document.querySelector('.book-cells-area') !== null
    """; timeout = 30.0)
    return (; disp, app, session, book)
end

"Tear down the window. Always call from a `finally` block."
function shutdown(ctx)
    try
        close(ctx.disp)
    catch
    end
    try
        close(ctx.book.runner)
    catch
    end
    return nothing
end

"""
    set_window_size(ctx, w, h)

Force the renderer viewport via Chromium device-emulation. We avoid
`BrowserWindow.setSize` because on Linux/offscreen it only shrinks the
viewport (a 480→1280 cycle leaves `window.innerWidth` stuck at 480) and
is subject to OS / window-manager minimum sizes that bypass our
`@media (max-width: 480px)` breakpoint test.
"""
function set_window_size(ctx, w::Int, h::Int)
    win_id = ctx.disp.window.window.id
    run(ctx.disp.window.app, """
        const win = electron.BrowserWindow.fromId($win_id);
        win.webContents.enableDeviceEmulation({
            screenPosition: 'desktop',
            screenSize:  { width: $w, height: $h },
            viewSize:    { width: $w, height: $h },
            deviceScaleFactor: 0,
            scale: 1,
        });
        win.setMinimumSize(0, 0);
        win.setSize($w, $h);
        win.setContentSize($w, $h);
        null
    """)
    # Resize is async; wait for the renderer's reported width to catch up.
    deadline = time() + 2
    while time() < deadline
        try
            iw = run(ctx.disp.window, "window.innerWidth")
            iw isa Number && abs(iw - w) < 30 && break
        catch
        end
        sleep(0.05)
    end
    return nothing
end

# ── JS evaluation / DOM probes ───────────────────────────────────────────────

"Run a JS expression in the renderer; return the JSON-decoded value."
eval_js(ctx, code::AbstractString) = run(ctx.disp.window, code)

"Number of elements matching `selector`."
dom_count(ctx, selector::AbstractString) =
    eval_js(ctx, "document.querySelectorAll($(JSON.json(selector))).length")

"True iff at least one element matches `selector`."
dom_exists(ctx, selector::AbstractString) =
    eval_js(ctx, "document.querySelector($(JSON.json(selector))) !== null")

"BoundingClientRect of the first match (or `nothing`)."
function dom_rect(ctx, selector::AbstractString)
    return eval_js(ctx, """
        (() => {
            const el = document.querySelector($(JSON.json(selector)));
            if (!el) return null;
            const r = el.getBoundingClientRect();
            return {x: r.x, y: r.y, w: r.width, h: r.height,
                    top: r.top, bottom: r.bottom, left: r.left, right: r.right};
        })()
    """)
end

"Inner text of the first match (or `nothing`)."
dom_text(ctx, selector::AbstractString) = eval_js(ctx, """
    (() => {
        const el = document.querySelector($(JSON.json(selector)));
        return el ? el.innerText : null;
    })()
""")

"Click the first match. Returns true iff it existed."
dom_click(ctx, selector::AbstractString) = eval_js(ctx, """
    (() => { const el = document.querySelector($(JSON.json(selector)));
              if (el) el.click(); return el !== null; })()
""") === true

"""
    wait_for(ctx, predicate_js; timeout=5.0, interval=0.05)

Poll a JS expression that returns boolean. Returns true the moment the
expression yields `true`, false on timeout.
"""
function wait_for(ctx, predicate_js::AbstractString;
                  timeout::Float64 = 5.0, interval::Float64 = 0.05)
    deadline = time() + timeout
    while time() < deadline
        try
            eval_js(ctx, "(() => { return ($predicate_js); })()") === true && return true
        catch
            # JS may throw transiently mid-render; just keep polling.
        end
        sleep(interval)
    end
    return false
end

"Variant of `wait_for` that takes a raw EWindow (used inside `open_book`)."
function wait_for_native(win, predicate_js::AbstractString;
                         timeout::Float64 = 5.0, interval::Float64 = 0.05)
    deadline = time() + timeout
    while time() < deadline
        try
            run(win, "(() => { return ($predicate_js); })()") === true && return true
        catch
        end
        sleep(interval)
    end
    return false
end

"Returns the JS error sink contents (empty list if no errors fired)."
function js_errors(ctx)
    e = eval_js(ctx, "window.__errs || []")
    return e === nothing ? Any[] : e
end

# ── Screenshots ──────────────────────────────────────────────────────────────

"""
    screenshot(ctx; path=tempname()*".png") -> path

Save a PNG of the current Electron viewport via `webContents.capturePage`.
"""
function screenshot(ctx; path::AbstractString = tempname() * ".png")
    win_id = ctx.disp.window.window.id
    b64 = run(ctx.disp.window.app, """
        (async () => {
            const win = electron.BrowserWindow.fromId($win_id);
            const img = await win.webContents.capturePage();
            return img.toPNG().toString('base64');
        })()
    """)
    b64 isa AbstractString || error("screenshot returned non-string: $(typeof(b64))")
    write(path, Base64.base64decode(b64))
    return path
end

function emit_screenshot(ctx; label::AbstractString = "")
    path = screenshot(ctx)
    println("--- ", isempty(label) ? "screenshot" : label, " saved → ", path, " ---")
    return path
end

# ── Driving the Julia side directly ──────────────────────────────────────────

"""
    insert_julia_cell!(ctx, source; pos=:end)

Insert a new Julia cell on the Julia side (mirroring what the +-menu
does in the UI), via the public `insert_cell_at!`. Returns the
`CellEditor`. After this, wait_for the new container to appear in the
DOM before asserting on it — the DOM update is async.
"""
function insert_julia_cell!(ctx, source::AbstractString;
                              pos = :end, language::AbstractString = "julia")
    book = ctx.book
    editor = if language == "markdown"
        BonitoBook.CellEditor(String(source), language, book.runner;
                              show_editor=false, show_output=true,
                              theme=book.monaco_theme)
    else
        BonitoBook.CellEditor(String(source), language, book.runner;
                              theme=book.monaco_theme)
    end
    BonitoBook.insert_cell_at!(book, editor, pos)
    return editor
end

"""
    delete_cell!(ctx, editor)

Delete a cell via the public API and wait for the DOM container to be
removed. Returns true on confirmed removal, false on timeout.
"""
function delete_cell!(ctx, editor::BonitoBook.CellEditor; timeout::Float64 = 5.0)
    container_id = "$(editor.uuid)-container"
    Base.delete!(ctx.book, editor)
    return wait_for(ctx,
        "document.getElementById($(JSON.json(container_id))) === null";
        timeout = timeout)
end

"""
    cell_run!(ctx, editor)

Trigger a cell evaluation through the runner (same path `run-from-newest`
takes on the JS side, minus the Monaco round-trip).
"""
cell_run!(ctx, editor::BonitoBook.CellEditor) = BonitoBook.run!(editor.editor)

"""
    cell_run_sync!(editor)

Block until a cell finishes evaluating. Useful for race-condition tests
where we want a deterministic "executed" baseline.
"""
cell_run_sync!(editor::BonitoBook.CellEditor) = BonitoBook.run_sync!(editor.editor)

"""
    wait_runner_idle(book; timeout=20.0)

Block until `book.runner.task_queue` is empty (i.e. every queued cell
has finished). Returns true on idle, false on timeout.
"""
function wait_runner_idle(book::BonitoBook.Book; timeout::Float64 = 20.0)
    deadline = time() + timeout
    while time() < deadline
        isempty(book.runner.task_queue) && return true
        sleep(0.05)
    end
    return false
end

# ── Test driver ──────────────────────────────────────────────────────────────

"""
    @test_eq actual expected

PASS/FAIL line, never raises — every assertion in the file runs so one
failure doesn't mask the rest. Mirrors the BonitoTeam style.
"""
macro test_eq(actual, expected)
    actual_str   = string(actual)
    expected_str = string(expected)
    quote
        local a = $(esc(actual))
        local e = $(esc(expected))
        if isequal(a, e)
            println("  PASS  $($(actual_str)) == $($(expected_str))  ($(repr(a)))")
            true
        else
            println("  FAIL  $($(actual_str)) == $($(expected_str))")
            println("        actual:   $(repr(a))")
            println("        expected: $(repr(e))")
            false
        end
    end
end

"As `@test_eq` but checks `actual` is truthy (`true` or a positive number)."
macro test_true(actual)
    actual_str = string(actual)
    quote
        local a = $(esc(actual))
        if a === true || (a isa Number && a > 0)
            println("  PASS  $($(actual_str))  ($(repr(a)))")
            true
        else
            println("  FAIL  $($(actual_str))")
            println("        actual: $(repr(a))")
            false
        end
    end
end

"Run a function under a banner. Use as `TH.section(\"label\") do ... end`."
function section(f, label::AbstractString)
    println("\n==> $label")
    return f()
end

# The runtests.jl harness peeks at this after each include() to build a
# cross-file summary. Test files call `TH.report!("label", results)`
# from their finally block; that pushes one entry per call.
const TIER_RESULTS = Tuple{String,Int,Int}[]   # (label, pass, fail)

"""
    report!(label, results)

Print the per-file summary and append the tally to `TH.TIER_RESULTS`
so the harness can produce a cross-file roll-up.
"""
function report!(label::AbstractString, results::AbstractVector)
    println("\n", "="^60)
    pass = count(p -> p.second, results)
    fail = length(results) - pass
    println("$label: $pass passed, $fail failed")
    for (name, ok) in results
        ok || println("  FAIL  $name")
    end
    push!(TIER_RESULTS, (String(label), pass, fail))
    return (pass, fail)
end

end # module TestHelpers

const TH = TestHelpers
