# LLM Chat Plugin for BonitoBook

Transform your BonitoBook notebook into an interactive LLM chat interface!

## Overview

The LLM Chat plugin turns your notebook into a conversation with an AI assistant. Each cell represents a message in the conversation history, creating a persistent, reloadable chat experience.

## Features

- **📝 Notebook-based chat**: Conversation history is stored as notebook cells
- **🔄 Streaming responses**: See AI responses as they're generated
- **🛠️ Tool support**: Agent can execute code, manipulate files, and more
- **💾 Persistent IDs**: Counter-based cell IDs persist across sessions
- **⌨️ ESC to stop**: Interrupt streaming responses anytime
- **🎨 Beautiful rendering**: Tool uses and results are rendered with rich previews
- **🔌 Extensible**: Easy to add custom tools and LLM backends

## Quick Start

### Option 1: Create from Template (Recommended)

The easiest way to start is using the plugin template system:

```julia
using BonitoBook

# Create a new LLM Chat book from template
create_book_from_plugin("chat.md", "LLMChat")

# Load and display
book = Book("chat.md")
display(book)
```

This automatically:
- Creates the `.chat-bbook/` folder structure
- Copies template files (style.jl, README.md)
- Sets up the LLMChat plugin configuration
- Creates necessary directories (data/, ai/)

### Option 2: Manual Setup

If you prefer manual setup:

```julia
using BonitoBook
using BonitoBook.LLMChatBooks

# Load your notebook
book = Book("mynotebook.md")

# Create an LLM chat book
chat_book = LLMChatBooks.create_book(book)

# Display it
chat_book
```

## Architecture

### Components

1. **tools.jl**: Tool system with abstract interface for extensibility
2. **rendering.jl**: Beautiful rendering for tool uses and results
3. **agent.jl**: Generic LLM agent protocol with streaming support
4. **cell_id.jl**: Persistent counter-based cell ID management
5. **agent_loop.jl**: Main agent loop handling streaming, tools, and cells
6. **book.jl**: Main UI with fixed chat input and message rendering
7. **styles.jl**: CSS styling for chat interface

### Data Flow

```
User Input → Agent Loop → Stream Response → Tool Execution → Add Cells → Update UI
                ↑                                                    ↓
                └────────────── Cell History ←──────────────────────┘
```

## Cell Metadata

Cells in an LLM chat notebook have extended metadata:

```julia
metadata = Dict{Symbol, Any}(
    :from => :user,      # or :agent
    :id => 1             # persistent counter-based ID
)
```

This metadata is preserved in export/import:

```markdown
```julia (editor=true, logging=false, output=true, from=:agent, id=5)
println("Hello from the agent!")
\```
```

## Creating Custom Tools

Tools implement the `AbstractTool` interface:

```julia
using BonitoBook.LLMChatBooks

struct MyCustomTool <: AbstractTool
    argument::String
end

# Required methods
tool_name(::Type{MyCustomTool}) = "my_tool"
tool_description(::Type{MyCustomTool}) = "Description for the LLM"
tool_input_schema(::Type{MyCustomTool}) = Dict(
    "type" => "object",
    "properties" => Dict(
        "argument" => Dict("type" => "string", "description" => "...")
    ),
    "required" => ["argument"]
)

function execute_tool(tool::MyCustomTool, book)
    # Do something with tool.argument
    return (success=true, result="...")
end

# Optional: Custom rendering
function render_tool_result(::Type{MyCustomTool}, result)
    return DOM.div("Custom rendering for my tool result!")
end
```

## LLM Backend Integration

The plugin supports multiple LLM backends through a simple protocol:

```julia
# In your extension (e.g., BonitoBookMyLLMExt.jl)
struct MyLLMChatAgent <: BonitoBook.LLMChatAgent
    # Your agent fields
end

function BonitoBook.stream_response(agent::MyLLMChatAgent, messages, tools)
    channel = Channel{Any}(100)

    @async begin
        # Stream text
        put!(channel, "Hello ")
        put!(channel, "world!")

        # Or stream tool uses
        tool_use = ToolUse(BashTool, "args_file.json", cell_id)
        put!(channel, tool_use)

        close(channel)
    end

    return channel
end

# Register your agent
function BonitoBook.create_llm_chat_agent(book::BonitoBook.Book)
    return MyLLMChatAgent(...)
end
```

## Configuration

Configuration is stored in `.your-notebook-bbook/ai/`:

**llm-config.toml**:
```toml
model = "claude-sonnet-4-20250514"
max_tokens = 4096
temperature = 0.7
tool_choice = "auto"
tools = ["bash", "file_read", "file_write", "file_edit", "http_get", "add_cell"]
```

**llm-system-prompt.md**:
```markdown
You are a helpful AI assistant integrated into a Julia notebook.
You can execute code, read/write files, and help with programming tasks.
```

### Customizing with Plugin Templates

The LLMChat plugin provides a template system for easy customization:

```julia
# List available plugins
using BonitoBook
list_plugins()

# Create book from template with custom variables
create_book_from_plugin(
    "my_chat.md",
    "LLMChat",
    template_vars = Dict(
        "BOOK_TITLE" => "Research Assistant",
        "AUTHOR" => "Dr. Smith"
    )
)

# Or initialize template for existing book
initialize_plugin_template("my_chat.md")
```

The template includes:
- `style.jl` - Customizable styling (colors, layout, fonts)
- `README.md` - Usage instructions and examples
- Standard directories (`data/`, `ai/`)

See the [Plugin Template System documentation](../../docs/plugin_template_system.md) for details.

## Built-in Tools

- **BashTool**: Execute bash commands
- **FileReadTool**: Read file contents
- **FileWriteTool**: Write to files
- **FileEditTool**: Edit files with find/replace
- **HttpGetTool**: Fetch content from URLs
- **AddCellTool**: Add cells to the notebook

## UI Features

- **Fixed bottom input**: Chat input stays at bottom like modern chat apps
- **Streaming indicator**: Shows when AI is thinking
- **Stop button**: Click or press ESC to stop generation
- **Auto-scroll**: Automatically scrolls to new messages
- **User/Agent styling**: Distinct styling for user and agent messages
- **Tool previews**: Collapsible tool use and result rendering

## File Storage

Tool arguments are stored as JSON files:

```
.your-notebook-bbook/
├── data/
│   ├── cell_id_counter.txt          # BonitoBook cell ID counter (core feature)
│   └── tools/
│       ├── 1.json                    # Tool args for cell 1
│       ├── 2.json                    # Tool args for cell 2
│       └── ...
└── ai/
    ├── llm-config.toml
    └── llm-system-prompt.md
```

## Example Usage

See `docs/examples/llm-chat-example.md` for a complete example notebook.

## License

Same as BonitoBook - MIT License
