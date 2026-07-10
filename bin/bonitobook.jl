#!/usr/bin/env julia

# BonitoBook Welcome Page Server
# Serves all example books from docs/examples with a welcome page
using WGLMakie # for faster book loading with WGLMakie examples
using BonitoBook
using Bonito
using Electron


"""
    @main(args)

Start the BonitoBook welcome page server.

Opens an Electron window with the welcome page showing all example books
in the docs/examples directory. The server runs until the window is closed.

# Arguments
- `args`: Command line arguments (currently unused)
"""
function @main(args)
    # Get the examples folder path
    examples_folder = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))

    if !isdir(examples_folder)
        error("Examples folder not found: $examples_folder")
    end

    @info "Starting BonitoBook welcome server..."
    @info "Examples folder: $examples_folder"

    # Create and start the server
    server = serve_welcome(examples_folder; url="127.0.0.1", port=8773, proxy_url="")

    @info "Server started at: $(Bonito.online_url(server, "/"))"
    # Open in Electron
    @info "Opening Electron window..."
    # Create Electron application

    # Create window with a good size for BonitoBook (1400x900, centered)
    win = Main.Electron.Window(
        Dict(
            "width" => 1400,
            "height" => 900,
            "title" => "BonitoBook",
            "center" => true
        )
    )

    # Load the welcome page
    Main.Electron.load(win, Bonito.URI(Bonito.online_url(server, "/")))

    @info "Window opened. Close the window to exit."

    # Wait for the window to close by checking if it still exists
    while win.exists
        sleep(0.5)  # Check every 100ms
    end

    @info "Window closed. Shutting down server..."

    # Close the server
    close(server)

    return 0
end
# main([])
#
