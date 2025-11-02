# Plugin Template System

The Plugin Template System provides a formalized way to create, distribute, and use BonitoBook plugins with templates.

## Overview

Plugins can provide:
- **Template folders** (`bbook/`) with default configurations and styles
- **Data folders** with example data or assets
- **Metadata** (`plugin.toml`) describing the plugin
- **Template variables** for customization during instantiation

## Plugin Structure

A plugin should have this structure:

```
plugins/
  MyPlugin/
    book.jl              # Main plugin module
    plugin.toml          # Plugin metadata (optional)
    README.md            # Plugin documentation
    bbook/               # Template folder (optional)
      style.jl           # Style template
      README.md          # Template usage guide
    data/                # Example data (optional)
      examples/
        sample.json
    ...other plugin files...
```

## Plugin Metadata (plugin.toml)

The `plugin.toml` file provides metadata about the plugin:

```toml
[plugin]
name = "MyPlugin"
version = "1.0.0"
author = "Your Name"
description = "A brief description of what this plugin does"

[features]
streaming = true
tool_use = false
custom_feature = true

[dependencies]
required = ["Bonito", "BonitoBook", "SomePackage"]

[template]
has_template = true
copy_data_by_default = false
include = ["style.jl", "README.md", "config.toml"]
variables = ["BOOK_TITLE", "AUTHOR"]
```

## Discovering Plugins

### List all available plugins

```julia
using BonitoBook

# List all plugins with descriptions
list_plugins()
```

Output:
```
Available Plugins:
══════════════════════════════════════════════════════════════════════

📦 LLMChat
   Module: LLMChatBooks
   Version: 0.1.0
   Author: BonitoBook Contributors
   Interactive LLM chat notebook with streaming responses, tool use, and file editing
   ✓ Has template folder

══════════════════════════════════════════════════════════════════════
```

### Get plugin information

```julia
# Get info about a specific plugin
plugin = get_plugin_info("LLMChat")

# Access plugin metadata
println(plugin.name)           # "LLMChat"
println(plugin.module_name)    # "LLMChatBooks"
println(plugin.description)    # Plugin description
println(plugin.template_path)  # Path to template folder
```

### Discover all plugins programmatically

```julia
# Returns Dict{String, PluginInfo}
plugins = discover_plugins()

for (name, info) in plugins
    println("Found plugin: $(info.name)")
end
```

## Creating Books from Plugin Templates

### Basic usage

```julia
# Create a book using the LLMChat plugin template
folder = create_book_from_plugin("mybook.md", "LLMChat")
```

This will:
1. Create the `.mybook-bbook/` folder structure
2. Create a `book.jl` that loads the plugin
3. Copy all template files from the plugin's `bbook/` folder
4. Set up the basic directory structure (`data/`, `ai/`, etc.)

### Advanced options

```julia
# Create book with all options
folder = create_book_from_plugin(
    "mybook.md",
    "LLMChat",
    copy_template = true,      # Copy template files (default: true)
    copy_data = true,          # Copy data folder (default: false)
    template_vars = Dict(      # Template variable substitution
        "BOOK_TITLE" => "My Custom Chat",
        "AUTHOR" => "John Doe",
        "DEFAULT_MODEL" => "claude-3-sonnet"
    )
)
```

### Template variable substitution

If your plugin templates include placeholders like `{{BOOK_TITLE}}`, they will be replaced:

**Template file (`bbook/config.toml`):**
```toml
title = "{{BOOK_TITLE}}"
author = "{{AUTHOR}}"
```

**After instantiation:**
```toml
title = "My Custom Chat"
author = "John Doe"
```

## Initializing Templates for Existing Books

If you have an existing book with a `book.jl` that loads a plugin:

```julia
# Auto-detect plugin and copy its template
initialize_plugin_template("mybook.md")
```

This reads your `book.jl`, detects which plugin you're using, and copies the template files.

## Creating Your Own Plugin

### 1. Create the plugin structure

```bash
mkdir -p plugins/MyPlugin/bbook
```

### 2. Create the main module (`plugins/MyPlugin/book.jl`)

```julia
module MyPluginBooks

using Bonito
using BonitoBook

# Define your plugin types
struct MyPluginBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    # ... your custom fields ...
end

# Create function
function create_book(book::BonitoBook.Book)
    # Initialize your plugin
    return MyPluginBook(book)
end

# Rendering
function Bonito.jsrender(session::Session, plugin_book::MyPluginBook)
    # Your custom UI
end

export MyPluginBook, create_book

end # module MyPluginBooks
```

### 3. Create template files (`plugins/MyPlugin/bbook/`)

Create template files that users can customize:

- `style.jl` - Custom styling
- `README.md` - Usage instructions
- `config.toml` - Configuration template
- Any other files users might want to customize

### 4. Create plugin metadata (`plugins/MyPlugin/plugin.toml`)

```toml
[plugin]
name = "MyPlugin"
version = "1.0.0"
author = "Your Name"
description = "Brief description of your plugin"

[template]
has_template = true
variables = ["CUSTOM_VAR_1", "CUSTOM_VAR_2"]
```

### 5. Add the plugin to BonitoBook

Edit `src/BonitoBook.jl`:

```julia
# Include your plugin
include("../plugins/MyPlugin/book.jl")

# Export the plugin module
export MyPluginBooks
```

### 6. Test your plugin

```julia
using BonitoBook

# Check if plugin is discovered
list_plugins()

# Create a book from your plugin
create_book_from_plugin("test.md", "MyPlugin")
```

## Template Best Practices

### 1. Lazy loading

Don't copy everything by default. Let users copy template files only when they need to customize:

- ✅ Small template folder with only essential files
- ✅ Copy on demand using `initialize_file_for_editing()`
- ❌ Large template with many files users won't customize

### 2. Good defaults

Template files should work out of the box with sensible defaults:

```julia
# Good: Works without customization
style = MyPlugin.generate_style(current_book(),
    theme = nothing,  # Auto-detect
    # ... sensible defaults ...
)
```

### 3. Documentation

Always include a README.md in your template explaining:
- What the plugin does
- How to customize the template files
- Example customizations
- Links to detailed documentation

### 4. Template variables

Use template variables for common customizations:

```julia
# Instead of hardcoding
title = "My Book"

# Use template variable
title = "{{BOOK_TITLE}}"
```

Users can then instantiate with custom values:

```julia
create_book_from_plugin(
    "book.md",
    "MyPlugin",
    template_vars = Dict("BOOK_TITLE" => "Custom Title")
)
```

## API Reference

### `discover_plugins() -> Dict{String, PluginInfo}`

Scan the plugins directory and return all available plugins.

### `get_plugin_info(plugin_name::String) -> Union{PluginInfo, Nothing}`

Get information about a specific plugin by name.

### `list_plugins()`

Print a formatted list of all available plugins.

### `create_book_from_plugin(bookfile, plugin_name; kwargs...)`

Create a book structure from a plugin template.

**Arguments:**
- `bookfile::String` - Path to book file
- `plugin_name::String` - Name of plugin to use
- `copy_template::Bool` - Copy template files (default: true)
- `copy_data::Bool` - Copy data folder (default: false)
- `template_vars::Dict{String,String}` - Template variables

**Returns:** Path to created bbook folder

### `initialize_plugin_template(bookfile::String)`

Initialize plugin template for an existing book by auto-detecting the plugin from `book.jl`.

**Returns:** Path to bbook folder, or nothing if no plugin detected

### `copy_template_folder(src, dest; exclude_patterns=String[])`

Recursively copy a template folder with exclusions.

**Arguments:**
- `src::String` - Source template folder
- `dest::String` - Destination folder
- `exclude_patterns::Vector{String}` - Patterns to exclude

**Returns:** Vector of copied file paths (relative to dest)

### `apply_template_vars!(folder, files, vars)`

Apply template variable substitution to files.

**Arguments:**
- `folder::String` - Base folder containing files
- `files::Vector{String}` - List of files to process (relative paths)
- `vars::Dict{String,String}` - Variable name => value mapping

## Examples

### Example 1: Create LLM Chat book

```julia
using BonitoBook

# Create with defaults
folder = create_book_from_plugin("chat.md", "LLMChat")

# Open in browser
book = Book("chat.md")
display(book)
```

### Example 2: Create with customization

```julia
folder = create_book_from_plugin(
    "research_chat.md",
    "LLMChat",
    copy_template = true,
    copy_data = false,
    template_vars = Dict(
        "BOOK_TITLE" => "Research Assistant",
        "AUTHOR" => "Dr. Smith"
    )
)
```

### Example 3: Initialize template for existing book

```julia
# You have an existing .mybook-bbook/book.jl that loads a plugin
initialize_plugin_template("mybook.md")

# Template files are now copied and ready to customize
```

### Example 4: List and explore plugins

```julia
# See all available plugins
list_plugins()

# Get detailed info
plugin = get_plugin_info("LLMChat")
println("Template path: $(plugin.template_path)")
println("Description: $(plugin.description)")

# Check what's in the template
if !isnothing(plugin.template_path)
    run(`ls -la $(plugin.template_path)`)
end
```

## See Also

- [How to Create Custom Styling](howto/customize-styling.md)
- [LLMChat Plugin Documentation](../plugins/LLMChat/README.md)
- [Book Structure Guide](book-structure.md)
