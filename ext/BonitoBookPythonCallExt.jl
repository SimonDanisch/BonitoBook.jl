module BonitoBookPythonCallExt

using BonitoBook
using PythonCall
using CondaPkg

"""
    PythonEval <: LanguageEval

Python code evaluator using PythonCall.
"""
mutable struct PythonEval <: BonitoBook.LanguageEval
    globals::Py
    locals::Py
    eval_function::Base.RefValue{Union{Py, Nothing}}

    function PythonEval()
        task = BonitoBook.spawnat(1) do
            return new(PythonCall.pydict(), PythonCall.pydict(), Base.RefValue{Union{Py, Nothing}}(nothing))

        end
        return fetch(task)
    end
end

"""
    get_python_eval_function(evaluator::PythonEval)

Get or create the Python evaluation function.
"""
function get_python_eval_function(evaluator::PythonEval)
    if isnothing(evaluator.eval_function[])
        pyexec(
            """
            import ast
            import textwrap

            def eval_python_code(source, globals_dict, locals_dict):
                tree = ast.parse(source, mode="exec")
                body = tree.body
                n = len(body)
                if n == 0:
                    return None

                exprs = body[:-1]
                last_stmt = body[-1]

                if exprs:
                    init_code = textwrap.dedent("\\n".join(ast.unparse(stmt) for stmt in exprs))
                    exec(init_code, globals_dict, locals_dict)

                if isinstance(last_stmt, ast.Expr):
                    tail_expr = ast.unparse(last_stmt.value)
                    return eval(tail_expr, globals_dict, locals_dict)
                else:
                    full_code = textwrap.dedent(source)
                    exec(full_code, globals_dict, locals_dict)
                    return None
            """, Main
        )
        evaluator.eval_function[] = pyeval("eval_python_code", Main)
    end
    return evaluator.eval_function[]
end

"""
    transfer_python_vars(python_dict::Py, julia_module, var_type::String)

Transfer variables from Python namespace to Julia module.
"""
function transfer_python_vars(python_dict::Py, julia_module, var_type::String)
    jl_dict = pyconvert(Dict, python_dict)
    for key in keys(jl_dict)
        key_str = string(key)
        if !startswith(key_str, "_")  # Skip private variables
            julia_symbol = Symbol(key_str)
            if !hasproperty(julia_module, julia_symbol)
                try
                    value = jl_dict[key]
                    @eval julia_module $julia_symbol = $value
                catch e
                    @warn "Could not transfer Python $var_type variable $key_str to Julia: " e
                end
            end
        end
    end
    return
end

"""
    eval_code(evaluator::PythonEval, mod::Module, file::String, line::Int, source::String)

Evaluate Python code using PythonCall.
"""
function BonitoBook.eval_code(evaluator::PythonEval, mod::Module, ::String, ::Int, source::String)
    if startswith(source, "]add ")
        # Special handling for conda package installation
        packages = split(replace(source, "]add " => ""), " ")
        CondaPkg.add(packages)
        return nothing
    else
        eval_py = get_python_eval_function(evaluator)
        result = eval_py(source, evaluator.globals, evaluator.locals)
        transfer_python_vars(evaluator.globals, mod, "global")
        transfer_python_vars(evaluator.locals, mod, "local")
        return result
    end
end

"""
Get language evaluator for Python when this extension is loaded.
"""
function get_language_evaluator()
    return PythonEval()
end

end # module BonitoBookPythonCallExt
