# Plugin Template System
#
# This module provides a formalized system for creating and managing plugin templates.
# Plugins can provide template folders that get copied with data and initialization.

"""
    PluginInfo

Metadata about a plugin.

# Fields
- `name::String`: Plugin name (e.g., "Slideshow")
- `module_name::String`: Module name (e.g., "SlideshowBooks")
- `path::String`: Path to plugin directory
- `template_path::Union{String, Nothing}`: Path to plugin's bbook template folder
- `description::String`: Plugin description
"""
struct PluginInfo
    name::String
    module_name::String
    path::String
    template_path::Union{String, Nothing}
    description::String
    author::String
    version::String
end

"""
    discover_plugins()

Discover all available plugins by scanning the plugins directory.

Returns a Dict{String, PluginInfo} mapping plugin names to their metadata.
"""
function discover_plugins()
    plugins = Dict{String, PluginInfo}()
    plugins_dir = joinpath(@__DIR__, "..", "plugins")

    if !isdir(plugins_dir)
        return plugins
    end

    for entry in readdir(plugins_dir; join=false)
        plugin_path = joinpath(plugins_dir, entry)
        if !isdir(plugin_path)
            continue
        end

        # Check if plugin has a book.jl file
        book_jl = joinpath(plugin_path, "book.jl")
        if !isfile(book_jl)
            continue
        end

        # Extract module name from book.jl
        book_jl_content = read(book_jl, String)
        m = match(r"module\s+(\w+)", book_jl_content)
        if m === nothing
            continue
        end
        module_name = m.captures[1]

        # Check for bbook template folder
        template_path = joinpath(plugin_path, "bbook")
        has_template = isdir(template_path)

        description = ""
        author = ""
        version = ""

        # If no description, try to extract from README
        if isempty(description)
            readme_path = joinpath(plugin_path, "README.md")
            if isfile(readme_path)
                try
                    readme_content = read(readme_path, String)
                    # Try to extract first paragraph as description
                    lines = split(readme_content, '\n')
                    for line in lines
                        line = strip(line)
                        if !isempty(line) && !startswith(line, '#')
                            description = line
                            break
                        end
                    end
                catch e
                    # Ignore read errors
                end
            end
        end

        plugins[entry] = PluginInfo(
            entry,
            module_name,
            plugin_path,
            has_template ? template_path : nothing,
            description,
            author,
            version
        )
    end

    return plugins
end

"""
    get_plugin_info(plugin_name::String)

Get information about a specific plugin.

Returns a PluginInfo if found, nothing otherwise.
"""
function get_plugin_info(plugin_name::String)
    plugins = discover_plugins()
    return get(plugins, plugin_name, nothing)
end

"""
    list_plugins()

List all available plugins.

Prints a formatted list of plugins with their descriptions.
"""
function list_plugins()
    plugins = discover_plugins()

    if isempty(plugins)
        println("No plugins found.")
        return
    end

    println("\nAvailable Plugins:")
    println("═" ^ 70)

    for (name, info) in sort(collect(plugins), by=x->x[1])
        println("\n📦 $(info.name)")
        println("   Module: $(info.module_name)")
        if !isempty(info.version)
            println("   Version: $(info.version)")
        end
        if !isempty(info.author)
            println("   Author: $(info.author)")
        end
        if !isempty(info.description)
            println("   $(info.description)")
        end
        if !isnothing(info.template_path)
            println("   ✓ Has template folder")
        end
    end
    println("\n" * "═" ^ 70)
end

"""
    copy_template_folder(src::String, dest::String; exclude_patterns=String[])

Recursively copy a template folder, excluding certain patterns.

# Arguments
- `src::String`: Source template folder
- `dest::String`: Destination folder
- `exclude_patterns::Vector{String}`: Patterns to exclude (e.g., [".git", "*.swp"])

# Returns
Vector of copied file paths (relative to dest)
"""
function copy_template_folder(src::String, dest::String; exclude_patterns=String[])
    copied_files = String[]

    function should_exclude(path::String)
        name = basename(path)
        for pattern in exclude_patterns
            if occursin(pattern, name) ||
               (startswith(pattern, "*.") && endswith(name, pattern[2:end]))
                return true
            end
        end
        return false
    end

    function copy_recursive(src_path::String, dest_path::String, rel_path::String="")
        if should_exclude(src_path)
            return
        end

        if isfile(src_path)
            # Ensure parent directory exists
            parent_dir = dirname(dest_path)
            if !isempty(parent_dir)
                mkpath(parent_dir)
            end

            # Copy file
            _cp(src_path, dest_path)
            push!(copied_files, rel_path)
        elseif isdir(src_path)
            # Create directory
            if !isdir(dest_path)
                mkpath(dest_path)
            end

            # Copy contents
            for entry in readdir(src_path; join=false)
                src_entry = joinpath(src_path, entry)
                dest_entry = joinpath(dest_path, entry)
                rel_entry = isempty(rel_path) ? entry : joinpath(rel_path, entry)
                copy_recursive(src_entry, dest_entry, rel_entry)
            end
        end
    end

    copy_recursive(src, dest)
    return copied_files
end

"""
    create_book_from_plugin(bookfile::String, plugin_name::String;
                           copy_template=true, copy_data=false,
                           template_vars=Dict{String,String}())

Create a book structure from a plugin template.

# Arguments
- `bookfile::String`: Path to the book file (e.g., "mybook.md")
- `plugin_name::String`: Name of the plugin to use
- `copy_template::Bool`: Whether to copy template files (default: true)
- `copy_data::Bool`: Whether to copy data folder (default: false)
- `template_vars::Dict{String,String}`: Variables for template substitution

# Returns
Path to the created bbook folder

# Example
```julia
# Create a slideshow book
folder = create_book_from_plugin("slides.md", "Slideshow")

# Create with custom variables
folder = create_book_from_plugin(
    "slides.md",
    "Slideshow",
    template_vars = Dict(
        "BOOK_TITLE" => "My Slides",
        "AUTHOR" => "John Doe"
    )
)
```
"""
function create_book_from_plugin(bookfile::String, plugin_name::String;
                                copy_template=true, copy_data=false,
                                template_vars=Dict{String,String}())
    # Get plugin info
    plugin = get_plugin_info(plugin_name)
    if plugin === nothing
        error("Plugin '$plugin_name' not found. Use list_plugins() to see available plugins.")
    end

    # Create basic book structure
    folder = create_book_structure(bookfile)

    # Create book.jl that loads the plugin
    book_jl_path = joinpath(folder, "book.jl")
    if !isfile(book_jl_path)
        book_jl_content = """
        # This book uses the $(plugin.name) plugin
        # Module: $(plugin.module_name)

        module AutoPluginBook
        using BonitoBook
        using BonitoBook.$(plugin.module_name)
        create_book(book::BonitoBook.Book; kwargs...) = BonitoBook.$(plugin.module_name).create_book(book; kwargs...)
        end
        """
        write(book_jl_path, book_jl_content)
    end

    # Copy template files if requested
    if copy_template && !isnothing(plugin.template_path)
        exclude = [".git", "*.swp", "*~", ".DS_Store"]
        copied = copy_template_folder(
            plugin.template_path,
            folder;
            exclude_patterns=exclude
        )

        # Apply template variable substitution if variables provided
        if !isempty(template_vars)
            apply_template_vars!(folder, copied, template_vars)
        end

        @info "Copied $(length(copied)) template files from $(plugin.name) plugin"
    end

    # Copy data folder if requested
    if copy_data
        data_src = joinpath(plugin.path, "data")
        if isdir(data_src)
            data_dest = joinpath(folder, "data")
            if !isdir(data_dest)
                mkpath(data_dest)
            end

            exclude = [".git", "*.swp", "*~", ".DS_Store"]
            copied_data = copy_template_folder(
                data_src,
                data_dest;
                exclude_patterns=exclude
            )
            @info "Copied $(length(copied_data)) data files from $(plugin.name) plugin"
        end
    end

    return folder
end

"""
    apply_template_vars!(folder::String, files::Vector{String}, vars::Dict{String,String})

Apply template variable substitution to files.

Replaces placeholders like {{VARIABLE_NAME}} with values from vars dict.

# Arguments
- `folder::String`: Base folder containing the files
- `files::Vector{String}`: List of files to process (relative paths)
- `vars::Dict{String,String}`: Variable name => value mapping
"""
function apply_template_vars!(folder::String, files::Vector{String}, vars::Dict{String,String})
    for file_rel in files
        file_path = joinpath(folder, file_rel)

        # Only process text files
        if !isfile(file_path)
            continue
        end

        # Skip binary files by checking extension
        ext = lowercase(splitext(file_path)[2])
        binary_exts = [".png", ".jpg", ".jpeg", ".gif", ".pdf", ".zip", ".tar", ".gz"]
        if ext in binary_exts
            continue
        end

        try
            content = read(file_path, String)
            modified = false

            # Replace each variable
            for (var_name, var_value) in vars
                placeholder = "{{$(var_name)}}"
                if occursin(placeholder, content)
                    content = replace(content, placeholder => var_value)
                    modified = true
                end
            end

            # Write back if modified
            if modified
                write(file_path, content)
            end
        catch e
            @warn "Failed to process template variables in $file_rel" exception=e
        end
    end
end

"""
    initialize_plugin_template(bookfile::String)

Initialize a plugin template for an existing book by detecting the plugin from book.jl.

This is useful when you have a book.jl that loads a plugin but haven't copied the template yet.

# Arguments
- `bookfile::String`: Path to the book file

# Returns
Path to the bbook folder, or nothing if no plugin detected
"""
function initialize_plugin_template(bookfile::String)
    # Get existing bbook folder
    folder = get_bbook_folder(bookfile)
    if folder === nothing
        @warn "No bbook folder found for $bookfile. Create one first with create_book_structure()."
        return nothing
    end

    # Check if book.jl exists
    book_jl_path = joinpath(folder, "book.jl")
    if !isfile(book_jl_path)
        @warn "No book.jl found in $folder"
        return nothing
    end

    # Try to extract plugin name
    book_jl_content = read(book_jl_path, String)
    m = match(r"using BonitoBook\.(\w+)", book_jl_content)
    if m === nothing
        @warn "Could not detect plugin from book.jl"
        return nothing
    end

    module_name = m.captures[1]

    # Find plugin by module name
    plugins = discover_plugins()
    plugin_info = nothing
    for (name, info) in plugins
        if info.module_name == module_name
            plugin_info = info
            break
        end
    end

    if plugin_info === nothing
        @warn "Plugin module $module_name not found in plugins directory"
        return nothing
    end

    # Copy template
    if !isnothing(plugin_info.template_path)
        exclude = [".git", "*.swp", "*~", ".DS_Store"]
        copied = copy_template_folder(
            plugin_info.template_path,
            folder;
            exclude_patterns=exclude
        )
        @info "Initialized $(plugin_info.name) template: copied $(length(copied)) files"
    else
        @info "Plugin $(plugin_info.name) has no template folder"
    end

    return folder
end

export PluginInfo, discover_plugins, get_plugin_info, list_plugins
export create_book_from_plugin, initialize_plugin_template
export copy_template_folder, apply_template_vars!
