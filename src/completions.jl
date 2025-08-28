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

replace_dict_compl(text) = replace(text, r"\"(.*)\"]" => s"\1")

function insert_text(completion, mod, context_text="")
    text = REPL.REPLCompletions.completion_text(completion)
    if completion isa REPL.REPLCompletions.BslashCompletion
        completions_list, _, _ = REPL.completions(text, length(text), mod)
        return REPL.REPLCompletions.completion_text(completions_list[1])
    elseif completion isa REPL.REPLCompletions.DictCompletion
        texto = REPL.REPLCompletions.completion_text(completion)
        # Check if Monaco already auto-inserted quotes and brackets
        if endswith(context_text, "[\"") && contains(texto, "\"]")
            # If we have dict[" and completion is "key"], just return key
            return replace_dict_compl(texto)
        elseif endswith(context_text, "[") && contains(texto, "\"]")
            # If we have dict[ and completion is "key"], return "key" (keep quotes)
            return replace(texto, r"\]$" => "")
        else
            return replace_dict_compl(texto)
        end
    else
        return REPL.REPLCompletions.completion_text(completion)
    end
end

function display_text(completion)
    texto = REPL.REPLCompletions.completion_text(completion)
    if completion isa REPL.REPLCompletions.DictCompletion
        return replace_dict_compl(texto)
    else
        return texto
    end
end

function get_completions(text::String, position::Int, mod::Module)
    completions_list, range_start = REPL.completions(text, position, mod)
    return map(completions_list) do c
        return Dict(
            "kind" => julia_to_monaco_kind(c),
            "insertText" => insert_text(c, mod, text),
            "label" => display_text(c),
        )
    end
end
