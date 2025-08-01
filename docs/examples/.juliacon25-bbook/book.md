# Makie Mentions at JuliaCon

```julia
using HTTP, JSON

function get_subtitle_url(video_url::String)
    try
        # Get video info including subtitle URLs
        cmd = `yt-dlp --list-subs --print-json $video_url`
        output = read(cmd, String)

        # Parse each line as JSON (yt-dlp outputs one JSON per line for this command)
        for line in split(strip(output), '\n')
            if !isempty(line)
                try
                    info = JSON.parse(line)
                    if haskey(info, "automatic_captions") && haskey(info["automatic_captions"], "en")
                        # Get the first available English subtitle format
                        en_subs = info["automatic_captions"]["en"]
                        for sub in en_subs
                            if haskey(sub, "url") && (haskey(sub, "ext") && sub["ext"] == "vtt")
                                return sub["url"]
                            end
                        end
                    end
                catch json_error
                    continue
                end
            end
        end
    catch e
        println("Error getting subtitle URL: $e")
    end
    return nothing
end
function parse_vtt_content(vtt_content::String)
    lines = split(vtt_content, '\n')
    entries = []

    i = 1
    while i <= length(lines)
        line = strip(lines[i])

        # Look for timestamp lines (format: 00:00:00.000 --> 00:00:00.000)
        if occursin("-->", line)
            timestamp_match = match(r"(\d{2}):(\d{2}):(\d{2})\.(\d{3})", line)
            if timestamp_match !== nothing
                hours, minutes, seconds, milliseconds = parse.(Int, timestamp_match.captures)
                start_time = hours * 3600 + minutes * 60 + seconds + milliseconds / 1000

                # Get the text (next non-empty line)
                i += 1
                text_lines = String[]
                while i <= length(lines) && !isempty(strip(lines[i]))
                    push!(text_lines, strip(lines[i]))
                    i += 1
                end

                if !isempty(text_lines)
                    text = join(text_lines, " ")
                    # Clean up HTML tags and formatting
                    text = replace(text, r"<[^>]*>" => "")
                    push!(entries, Dict("start" => start_time, "text" => text))
                end
            end
        end
        i += 1
    end

    return entries
end
function fetch_and_parse_subtitles(video_url::String)
    subtitle_url = get_subtitle_url(video_url)

    if subtitle_url === nothing
        println("No subtitle URL found")
        return nothing
    end

    try
        response = HTTP.get(subtitle_url)
        vtt_content = String(response.body)
        return parse_vtt_content(vtt_content)
    catch e
        println("Error fetching subtitles: $e")
        return nothing
    end
end

```

```julia
video_url = "https://youtu.be/C-mmHWjG_sY"
subtitles = fetch_and_parse_subtitles(video_url)
```

```julia

makie_mentions = []
for entry in subtitles
    if occursin("Makie", entry["text"])
        push!(makie_mentions, entry)
    end
end
makie_mentions

subtitles[1]["text"]
```

