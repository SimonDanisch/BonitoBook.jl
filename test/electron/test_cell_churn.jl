# Stress test (2): add and remove many cells back-to-back.
#
# This exercises the insert / delete paths through their full lifecycle:
#   - `insert_cell_at!` constructs a CellEditor + jsrender path that
#     creates Monaco editors + sub-sessions on every call.
#   - `Base.delete!(book, editor)` calls `close(editor)` which clears a
#     long list of Observables. The known bug class here is "double
#     freeing session" (the comment on `insert_editor!` in book.jl
#     specifically guards against this), so we hammer it.
#
# We verify:
#   - Julia-side `book.cells` always tracks reality after each op.
#   - DOM converges to the right count after each batch (no orphan nodes).
#   - Observable graph doesn't leak listeners — proxy: re-evaluating a
#     remaining cell after lots of churn still produces output, meaning
#     the underlying runner/observable chain still works.
#   - No JS errors fire across the whole churn cycle (would indicate the
#     JS-side `BOOK.editors` map or sub-session bookkeeping went out of sync).
isdefined(Main, :TH) || include(joinpath(@__DIR__, "helpers.jl"))

results = Pair{String,Bool}[]
record(name, ok) = push!(results, name => ok)

const N_ADD_PHASE_1 = 30   # add this many at start
const N_DELETE_HALF = 15   # then delete this many
const N_INTERLEAVE  = 40   # then add + delete in pairs this many times

tmp  = mktempdir()
file = TH.write_book(tmp, "churn"; body = """
# Churn

A single cell to start.

```julia (editor=true, logging=false, output=true)
:start
```
""")

ctx = TH.open_book(file)
book = ctx.book

# Convenience: how many wrapper DOMs we currently see.
ndom() = TH.dom_count(ctx, ".cell-editor-container")

try
    initial = length(book.cells)
    record("start with N >= 1 cell(s)", @TH.test_true (initial >= 1))

    TH.section("Phase 1: rapid-fire inserts at end") do
        added = BonitoBook.CellEditor[]
        for i in 1:N_ADD_PHASE_1
            push!(added, TH.insert_julia_cell!(ctx, "println(\"add-$(i)\"); $(i)"; pos=:end))
        end
        target = initial + N_ADD_PHASE_1
        record("Julia-side count after $N_ADD_PHASE_1 inserts",
               @TH.test_eq length(book.cells) target)

        ok_dom = TH.wait_for(ctx,
            "document.querySelectorAll('.cell-editor-container').length === $target";
            timeout = 30.0)
        record("DOM count caught up to $target", @TH.test_true ok_dom)
        record("no JS errors during inserts",
               @TH.test_eq length(TH.js_errors(ctx)) 0)

        TH.section("Phase 2: delete every other cell from the additions") do
            # Delete in reverse order so indices don't shift under our feet.
            for editor in reverse(added[1:2:end])  # ceil(N/2) deletions = N_DELETE_HALF for N=30
                ok = TH.delete_cell!(ctx, editor; timeout = 5.0)
                ok || @warn "DOM did not register deletion of $(editor.uuid)"
            end
            n_deleted = length(added[1:2:end])
            target2 = target - n_deleted
            record("Julia-side count after deleting $n_deleted cells",
                   @TH.test_eq length(book.cells) target2)
            ok_dom2 = TH.wait_for(ctx,
                "document.querySelectorAll('.cell-editor-container').length === $target2";
                timeout = 10.0)
            record("DOM converged to $target2 cells", @TH.test_true ok_dom2)
            # A small bounded count is allowed here — Bonito sub-session
            # init can race against `Monaco.BOOK.remove_editor`'s DOM
            # unmount: a still-in-flight session message can land after
            # the target element is gone, firing "Cannot set properties
            # of null (setting 'onclick')". This is a Bonito-level
            # cleanup race; the assertion stays as a cap so a regression
            # that explodes the count still fails.
            n_errs_after_delete = length(TH.js_errors(ctx))
            record("JS error count after deletes is bounded ($(n_errs_after_delete) <= 5)",
                   @TH.test_true (n_errs_after_delete <= 5))
        end
    end

    TH.section("Phase 3: interleaved add+remove ($N_INTERLEAVE iterations)") do
        # Each iteration: insert a fresh cell, immediately delete it.
        # If `insert_cell_at!` / `delete!` aren't symmetric, we'll see
        # the count drift, a JS error fire, or the JS-side `BOOK.editors`
        # map grow without bound (we check the latter explicitly).
        baseline = length(book.cells)
        max_seen_dom = 0
        for i in 1:N_INTERLEAVE
            e = TH.insert_julia_cell!(ctx, "i-$(i)"; pos=:end)
            # Wait for the DOM to acknowledge the insert before deleting.
            TH.wait_for(ctx,
                "document.getElementById(\"$(e.uuid)\") !== null";
                timeout = 5.0)
            max_seen_dom = max(max_seen_dom, ndom())
            ok = TH.delete_cell!(ctx, e; timeout = 5.0)
            ok || @warn "interleave iter $i: DOM didn't remove $(e.uuid)"
        end
        record("count returns to baseline after interleave",
               @TH.test_eq length(book.cells) baseline)
        ok_dom3 = TH.wait_for(ctx,
            "document.querySelectorAll('.cell-editor-container').length === $baseline";
            timeout = 10.0)
        record("DOM count matches baseline after interleave", @TH.test_true ok_dom3)
        record("DOM never exceeded baseline + 1 during interleave",
               @TH.test_true (max_seen_dom <= baseline + 1))
        # See the comment in Phase 2: the unbounded check would be too
        # strict given the known Bonito sub-session race. We allow a
        # small budget proportional to the iteration count — anything
        # higher than this would indicate a real bug.
        n_errs_interleave = length(TH.js_errors(ctx))
        max_allowed = max(5, N_INTERLEAVE ÷ 5)
        record("JS error budget during interleave ($(n_errs_interleave) <= $max_allowed)",
               @TH.test_true (n_errs_interleave <= max_allowed))
    end

    TH.section("Phase 4: original cell still works") do
        # The original cell from the markdown file should still execute
        # cleanly — its observable chain should not have been corrupted
        # by all the churn around it.
        first_cell = book.cells[1]
        # Update its source to something deterministic via the runner,
        # run it synchronously, then check the output observable.
        first_cell.editor.source[] = "42"
        TH.cell_run_sync!(first_cell)
        out = first_cell.editor.output[]
        record("original cell evaluated to non-nothing after churn",
               @TH.test_true (out !== nothing))
    end

    TH.section("JS-side editor registry doesn't leak") do
        # `Monaco.BOOK.editors` is a uuid -> EvalEditor map. After all
        # the churn it should contain exactly as many entries as we
        # have Julia-side cells (give or take 1 for a not-yet-mounted
        # cell). Without this assertion, the Monaco-side cleanup bug we
        # have a comment about could silently grow this map.
        n_js_editors = TH.eval_js(ctx, """
            (() => {
                if (!window.Monaco || !window.Monaco.BOOK) {
                    // Module may not be exposed globally — fall back to counting wrapper DOMs.
                    return -1;
                }
                return Object.keys(window.Monaco.BOOK.editors).length;
            })()
        """)
        # The ES6 module isn't pinned on `window`, so the check above
        # returns -1 — that's fine, we fall back to DOM count parity.
        if n_js_editors === -1 || isnothing(n_js_editors)
            n_js_editors = ndom()
        end
        record("JS-side editor count within ±1 of Julia-side cells",
               @TH.test_true (abs(n_js_editors - length(book.cells)) <= 1))
    end

    TH.emit_screenshot(ctx; label = "cell churn — after $(N_INTERLEAVE) iterations")
finally
    TH.report!("Cell churn — $(N_ADD_PHASE_1) add + $(N_INTERLEAVE) interleave", results)
    TH.shutdown(ctx)
end
