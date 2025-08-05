# Makie Mentions at JuliaCon

One save data to `./data/**`, which will get packaged into the Books zip format, to be fully reproducable and allow caching. In this notebook, we cache the video downloads and thumbnails into the data folder, to be able to run this notebook many times, without the many minutes of downloading and unpacking the preview thumbnails.

```julia (editor=true, logging=false, output=true)
urls = [
    "https://www.youtube.com/watch?v=yh3ZuJH3I20",
    "https://www.youtube.com/watch?v=fzrUDmM_ris",
    "https://www.youtube.com/watch?v=1NjovGpDbFk",
    "https://www.youtube.com/watch?v=Msm2qHsYZRg",
    "https://www.youtube.com/watch?v=G_DLBmO1EGM",
    "https://www.youtube.com/watch?v=C-mmHWjG_sY",
    "https://www.youtube.com/watch?v=HMdBi9Lrbes",
    "https://www.youtube.com/watch?v=3o0lAXCa9Wg",
    "https://www.youtube.com/watch?v=eernjfj1nHA",
    "https://www.youtube.com/watch?v=ZjcfHooWmb0",
    "https://www.youtube.com/watch?v=5vllhdzecJM",
    "https://www.youtube.com/watch?v=2KbMQyklVaE",
    "https://www.youtube.com/watch?v=oeYhwagpI98",
    "https://www.youtube.com/watch?v=_Uf2KQXtPNg",
    "https://www.youtube.com/watch?v=33rxNE4e50A",
    "https://www.youtube.com/watch?v=WhwSpXLyNaA",
    "https://www.youtube.com/watch?v=-1ZkdVs2zko",
    "https://www.youtube.com/watch?v=9JWnu5ecET8",
    "https://www.youtube.com/watch?v=0YszUgzh7is"
]

```
```julia (editor=true, logging=false, output=true)
# Simple YouTube ID extraction function
using HTTP, JSON

function get_subtitle_url(video_url::String)
    try
        # Get video info including subtitle URLs
        cmd = `yt-dlp.exe --list-subs --print-json $video_url`
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

function extract_youtube_id(url::String)
    """
    Extract YouTube video ID from URL format: https://www.youtube.com/watch?v=VIDEO_ID
    """
    pattern = r"https://www\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})"
    match_result = match(pattern, url)

    if match_result !== nothing
        return match_result.captures[1]
    else
        return nothing
    end
end
subtitles = map(urls) do url
    id = extract_youtube_id(url)
    path = "./data/subtitles-$(id).json"
    if !isfile(path)
        subtitles = fetch_and_parse_subtitles(url)
        open(path, "w") do io
            JSON.print(io, subtitles)
        end
    end
    subs = open(path, "r") do io
        JSON.parse(io)
    end
    return subs
end
length(subtitles)
```
```julia (editor=true, logging=false, output=true)
using Printf, SHA, FFMPEG_jll
function download_video(video_url)
    """Download video and return local path, downloading only once per video."""
    video_id = extract_youtube_id(video_url)

    # Create hash for video caching
    video_cache_key = bytes2hex(sha256(video_id))
    video_path = "./data/videos/$video_cache_key.mp4"

    # Create videos directory if it doesn't exist
    mkpath("./data/videos")

    # Return cached video if it exists
    if isfile(video_path)
        return video_path
    end

    # Download video using yt-dlp
    try
        cmd = `yt-dlp --format "best[height<=720]" --output "$video_path" "$video_url"`
        run(cmd)

        if isfile(video_path)
            return video_path
        end
    catch e
        println("Failed to download video: $e")
        return nothing
    end

    return nothing
end

function grab_thumbnail(video_url, timestamp)
    """Extract thumbnail from video at specified timestamp using FFMPEG_jll."""
    video_id = extract_youtube_id(video_url)

    # Create hash for thumbnail caching
    cache_key = bytes2hex(sha256("$video_id-$timestamp"))
    thumb_path = "./data/thumbs/$cache_key.jpg"

    # Create thumbs directory if it doesn't exist
    mkpath("./data/thumbs")

    # Return cached thumbnail if it exists
    if isfile(thumb_path)
        return thumb_path
    end

    # Download video (will use cached version if available)
    video_path = download_video(video_url)
    if video_path === nothing
        println("Could not download video")
        return nothing
    end

    # Convert timestamp to HH:MM:SS format for ffmpeg
    hours = floor(Int, timestamp / 3600)
    mins = floor(Int, (timestamp % 3600) / 60)
    secs = timestamp % 60  # Keep fractional seconds
    time_str = @sprintf("%02d:%02d:%06.3f", hours, mins, secs)

    # Use FFMPEG_jll to extract frame at timestamp
    try
        FFMPEG_jll.ffmpeg() do ffmpeg
            cmd = `$ffmpeg -ss $time_str -i "$video_path" -frames:v 1 -q:v 2 -y "$thumb_path"`
            run(cmd)
        end

        if isfile(thumb_path)
            return thumb_path
        end
    catch e
        println("Failed to extract thumbnail with FFMPEG_jll: $e")
    end

    return nothing
end
function format_time(seconds)
    hours = floor(Int, seconds / 3600)
    mins = floor(Int, (seconds % 3600) / 60)
    secs = floor(Int, seconds % 60)
    if hours > 0
        return "$(hours)h$(mins)m$(secs)s"
    else
        return "$(mins)m$(secs)s"
    end
end

function create_youtube_link(video_id, start_time)
    return "https://www.youtube.com/watch?v=$(video_id)&t=$(floor(Int, start_time))s"
end

function visualize_mentions_with_thumbnails(mentions)
    mention_items = []

    for (entry, url) in mentions
        video_id = extract_youtube_id(url)
        video_index = findfirst(u -> u == url, urls)

        time_str = format_time(entry["start"])
        link = create_youtube_link(video_id, entry["start"])
        text = entry["text"]

        # Get thumbnail for this timestamp
        thumb_path = grab_thumbnail(url, entry["start"])

        push!(mention_items, DOM.div(
            class="flex-row gap-10",
            style="padding: 8px; border-bottom: 1px solid var(--border-primary); align-items: flex-start;",

            # Thumbnail
            DOM.div(
                class="inline-block",
                style="min-width: 120px; flex-shrink: 0;",
                if thumb_path !== nothing
                    DOM.a(
                        DOM.img(
                            src=Asset(thumb_path),
                            style="width: 120px; height: 68px; object-fit: cover; border-radius: 4px; border: 1px solid var(--border-primary);"
                        ),
                        href=link,
                        target="_blank",
                        style="display: block; text-decoration: none;"
                    )
                else
                    DOM.div(
                        style="width: 120px; height: 68px; background-color: var(--hover-bg); border-radius: 4px; border: 1px solid var(--border-primary); display: flex; align-items: center; justify-content: center; color: var(--text-secondary); font-size: 12px;",
                        "No thumbnail"
                    )
                end
            ),

            # Content
            DOM.div(
                class="flex-column",
                style="flex: 1; min-width: 0;",
                DOM.div(
                    class="inline-block",
                    style="color: var(--text-secondary); font-size: 12px; font-family: monospace; margin-bottom: 4px;",
                    "📺 $video_index • $time_str"
                ),
                DOM.a(
                    text,
                    href=link,
                    target="_blank",
                    style="color: var(--text-primary); font-size: 13px; text-decoration: none; line-height: 1.4; word-wrap: break-word; cursor: pointer; display: block;",
                    onmouseover="this.style.color = 'var(--accent-blue)'",
                    onmouseout="this.style.color = 'var(--text-primary)'"
                )
            )
        ))
    end

    return DOM.div(
        class="max-width-90ch",
        style="border: 1px solid var(--border-primary); border-radius: 8px; background-color: var(--bg-primary);",
        DOM.div(
            style="padding: 12px; border-bottom: 1px solid var(--border-primary); background-color: var(--hover-bg);",
            DOM.h4(
                "Mentions with Thumbnails $(length(mention_items)) found",
                style="margin: 0; color: var(--text-primary); font-size: 14px;"
            )
        ),
        DOM.div(
            style="max-height: 500px; overflow-y: auto;",
            mention_items...
        )
    )
end

function find_mentions_with_thumbnails(regex)
    mentions = []
    for (url, subs) in zip(urls, subtitles)
        for entry in subs
            text = lowercase(entry["text"])
            matches = match(regex, text)
            if !isnothing(matches)
                push!(mentions, (entry, url))
            end
        end
    end
    return visualize_mentions_with_thumbnails(mentions)
end
```
```julia (editor=true, logging=false, output=true)
find_mentions_with_thumbnails(r"\b(makia|makitech|maki|makie|macki|mackie)\b")
```
```julia (editor=true, logging=false, output=true)
find_mentions_with_thumbnails(r"\b(plotting|plots|plot|visualization)\b")
```
