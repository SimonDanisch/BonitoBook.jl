module BonitoBookGUI

# Currently AppBundler only precompiles the main app module and its direct dependencies
# (including transitive dependencies of those direct dependencies).
# Weak dependencies are not precompiled since they're not in the dependency tree.
# This is a temporary workaround until AppBundler properly handles precompilation of weak dependencies.
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

    # Copy examples to a mutable user data directory
    if haskey(ENV, "USER_DATA")
        user_examples = joinpath(ENV["USER_DATA"], "examples")
        @info "Using examples stored in user data directory $user_examples"
        if !isdir(user_examples)
            @info "Instantiating examples into user data directory"
            mkpath(ENV["USER_DATA"])
            cp(examples_folder, user_examples)
            chmod(user_examples, 0o755; recursive=true)
        end
        examples_folder = user_examples
    end

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
