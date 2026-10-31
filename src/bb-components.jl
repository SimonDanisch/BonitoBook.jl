"""
    Components

A module containing custom styled widgets for BonitoBook, isolated from Bonito's default widgets.
These widgets use the global theme CSS variables defined in style.jl.
"""
module Components

using Bonito




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
    css = get(button.attributes, :style, Styles)
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
    Card(content; style=Styles(), attributes...)

A themed card container widget compatible with Bonito's interface.
Uses BonitoBook's CSS variables for consistent styling.
"""
struct Card
    content::Any
    attributes::Dict{Symbol,Any}
end

function Card(content; style=Styles(), attributes...)
    attrs = Dict{Symbol,Any}(attributes)
    attrs[:style] = style
    return Card(content, attrs)
end

function Bonito.jsrender(session::Session, card::Card)
    css = get(card.attributes, :style, Styles())
    card_dom = DOM.div(
        card.content;
        class="bonitobook-card",
        card.attributes...,
        style=css
    )
    return Bonito.jsrender(session, card_dom)
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
    css = get(checkbox.attributes, :style, Styles())
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
    css = get(ni.attributes, :style, Styles())
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
    css = get(dropdown.attributes, :style, Styles())
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
    css = get(slider.attributes, :style, Styles())
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
                const idx = event.srcElement.valueAsNumber;
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
