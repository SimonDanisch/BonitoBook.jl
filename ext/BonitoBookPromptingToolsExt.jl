module BonitoBookPromptingToolsExt

using BonitoBook
using PromptingTools
using Bonito
using Markdown
using TOML
using JSON

"""
    PromptingToolsAgent <: ChatAgent

A chat agent that uses PromptingTools.jl for AI conversations.
Supports multiple models and providers (OpenAI, Anthropic, MistralAI, etc.).

# Fields
- `book::Book`: The book object this agent is associated with
- `model::String`: Current model to use (e.g., "gpt-4o", "claude-3-5-sonnet-20241022")
- `system_prompt::String`: System prompt to use for conversations
- `mcp_server_url::String`: URL of the MCP server for Julia execution
"""
mutable struct PromptingToolsAgent <: BonitoBook.ChatAgent
    book::BonitoBook.Book
    model::String
    system_prompt::String
    mcp_server_url::String
end

"""
    PromptingToolsAgent(book::Book; config::Dict = Dict())

Create a new PromptingTools agent.

# Arguments
- `book`: The Book object this agent is associated with
- `config`: Optional configuration dictionary to override defaults
"""
function PromptingToolsAgent(book::BonitoBook.Book; config::Dict = Dict())
    folder = book.folder

    # Load configuration from TOML file if it exists
    config_path = joinpath(folder, "ai", "config.toml")
    system_prompt_path = joinpath(folder, "ai", "system-prompt.md")

    # Load TOML config if it exists
    toml_config = Dict()
    if isfile(config_path)
        try
            toml_data = TOML.parsefile(config_path)
            # Flatten the nested structure
            for (_, section_data) in toml_data
                if isa(section_data, Dict)
                    for (key, value) in section_data
                        toml_config[key] = value
                    end
                end
            end
        catch e
            @warn "Failed to load TOML config from $config_path: $e"
        end
    end

    # Load system prompt if it exists
    system_prompt = ""
    if isfile(system_prompt_path)
        try
            system_prompt = read(system_prompt_path, String)
        catch e
            @warn "Failed to load system prompt from $system_prompt_path: $e"
        end
    end

    # Get MCP server URL
    mcp_server_url = BonitoBook.get_server_url(book.mcp_server)

    # Add MCP server instructions to system prompt
    mcp_instructions = """

# Julia Code Execution via MCP Server

You have access to a Julia MCP server at $(mcp_server_url) that allows you to execute Julia code directly in the book's environment. Use this for:
- Running calculations and data analysis
- Creating visualizations with Makie.jl
- Testing code snippets
- Accessing variables and functions defined in the book

When executing Julia code, the results will be displayed directly in the chat.
"""

    enhanced_system_prompt = isempty(system_prompt) ? mcp_instructions : system_prompt * mcp_instructions

    # Set default model
    default_model = get(toml_config, "model", get(config, "model", "gpt-4o"))

    return PromptingToolsAgent(
        book,
        default_model,
        enhanced_system_prompt,
        mcp_server_url
    )
end

BonitoBook.create_prompting_tools_agent(book::BonitoBook.Book) = PromptingToolsAgent(book)

"""
    update_model!(agent::PromptingToolsAgent, model::String)

Update the model used by the agent.
"""
function update_model!(agent::PromptingToolsAgent, model::String)
    agent.model = model
    save_config_to_toml(agent)
end

"""
    save_config_to_toml(agent::PromptingToolsAgent)

Save current agent configuration to TOML file.
"""
function save_config_to_toml(agent::PromptingToolsAgent)
    config_path = joinpath(agent.book.folder, "ai", "config.toml")

    # Create directory if it doesn't exist
    mkpath(dirname(config_path))

    # Build TOML structure
    toml_data = Dict{String, Any}()

    # Agent section
    agent_section = Dict{String, Any}(
        "model" => agent.model
    )
    toml_data["agent"] = agent_section

    # Write to file
    try
        open(config_path, "w") do io
            TOML.print(io, toml_data)
        end
        @info "PromptingTools configuration saved to $config_path"
    catch e
        @error "Failed to save configuration to $config_path: $e"
    end
end

# Custom rendering for PromptingTools messages
function Bonito.jsrender(session::Bonito.Session, msg::PromptingTools.AIMessage)
    return Bonito.jsrender(session, Markdown.parse(msg.content))
end

function Bonito.jsrender(session::Bonito.Session, msg::PromptingTools.SystemMessage)
    return Bonito.jsrender(session, BonitoBook.Collapsible("System", msg.content, expanded=false))
end

function Bonito.jsrender(session::Bonito.Session, msg::PromptingTools.UserMessage)
    return Bonito.jsrender(session, Bonito.DOM.div(msg.content))
end

"""
    prompt(agent::PromptingToolsAgent, question::String)

Send a prompt to the PromptingTools agent and return a streaming response.
"""
function BonitoBook.prompt(agent::PromptingToolsAgent, question::String)
    # Create a channel for streaming responses
    response_channel = Channel{Any}(100)

    # Start async task to generate response
    Threads.@spawn begin
        try
            # Use PromptingTools.aigenerate with streaming-like behavior
            # Note: PromptingTools doesn't have native streaming, so we'll simulate it

            # Create conversation with system prompt and user message
            conversation = [
                PromptingTools.SystemMessage(agent.system_prompt),
                PromptingTools.UserMessage(question)
            ]

            # Generate response
            response = PromptingTools.aigenerate(
                conversation;
                model = agent.model,
                return_all = false,
                api_key = ENV["OPENAI_API_KEY"],  # Use environment variable for API key
            )

            # Send the response as markdown
            if isa(response, PromptingTools.AIMessage)
                # Parse and send content in chunks to simulate streaming
                content = response.content
                lines = split(content, '\n')

                for (i, line) in enumerate(lines)
                    if !isempty(strip(line)) || i < length(lines)  # Include empty lines except the last one
                        put!(response_channel, Bonito.DOM.div(line))
                        if i < length(lines)
                            put!(response_channel, Bonito.DOM.br())
                        end
                        sleep(0.01)  # Small delay to simulate streaming
                    end
                end
            else
                put!(response_channel, Bonito.DOM.div("Error: Unexpected response type"))
            end

        catch e
            # Send error message
            error_msg = "Error: $(string(e))"
            put!(response_channel, Bonito.DOM.div(error_msg, style="color: red;"))
        finally
            close(response_channel)
        end
    end

    return response_channel
end

"""
    settings_menu(agent::PromptingToolsAgent)

Returns a Bonito widget for configuring PromptingTools agent settings.
"""
function BonitoBook.settings_menu(agent::PromptingToolsAgent)
    # Model selection - Get available models from PromptingTools
    available_models = [
        "gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo",
        "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", "claude-3-opus-20240229",
        "mistral-large-latest", "mistral-small-latest",
        "gemini-1.5-pro-latest", "gemini-1.5-flash-latest"
    ]

    # Find current model index
    current_index = findfirst(==(agent.model), available_models)
    current_index = current_index !== nothing ? current_index : 1

    # Create model dropdown
    model_dropdown = BonitoBook.Components.Dropdown(available_models; index=current_index)

    # Model section
    model_section = Bonito.DOM.div(
        Bonito.DOM.div("Model:", class="settings-label"),
        Bonito.DOM.div(model_dropdown, class="settings-input"),
        class="settings-row"
    )

    # MCP Server info section
    mcp_info_section = Bonito.DOM.div(
        Bonito.DOM.div("MCP Server:", class="settings-label"),
        Bonito.DOM.div(
            Bonito.DOM.code(agent.mcp_server_url, style="font-size: 11px; color: var(--text-secondary);"),
            class="settings-input"
        ),
        class="settings-row"
    )

    # Edit system prompt button
    edit_prompt_button, edit_prompt_clicks = BonitoBook.SmallButton("edit")
    edit_prompt_section = Bonito.DOM.div(
        Bonito.DOM.div("System Prompt:", class="settings-label"),
        Bonito.DOM.div(edit_prompt_button, class="settings-input"),
        class="settings-row"
    )

    # Apply button
    apply_button, apply_clicks = BonitoBook.SmallButton("check")
    apply_section = Bonito.DOM.div(
        Bonito.DOM.span("Apply Settings"),
        apply_button,
        class="settings-apply-section"
    )

    # Main settings card
    settings_card = Bonito.DOM.div(
        SettingsStyles,
        Bonito.DOM.div(
            Bonito.DOM.h3("PromptingTools Agent Settings", class="settings-title"),
            model_section,
            mcp_info_section,
            edit_prompt_section,
            apply_section
        ),
        class="settings-container"
    )

    # Set up event handlers
    Bonito.on(model_dropdown.value) do selected_model
        update_model!(agent, selected_model)
    end

    Bonito.on(apply_clicks) do _
        save_config_to_toml(agent)
        @info "PromptingTools Agent settings applied successfully!"
    end

    # Handle edit system prompt button
    Bonito.on(edit_prompt_clicks) do _
        system_prompt_path = joinpath(agent.book.folder, "ai", "system-prompt.md")
        BonitoBook.open_file!(BonitoBook.get_file_editor(agent.book), system_prompt_path)
        @info "Opened system prompt in file editor: $system_prompt_path"
    end

    return settings_card
end

# Settings-specific styles (reusing from ClaudeCode extension)
const SettingsStyles = BonitoBook.Styles(
    BonitoBook.CSS(
        ".settings-container",
        "max-width" => "500px",
        "margin" => "0 auto"
    ),
    BonitoBook.CSS(
        ".settings-title",
        "margin-top" => "0",
        "color" => "var(--text-primary)",
        "text-align" => "center",
        "font-size" => "18px",
        "margin-bottom" => "20px"
    ),
    BonitoBook.CSS(
        ".settings-row",
        "display" => "flex",
        "align-items" => "center",
        "margin-bottom" => "16px",
        "gap" => "12px"
    ),
    BonitoBook.CSS(
        ".settings-label",
        "font-size" => "13px",
        "color" => "var(--text-secondary)",
        "min-width" => "140px",
        "text-align" => "left",
        "flex-shrink" => "0"
    ),
    BonitoBook.CSS(
        ".settings-input",
        "flex" => "1",
        "min-width" => "0"
    ),
    BonitoBook.CSS(
        ".settings-apply-section",
        "display" => "flex",
        "align-items" => "center",
        "justify-content" => "center",
        "margin-top" => "20px",
        "gap" => "8px"
    )
)

# Export the agent and helper functions
export PromptingToolsAgent, update_model!, save_config_to_toml

end # module BonitoBookPromptingToolsExt
