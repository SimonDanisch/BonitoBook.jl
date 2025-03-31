const REDIRECT_CHANNEL = Base.RefValue{Channel{Vector{UInt8}}}()

# Taken from IOCapture.jl, adpated to our needs!
function redirect_all_to_channel()
    # Needs to be singleton, since we can only redirect one time
    if isassigned(REDIRECT_CHANNEL) && isopen(REDIRECT_CHANNEL[])
        return REDIRECT_CHANNEL[]
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
    capture_channel = Channel{Vector{UInt8}}(Inf; spawn = true) do chan
        while !eof(pipe) && isopen(chan)
            data = readavailable(pipe)
            put!(chan, copy(data))
            write(default_stdout, data)
        end
        # Clean up after channel is closed
        redirect_stdout(default_stdout)
        redirect_stderr(default_stderr)
    end
    REDIRECT_CHANNEL[] = capture_channel
    return capture_channel
end
