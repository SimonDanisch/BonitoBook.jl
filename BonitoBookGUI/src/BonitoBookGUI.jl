module BonitoBookGUI

# Currently AppBundler precompiles only dependencies that are launched from the main app module
# This fix is temporary until we figure out details within AppBundler on how to do this properly
import Sunny, GeometryBasics, WGLMakie, DataFrames

# BonitoBook Welcome Page Server
# Serves all example books from docs/examples with a welcome page
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
function (@main)(args)
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
    win = Electron.Window(
        Dict(
            "width" => 1400,
            "height" => 900,
            "title" => "BonitoBook",
            "center" => true
        )
    )

    # Load the welcome page
    Electron.load(win, Bonito.URI(Bonito.online_url(server, "/")))

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

export main

end # module BonitoBookGUI
