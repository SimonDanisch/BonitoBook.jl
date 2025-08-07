
mutable struct RedirectTarget
    lock::ReentrantLock
    observable::Observable{String}
end

RedirectTarget() = RedirectTarget(ReentrantLock(), Observable(""))

const REDIRECT_TARGET = Base.RefValue{RedirectTarget}()

function Base.write(target::RedirectTarget, bytes::AbstractVector{UInt8})
    lock(target.lock) do
        if !isempty(bytes)
            printer = HTMLPrinter(IOBuffer(bytes); root_tag = "span")
            str = sprint(io -> show(io, MIME"text/html"(), printer))
            target.observable[] = str
        end
    end
end

function Base.setindex!(target::RedirectTarget, obs::Observable{String})
    lock(target.lock) do
        target.observable = obs
    end
end

# Taken from IOCapture.jl, adpated to our needs!
function redirect_all_to_channel()
    # Needs to be singleton, since we can only redirect one time
    if isassigned(REDIRECT_TARGET)
        return REDIRECT_TARGET[]
    end
    # Original implementation from Documenter.jl (MIT license)
    # Save the default output streams.
    default_stdout = stdout
    default_stderr = stderr
    # Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    pe_stdout = IOContext(pipe.in, :color => true)
    pe_stderr = IOContext(pipe.in, :color => true)
    redirect_stdout(pe_stdout)
    redirect_stderr(pe_stderr)
    # Also redirect logging stream to the same pipe
    logger = Logging.ConsoleLogger(pe_stderr)
    Logging.global_logger(logger)
    # Bytes written to the `pipe` are captured in `output` and eventually converted to a
    # `String`. We need to use an asynchronous task to continously tranfer bytes from the
    # pipe to `output` in order to avoid the buffer filling up and stalling write() calls in
    # user code.
    redirect_target = RedirectTarget()

    Threads.@spawn begin
        while !eof(pipe)
            data = copy(readavailable(pipe))
            write(default_stdout, data)
            write(redirect_target, data)
        end
        # Clean up after channel is closed
        redirect_stdout(default_stdout)
        redirect_stderr(default_stderr)
    end
    REDIRECT_TARGET[] = redirect_target
    return redirect_target
end
