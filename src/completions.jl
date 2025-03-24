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

function get_completions(text::String, position::Int, mod::Module)
    completions_list, range_start = REPL.completions(text, position, mod)
    return map(completions_list) do c
        return Dict(
            "kind" => julia_to_monaco_kind(c),
            "insertText" => REPL.completion_text(c),
        )
    end
end
