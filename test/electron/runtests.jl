# Run every BonitoBook electron stress test in sequence. Each file is
# self-contained: brings up its own Electron window, drives a series of
# assertions, prints a per-file summary via `TH.report!(...)`, and tears
# down in `finally`.
#
# Same pattern as BonitoTeam's `test/electron/runtests.jl` — `TH.report!`
# pushes its tally into `TH.TIER_RESULTS`, and the harness peeks at the
# last entry after each `include()` to build the cross-file summary.
#
# Usage:
#     julia --project=. dev/BonitoBook/test/electron/runtests.jl
#
# These tests are independent of the existing test/runtests.jl unit
# suite — they require ElectronCall + a usable X11 (or XWayland)
# session, so they aren't checked into CI by default. Run locally
# whenever you touch:
#   - cell lifecycle (insert / delete / move / cell_id assignment)
#   - the AsyncRunner / eval pipeline
#   - sidebar / layout CSS or breakpoint behaviour
#   - any Monaco.js wiring that touches the BOOK registry

# `BonitoBook` must be in Main scope — individual test files reference
# `BonitoBook.run!`, `BonitoBook.NoSplat`, etc. at top level.
using BonitoBook

const HERE = @__DIR__

# Load the helpers once. Subsequent `include("helpers.jl")` inside test
# files becomes a no-op at module level because `TestHelpers` is wrapped
# in `module ... end` — Julia simply redefines its contents in place.
include(joinpath(HERE, "helpers.jl"))
empty!(TH.TIER_RESULTS)

# Order: cheapest first so a regression in basic mount fails fast, then
# the heavier stress files. The race-condition test runs last because
# it briefly fires interrupts and we don't want those to perturb later
# windows.
const FILES = [
    "test_rendering.jl",     # ~30s — basic mount + 3 viewports + screenshots
    "test_large_book.jl",    # ~10s — 200-cell book
    "test_cell_churn.jl",    # ~30s — 30 inserts + 40 interleaved insert/delete
    "test_eval_race.jl",     # ~20s — 30 concurrent runs, source mutation, interrupts
    "test_export_menu.jl",   # ~90s — saving-menu buttons + WGLMakie PNG capture
    "test_logging.jl",       # ~40s — vanishing-cell regression + 4-mode picker
]

# (file, label, pass, fail) — populated as each test runs.
const RESULTS = Tuple{String,String,Int,Int}[]

for f in FILES
    println("\n", "█"^60)
    println("▶ Running ", f)
    println("█"^60)
    pre = length(TH.TIER_RESULTS)
    crashed = nothing
    try
        Main.include(joinpath(HERE, f))
    catch e
        crashed = e
        println(stderr, "[runtests] ", f, " raised: ", sprint(showerror, e))
    end
    if length(TH.TIER_RESULTS) > pre
        label, p, fl = TH.TIER_RESULTS[end]
        if crashed !== nothing
            # Test reported its assertions but then errored (e.g. a
            # screenshot timeout or a cleanup error in `finally`).
            # Surface it as a failure so the suite summary doesn't lie.
            push!(RESULTS, (f, label * " — crashed after report: " *
                                    sprint(showerror, crashed), p, fl + 1))
        else
            push!(RESULTS, (f, label, p, fl))
        end
    elseif crashed !== nothing
        push!(RESULTS, (f, "(crashed before report) — " *
                            sprint(showerror, crashed), 0, 1))
    else
        push!(RESULTS, (f, "(no report)", 0, 1))
    end
end

println("\n", "═"^60)
println("BonitoBook electron suite — final summary")
println("═"^60)
let total_pass = 0, total_fail = 0
    for (file, label, p, fl) in RESULTS
        total_pass += p
        total_fail += fl
        sym = fl == 0 ? "✓" : "✗"
        println("  ", sym, "  ", rpad(file, 30),
                lpad(p, 4), " passed, ", lpad(fl, 4), " failed   ", label)
    end
    println("─"^60)
    println("  TOTAL: ", total_pass, " passed, ", total_fail, " failed")
    isinteractive() || exit(total_fail == 0 ? 0 : 1)
end
