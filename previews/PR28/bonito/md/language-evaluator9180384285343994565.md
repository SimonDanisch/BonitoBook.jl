# How to Create a Language Evaluator

Add support for new programming languages in BonitoBook by creating a custom language evaluator.

## Implementation

Create an extension module that defines:

1. **Evaluator struct** inheriting from `LanguageEval`
2. **eval_code method** that executes code
3. **get*language*evaluator function** that returns the evaluator

## Example: Shell Evaluator

```julia
# ext/BonitoBookShellExt.jl
module BonitoBookShellExt

using BonitoBook

struct ShellEval <: BonitoBook.LanguageEval end

function BonitoBook.eval_code(::ShellEval, mod::Module, file::String, line::Int, source::String)
    result = read(`bash -c $source`, String)
    return result
end

function get_language_evaluator()
    return ShellEval()
end

end # module
```

## Register Language

Add your language to `ALL_LANGUAGES` in `src/BonitoBook.jl`:

```julia
const ALL_LANGUAGES = Dict(
    "julia" => (icon = "julia-logo", always_available = true, activation_help = "", extension_module = nothing),
    "python" => (icon = "python-logo", always_available = false, activation_help = "Install PythonCall.jl", extension_module = :BonitoBookPythonCallExt),
    "shell" => (icon = "terminal", always_available = false, activation_help = "Enable shell extension", extension_module = :BonitoBookShellExt)
)
```

## Real Example: Python

The Python evaluator shows the full pattern:

```julia
mutable struct PythonEval <: BonitoBook.LanguageEval
    globals::Py
    locals::Py
    eval_function::Base.RefValue{Union{Py, Nothing}}
end

function BonitoBook.eval_code(evaluator::PythonEval, mod::Module, ::String, ::Int, source::String)
    eval_py = get_python_eval_function(evaluator)
    result = eval_py(source, evaluator.globals, evaluator.locals)
    # Transfer Python variables to Julia module
    transfer_python_vars(evaluator.globals, mod, "global")
    return result
end
```

## Key Points

  * **Extension loading**: BonitoBook uses `Base.get_extension()` to load evaluators
  * **Thread safety**: Code runs in `spawnat(1)` for thread safety (e.g. for PythonCall)
  * **Variable sharing**: Transfer variables between language and Julia using the `mod` parameter
  * **Error handling**: Wrap execution in try-catch, BonitoBook handles display

That's it! The `AsyncRunner` handles the rest automatically.

