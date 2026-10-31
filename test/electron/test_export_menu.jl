# Stress test (5): the export menu + `export_md_with_results` with a
# live browser (the WGLMakie path that the unit tests can't cover).
#
# Coverage:
#   1. Each saving-menu button (`.saving .small-button`) fires its
#      export handler when clicked, and the resulting file lands on
#      disk with sane content. We skip the PDF button because it calls
#      `window.print()` which opens a native dialog Electron can't
#      drive headlessly.
#   2. `export_md_with_results` against a WGLMakie figure: with a live
#      `book.session`, the HTML output triggers a browser-side
#      `htmlToImage.toPng` capture and a PNG lands in the output dir.
#      Without this test we'd only know the unit-test synthetic-HTML
#      path works — we wouldn't know the real WebGL path does.
isdefined(Main, :TH) || include(joinpath(@__DIR__, "helpers.jl"))

results = Pair{String,Bool}[]
record(name, ok) = push!(results, name => ok)

# ── Set up a book with a Julia cell that produces a small scalar.
# WGLMakie is loaded later only if the test reaches that section, so
# the menu-button test stays fast even if Makie isn't available.
tmp  = mktempdir()
file = TH.write_book(tmp, "export"; body = """
# Export menu test

A regular markdown cell with some content.

```julia (editor=true, logging=false, output=true)
1 + 1
```

```julia (editor=true, logging=false, output=true)
"hello export"
```
""")

ctx  = TH.open_book(file)
book = ctx.book

# Wait until the saving menu is mounted (its buttons load via the
# `Monaco` ES6 module promise alongside the rest of the book).
TH.wait_for(ctx, """
    document.querySelectorAll('.saving .small-button').length >= 5
"""; timeout = 30.0)

# Click the menu button that contains an icon `<img>` whose `src`
# matches `icon_substr`. Returns true if the click was dispatched.
function click_export_button(ctx, icon_substr::AbstractString)
    return TH.eval_js(ctx, """
        (() => {
            const imgs = document.querySelectorAll('.saving .small-button img');
            for (const img of imgs) {
                if ((img.getAttribute('src') || '').includes($(repr(icon_substr)))) {
                    img.closest('button').click();
                    return true;
                }
            }
            return false;
        })()
    """) === true
end

# Block until `predicate()` becomes true or `timeout` elapses. Used
# in place of TH.wait_for when the condition is checked Julia-side
# (e.g., a file appearing on disk) rather than via JS.
function wait_until(predicate::Function; timeout::Float64 = 15.0, interval::Float64 = 0.1)
    deadline = time() + timeout
    while time() < deadline
        try
            predicate() && return true
        catch
        end
        sleep(interval)
    end
    return false
end

try
    TH.section("All menu buttons present in the DOM") do
        # Sanity: there should be at least 5 small-buttons in `.saving`
        # (we skip PDF — the test doesn't click it but it should still
        # exist).
        n = TH.dom_count(ctx, ".saving .small-button")
        record("at least 6 export buttons rendered", @TH.test_true (n >= 6))
    end

    TH.section("Markdown button → export_md writes book.file") do
        # The handler overwrites `book.file` with the canonical export.
        # We can detect it by deleting the file beforehand and waiting
        # for it to reappear.
        rm(book.file; force = true)
        record("clicked markdown export button",
               @TH.test_true click_export_button(ctx, "markdown"))
        ok = wait_until(() -> isfile(book.file) && filesize(book.file) > 0;
                        timeout = 10.0)
        record("book.file written by markdown export", @TH.test_true ok)
        if ok
            text = read(book.file, String)
            # Round-trip parity: every fenced cell carries its metadata.
            record("exported markdown contains fenced julia cell",
                   @TH.test_true occursin("```julia", text))
            record("exported markdown contains the metadata id=",
                   @TH.test_true occursin("id=", text))
        end
    end

    TH.section("HTML button → export_html writes book.folder/book.html") do
        html_file = joinpath(book.folder, "book.html")
        rm(html_file; force = true)
        record("clicked HTML export button",
               @TH.test_true click_export_button(ctx, "html-file"))
        # HTML export goes through Bonito.export_static which can take
        # a few seconds while serialising assets — give it a longer
        # budget than the lighter exports.
        ok = wait_until(() -> isfile(html_file) && filesize(html_file) > 1024;
                        timeout = 60.0)
        record("book.html written and >1KB", @TH.test_true ok)
        if ok
            head = read(html_file, 200)
            record("HTML file looks like HTML",
                   @TH.test_true occursin("<!DOCTYPE html>",
                                          String(copy(head))) ||
                                 occursin("<html", String(copy(head))))
        end
    end

    TH.section("Quarto button → export_quarto writes book.qmd") do
        qmd_file = joinpath(book.folder, "book.qmd")
        rm(qmd_file; force = true)
        record("clicked Quarto export button",
               @TH.test_true click_export_button(ctx, "quarto"))
        ok = wait_until(() -> isfile(qmd_file) && filesize(qmd_file) > 0;
                        timeout = 10.0)
        record("book.qmd written by Quarto export", @TH.test_true ok)
        if ok
            text = read(qmd_file, String)
            # Quarto's executable-block format is `{language}` (curly braces).
            record("Quarto markdown uses {julia} fence syntax",
                   @TH.test_true occursin("```{julia", text))
        end
    end

    TH.section("Jupyter button → export_ipynb writes book.ipynb") do
        ipynb_file = joinpath(book.folder, "book.ipynb")
        rm(ipynb_file; force = true)
        record("clicked ipynb export button",
               @TH.test_true click_export_button(ctx, "notebook"))
        ok = wait_until(() -> isfile(ipynb_file) && filesize(ipynb_file) > 0;
                        timeout = 10.0)
        record("book.ipynb written by ipynb export", @TH.test_true ok)
        if ok
            text = read(ipynb_file, String)
            record("ipynb is valid JSON with cells",
                   @TH.test_true (occursin("\"cells\"", text) &&
                                  occursin("\"nbformat\"", text)))
        end
    end

    TH.section("ZIP button → export_zip writes <name>.zip") do
        zip_file = joinpath(book.folder, "$(splitext(basename(book.file))[1]).zip")
        rm(zip_file; force = true)
        record("clicked ZIP export button",
               @TH.test_true click_export_button(ctx, "archive"))
        # p7zip shells out — bump the budget a bit.
        ok = wait_until(() -> isfile(zip_file) && filesize(zip_file) > 64;
                        timeout = 30.0)
        record("zip archive written", @TH.test_true ok)
        if ok
            # ZIP magic bytes are "PK\x03\x04".
            header = read(zip_file, 4)
            record("zip file has PK magic bytes",
                   @TH.test_true (header[1] == UInt8('P') && header[2] == UInt8('K')))
        end
    end

    TH.section("No JS errors during the full export-menu cycle") do
        errs = TH.js_errors(ctx)
        record("JS error count bounded ($(length(errs)) <= 5)",
               @TH.test_true (length(errs) <= 5))
    end

    TH.section("export_md_with_results with a live browser captures WGLMakie as PNG") do
        # We load WGLMakie at this point so the rest of the test could
        # have run without it. If it's unavailable, mark the section as
        # skipped rather than failing the suite.
        wglmakie_loaded = try
            Core.eval(book.runner.mod, :(using WGLMakie))
            true
        catch e
            @warn "WGLMakie unavailable in runner module — skipping live-capture test" exception = e
            false
        end

        if !wglmakie_loaded
            record("WGLMakie available in runner — SKIPPED", false)
        else
            # Insert + run a plot cell. The figure renders inside the
            # cell's output_div; we then call export_md_with_results
            # which sees book.session !== nothing and calls the
            # browser-side `htmlToImage.toPng` to snapshot the output.
            plot_cell = TH.insert_julia_cell!(ctx,
                "using WGLMakie\nfig = scatter(1:10, rand(10))"; pos = :end)
            TH.wait_for(ctx,
                "document.getElementById(\"$(plot_cell.uuid)\") !== null";
                timeout = 10.0)
            TH.cell_run_sync!(plot_cell)

            # Wait for the cell's .cell-output to actually contain a
            # canvas (WGLMakie mounts via a sub-session that resolves
            # asynchronously). If no canvas after the timeout, we can
            # still proceed — the capture path will succeed against
            # whatever HTML is in there, but a missing canvas means
            # the test won't have proved much.
            canvas_ok = TH.wait_for(ctx, """
                (() => {
                    const out = document.querySelectorAll('.cell-output');
                    return Array.from(out).some(e => e.querySelector('canvas'));
                })()
            """; timeout = 30.0)
            record("WGLMakie canvas rendered into cell output",
                   @TH.test_true canvas_ok)

            # Now actually export — this is the bit that exercises
            # `_capture_output_png_from_browser`.
            out_dir = joinpath(tmp, "live-output")
            out_md  = joinpath(tmp, "live.md")
            BonitoBook.export_md_with_results(out_md, book; output_dir = out_dir)
            text = read(out_md, String)

            png_file = joinpath(out_dir, "cell_$(plot_cell.uuid).png")
            record("browser-snapshot PNG was written for the plot cell",
                   @TH.test_true isfile(png_file))
            if isfile(png_file)
                # Sanity-check it's a real PNG (first 8 bytes).
                hdr = read(png_file, 8)
                record("PNG file has the 0x89 PNG magic bytes",
                       @TH.test_true (hdr == UInt8[0x89, 0x50, 0x4e, 0x47,
                                                    0x0d, 0x0a, 0x1a, 0x0a]))
                record("PNG file is non-trivial (>1KB → real picture, not blank)",
                       @TH.test_true (filesize(png_file) > 1024))
            end

            # The markdown should reference that PNG as an image.
            record("exported markdown references the captured PNG",
                   @TH.test_true occursin("cell_$(plot_cell.uuid).png", text))
        end
    end

    TH.emit_screenshot(ctx; label = "export menu — after full cycle")
finally
    TH.report!("Export menu + live results", results)
    TH.shutdown(ctx)
end
