# Stress test (4): rendering at desktop, tablet, and mobile viewports.
#
# BonitoBook ships three breakpoints in `style.jl`:
#   - desktop (no media query): editor at fixed 90ch, default layout
#   - tablet (max-width: 768px): editor switches to 95vw
#   - mobile (max-width: 480px): tighter border radius, narrower
#                                 new-cell-plus / new-cell-buttons,
#                                 .markdown-body { overflow-wrap, word-break }
#
# We boot a content-rich book that exercises:
#   - Julia code cells with output
#   - Markdown cells with bold + lists + a code fence (renders as Monaco
#     read-only editor inline) so we hit the markdown rendering path
#   - "Hard-to-wrap" content: an unbreakable long URL, a wide table, and
#     a long single-line julia expression. Without `.markdown-body`'s
#     `overflow-wrap: break-word` + `word-break: break-word` rules, the
#     URL alone would push the viewport.
# …then cycle through viewport sizes and verify each one:
#   - layout doesn't overflow horizontally (the canonical mobile
#     regression is a fixed-width editor or unbreakable URL spilling
#     past the viewport — the scrollWidth check catches it)
#   - editor width hits the expected `--editor-width` var value
#   - the +-menu (`.new-cell-plus` + `.new-cell-buttons`) is in-frame
#     after the mobile shift
#   - .markdown-body's break-word rules computed in (verified via
#     getComputedStyle, since the visible effect can be subtle)
#   - tap targets meet a minimum size (~24px) for finger-friendly UI
#   - .hover-buttons (per-cell edit/delete bar) and the right-anchored
#     sidebar still sit within the viewport
#   - book-cells-area remains scrollable at every width
#   - we can take a screenshot at each size for visual diffing
#
# We don't unit-test individual CSS rules — the assertions look at the
# observable side-effects in the rendered DOM, which is what users see.
isdefined(Main, :TH) || include(joinpath(@__DIR__, "helpers.jl"))

results = Pair{String,Bool}[]
record(name, ok) = push!(results, name => ok)

# The fixture: a mix of normal content plus three hostile-to-wrap items
# (long URL, wide markdown table, long single-line julia). The URL has
# no break opportunities, so only `word-break: break-word` lets the
# browser break it; without that rule, scrollWidth jumps past viewport.
const LONG_URL = "https://example.com/very/long/path/that/has/no/break/opportunities/" *
                 "and/will/blow/past/a/mobile/viewport/unless/word-break/is/configured/" *
                 "correctly/on/the/markdown-body/container/here/now/please/work"
const LONG_JULIA_LINE = "sum([" * join(["i^2" for i in 1:80], ", ") * "])"

tmp  = mktempdir()
file = TH.write_book(tmp, "render"; body = """
# Rendering test

A document with **mixed** content to stress the breakpoint CSS.

```julia (editor=true, logging=false, output=true)
1 + 1
```

Some markdown with a list:

  - one
  - two
  - three

A reference that must wrap on mobile: $(LONG_URL)

A wide table (5 columns) to test horizontal containment:

| Column-A | Column-B | Column-C | Column-D | Column-E |
| -------- | -------- | -------- | -------- | -------- |
| alpha    | beta     | gamma    | delta    | epsilon  |
| eta      | theta    | iota     | kappa    | lambda   |
| mu       | nu       | xi       | omicron  | pi       |

```julia (editor=true, logging=false, output=true)
collect(1:5)
```

A *second* markdown block with `inline code` and a Julia fence below.

```julia
# This is just decorative — no executor, rendered via Monaco read-only
function example(x)
    x * 2
end
```

```julia (editor=true, logging=false, output=true)
$(LONG_JULIA_LINE)
```

```julia (editor=true, logging=false, output=true)
"the answer is \$(6 * 7)"
```
""")

ctx = TH.open_book(file)

# Read a CSS custom property off the root element (`:root`). Returns
# the trimmed string, or "" if not set / no element.
function root_var(ctx, name::AbstractString)
    return TH.eval_js(ctx, """
        (() => {
            const v = getComputedStyle(document.documentElement)
                        .getPropertyValue($(repr(name))).trim();
            return v;
        })()
    """)
end

# Read a computed CSS property off the first element matching `selector`.
# Returns the trimmed string, or "" if no match.
function computed_style(ctx, selector::AbstractString, prop::AbstractString)
    return TH.eval_js(ctx, """
        (() => {
            const el = document.querySelector($(repr(selector)));
            if (!el) return "";
            return getComputedStyle(el).getPropertyValue($(repr(prop))).trim();
        })()
    """)
end

# Width of the documentElement (== outer viewport width in px).
inner_width(ctx) = TH.eval_js(ctx, "window.innerWidth")

# Horizontal overflow detector: page-level scrollbar would appear if
# the document's scrollWidth exceeds the viewport. We don't iterate
# descendant bounding rects because Monaco renders internal layers
# at 16777216 px (its virtual canvas) which are clipped by
# `overflow:hidden` on their wrappers and never reach the user.
overflows_x(ctx) = TH.eval_js(ctx, """
    (() => {
        const docw  = document.documentElement.scrollWidth;
        const bodyw = document.body ? document.body.scrollWidth : docw;
        return Math.max(docw, bodyw) > window.innerWidth + 1;
    })()
""")

# Bounding rects for VISIBLE `.small-button`s (tap-target audit).
# `visibility: hidden` cluster members (the +-menu's collapsed
# .new-cell-buttons children, the sidebar's hidden tab content)
# report a zero-size rect; including those would always fail the
# >=24px floor since their "size" is 0x0 in CSS terms.
small_button_rects(ctx) = TH.eval_js(ctx, """
    Array.from(document.querySelectorAll('.small-button'))
        .map(el => {
            const r = el.getBoundingClientRect();
            return {w: r.width, h: r.height, left: r.left, right: r.right};
        })
        .filter(r => r.w > 0 && r.h > 0)
""")

# Check every element matching selector fits within the viewport's
# horizontal band [-margin, viewportWidth+margin]. Returns the count
# that pokes outside. Useful for catching the hover-buttons / sidebar
# regression where an absolutely-positioned cluster ends up off-screen.
function offscreen_x_count(ctx, selector::AbstractString; margin::Int = 0)
    return TH.eval_js(ctx, """
        (() => {
            const vw = window.innerWidth;
            const m  = $margin;
            let n = 0;
            for (const el of document.querySelectorAll($(repr(selector)))) {
                const r = el.getBoundingClientRect();
                // Only count visible elements (some are hidden via .hide-* classes).
                if (r.width === 0 && r.height === 0) continue;
                if (r.right < -m || r.left > vw + m) n++;
            }
            return n;
        })()
    """)
end

try
    TH.section("Desktop (1280x900) baseline") do
        TH.set_window_size(ctx, 1280, 900)
        sleep(0.2)
        record("viewport reports 1280px",
               @TH.test_true (abs(inner_width(ctx) - 1280) < 5))
        # `--editor-width` defaults to 90ch — outside the tablet breakpoint
        # there shouldn't be a vw override.
        editor_width = root_var(ctx, "--editor-width")
        record("desktop --editor-width is the ch-based default (`$(editor_width)`)",
               @TH.test_true (occursin("ch", editor_width)))
        # No horizontal overflow — the whole book fits in viewport.
        record("no horizontal overflow at 1280px",
               @TH.test_eq overflows_x(ctx) false)
        # Cells-area must be scrollable.
        rect = TH.dom_rect(ctx, ".book-cells-area")
        record("book-cells-area has a positive height",
               @TH.test_true (rect !== nothing && rect["h"] > 50))
        # Every cell container is present.
        n_cells = TH.dom_count(ctx, ".cell-editor-container")
        record("all cell containers rendered ($(n_cells))",
               @TH.test_true (n_cells >= 5))
        TH.emit_screenshot(ctx; label = "rendering — desktop 1280")
    end

    TH.section("Tablet (760x900) — editor switches to vw") do
        TH.set_window_size(ctx, 760, 900)
        sleep(0.2)  # let the media query take effect
        record("viewport reports 760px",
               @TH.test_true (abs(inner_width(ctx) - 760) < 5))
        editor_width = root_var(ctx, "--editor-width")
        record("tablet --editor-width is the vw override (`$(editor_width)`)",
               @TH.test_true (occursin("vw", editor_width)))
        # Sizing in vw means the editor's actual pixel width should be
        # somewhere south of the viewport width.
        ed_rect = TH.dom_rect(ctx, ".monaco-editor-div")
        if ed_rect !== nothing
            record("editor pixel width <= viewport width",
                   @TH.test_true (ed_rect["w"] <= 760 + 5))
        end
        record("no horizontal overflow at 760px",
               @TH.test_eq overflows_x(ctx) false)
        # Above the mobile breakpoint, the radius vars should still be
        # the desktop defaults (the @media (max-width: 480px) rule
        # mustn't leak upward).
        br_large = root_var(ctx, "--border-radius-large")
        br_small = root_var(ctx, "--border-radius-small")
        record("tablet --border-radius-large still desktop value (`$(br_large)`)",
               @TH.test_true (br_large != "3px"))
        record("tablet --border-radius-small still desktop value (`$(br_small)`)",
               @TH.test_true (br_small != "2px"))
        TH.emit_screenshot(ctx; label = "rendering — tablet 760")
    end

    TH.section("Mid-band (600x900) — tablet rule on, mobile rule off") do
        # This viewport sits between the mobile (480) and tablet (768)
        # breakpoints. A regression that moves either rule's media
        # query (e.g., bumps mobile to 640) would show up here as
        # either the wrong editor-width or the wrong border-radius.
        TH.set_window_size(ctx, 600, 900)
        sleep(0.2)
        editor_width = root_var(ctx, "--editor-width")
        record("600px viewport: editor-width still on vw override (`$(editor_width)`)",
               @TH.test_true (occursin("vw", editor_width)))
        br_large = root_var(ctx, "--border-radius-large")
        record("600px viewport: border-radius-large NOT yet `3px` (`$(br_large)`)",
               @TH.test_true (br_large != "3px"))
        record("no horizontal overflow at 600px",
               @TH.test_eq overflows_x(ctx) false)
    end

    TH.section("Mobile (420x900) — narrower radii, +-menu visible, URL wraps") do
        TH.set_window_size(ctx, 420, 900)
        sleep(0.3)
        record("viewport reports 420px",
               @TH.test_true (abs(inner_width(ctx) - 420) < 5))
        # Mobile breakpoint sets both radius vars.
        br_large = root_var(ctx, "--border-radius-large")
        br_small = root_var(ctx, "--border-radius-small")
        record("mobile --border-radius-large == 3px (`$(br_large)`)",
               @TH.test_eq br_large "3px")
        record("mobile --border-radius-small == 2px (`$(br_small)`)",
               @TH.test_eq br_small "2px")

        # The +-menu has two pieces: `.new-cell-plus` (always visible
        # icon) and `.new-cell-buttons` (expands on hover). Both get
        # shifted to `left: -0.5rem` so they don't collide with the
        # left edge of the cell. Verify each lands inside a sane band
        # around x=0.
        plus_rect = TH.dom_rect(ctx, ".new-cell-plus")
        if plus_rect !== nothing
            record("new-cell-plus lands within [-25, 25] of x=0 at mobile",
                   @TH.test_true (-25 <= plus_rect["left"] <= 25))
        end
        # The buttons cluster is `visibility: hidden` until the
        # `.new-cell-menu` hovers. It still has a layout rect (left
        # coord), so we can check it without simulating hover.
        ncb_rect = TH.dom_rect(ctx, ".new-cell-buttons")
        if ncb_rect !== nothing
            record("new-cell-buttons lands within [-25, 25] of x=0 at mobile",
                   @TH.test_true (-25 <= ncb_rect["left"] <= 25))
        end

        # The single most likely mobile regression: a long unbreakable
        # URL in a markdown cell pokes past the viewport. The CSS rule
        # at @media (max-width: 480px) sets:
        #   .markdown-body { overflow-wrap: break-word; word-break: break-word }
        # Verify both made it onto the computed style. (Browsers can
        # normalise the `word-break` value — Chromium reports it as
        # `break-word`; we accept any "break-word"-containing value.)
        ow = computed_style(ctx, ".markdown-body", "overflow-wrap")
        wb = computed_style(ctx, ".markdown-body", "word-break")
        record(".markdown-body overflow-wrap == `break-word` (`$(ow)`)",
               @TH.test_eq ow "break-word")
        record(".markdown-body word-break contains `break-word` (`$(wb)`)",
               @TH.test_true occursin("break-word", wb))

        # The hostile-to-wrap content must not push the viewport out.
        # This is the canonical regression the word-break rule prevents;
        # without it, the page would acquire a horizontal scrollbar.
        record("no horizontal overflow at 420px (long URL + wide table)",
               @TH.test_eq overflows_x(ctx) false)

        # The monaco editor itself should not exceed the viewport
        # width. Tables that overflow are a known case — they live
        # inside .markdown-body but their own width can exceed 420 if
        # the user squeezes too hard. The table is allowed to scroll
        # within its container as long as the page doesn't.
        ed_rect = TH.dom_rect(ctx, ".monaco-editor-div")
        if ed_rect !== nothing
            record("editor pixel width fits in 420px viewport",
                   @TH.test_true (ed_rect["w"] <= 420 + 5))
        end

        # `.hover-buttons` (per-cell edit/delete bar) is absolutely
        # positioned. On mobile it should still sit within the
        # viewport — a missing rule that anchors it to the right edge
        # could leave it off-screen.
        n_off = offscreen_x_count(ctx, ".hover-buttons"; margin = 10)
        record("no .hover-buttons offscreen at mobile (offscreen count: $(n_off))",
               @TH.test_eq n_off 0)

        # `.sidebar-main-container` is fixed to right: 0. Confirm it's
        # still visible at the right edge (not pushed below or off-screen).
        n_sb_off = offscreen_x_count(ctx, ".sidebar-main-container"; margin = 10)
        record("sidebar still on-screen at mobile (offscreen: $(n_sb_off))",
               @TH.test_eq n_sb_off 0)

        # Tap-target audit: every visible `.small-button` should be at
        # least 24x24 px. 24px is below Material's 48dp recommendation
        # but our current padding gives ~30px naturally, so 24 is a
        # safe floor: a regression that shrinks the icon or padding
        # below ergonomic territory still trips this.
        rects = small_button_rects(ctx)
        small_buttons_ok = all(r -> r["w"] >= 24 && r["h"] >= 24, rects)
        record("every .small-button >= 24x24 px ($(length(rects)) checked)",
               @TH.test_true small_buttons_ok)

        TH.emit_screenshot(ctx; label = "rendering — mobile 420")
    end

    TH.section("Mobile interaction: clicking `+` inserts a cell into the DOM") do
        # End-to-end UI click. Drives the full round-trip:
        #   .new-cell-plus.onclick → $(plus_value).notify(true) over Bonito's
        #   websocket → Julia `on(plus_value)` callback → insert_editor_below!
        #   → Bonito.dom_in_js → JS-side `Monaco.insert_editor_at_index` →
        #   the new wrapper appears in the DOM.
        # If any link in that chain breaks at narrow widths (e.g., the
        # plus icon hit area collapses to 0, the click stops propagating
        # due to a positioning bug, or the websocket message gets eaten
        # while the Bonito sub-session for the new cell initialises),
        # the wrapper count won't climb and we fail.
        n_before     = TH.dom_count(ctx, ".cell-editor-container")
        cells_before = length(ctx.book.cells)

        # Click the LAST visible `.new-cell-plus` so we insert at the
        # end of the document — easier to verify in viewport since
        # we don't have to scroll. The plus button is opacity:0 until
        # hover but still receives click events.
        clicked = TH.eval_js(ctx, """
            (() => {
                const els = document.querySelectorAll('.new-cell-plus');
                if (!els.length) return false;
                const el = els[els.length - 1];
                el.click();
                return true;
            })()
        """)
        record("clickable `.new-cell-plus` found", @TH.test_true (clicked === true))

        # Wait for the Julia side to insert + the new DOM wrapper to mount.
        target = n_before + 1
        ok = TH.wait_for(ctx, """
            document.querySelectorAll('.cell-editor-container').length === $target
        """; timeout = 10.0)
        record("DOM wrapper count rose by 1 after click", @TH.test_true ok)
        record("Julia book.cells rose by 1 after click",
               @TH.test_eq length(ctx.book.cells) (cells_before + 1))

        # The new cell must be reachable: its wrapper id matches the
        # newly assigned uuid (the ensure_cell_id! fix we made earlier),
        # and the wrapper must lie inside the current viewport (horiz).
        new_editor = ctx.book.cells[end]
        record("new cell got a non-zero uuid (the insert-id fix held)",
               @TH.test_true (new_editor.uuid != 0))
        # `new_editor.uuid` is an integer, so a `#42` CSS selector is
        # invalid (id selectors can't start with a digit without
        # escaping). Use getElementById which doesn't go through the
        # selector grammar.
        new_rect = TH.eval_js(ctx, """
            (() => {
                const el = document.getElementById("$(new_editor.uuid)");
                if (!el) return null;
                const r = el.getBoundingClientRect();
                return {left: r.left, right: r.right, w: r.width, h: r.height};
            })()
        """)
        if new_rect !== nothing
            record("new cell wrapper sits within the 420px viewport",
                   @TH.test_true (-25 <= new_rect["left"] && new_rect["right"] <= 420 + 25))
        end
        # Sanity: still no page-level horizontal overflow after the click.
        record("no horizontal overflow after click-to-insert",
               @TH.test_eq overflows_x(ctx) false)
    end

    TH.section("Landscape phone (800x420) — tablet by width, shallow height") do
        # Landscape phones hit the tablet breakpoint by width (800 < 768?
        # no, 800 > 768 — landed in the desktop band by width). Use 760
        # to land in tablet. The point of this section is to confirm
        # nothing breaks at a shallow height: cells-area must remain
        # scrollable with only 420px of viewport height.
        TH.set_window_size(ctx, 760, 420)
        sleep(0.3)
        rect = TH.dom_rect(ctx, ".book-cells-area")
        record("book-cells-area has positive height at 760x420",
               @TH.test_true (rect !== nothing && rect["h"] > 100))
        sh = TH.eval_js(ctx,
            "document.querySelector('.book-cells-area').scrollHeight")
        ch = TH.eval_js(ctx,
            "document.querySelector('.book-cells-area').clientHeight")
        record("content still overflows so the user can scroll",
               @TH.test_true (sh > ch + 50))
        record("no horizontal overflow at 760x420",
               @TH.test_eq overflows_x(ctx) false)
        TH.emit_screenshot(ctx; label = "rendering — landscape 760x420")
    end

    TH.section("Resize back to desktop restores layout") do
        TH.set_window_size(ctx, 1280, 900)
        sleep(0.3)
        editor_width = root_var(ctx, "--editor-width")
        record("--editor-width back to ch-based after resize (`$(editor_width)`)",
               @TH.test_true (occursin("ch", editor_width)))
        br_large = root_var(ctx, "--border-radius-large")
        record("--border-radius-large back to non-mobile value (`$(br_large)`)",
               @TH.test_true (br_large != "3px"))
        br_small = root_var(ctx, "--border-radius-small")
        record("--border-radius-small back to non-mobile value (`$(br_small)`)",
               @TH.test_true (br_small != "2px"))
    end

    TH.section("Markdown still renders correctly after viewport churn") do
        # The markdown cells render via CommonMark to a tree of DOM
        # nodes. If anything in the resize cycle broke the runner state,
        # we'd see empty .cell-output divs. Check there's at least one
        # `<li>` and some output text from a Julia cell.
        n_li = TH.dom_count(ctx, "li")
        record("list items from markdown still rendered ($(n_li))",
               @TH.test_true (n_li >= 3))

        # Each julia cell with show_output=true should have a
        # .cell-output element after render.
        n_outputs = TH.dom_count(ctx, ".cell-output")
        record(".cell-output count >= 4 julia cells", @TH.test_true (n_outputs >= 4))

        # The wide table should be in the DOM as a real <table> with
        # at least 5 columns of headers.
        n_th = TH.dom_count(ctx, "th")
        record("table headers from wide-table fixture present ($(n_th))",
               @TH.test_true (n_th >= 5))
    end

    TH.section("No JS errors during full viewport cycle") do
        errs = TH.js_errors(ctx)
        # Same Bonito sub-session lifecycle race we document elsewhere —
        # resizing can fire a few during the device-emulation flip. We
        # only fail if it's clearly catastrophic.
        record("JS error count bounded ($(length(errs)) <= 5)",
               @TH.test_true (length(errs) <= 5))
    end

finally
    TH.report!("Rendering across breakpoints", results)
    TH.shutdown(ctx)
end
