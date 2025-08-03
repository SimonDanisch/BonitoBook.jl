"""
    Components

A module containing custom styled widgets for BonitoBook, isolated from Bonito's default widgets.
These widgets use the global theme CSS variables defined in style.jl.
"""
module Components

using Bonito

export Button, Checkbox, Dropdown, NumberInput, Slider

# Define global widget styles that use CSS variables
const WIDGET_STYLES = Styles(
    CSS(
        ".bonitobook-button",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 16px",
        "margin" => "4px",
        "font-size" => "14px",
        "font-weight" => "500",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "box-shadow" => "0 1px 3px rgba(0, 0, 0, 0.1)",
        "min-width" => "80px",
        "display" => "inline-flex",
        "align-items" => "center",
        "justify-content" => "center",
        "font-family" => "inherit"
    ),
    CSS(
        ".bonitobook-button:hover",
        "background-color" => "var(--hover-bg)",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 2px 6px rgba(0, 0, 0, 0.15)"
    ),
    CSS(
        ".bonitobook-button:focus",
        "outline" => "none",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-button:active",
        "transform" => "translateY(1px)",
        "box-shadow" => "0 1px 2px rgba(0, 0, 0, 0.1)"
    )
)

const INPUT_STYLES = Styles(
    CSS(
        ".bonitobook-input",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 12px",
        "margin" => "4px",
        "font-size" => "14px",
        "font-family" => "inherit",
        "transition" => "all 0.2s ease",
        "outline" => "none",
        "width" => "calc(100% - 8px)",
        "box-sizing" => "border-box"
    ),
    CSS(
        ".bonitobook-input:hover",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-input:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-input:disabled",
        "background-color" => "var(--hover-bg)",
        "color" => "var(--text-secondary)",
        "cursor" => "not-allowed"
    )
)

const CHECKBOX_STYLES = Styles(
    CSS(
        ".bonitobook-checkbox",
        "width" => "16px",
        "height" => "16px",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "3px",
        "background-color" => "var(--bg-primary)",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "position" => "relative",
        "margin" => "4px 8px 4px 4px",
        "flex-shrink" => "0"
    ),
    CSS(
        ".bonitobook-checkbox:hover",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-checkbox:focus",
        "outline" => "none",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-checkbox:checked",
        "background-color" => "var(--accent-blue)",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-checkbox:checked::after",
        "content" => "\"✓\"",
        "position" => "absolute",
        "top" => "50%",
        "left" => "50%",
        "transform" => "translate(-50%, -50%)",
        "color" => "white",
        "font-size" => "12px",
        "line-height" => "1"
    )
)

const DROPDOWN_STYLES = Styles(
    CSS(
        ".bonitobook-dropdown",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)",
        "border" => "1px solid var(--border-secondary)",
        "border-radius" => "6px",
        "padding" => "8px 12px",
        "margin" => "4px",
        "font-size" => "14px",
        "font-family" => "inherit",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "outline" => "none",
        "width" => "calc(100% - 8px)",
        "box-sizing" => "border-box",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "background-image" => "url('data:image/svg+xml;charset=US-ASCII,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 5\"><path fill=\"%23666\" d=\"M2 0L0 2h4zm0 5L0 3h4z\"/></svg>')",
        "background-repeat" => "no-repeat",
        "background-position" => "right 12px center",
        "background-size" => "12px",
        "padding-right" => "36px"
    ),
    CSS(
        ".bonitobook-dropdown:hover",
        "border-color" => "var(--accent-blue)"
    ),
    CSS(
        ".bonitobook-dropdown:focus",
        "border-color" => "var(--accent-blue)",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2)"
    ),
    CSS(
        ".bonitobook-dropdown option",
        "background-color" => "var(--bg-primary)",
        "color" => "var(--text-primary)"
    )
)

const SLIDER_STYLES = Styles(
    CSS(
        ".bonitobook-slider",
        "width" => "calc(100% - 8px)",
        "height" => "6px",
        "border-radius" => "3px",
        "background" => "var(--border-secondary)",
        "outline" => "none",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "cursor" => "pointer",
        "transition" => "all 0.2s ease",
        "margin" => "4px"
    ),
    CSS(
        ".bonitobook-slider::-webkit-slider-thumb",
        "appearance" => "none",
        "-webkit-appearance" => "none",
        "width" => "20px",
        "height" => "20px",
        "border-radius" => "50%",
        "background" => "var(--accent-blue)",
        "cursor" => "pointer",
        "border" => "2px solid var(--bg-primary)",
        "box-shadow" => "0 2px 6px rgba(0, 0, 0, 0.2)",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".bonitobook-slider::-webkit-slider-thumb:hover",
        "transform" => "scale(1.1)",
        "box-shadow" => "0 3px 8px rgba(0, 0, 0, 0.3)"
    ),
    CSS(
        ".bonitobook-slider::-moz-range-thumb",
        "width" => "20px",
        "height" => "20px",
        "border-radius" => "50%",
        "background" => "var(--accent-blue)",
        "cursor" => "pointer",
        "border" => "2px solid var(--bg-primary)",
        "box-shadow" => "0 2px 6px rgba(0, 0, 0, 0.2)",
        "transition" => "all 0.2s ease"
    ),
    CSS(
        ".bonitobook-slider::-moz-range-track",
        "width" => "100%",
        "height" => "6px",
        "border-radius" => "3px",
        "background" => "var(--border-secondary)",
        "border" => "none"
    ),
    CSS(
        ".bonitobook-slider:focus",
        "outline" => "none"
    ),
    CSS(
        ".bonitobook-slider:focus::-webkit-slider-thumb",
        "box-shadow" => "0 0 0 2px rgba(3, 102, 214, 0.2), 0 2px 6px rgba(0, 0, 0, 0.2)"
    )
)

"""
    Button(content; style=Styles(), attributes...)

A themed button widget compatible with Bonito's Button interface.
Uses BonitoBook's CSS variables for consistent styling.
"""
struct Button
    content::Observable{String}
    value::Observable{Bool}
    attributes::Dict{Symbol,Any}
end

function Button(content; style=Styles(), attributes...)
    content_obs = convert(Observable{String}, content)
    value_obs = Observable(false)
    attrs = Dict{Symbol,Any}(attributes)
    if haskey(attrs, :style)
        attrs[:style] = Styles(attrs[:style], style)
    else
        attrs[:style] = style
    end
    return Button(content_obs, value_obs, attrs)
end

function Bonito.jsrender(session::Session, button::Button)
    css = Styles(get(button.attributes, :style, Styles()), WIDGET_STYLES)
    button_dom = DOM.button(
        button.content[];
        onclick=js"event=> $(button.value).notify(true);",
        class="bonitobook-button",
        button.attributes...,
        style=css
    )
    onjs(session, button.content, js"x=> $(button_dom).innerText = x")
    return Bonito.jsrender(session, button_dom)
end

"""
    Checkbox(default_value; style=Styles(), attributes...)

A themed checkbox widget compatible with Bonito's Checkbox interface.
Uses BonitoBook's CSS variables for consistent styling.
"""
struct Checkbox
    value::Observable{Bool}
    attributes::Dict{Symbol,Any}
end

function Checkbox(default_value; style=Styles(), attributes...)
    value_obs = convert(Observable{Bool}, default_value)
    attrs = Dict{Symbol,Any}(attributes)
    if haskey(attrs, :style)
        attrs[:style] = Styles(attrs[:style], style)
    else
        attrs[:style] = style
    end
    return Checkbox(value_obs, attrs)
end

function Bonito.jsrender(session::Session, checkbox::Checkbox)
    css = Styles(get(checkbox.attributes, :style, Styles()), CHECKBOX_STYLES)
    return Bonito.jsrender(
        session,
        DOM.input(;
            type="checkbox",
            checked=checkbox.value,
            onchange=js"event=> $(checkbox.value).notify(event.srcElement.checked);",
            class="bonitobook-checkbox",
            checkbox.attributes...,
            style=css
        ),
    )
end

"""
    NumberInput(default_value; style=Styles(), attributes...)

A themed number input widget compatible with Bonito's NumberInput interface.
Uses BonitoBook's CSS variables for consistent styling.
"""
struct NumberInput
    value::Observable{Float64}
    attributes::Dict{Symbol,Any}
end

function NumberInput(default_value; style=Styles(), attributes...)
    value_obs = convert(Observable{Float64}, default_value)
    attrs = Dict{Symbol,Any}(attributes)
    if haskey(attrs, :style)
        attrs[:style] = Styles(attrs[:style], style)
    else
        attrs[:style] = style
    end
    return NumberInput(value_obs, attrs)
end

function Bonito.jsrender(session::Session, ni::NumberInput)
    css = Styles(get(ni.attributes, :style, Styles()), INPUT_STYLES)
    return Bonito.jsrender(
        session,
        DOM.input(;
            type="number",
            value=ni.value,
            onchange=js"event => {
                const new_value = parseFloat(event.srcElement.value);
                if (!isNaN(new_value) && $(ni.value).value != new_value) {
                    $(ni.value).notify(new_value);
                }
            }",
            class="bonitobook-input",
            ni.attributes...,
            style=css,
        ),
    )
end

"""
    Dropdown(options; index=1, option_to_string=string, style=Styles(), attributes...)

A themed dropdown widget compatible with Bonito's Dropdown interface.
Uses BonitoBook's CSS variables for consistent styling.
"""
struct Dropdown
    options::Observable{Vector{Any}}
    value::Observable{Any}
    option_to_string::Function
    option_index::Observable{Int}
    attributes::Dict{Symbol,Any}
end

function Dropdown(options; index=1, option_to_string=string, style=Styles(), attributes...)
    option_index = convert(Observable{Int}, index)
    options_obs = convert(Observable{Vector{Any}}, options)
    option = Observable{Any}(options_obs[][option_index[]])
    onany(option_index, options_obs) do index, options
        if 1 <= index <= length(options)
            option[] = options[index]
        end
        return nothing
    end
    attrs = Dict{Symbol,Any}(attributes)
    if haskey(attrs, :style)
        attrs[:style] = Styles(attrs[:style], style)
    else
        attrs[:style] = style
    end
    return Dropdown(options_obs, option, option_to_string, option_index, attrs)
end

function Bonito.jsrender(session::Session, dropdown::Dropdown)
    css = Styles(get(dropdown.attributes, :style, Styles()), DROPDOWN_STYLES)
    string_options = map(x-> map(dropdown.option_to_string, x), session, dropdown.options)

    onchange = js"""
    function onload(element) {
        function onchange(e) {
            if (element === e.srcElement) {
                ($(dropdown.option_index)).notify(element.selectedIndex + 1);
            }
        }
        element.addEventListener("change", onchange);
        element.selectedIndex = $(dropdown.option_index[] - 1)
        function set_option_index(index) {
            if (element.selectedIndex === index - 1) {
                return
            }
            element.selectedIndex = index - 1;
        }
        $(dropdown.option_index).on(set_option_index);
        function set_options(opts) {
            element.selectedIndex = 0;
            // https://stackoverflow.com/questions/3364493/how-do-i-clear-all-options-in-a-dropdown-box
            element.options.length = 0;
            opts.forEach((opt, i) => element.options.add(new Option(opts[i], i)));
        }
        $(string_options).on(set_options);
    }
    """
    option2div(x) = DOM.option(x)
    dom = map(options -> map(option2div, options), session, string_options)[]

    select = DOM.select(dom;
        class="bonitobook-dropdown",
        style=css,
        dropdown.attributes...)
    Bonito.onload(session, select, onchange)
    return Bonito.jsrender(session, select)
end

"""
    Slider(values; value=first(values), style=Styles(), attributes...)

A themed slider widget compatible with Bonito's Slider interface.
Uses BonitoBook's CSS variables for consistent styling.
"""
struct Slider{T}
    values::Observable{Vector{T}}
    value::Observable{T}
    index::Observable{Int}
    attributes::Dict{Symbol,Any}
end

function Slider(values::AbstractArray{T}; value=first(values), style=Styles(), attributes...) where {T}
    values_obs = convert(Observable{Vector{T}}, values)
    initial_idx = findfirst((==)(value), values_obs[])
    idx = isnothing(initial_idx) ? 1 : initial_idx
    index = Observable(idx)
    value_obs = Observable(values_obs[][idx])
    attrs = Dict{Symbol,Any}(attributes)
    if haskey(attrs, :style)
        attrs[:style] = Styles(attrs[:style], style)
    else
        attrs[:style] = style
    end
    return Slider(values_obs, value_obs, index, attrs)
end

function Bonito.jsrender(session::Session, slider::Slider)
    css = Styles(get(slider.attributes, :style, Styles()), SLIDER_STYLES)
    values = slider.values
    index = slider.index
    onjs(
        session,
        index,
        js"""(index) => {
            const values = $(values).value
            $(slider.value).notify(values[index - 1])
        }
        """,
    )

    return Bonito.jsrender(
        session,
        DOM.input(;
            type="range",
            min=1,
            max=map(length, values),
            value=index,
            step=1,
            oninput=js"""(event)=> {
                console.log(event)
                const idx = event.srcElement.valueAsNumber;
                console.log(idx)
                console.log($(index))
                if (idx !== $(index).value) {
                    $(index).notify(idx)
                }
            }""",
            class="bonitobook-slider",
            style=css,
            slider.attributes...,
        ),
    )
end

function Base.setindex!(slider::Slider, value)
    values = slider.values
    idx = findfirst(x -> x >= value, values[])
    if isnothing(idx)
        @warn(
            "Value $(value) out of range for the values of slider (highest value: $(last(values[]))). Setting to highest value!"
        )
        idx = length(values[])
    end
    slider.index[] = idx
    return idx
end

end # module Components
