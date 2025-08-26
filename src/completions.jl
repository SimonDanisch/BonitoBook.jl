using REPL

function julia_to_monaco_kind(completion)
    if completion isa REPL.REPLCompletions.BslashCompletion
        return 17  # Keyword
    elseif completion isa REPL.REPLCompletions.DictCompletion
        return 7   # Class
    elseif completion isa REPL.REPLCompletions.FieldCompletion
        return 5   # Field
    elseif completion isa REPL.REPLCompletions.KeyvalCompletion
        return 10  # Property
    elseif completion isa REPL.REPLCompletions.KeywordArgumentCompletion
        return 10  # Property
    elseif completion isa REPL.REPLCompletions.KeywordCompletion
        return 17  # Keyword
    elseif completion isa REPL.REPLCompletions.MethodCompletion
        return 1   # Function
    elseif completion isa REPL.REPLCompletions.ModuleCompletion
        return 9   # Module
    elseif completion isa REPL.REPLCompletions.PackageCompletion
        return 9   # Module
    elseif completion isa REPL.REPLCompletions.PathCompletion
        return 16  # File
    elseif completion isa REPL.REPLCompletions.PropertyCompletion
        return 10  # Property
    elseif completion isa REPL.REPLCompletions.ShellCompletion
        return 18  # Text
    elseif completion isa REPL.REPLCompletions.TextCompletion
        return 18  # Text
    else
        return 18  # Default to Text
    end
end


function insert_text(completion, mod)
    text = REPL.REPLCompletions.completion_text(completion)
    if completion isa REPL.REPLCompletions.BslashCompletion
        completions_list, _, _ = REPL.completions(text, length(text), mod)
        return REPL.REPLCompletions.completion_text(completions_list[1])
    else
        return REPL.REPLCompletions.completion_text(completion)
    end
end

function display_text(completion)
    return REPL.REPLCompletions.completion_text(completion)
end

function get_completions(text::String, position::Int, mod::Module)
    @show text position
    completions_list, range_start = REPL.completions(text, position, mod)
    return map(completions_list) do c
        return Dict(
            "kind" => julia_to_monaco_kind(c),
            "insertText" => insert_text(c, mod),
            "label" => display_text(c),
        )
    end
end
