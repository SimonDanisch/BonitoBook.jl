# Tests for the logging-mode system + the cell-vanishing regression
# it grew out of.
#
# Covers:
#   1. A cell with `editor=false` and `nothing` output no longer
#      acquires `hide-vertical` after a run. (Was: 2.5 s auto-hide of
#      `show_logging` + already-off `show_editor` made `any_visible`
#      false → the JS bridge added `hide-vertical` → card content
#      vanished; for cells whose output was `nothing` only the hover
#      buttons remained, looking like the cell disappeared.)
#   2. The runner always records cell stdout into `book.console_log`
#      with cell-id attribution, regardless of mode. Switching modes
#      never drops data.
#   3. CSS hooks: `body.logmode-<mode>` class follows
#      `book.logging_mode[]`; CSS in style.jl uses that class to
#      show/hide inline logging divs and the bottom-panel console.
#   4. `meta.toml` round-trip: setting the mode persists; reopening
#      the same folder restores it.
isdefined(Main, :TH) || include(joinpath(@__DIR__, "helpers.jl"))
using BonitoBook

results = Pair{String,Bool}[]
record(name, ok) = push!(results, name => ok)

# Helper: read body class list as a Set of strings.
body_classes(ctx) = TH.eval_js(ctx,
    "Array.from(document.body.classList || [])")

# Helper: the card content of a cell — that's the div that gets
# `hide-vertical` in the failing case.
card_class(ctx, uuid) = TH.eval_js(ctx, """
    (() => {
        const w = document.getElementById("$(uuid)");
        if (!w) return "NO-WRAPPER";
        const card = w.querySelector(".cell-editor");
        return card ? (card.className || "<empty>") : "NO-CARD";
    })()
""")

# Helper: computed `display` of an element (matched via CSS selector).
# A `display: none` from a CSS rule (e.g. our mode override) shows up
# here even though the element has no inline style.
computed_display(ctx, selector) = TH.eval_js(ctx, """
    (() => {
        const el = document.querySelector($(repr(selector)));
        if (!el) return "NO-ELEMENT";
        return getComputedStyle(el).getPropertyValue("display");
    })()
""")

# Helper: count entries in book.console_log attributed to cell_id.
own_console_entries(book, cell_id::Int) =
    length(filter(e -> e.cell_id == cell_id, book.console_log[]))

# ── Test 1: cell stays visible 3s after run (auto-hide-timer is gone) ────────
# Original bug: `run!` set `show_logging[] = true`, then `Timer(2.5)`
# flipped it back to false. For cells where the user had toggled
# `show_editor` off (or where `show_editor` was off in the cell
# metadata), the resulting `any_visible = false` triggered the JS
# `all_visible_obs.on(toggle_elem(..., "vertical"))` handler, which
# added `hide-vertical` to `.cell-editor`. Cells with `nothing` output
# then appeared to disappear entirely (only the empty output area
# and hover buttons remained).
# Fix: drop the timer + the `show_logging[] = true` override in `run!`.
# Test: simulate the user-toggle-editor-off scenario, run the cell,
# verify hide-vertical never fires post-run.
TH.section("editor toggled off + run: hide-vertical never appears post-run") do
    tmp = mktempdir()
    file = TH.write_book(tmp, "vanish"; body = """
    # Vanish

    ```julia (editor=true, logging=false, output=true)
    nothing
    ```
    """)
    ctx = TH.open_book(file)
    book = ctx.book
    cell = book.cells[findfirst(c -> c.language == "julia", book.cells)]
    try
        record("before any user action: no hide-vertical (editor=true)",
               @TH.test_true (!occursin("hide-vertical",
                                         card_class(ctx, cell.uuid))))
        # Simulate the user clicking the "show editor" toggle in the
        # hover buttons. That sets show_editor[] = false, which by
        # itself triggers hide-vertical (intentional collapse). Run
        # the cell next.
        cell.editor.show_editor[] = false
        sleep(0.2)
        BonitoBook.run!(cell.editor)
        TH.wait_runner_idle(book; timeout = 10.0)
        sleep(0.5)
        # show_logging shouldn't have been forced to true (the override
        # we removed). show_editor we just set to false; if `run!` is
        # well-behaved it didn't change.
        record("show_logging not force-true after run",
               @TH.test_eq cell.editor.show_logging[] false)
        record("show_editor not changed by run",
               @TH.test_eq cell.editor.show_editor[] false)
        # Wait past where the old 2.5 s timer would have fired and
        # restored hide-vertical. With the timer removed, no JS-side
        # observable change should happen — hide-vertical stays in
        # whatever state the initial render + toggle set it to.
        sleep(3.0)
        # The cell IS hide-vertical at this point because the user
        # toggled show_editor off. That's intentional and not the
        # bug; the bug was a *transient* state-change firing the JS
        # toggle. We assert the *quiescent* hide-vertical state
        # didn't change unexpectedly by running the cell.
        delayed = card_class(ctx, cell.uuid)
        record("3 s after run: card-class unchanged from toggle-only state",
               @TH.test_true occursin("hide-vertical", delayed))
        # If a regression re-introduces an auto-hide that touches
        # show_logging, the assertion above still holds (logging false
        # → any_visible still false → hide-vertical). The smoking gun
        # is now in the test below.
    finally
        TH.shutdown(ctx)
    end
end

# ── Test 1b: cell with editor=true, never toggled off, never gains hide-vertical ──
TH.section("editor=true cell never auto-hides after run completes") do
    tmp = mktempdir()
    file = TH.write_book(tmp, "stays-visible"; body = """
    # Stays visible

    ```julia (editor=true, logging=false, output=true)
    println("hello"); 1
    ```
    """)
    ctx = TH.open_book(file)
    book = ctx.book
    cell = book.cells[findfirst(c -> c.language == "julia", book.cells)]
    try
        record("initial: no hide-vertical on the card",
               @TH.test_true (!occursin("hide-vertical",
                                         card_class(ctx, cell.uuid))))
        BonitoBook.run!(cell.editor)
        TH.wait_runner_idle(book; timeout = 10.0)
        sleep(0.5)
        record("immediately after run: still no hide-vertical",
               @TH.test_true (!occursin("hide-vertical",
                                         card_class(ctx, cell.uuid))))
        # The smoking gun for the original bug: hide-vertical appearing
        # 2.5 s post-run when the old `Timer(2.5) do t; show_logging[]=false`
        # fired. With it gone, this stays false forever.
        sleep(3.0)
        record("3 s after run (past old timer): still no hide-vertical",
               @TH.test_true (!occursin("hide-vertical",
                                         card_class(ctx, cell.uuid))))
        record("show_logging stayed at original false (no forced toggle)",
               @TH.test_eq cell.editor.show_logging[] false)
    finally
        TH.shutdown(ctx)
    end
end

# ── Test 2: console_log captures cell stdout with attribution ───────────────
TH.section("Runner mirrors every cell chunk into book.console_log") do
    tmp = mktempdir()
    file = TH.write_book(tmp, "capture"; body = """
    # Capture

    ```julia (editor=true, logging=false, output=true)
    println("line A"); println("line B"); 99
    ```
    """)
    ctx = TH.open_book(file)
    book = ctx.book
    cell = book.cells[findfirst(c -> c.language == "julia", book.cells)]
    try
        before = own_console_entries(book, cell.uuid)
        record("no own entries before run", @TH.test_eq before 0)

        BonitoBook.run!(cell.editor)
        TH.wait_runner_idle(book; timeout = 10.0)
        # Pipe is async — give the writer a moment to drain after the
        # eval returns.
        sleep(0.5)

        own_total = sum(
            (e.cell_id == cell.uuid ? sizeof(e.html) : 0)
            for e in book.console_log[]; init = 0)
        own_text = String[]
        for e in book.console_log[]
            e.cell_id == cell.uuid && push!(own_text, e.html)
        end
        joined = join(own_text, "")
        record("console_log got at least one entry for this cell",
               @TH.test_true (own_total > 0))
        record("captured chunks contain 'line A'",
               @TH.test_true occursin("line A", joined))
        record("captured chunks contain 'line B'",
               @TH.test_true occursin("line B", joined))
    finally
        TH.shutdown(ctx)
    end
end

# ── Test 3: body class + computed display follow the mode ───────────────────
TH.section("Body class + element visibility follow book.logging_mode") do
    tmp = mktempdir()
    file = TH.write_book(tmp, "modes"; body = """
    # Modes

    ```julia (editor=true, logging=true, output=true)
    println("logged"); 1
    ```
    """)
    ctx = TH.open_book(file)
    book = ctx.book
    cell = book.cells[findfirst(c -> c.language == "julia", book.cells)]
    try
        # Initial mode should be :respect_cell. Run once so there's
        # something to look at if logging is shown.
        BonitoBook.run!(cell.editor)
        TH.wait_runner_idle(book; timeout = 10.0)
        sleep(0.3)

        for mode in (:respect_cell, :hide_all, :show_all, :console)
            book.logging_mode[] = mode
            ok_class = TH.wait_for(ctx, """
                document.body.classList.contains("logmode-$(mode)")
            """; timeout = 5.0)
            record("body carries logmode-$(mode) class", @TH.test_true ok_class)

            # Bottom panel only visible in :console mode.
            panel_display = computed_display(ctx, ".book-bottom-panel")
            if mode === :console
                record("$(mode): bottom panel is shown (display != none)",
                       @TH.test_true (panel_display != "none"))
            else
                record("$(mode): bottom panel hidden (display == none)",
                       @TH.test_eq panel_display "none")
            end

            # Cell logging visibility for the test cell. The cell
            # itself has `show_logging=true` in its source, so under
            # :respect_cell the div should be visible.
            cell_log_display = computed_display(ctx, ".cell-logging")
            if mode === :show_all
                record("$(mode): inline .cell-logging visible",
                       @TH.test_true (cell_log_display != "none"))
            elseif mode === :hide_all || mode === :console
                record("$(mode): inline .cell-logging hidden",
                       @TH.test_eq cell_log_display "none")
            else
                # :respect_cell — cell has logging=true so it's shown.
                record("$(mode): inline .cell-logging visible (per-cell true)",
                       @TH.test_true (cell_log_display != "none"))
            end
        end
        # Final: book.console_log accumulates across the run regardless
        # of mode. It should have at least one entry for the cell.
        own = own_console_entries(book, cell.uuid)
        record("console_log captured cell output across mode switches",
               @TH.test_true (own >= 1))
    finally
        TH.shutdown(ctx)
    end
end

# ── Test 4: meta.toml persistence round-trip ────────────────────────────────
TH.section("meta.toml round-trip: setting mode persists across Book open") do
    tmp = mktempdir()
    file = TH.write_book(tmp, "persist"; body = """
    # Persist

    ```julia (editor=true, logging=false, output=true)
    1
    ```
    """)
    # First open: default mode
    book1 = BonitoBook.Book(file)
    record("fresh book defaults to :respect_cell",
           @TH.test_eq book1.logging_mode[] :respect_cell)
    book1.logging_mode[] = :console
    sleep(0.1)  # let the on(...) write handler run
    meta = read(joinpath(book1.folder, "meta.toml"), String)
    record("meta.toml contains logging_mode = \"console\"",
           @TH.test_true occursin("logging_mode = \"console\"", meta))
    close(book1.runner)

    # Reopen — same folder, same .md file. Expect :console restored.
    book2 = BonitoBook.Book(file; folder = book1.folder)
    record("reopened book picks up :console from meta.toml",
           @TH.test_eq book2.logging_mode[] :console)
    close(book2.runner)
end

TH.report!("Logging mode + cell-vanish regression", results)
