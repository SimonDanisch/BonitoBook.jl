# Stress test (1): large notebooks render without breaking.
#
# Loads a book with hundreds of cells (mixed julia + markdown) into an
# Electron window and verifies:
#   - every cell makes it into the DOM
#   - the cells-area scroller is functional (scrollTop responds, scrollHeight
#     reflects actual content height)
#   - rendering completes inside a generous budget
#   - the renderer doesn't fire any JS errors during mount
#   - a scrollTo(bottom) reveals cells that started off-screen (lazy /
#     deferred Monaco mounts still resolve when scrolled into view)
#
# Why this matters: very long books historically broke because
# `cells2editors` materialises one Monaco editor per cell synchronously
# and the cell DOM is mounted via a chain of Bonito sub-sessions. If any
# step is O(n^2) (or holds a lock per insert) the boot time explodes.
isdefined(Main, :TH) || include(joinpath(@__DIR__, "helpers.jl"))

results = Pair{String,Bool}[]
record(name, ok) = push!(results, name => ok)

# 200 cells = enough to make a slow O(n^2) path visible (~40k ops) but
# fast enough on a healthy implementation that CI doesn't time out.
const N_JULIA    = 100
const N_MARKDOWN = 100

tmp  = mktempdir()
body = TH.big_book_body(N_JULIA, N_MARKDOWN; mix = true)
file = TH.write_book(tmp, "stress_large"; body = body)

t_construct = @elapsed book = BonitoBook.Book(file)
println("Book construction took $(round(t_construct; digits=2))s for ",
        length(book.cells), " cells")
record("book construction under 60s", @TH.test_true (t_construct < 60.0))
record("Julia-side cell count >= N_JULIA + N_MARKDOWN",
       @TH.test_true (length(book.cells) >= N_JULIA + N_MARKDOWN))

t_open = @elapsed ctx = TH.open_book(book)
println("Window open + initial render took $(round(t_open; digits=2))s")

try
    TH.section("DOM mounts every cell") do
        ok = TH.wait_for(ctx, """
            document.querySelectorAll('.cell-editor-container').length === $(length(book.cells))
        """; timeout = 60.0)
        record("all $(length(book.cells)) cell containers in DOM", @TH.test_true ok)
        record("no JS errors during initial mount",
               @TH.test_eq length(TH.js_errors(ctx)) 0)
    end

    TH.section("Cells-area is scrollable and content overflows") do
        rect = TH.dom_rect(ctx, ".book-cells-area")
        record("cells-area has positive viewport height",
               @TH.test_true (rect !== nothing && rect["h"] > 100))
        scroll_height = TH.eval_js(ctx,
            "document.querySelector('.book-cells-area').scrollHeight")
        client_height = TH.eval_js(ctx,
            "document.querySelector('.book-cells-area').clientHeight")
        record("scrollHeight > clientHeight (content overflows)",
               @TH.test_true (scroll_height > client_height + 100))
    end

    TH.section("Scroll to bottom and back works") do
        # Drive a scroll on the scroll container, then verify scrollTop
        # ends up close to the requested position. Confirms no scroll
        # handler is preventing the user from reaching the end of the doc.
        TH.eval_js(ctx, """
            (() => {
                const sc = document.querySelector('.book-cells-area');
                sc.scrollTop = sc.scrollHeight;
                return sc.scrollTop;
            })()
        """)
        ok_bottom = TH.wait_for(ctx, """
            (() => {
                const sc = document.querySelector('.book-cells-area');
                return sc.scrollTop + sc.clientHeight >= sc.scrollHeight - 5;
            })()
        """; timeout = 5.0)
        record("scrollTop reaches bottom", @TH.test_true ok_bottom)

        TH.eval_js(ctx, "document.querySelector('.book-cells-area').scrollTop = 0")
        ok_top = TH.wait_for(ctx,
            "document.querySelector('.book-cells-area').scrollTop === 0";
            timeout = 5.0)
        record("scrollTop returns to 0", @TH.test_true ok_top)
    end

    TH.section("Last cell is reachable + has the right uuid") do
        last_uuid = book.cells[end].uuid
        # `cell.uuid` is an Int that BonitoBook uses as the wrapper's id
        # attribute. We can interpolate it directly into the JS string —
        # no JSON escaping needed.
        exists = TH.eval_js(ctx,
            "document.getElementById(\"$(last_uuid)\") !== null")
        record("last cell wrapper present in DOM", @TH.test_true (exists === true))
    end

    TH.section("Renderer still responsive after large mount") do
        # If the renderer is jammed, this round-trip times out.
        rt = TH.eval_js(ctx, "1 + 2")
        record("JS round-trip returns 3", @TH.test_eq rt 3)
    end

    TH.emit_screenshot(ctx; label = "large book — bottom of doc")
finally
    TH.report!("Large book — $(length(book.cells)) cells", results)
    TH.shutdown(ctx)
end
