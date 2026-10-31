function invoke_julia_c(project, file)
    cmd = Base.julia_cmd()
    run(`$cmd --project=$project  `)

end
function compile_notebook(book::Book)
    """
    Compile the notebook to a Julia script.

    This function compiles the notebook to a Julia script, which can be used for further processing or execution.
    """
    return book.compile()
end
