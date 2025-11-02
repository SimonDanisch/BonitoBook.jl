"""
Julia code execution sanitizer for LLMChat.

Prevents potentially dangerous operations like:
- Package operations (Pkg.add, using new packages)
- File system operations (unless explicitly allowed)
- Including other files
- Modifying global environment

Provides helpful error messages to guide users toward safe alternatives.
"""

"""
    SanitizerConfig

Configuration for code sanitization.

# Fields
- `allow_pkg_operations::Bool`: Allow Pkg.add, Pkg.rm, etc. (default: false)
- `allow_file_operations::Bool`: Allow file I/O operations (default: false)
- `allow_include::Bool`: Allow include() calls (default: false)
- `max_output_lines::Int`: Maximum lines of output (default: 1000)
- `blocked_patterns::Vector{Regex}`: Additional regex patterns to block
"""
struct SanitizerConfig
    allow_pkg_operations::Bool
    allow_file_operations::Bool
    allow_include::Bool
    max_output_lines::Int
    blocked_patterns::Vector{Regex}
end

function SanitizerConfig(;
    allow_pkg_operations=false,
    allow_file_operations=false,
    allow_include=false,
    max_output_lines=1000,
    blocked_patterns=Regex[]
)
    return SanitizerConfig(
        allow_pkg_operations,
        allow_file_operations,
        allow_include,
        max_output_lines,
        blocked_patterns
    )
end

"""
    SanitizerViolation

Represents a code sanitization violation.

# Fields
- `pattern::String`: The pattern that was matched
- `message::String`: User-friendly error message
- `suggestion::String`: Suggested alternative approach
"""
struct SanitizerViolation
    pattern::String
    message::String
    suggestion::String
end

"""
    check_code_safety(code::String, config::SanitizerConfig)

Check if code is safe to execute according to the sanitizer config.
Returns `nothing` if safe, or a `SanitizerViolation` if unsafe.
"""
function check_code_safety(code::String, config::SanitizerConfig)
    # Check for package operations
    if !config.allow_pkg_operations
        pkg_patterns = [
            r"\bPkg\s*\.\s*add\b" => (
                "Package installation (Pkg.add) is not allowed in LLM-generated code.",
                "Ask the user to install packages manually. You can check with Pkg.status() what is installed."
            ),
            r"\bPkg\s*\.\s*rm\b" => (
                "Package removal (Pkg.rm) is not allowed in LLM-generated code.",
                "Ask the user to remove packages manually."
            ),
            r"\bPkg\s*\.\s*update\b" => (
                "Package updates (Pkg.update) are not allowed in LLM-generated code.",
                "Ask the user to update packages manually."
            ),
        ]

        for (pattern, (message, suggestion)) in pkg_patterns
            if occursin(pattern, code)
                return SanitizerViolation(string(pattern), message, suggestion)
            end
        end
    end

    # Check for file operations
    if !config.allow_file_operations
        file_patterns = [
            r"\b(?:open|write|read|cp|mv|rm|mkdir|readdir|walkdir)\s*\(" => (
                "Direct file operations are not allowed in LLM-generated code.",
                "Use the FileReadTool, FileWriteTool, FileEditTool, or FileTool instead."
            ),
            r"\bBase\s*\.\s*Filesystem\s*\." => (
                "Direct file system operations are not allowed in LLM-generated code.",
                "Use the provided file tools (FileReadTool, FileWriteTool, etc.) instead."
            ),
        ]

        for (pattern, (message, suggestion)) in file_patterns
            if occursin(pattern, code)
                return SanitizerViolation(string(pattern), message, suggestion)
            end
        end
    end

    # Check for include
    if !config.allow_include
        if occursin(r"\binclude\s*\(", code)
            return SanitizerViolation(
                "include()",
                "Including external files is not allowed in LLM-generated code.",
                "Copy the needed code into the notebook or use FileReadTool to read the file content."
            )
        end
    end

    # Check custom blocked patterns
    for pattern in config.blocked_patterns
        if occursin(pattern, code)
            return SanitizerViolation(
                string(pattern),
                "This code pattern is blocked by custom sanitizer rules.",
                "Review the sanitizer configuration or ask the user for permission."
            )
        end
    end

    return nothing  # Code is safe
end

"""
    sanitize_output(output::String, max_lines::Int)

Truncate output to a maximum number of lines.
"""
function sanitize_output(output::String, max_lines::Int)
    lines = split(output, '\n')

    if length(lines) <= max_lines
        return output
    end

    # Keep first max_lines-5 and last 5 lines
    keep_start = max_lines - 10
    truncated_lines = vcat(
        lines[1:keep_start],
        ["", "... [$(length(lines) - max_lines) lines omitted] ...", ""],
        lines[end-4:end]
    )

    return join(truncated_lines, '\n')
end

"""
    format_violation_error(violation::SanitizerViolation, code::String="")

Format a sanitizer violation as a user-friendly error message.
Optionally includes the blocked code as a markdown code block.
"""
function format_violation_error(violation::SanitizerViolation, code::String="")
    error_msg = """
    ⚠️  Code Sanitization Error

    $(violation.message)

    💡 Suggestion:
    $(violation.suggestion)

    🔍 Matched pattern: $(violation.pattern)
    """

    if !isempty(code)
        error_msg *= "\n\n📝 Blocked code:\n```julia\n$(code)\n```"
    end

    return error_msg
end
