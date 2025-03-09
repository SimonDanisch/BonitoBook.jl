using OpenAI

function ask_chat!(prompt, history)
    push!(history, Dict("role" => "user", "content" => prompt))
    message = OpenAI.create_chat(ENV["OPENAI_API_KEY"], "gpt-4-turbo", history).response[:choices][begin][:message][:content]
    return message
end

function create_chat()
    system = read("system-prompt.md", String)
    history = [Dict("role" => "system", "content" => system)]
    return history
end
