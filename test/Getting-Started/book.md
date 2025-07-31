# BonitoBook

Features of BonitBook

```julia false false true
using Makie
using Gumbo

# Define structures for different SVG elements
abstract type SVGElement end

struct PathElement <: SVGElement
    d::String
    stroke::String
    fill::String
    stroke_width::Float64
end

struct LineElement <: SVGElement
    x1::Float64
    y1::Float64
    x2::Float64
    y2::Float64
    stroke::String
    stroke_width::Float64
end

struct PolygonElement <: SVGElement
    points::Vector{Tuple{Float64, Float64}}
    stroke::String
    fill::String
    stroke_width::Float64
end

struct TextElement <: SVGElement
    x::Float64
    y::Float64
    text::String
    font_size::Float64
    fill::String
end

struct SVGInfo
    width::Float64
    height::Float64
    viewbox::Tuple{Float64, Float64, Float64, Float64}  # x, y, width, height
end

# Parse SVG path data (handles M, L, V, H, Z commands)
function parse_path_data(d::String)
    points = Vector{Tuple{Float64, Float64}}()
    
    if isempty(d)
        return points
    end
    
    # Clean the path string - replace multiple spaces and commas with single spaces
    d = replace(d, r"[,\s]+" => " ")
    d = replace(d, r"([MLVHZmlvhz])" => s" \1 ")
    d = strip(d)
    
    tokens = split(d)
    i = 1
    current_pos = (0.0, 0.0)
    current_command = ""
    path_start = (0.0, 0.0)
    
    while i <= length(tokens)
        token = tokens[i]
        
        if occursin(r"^[MLVHZmlvhz]$", token)
            current_command = uppercase(token)
            i += 1
            continue
        end
        
        # Try to parse as number - if successful, use current command
        try
            num = parse(Float64, token)
            
            # Parse coordinates based on current command
            if current_command in ["M", "L"]
                if i + 1 <= length(tokens)
                    try
                        x = num
                        y = parse(Float64, tokens[i+1])
                        current_pos = (x, y)
                        push!(points, current_pos)
                        
                        # If this was a Move command, remember start position
                        if current_command == "M"
                            path_start = current_pos
                            current_command = "L"  # Subsequent coordinates are linetos
                        end
                        
                        i += 2
                    catch
                        i += 1
                    end
                else
                    i += 1
                end
            elseif current_command == "V"
                y = num
                current_pos = (current_pos[1], y)
                push!(points, current_pos)
                i += 1
            elseif current_command == "H"
                x = num
                current_pos = (x, current_pos[2])
                push!(points, current_pos)
                i += 1
            else
                # Unknown command or no command set
                i += 1
            end
        catch
            if current_command == "Z"
                # Close path - connect back to start
                if !isempty(points) && points[end] != path_start
                    push!(points, path_start)
                end
                i += 1
            else
                # Skip unknown tokens
                i += 1
            end
        end
    end
    
    return points
end

# Parse SVG polygon/polyline points
function parse_points(points_str::String)
    coords = parse.(Float64, split(replace(points_str, "," => " ")))
    points = Vector{Tuple{Float64, Float64}}()
    for i in 1:2:length(coords)-1
        push!(points, (coords[i], coords[i+1]))
    end
    return points
end

# Parse color string (simplified)
function parse_color(color_str::String)
    if color_str == "none" || color_str == ""
        return :transparent
    elseif startswith(color_str, "#")
        return color_str
    else
        return Symbol(color_str)
    end
end

# Extract SVG elements and info from parsed HTML
function extract_svg_elements(parsed_svg)
    elements = SVGElement[]
    svg_info = SVGInfo(400.0, 300.0, (0.0, 0.0, 400.0, 300.0))  # defaults

    function traverse_node(node)
        if isa(node, HTMLElement)
            tag_name = lowercase(string(tag(node)))
            attrs = node.attributes

            if tag_name == "svg"
                # Extract SVG dimensions and viewBox
                width_str = get(attrs, "width", "400")
                height_str = get(attrs, "height", "300")
                viewbox_str = get(attrs, "viewBox", "0 0 400 300")
                
                # Parse dimensions (remove 'pt' suffix if present)
                width = parse(Float64, replace(width_str, "pt" => ""))
                height = parse(Float64, replace(height_str, "pt" => ""))
                
                # Parse viewBox
                viewbox_parts = parse.(Float64, split(viewbox_str))
                if length(viewbox_parts) >= 4
                    viewbox = (viewbox_parts[1], viewbox_parts[2], viewbox_parts[3], viewbox_parts[4])
                else
                    viewbox = (0.0, 0.0, width, height)
                end
                
                svg_info = SVGInfo(width, height, viewbox)
                
            elseif tag_name == "path"
                d = get(attrs, "d", "")
                stroke = get(attrs, "stroke", "black")
                fill = get(attrs, "fill", "none")
                stroke_width = parse(Float64, get(attrs, "stroke-width", "1"))
                push!(elements, PathElement(d, stroke, fill, stroke_width))

            elseif tag_name == "line"
                x1 = parse(Float64, get(attrs, "x1", "0"))
                y1 = parse(Float64, get(attrs, "y1", "0"))
                x2 = parse(Float64, get(attrs, "x2", "0"))
                y2 = parse(Float64, get(attrs, "y2", "0"))
                stroke = get(attrs, "stroke", "black")
                stroke_width = parse(Float64, get(attrs, "stroke-width", "1"))
                push!(elements, LineElement(x1, y1, x2, y2, stroke, stroke_width))

            elseif tag_name in ["polygon", "polyline"]
                points_str = get(attrs, "points", "")
                if !isempty(points_str)
                    points = parse_points(points_str)
                    stroke = get(attrs, "stroke", "black")
                    fill = tag_name == "polygon" ? get(attrs, "fill", "lightgray") : "none"
                    stroke_width = parse(Float64, get(attrs, "stroke-width", "1"))
                    push!(elements, PolygonElement(points, stroke, fill, stroke_width))
                end
                
            elseif tag_name == "text"
                x = parse(Float64, get(attrs, "x", "0"))
                y = parse(Float64, get(attrs, "y", "0"))
                font_size = parse(Float64, get(attrs, "font-size", "12"))
                fill = get(attrs, "fill", "black")
                # Get text content
                text_content = ""
                for child in node.children
                    if isa(child, HTMLText)
                        text_content *= child.text
                    end
                end
                if !isempty(text_content)
                    push!(elements, TextElement(x, y, text_content, font_size, fill))
                end
            end

            # Recursively process children
            for child in node.children
                traverse_node(child)
            end
        end
    end

    # Start traversal from the root document
    if isa(parsed_svg, HTMLDocument)
        traverse_node(parsed_svg.root)
    else
        traverse_node(parsed_svg)
    end
    return elements, svg_info
end

# Transform coordinates from SVG to Makie coordinate system
function transform_coordinates(points, svg_info::SVGInfo)
    # SVG: (0,0) at top-left, Y increases downward
    # Makie: (0,0) at bottom-left, Y increases upward
    viewbox_height = svg_info.viewbox[4]
    
    return [(p[1], viewbox_height - p[2]) for p in points]
end

function transform_coordinate(x, y, svg_info::SVGInfo)
    viewbox_height = svg_info.viewbox[4]
    return (x, viewbox_height - y)
end

# Convert SVG elements to Makie plots
function plot_svg_element!(ax, element::PathElement, svg_info::SVGInfo)
    points = parse_path_data(element.d)
    if !isempty(points)
        # Transform coordinates
        transformed_points = transform_coordinates(points, svg_info)
        xs = [p[1] for p in transformed_points]
        ys = [p[2] for p in transformed_points]

        color = parse_color(element.stroke)
        if element.fill != "none"
            fill_color = parse_color(element.fill)
            poly!(ax, Point2f.(xs, ys), color=fill_color, strokecolor=color, strokewidth=element.stroke_width)
        else
            lines!(ax, Point2f.(xs, ys), color=color, linewidth=element.stroke_width)
        end
    end
end

function plot_svg_element!(ax, element::LineElement, svg_info::SVGInfo)
    # Transform coordinates
    x1, y1 = transform_coordinate(element.x1, element.y1, svg_info)
    x2, y2 = transform_coordinate(element.x2, element.y2, svg_info)
    
    color = parse_color(element.stroke)
    lines!(ax, [x1, x2], [y1, y2], color=color, linewidth=element.stroke_width)
end

function plot_svg_element!(ax, element::PolygonElement, svg_info::SVGInfo)
    if !isempty(element.points)
        # Transform coordinates
        transformed_points = transform_coordinates(element.points, svg_info)
        xs = [p[1] for p in transformed_points]
        ys = [p[2] for p in transformed_points]

        stroke_color = parse_color(element.stroke)

        if element.fill != "none"
            fill_color = parse_color(element.fill)
            poly!(ax, Point2f.(xs, ys), color=fill_color, strokecolor=stroke_color, strokewidth=element.stroke_width)
        else
            # Close the polygon for lines
            push!(xs, xs[1])
            push!(ys, ys[1])
            lines!(ax, Point2f.(xs, ys), color=stroke_color, linewidth=element.stroke_width)
        end
    end
end

function plot_svg_element!(ax, element::TextElement, svg_info::SVGInfo)
    # Transform coordinates
    x, y = transform_coordinate(element.x, element.y, svg_info)
    
    color = parse_color(element.fill)
    text!(ax, x, y, text=element.text, fontsize=element.font_size, color=color)
end

# Main function to parse SVG and create Makie plot
function parse_svg_to_makie(svg_string::String; figure_kwargs=(), axis_kwargs=())
    # Parse the SVG
    parsed = parsehtml(svg_string)
    elements, svg_info = extract_svg_elements(parsed)
    
    # Create figure and axis
    fig = Figure(; figure_kwargs...)
    ax = Axis(fig[1, 1]; aspect=DataAspect(), axis_kwargs...)

    # Plot each element
    for element in elements
        plot_svg_element!(ax, element, svg_info)
    end

    return fig, elements, svg_info
end

```
```julia true false true
svg = Asset("/sim/Programmieren/Books/test.svg")
```
```julia true false true
sample_svg = read(svg.local_path, String)
# Parse and plot the SVG
fig, elements, svg_info = parse_svg_to_makie(sample_svg,
    axis_kwargs=(title="SVG to Makie Conversion Demo", xlabel="X", ylabel="Y"))
hidedecorations!(fig.content[1])
fig
```
