# Stress test (3): race conditions in `eval_code` / `AsyncRunner`.
#
# The runner is a single Channel{RunnerTask} drained by a background
# task pinned to thread 1 (`spawnat(1)`). Each item evaluates code in
# the runner's module and mutates the output/logging observables, which
# then propagate to listeners (and through Bonito to the renderer).
#
# Race-condition surface this file exercises:
#
#   - Many `run!` calls submitted back-to-back: the runner's
#     Channel{RunnerTask} guarantees FIFO ordering, so each task must
#     observe the side-effects of every prior task — even with a
#     short `sleep` inside each cell.
#   - Sequential `run!`s with the source mutated between submissions:
#     `run!` captures `editor.source[]` at queue time, so the second
#     `run!` must see the updated value.
#   - `run_sync!` against the same runner while async runs are in flight:
#     both code paths spawn onto thread 1 and `fetch` — if there were a
#     missing yield point this would deadlock.
#   - `interrupt!` while a long cell runs: documented to be racy
#     (uses `Base.throwto` which can fail across OS threads), so we
#     assert what should hold instead of what we wish held.
#
# We don't drive these through the UI — we hit the public Julia API
# (`run!`, `run_sync!`, `interrupt!`) directly while an Electron window
# is open, so any observable-update-induced JS error still surfaces in
# `window.__errs`.
isdefined(Main, :TH) || include(joinpath(@__DIR__, "helpers.jl"))

using Base.Threads
using Observables: off, on

results = Pair{String,Bool}[]
record(name, ok) = push!(results, name => ok)

tmp  = mktempdir()
file = TH.write_book(tmp, "race"; body = """
# Race

A starter cell that defines a counter we'll race on.

```julia (editor=true, logging=false, output=true)
counter = Ref(0)
:initial
```

```julia (editor=true, logging=false, output=true)
sleep(0.02); counter[] += 1; counter[]
```
""")
ctx  = TH.open_book(file)
book = ctx.book

# Helper: pull `counter[]` out of the runner module, world-age safe.
get_counter() = Base.invokelatest(() -> Core.eval(book.runner.mod, :counter)[])

try
    # Find the counter-def + inc cells once.
    counter_cell = book.cells[findfirst(c -> occursin("counter = Ref", c.editor.source[]), book.cells)]
    inc_cell     = book.cells[findfirst(c -> occursin("counter[] +=", c.editor.source[]), book.cells)]

    TH.section("Setup — counter defined synchronously") do
        TH.cell_run_sync!(counter_cell)
        record("counter defined in runner module",
               @TH.test_true (get_counter() == 0))
    end

    TH.section("Race 1: N concurrent run!s on the same cell preserve FIFO") do
        # Wait for any stray initial render run before capturing baseline.
        TH.wait_runner_idle(book; timeout = 5.0)
        # Make sure the increment cell isn't mid-task either (its output
        # being touched between starting and the for-loop would skew the
        # count by 1).
        TH.cell_run_sync!(inc_cell)
        TH.wait_runner_idle(book; timeout = 5.0)

        baseline = get_counter()

        # Note: `run!`'s eval pipeline wraps results in `BonitoBook.NoSplat`
        # before assigning to `output[]` (so Hyperscript doesn't splat
        # arrays etc.). Unwrap on the listener side.
        unwrap(v) = v isa BonitoBook.NoSplat ? v.value : v
        observed = Int[]
        listener = on(inc_cell.editor.output) do val
            v = unwrap(val)
            v isa Integer && push!(observed, v)
        end

        N = 30  # 30 is enough to see ordering issues without blowing CI
        for _ in 1:N
            BonitoBook.run!(inc_cell.editor)
        end
        ok_idle = TH.wait_runner_idle(book; timeout = 30.0)
        record("runner drained $N jobs in <30s", @TH.test_true ok_idle)

        # Wait for the listener-side observed sequence to fully arrive
        # (the runner thread can be ahead of the observable propagation
        # by one step on slow CI). Poll for stabilisation.
        deadline = time() + 5.0
        while time() < deadline
            length(observed) >= N && break
            sleep(0.05)
        end

        ending = get_counter()
        record("runner counter advanced by exactly $N",
               @TH.test_eq (ending - baseline) N)
        # Each consecutive observed value must be exactly one larger —
        # FIFO with a single shared `counter[]` means no skips, no
        # reordering, no duplicates.
        is_mono = length(observed) > 1 &&
                  all(observed[i+1] == observed[i] + 1 for i in 1:length(observed)-1)
        record("observed sequence strictly +1 ($(length(observed)) samples)",
               @TH.test_true is_mono)

        off(listener)
    end

    TH.section("Race 2: source mutation between sequential run!s is honoured") do
        # Use a sandbox cell so we don't perturb the counter cells.
        sandbox = TH.insert_julia_cell!(ctx, "0"; pos = :end)
        TH.wait_for(ctx, "document.getElementById(\"$(sandbox.uuid)\") !== null"; timeout = 5.0)
        TH.wait_runner_idle(book; timeout = 5.0)

        # Set + sync run + check — three times, with different sources.
        # `run_sync!` captures source[] at the same point `run!` would,
        # so this is a deterministic check that the queueing path always
        # picks up the latest value.
        unwrap(v) = v isa BonitoBook.NoSplat ? v.value : v
        for (src, expected) in [
            ("111",       111),
            ("222",       222),
            ("11 * 11",   121),
        ]
            sandbox.editor.source[] = src
            TH.cell_run_sync!(sandbox)
            record("source `$src` -> output $expected",
                   @TH.test_eq unwrap(sandbox.editor.output[]) expected)
        end
    end

    TH.section("Race 3: interrupt!() is best-effort, runner stays usable") do
        # `interrupt!` uses `Threads.@spawn Base.throwto(...)` which is
        # only legal when the spawned task lands on the same OS thread
        # as the target task. The runner pins to thread 1; whether
        # @spawn picks thread 1 is up to the scheduler. So we accept
        # either outcome — the interrupt happened OR threw a
        # "cannot switch to task running on another thread" — and
        # check that the runner is still alive either way.
        long = TH.insert_julia_cell!(ctx, "sleep(2); :long_done"; pos = :end)
        TH.wait_for(ctx, "document.getElementById(\"$(long.uuid)\") !== null"; timeout = 5.0)
        BonitoBook.run!(long.editor)
        sleep(0.3)  # let it actually start

        int_task = BonitoBook.interrupt!(book.runner)
        # `wait` may raise the TaskFailedException — that's fine,
        # we're just verifying the channel stays alive.
        try
            wait(int_task)
        catch e
            @info "interrupt! task raised (cross-thread throwto, expected)" exception=e
        end

        # The contract we want to preserve: regardless of whether the
        # InterruptException landed, the task queue must remain open
        # so future runs are still possible.
        record("runner task_queue still open after interrupt!",
               @TH.test_true isopen(book.runner.task_queue))

        # Wait for any in-flight task to settle (the original long cell
        # either errored out via the catch in the runner loop, or
        # completed). Then a fresh run! should still drain.
        TH.wait_runner_idle(book; timeout = 10.0)
        followup = TH.insert_julia_cell!(ctx, ":after_interrupt"; pos = :end)
        TH.wait_for(ctx, "document.getElementById(\"$(followup.uuid)\") !== null"; timeout = 5.0)
        BonitoBook.run!(followup.editor)
        ok = TH.wait_runner_idle(book; timeout = 10.0)
        record("follow-up run completed after interrupt cycle",
               @TH.test_true (ok && followup.editor.output[] !== nothing))
    end

    TH.section("Race 4: run_sync! does not deadlock against a busy runner") do
        # Boot a brand-new Book with its own runner so we're isolated
        # from any lingering state from the interrupt test above. No
        # window is opened — we just need the Julia-side AsyncRunner.
        tmp2  = mktempdir()
        file2 = TH.write_book(tmp2, "syncrace"; body = """
# SyncRace

```julia (editor=true, logging=false, output=true)
x = 0
```
""")
        b2 = BonitoBook.Book(file2)
        try
            slow_cell = BonitoBook.CellEditor(
                "sleep(0.05); x = x + 1; x",
                "julia", b2.runner; theme = b2.monaco_theme)
            slow_cell.book = b2
            push!(b2.cells, slow_cell)

            # Fire several async runs, then call run_sync! on the same
            # cell. Both run! and run_sync! use `spawnat(1)`-backed
            # tasks; if there were a missing yield point the runner
            # loop and run_sync!'s fetch would deadlock on thread 1.
            for _ in 1:3
                BonitoBook.run!(slow_cell.editor)
            end
            t_sync = Threads.@spawn try
                BonitoBook.run_sync!(slow_cell.editor)
                true
            catch e
                @warn "run_sync! threw" exception = e
                false
            end
            ok_sync = false
            deadline = time() + 10.0
            while time() < deadline
                if istaskdone(t_sync)
                    ok_sync = fetch(t_sync)
                    break
                end
                sleep(0.05)
            end
            record("run_sync! returned within 10s without deadlock",
                   @TH.test_true (istaskdone(t_sync) && ok_sync))
        finally
            close(b2.runner)
        end
    end

    TH.section("No catastrophic JS errors during eval races") do
        # We allow a small budget for the Bonito sub-session race
        # documented in test_cell_churn.jl — the inserts in races 2/3/4
        # can each spawn a few of these. Anything noticeably larger
        # would be a real regression.
        n = length(TH.js_errors(ctx))
        record("JS error count bounded ($(n) <= 10)", @TH.test_true (n <= 10))
    end

    TH.emit_screenshot(ctx; label = "eval race — after all stress phases")
finally
    TH.report!("Eval race conditions", results)
    TH.shutdown(ctx)
end
