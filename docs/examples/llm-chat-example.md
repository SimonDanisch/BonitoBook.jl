# LLM Chat Example

This is an example of using BonitoBook's LLM Chat plugin.

The chat interface allows you to have conversations with an AI assistant, where each cell in the notebook represents a message in the conversation.

## How it works

1. **User messages** appear on the right with a blue background
2. **Agent messages** appear on the left with a gray background
3. **Tool calls** are rendered with expandable previews showing what the agent is doing
4. **Code cells** created by the agent are automatically executed

## Features

  * **Streaming responses**: See the agent's response as it's being generated
  * **Tool usage**: The agent can execute bash commands, read/write files, make HTTP requests, and more
  * **Persistent history**: The conversation is saved in the notebook and can be reloaded
  * **Stop with ESC**: Press ESC to interrupt the agent's response at any time
  * **Counter-based IDs**: Each cell has a unique, persistent ID

Hi Hi there! How can I help you today?

Hi Hello! 👋 I'm here to help you with anything you need—whether that's writing code, debugging, exploring data, or just chatting about a topic. What would you like to work on today?

Hi

```julia (editor=true, logging=false, output=true, id=3, tool=add_cell, from=:tool)
using JSON3
JSON3.read(read(data"tools/add_cell-3.json", String), AddCellTool)
```
Below is a **complete, copy‑and‑paste ready** example that shows how to create a *BonitoBook* notebook from scratch, add a few simple cells (including a reactive slider), and launch it in your default web browser.   Feel free to paste the whole block into a Julia REPL (or a file that you’ll run with `julia`) and hit **Enter**.

```julia
# --------------------------------------------------------------------
# 1️⃣  Install the package (only the first time you run this)
# --------------------------------------------------------------------
# Uncomment the next line if BonitoBook isn’t already installed.
# using Pkg; Pkg.add("BonitoBook")

# --------------------------------------------------------------------
# 2️⃣  Load the package
# --------------------------------------------------------------------
using BonitoBook          # this pulls in Bonito automatically

# --------------------------------------------------------------------
# 3️⃣  Create an empty book
# --------------------------------------------------------------------
book = Book()             # ← this is your notebook

# --------------------------------------------------------------------
# 4️⃣  Add a first cell: a static Markdown title
# --------------------------------------------------------------------
@cell(book) begin
    Markdown("# Welcome to *BonitoBook*")
end

# --------------------------------------------------------------------
# 5️⃣  Add a second cell: a reactive slider + text
# --------------------------------------------------------------------
@cell(book) begin
    # A nice horizontal layout for the slider + its label
    h2("Interactive Slider Demo")

    # Create an observable that will hold the slider value (default 5)
    val = Observable(5)

    # The slider widget (range 0…10)
    slider = Slider(0:10, 5) |> oninput(val)  # updates `val` whenever the slider moves

    # Whenever `val` changes, update the text below the slider
    reactive = @reactive begin
        h3("Current value: $(val[])")
    end

    # Return a column of widgets that BonitoBook will render
    vbox(slider, reactive)
end

# --------------------------------------------------------------------
# 6️⃣  Launch the notebook in your browser
# --------------------------------------------------------------------
run(book)
```

### What this does

| Step |                                                                                                                          What happens |
| ----:| -------------------------------------------------------------------------------------------------------------------------------------:|
|    1 |                                                    Installs `BonitoBook` if you haven’t already (comment out if you already have it). |
|    2 |                                                                                  Loads the library and pulls in Bonito automatically. |
|    3 |                                                                  Creates an empty *Book* object – the container that holds all cells. |
|    4 |                                                                                   Adds a simple Markdown cell that displays a header. |
|    5 | Adds a second cell that contains: <br>• a **Slider** (0–10) <br>• a reactive `<h3>` element that updates whenever the slider changes. |
|    6 |                                                      Opens the notebook in a new browser tab and keeps it running until you close it. |

> **Tip** – If you’re working in VS Code, you can also run the book by clicking the *Run* button that appears next to the `run(book)` line.   The notebook will open in a separate VS Code tab (or a browser tab, depending on your settings).


---

## Customizing the look & feel

  * **Theme** – the book defaults to the system theme (dark / light).   To force a particular theme, set the `theme` property:

    ```julia
    book.theme[] = "dark"      # or "light"
    ```
  * **Editor width** – on mobile devices the editor shrinks automatically.   You can adjust it manually:

    ```julia
    book.editor_width[] = "80vw"
    ```
  * **Adding more cells** – simply repeat the `@cell(book)` block.   You can add tables, plots, or any Bonito widgets.

---

## Next steps

1. **Try a plot** – replace the slider cell with something that shows a dynamic plot.
2. **Experiment with widgets** – add buttons, checkboxes, and observe how reactive variables update.
3. **Export to a static page** – use `BonitoBook.export` to save the notebook as an HTML file that can be opened without Julia.

Happy exploring! If you hit any snags or want to see more advanced examples, just let me know.

Hi Hello! 👋 How can I help you today? If you’d like to try out the BonitoBook example again, add a new cell, or dive into a specific feature (like plots, widgets, or exporting), just let me know and I’ll walk you through it. Create a WGLMakie example

```julia (editor=true, logging=false, output=true, id=7, tool=add_cell, from=:tool)
JSON3.read(read(data"data\tools\add_cell-7.json", String), AddCellTool)
```
Can you try again? Sure! Could you let me know what you’d like to try again? For example, did you want me to run a specific script, modify a file, or something else? Just give me a bit more detail and I’ll get right on it. Adding a new cell with a WGLMakie example

```julia (editor=true, logging=true, output=true, id=12, tool=add_cell, from=:tool)
JSON3.read(read(data"tools/add_cell-12.json", String), AddCellTool)
```
```julia (editor=true, logging=false, output=true, id=13, tool=add_cell, from=:tool)
JSON3.read(read(data"tools/add_cell-13.json", String), AddCellTool)
```
```julia (editor=true, logging=false, output=true, id=14)
read(data"tools/add_cell-13.json", String)
```
Can you add a cell with a cool wglmakie example?

```julia (editor=true, logging=false, output=true, id=16, from=:agent)
using WGLMakie
fig = Figure(size = (600, 400))
ax = fig[1, 1] = LScene(fig)
sphere = mesh!(ax, Sphere(Point3f(0, 0, 0), 1f0), color = rand(RGBf, 10, 10))
# animate rotation
@async for i in 1:120
    rotate!(sphere, Vec3f(0, 1, 0), i * 0.01)
    sleep(1/10) # ~60fps
end
fig
```
```julia (editor=true, logging=false, output=true, id=17)
rotate!(sphere, Vec3f(0, 1, 0), 0.01)
```
