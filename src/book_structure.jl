# Book folder structure management

"""
    get_bbook_folder(bookfile::String)

Find the bbook folder for a given book file.
Checks in order:
1. .bbook in the same directory (shared)
2. .name-bbook in the same directory (per-file)

Returns the path if found, nothing otherwise.
"""
function get_bbook_folder(bookfile::String)
    book_file = normpath(abspath(bookfile))
    book_dir = dirname(book_file)
    name, ext = splitext(basename(book_file))

    # Check for shared .bbook folder first
    shared_folder = joinpath(book_dir, ".bbook")
    if isdir(shared_folder)
        return shared_folder
    end

    # Check for per-file .name-bbook folder
    per_file_folder = joinpath(book_dir, ".$(name)-bbook")
    if isdir(per_file_folder)
        return per_file_folder
    end

    return nothing
end

"""
    get_template_path()

Get the path to the bbook template folder.
"""
function get_template_path()
    return joinpath(@__DIR__, "bbook")
end

"""
    get_plugin_template_path(bbook_folder::String)

Get the plugin's bbook template path if a plugin is loaded.
Checks if book.jl exists and if the plugin module provides a bbook template.

Returns the plugin template path if found, nothing otherwise.
"""
function get_plugin_template_path(bbook_folder::String)
    book_jl_path = joinpath(bbook_folder, "book.jl")
    if !isfile(book_jl_path)
        return nothing
    end

    # Read the book.jl to determine the plugin module
    book_jl_content = read(book_jl_path, String)

    # Try to extract module name (assuming format: BonitoBook.PluginName)
    m = match(r"BonitoBook\.(\w+)", book_jl_content)
    if m === nothing
        return nothing
    end

    plugin_name = m.captures[1]

    # Check if plugin template exists
    plugin_template = joinpath(@__DIR__, "..", "plugins", plugin_name, "bbook")
    if isdir(plugin_template)
        return plugin_template
    end

    return nothing
end

"""
    get_file_path(bbook_folder, relative_path::String)

Get path to a file, checking in order:
1. Custom file in bbook_folder (user's custom version)
2. Plugin template (if a plugin is loaded and has the file)
3. BonitoBook template (default fallback)

Returns (path, is_custom) where is_custom indicates if it's from the custom folder.
"""
function get_file_path(bbook_folder, relative_path::String)
    if !isnothing(bbook_folder)
        # Check for custom file first
        custom_path = joinpath(bbook_folder, relative_path)
        if isfile(custom_path)
            return (custom_path, true)
        end

        # Check for plugin template
        plugin_template = get_plugin_template_path(bbook_folder)
        if !isnothing(plugin_template)
            plugin_file = joinpath(plugin_template, relative_path)
            if isfile(plugin_file)
                return (plugin_file, false)
            end
        end
    end

    # Fall back to BonitoBook template
    template_path = joinpath(get_template_path(), relative_path)
    return (template_path, false)
end

"""
    has_old_structure(bbook_folder::String)

Check if folder has old structure (pre-lazy-loading) by looking for old file locations.
"""
function has_old_structure(bbook_folder::String)
    # Check for old style.jl location
    old_style_path = joinpath(bbook_folder, "styles", "style.jl")
    if isfile(old_style_path)
        return true
    end

    # Check for old AI config locations (if they were ever in a different place)
    # Add more checks here as needed

    return false
end

"""
    check_or_create_meta(bbook_folder::String)

Check for meta.toml and handle version migration.
Returns true if folder structure is up to date, false if needs migration.
"""
function check_or_create_meta(bbook_folder::String)
    meta_path = joinpath(bbook_folder, "meta.toml")
    template_meta = joinpath(get_template_path(), "meta.toml")

    if !isfile(meta_path) || has_old_structure(bbook_folder)
        # Old structure detected - recommend deletion and fresh start
        @warn """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        BonitoBook folder structure has been updated!
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Old structure detected in: $bbook_folder

        RECOMMENDED MIGRATION STEPS:

        1. If you have custom styling in style.jl:
           - Backup your style.jl file
           - Delete the entire $bbook_folder folder
           - Restart BonitoBook (it will create new structure)
           - Use Claude Code or the styling guide to port your changes
             to the new style.jl format

        2. If you haven't customized anything:
           - Simply delete the entire $bbook_folder folder
           - Restart BonitoBook (it will create fresh structure)

        Files are now lazy-loaded from templates - they're only created
        when you edit them. See docs/howto/customize-styling.md for details.

        For now, continuing with existing structure (may have issues)...
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """

        if !isfile(meta_path)
            # Create meta.toml so we don't show this warning every time
            _cp(template_meta, meta_path)
        end
        return false
    end

    return true
end

"""
    initialize_file_for_editing(bbook_folder::String, relative_path::String)

Initialize a file for editing by copying from template if it doesn't exist.
Checks plugin template first, then falls back to BonitoBook template.
Creates the bbook folder and necessary subdirectories if needed.
Returns the path to the file to edit.
"""
function initialize_file_for_editing(bbook_folder::String, relative_path::String)
    # Ensure bbook folder exists
    if !isdir(bbook_folder)
        mkpath(bbook_folder)
        # Create basic structure
        mkpath(joinpath(bbook_folder, "data"))
        mkpath(joinpath(bbook_folder, "ai"))
        # Create meta.toml
        template_meta = joinpath(get_template_path(), "meta.toml")
        meta_path = joinpath(bbook_folder, "meta.toml")
        _cp(template_meta, meta_path)
    end

    # Check if file already exists
    custom_path = joinpath(bbook_folder, relative_path)
    if isfile(custom_path)
        return custom_path
    end

    # Create parent directory if needed
    parent_dir = dirname(custom_path)
    if !isdir(parent_dir) && !isempty(parent_dir)
        mkpath(parent_dir)
    end

    # Try to copy from plugin template first
    plugin_template = get_plugin_template_path(bbook_folder)
    if !isnothing(plugin_template)
        plugin_file = joinpath(plugin_template, relative_path)
        if isfile(plugin_file)
            _cp(plugin_file, custom_path)
            return custom_path
        end
    end

    # Fall back to BonitoBook template
    template_path = joinpath(get_template_path(), relative_path)
    if isfile(template_path)
        _cp(template_path, custom_path)
    else
        # Create empty file if template doesn't exist
        write(custom_path, "")
    end

    return custom_path
end

"""
    create_book_structure(bookfile::String; replace_style=false)

Find or create the bbook folder structure for a book file.
Always creates the base folder structure (for version backups and meta.toml).
Individual files are created lazily when accessed/edited.
"""
function create_book_structure(bookfile::String; replace_style=false)
    book_file = normpath(abspath(bookfile))
    name, ext = splitext(book_file)
    if !(ext in (".md", ".ipynb"))
        error("File $bookfile is not a markdown or ipynb file: $(ext)")
    end

    # Check for existing folder
    existing_folder = get_bbook_folder(book_file)

    if !isnothing(existing_folder)
        # Check/create meta.toml for version tracking
        check_or_create_meta(existing_folder)
        return existing_folder
    end

    # Create default folder structure
    book_dir = dirname(book_file)
    book_basename = basename(name)
    folder = joinpath(book_dir, ".$(book_basename)-bbook")

    # Always create base folder structure
    if !isdir(folder)
        mkpath(folder)
        mkpath(joinpath(folder, "data"))
        mkpath(joinpath(folder, ".versions"))  # For version backups
        mkpath(joinpath(folder, "ai"))

        # Create meta.toml
        template_meta = joinpath(get_template_path(), "meta.toml")
        meta_path = joinpath(folder, "meta.toml")
        _cp(template_meta, meta_path)
    end

    return folder
end

# ============================================================================
# Cell ID Management
# ============================================================================

"""
    assign_cell_ids!(cells::Vector)

Assign IDs to cells that don't have them (uuid == 0), using the highest existing ID + 1 as the starting point.
Returns the next available ID counter.
"""
function assign_cell_ids!(cells::Vector)
    max_id = 0

    # Find the highest existing ID
    for cell in cells
        if cell.uuid > 0
            max_id = max(max_id, cell.uuid)
        end
    end

    # Start counter after the highest ID
    counter = Ref(max_id + 1)

    # Assign IDs to cells without them (uuid == 0)
    for (i, cell) in enumerate(cells)
        if cell.uuid == 0
            # Create new cell with assigned ID
            cells[i] = CellEditor(
                cell.editor.source[],
                cell.language,
                cell.editor.runner;
                show_editor = cell.editor.show_editor[],
                show_logging = cell.editor.show_logging[],
                show_output = cell.editor.show_output[],
                theme = cell.editor.editor.theme,
                metadata = cell.metadata,
                id = counter[]
            )
            counter[] += 1
        end
    end

    return counter
end
