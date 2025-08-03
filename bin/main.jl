using BonitoBook, Bonito

proxy = get(ENV, "JULIAHUB_APP_URL", "")
if isempty(proxy)
    @info "No Bonito proxy found in environment variable JULIAHUB_APP_URL"
else
    @info "Using Bonito proxy from JULIAHUB_APP_URL: $proxy"
end
port = get(ENV, "PORT", "8080") # it's guaranteed this exists on JuliaHub
@info "Constructing Bonito server on 0.0.0.0:$port $(isempty(proxy) ? "" : "with proxy $proxy")"
server = Bonito.Server("0.0.0.0", parse(Int, port); proxy_url=proxy, verbose=-1)
path = joinpath(@__DIR__, "..", "docs", "examples", "intro.md")
app = Bonito.App() do
    return BonitoBook.Book(path)
end;
route!(server, "/" => app)

# Wait for the server to exit, because if running in an app, the app will
# exit when the script is done.  This makes sure that the app is only closed
# if (a) the server closes, or (b) the app itself times out and is killed externally.
wait(server)
