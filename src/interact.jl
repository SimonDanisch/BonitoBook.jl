struct LabeledWidget{T}
    label::Symbol
    value::Observable{T}
    widget
end

function LabeledWidget(label, widget)
    return LabeledWidget(label, widget.value, widget)
end

function Bonito.jsrender(s::Session, widget::LabeledWidget)
    return Bonito.jsrender(s, DOM.div(
        DOM.div(string(widget.label), class="manipulate-label"),
        DOM.div(widget.widget, class="manipulate-widget"),
        class="manipulate-control-row"
    ))
end

function create_widget(sym, data::Tuple{Bool, Bool})
    data[1] != data[2] || error("Tuple must contain true and false values")
    s = Components.Checkbox(data[1])
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::AbstractVector{<:Real})
    s = Components.Slider(data)
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::AbstractVector)
    if length(data) < 1000
        s = Components.Dropdown(data)
    else
        s = Components.Slider(data)
    end
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::AbstractDict)
    s = Components.Dropdown(data)
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::NamedTuple)
    lookup = Dict(Pair.(values(data), keys(data)))
    s = Components.Dropdown(collect(values(data)); option_to_string = x -> lookup[x])
    return LabeledWidget(sym, s)
end


function make_widget(binding)
    if binding.head != :(=)
        error("@manipulate syntax error.")
    end
    sym, expr = binding.args
    return :(Pair{Symbol, Any}($(QuoteNode(sym)), $(esc(expr))))
end

function symbols(bindings)
    return map(x -> x.args[1], bindings)
end



struct ManipulateWidgets
    widgets::Vector{Pair{Symbol, Any}}
    callback::Function
end

function Bonito.jsrender(s::Session, mw::ManipulateWidgets)
    func = mw.callback
    widgets = map(mw.widgets) do (name, input)
        return create_widget(name, input)
    end
    observies = map(x -> x.value, widgets)
    init = map(to_value, observies)
    obs = @D Observable(func(init...))
    l = Base.ReentrantLock()
    Bonito.onany(observies...) do args...
        task = @async lock(l) do
            # Prevent reentrant calls to func
            try
                obs[] = func(args...)
            catch e
                return CapturedException(e, Base.catch_backtrace())
            end
        end
        Base.errormonitor(task)
        return
    end

    # Create controls panel
    controls = DOM.div(
        widgets...,
        class="manipulate-controls"
    )

    # Create output area
    output = DOM.div(
        obs,
        class="manipulate-output"
    )

    # Create main container
    return Bonito.jsrender(s, DOM.div(
        controls,
        output,
        class="manipulate-container"
    ))
end


"""
Creates a reactive UI for manipulating variables.

This macro allows you to create interactive widgets that update a given expression based on user input.

@manipulate for <variable>=<domain>, ...
    <expression>
end

Example with Makie:
```julia
import Makie.SpecApi as S
funcs = (sqrt=sqrt, x_square=x->x^2, sin=sin, cos=cos)
colormaps = ["viridis", "heat", "blues"]
types = (scatter=S.Scatter, lines=S.Lines, linesegments=S.LineSegments)
sizes=10:0.1:100
checkbox = (true, false)
@manipulate for cmap=colormaps, func=funcs, Typ=types, size=sizes, show_legend=checkbox
    x = 0:0.3:10
    s = Typ == S.Scatter ? (; markersize=size) : (; linewidth=size)
    splot = Typ(x, func.(x); colormap=cmap, color=x, s...)
    ax = S.Axis(; plots=[splot])
    if show_legend
        cbar = S.Colorbar(splot)
        S.GridLayout([ax cbar])
    else
        S.GridLayout([ax])
    end
end
```

Example with AlgebraOfGraphics:

```julia
using AlgebraOfGraphics
penguins = AlgebraOfGraphics.penguins()
@manipulate for vis in (
        scatter = visual(BoxPlot),
        violin = visual(Violin),
    )
    p = data(penguins) * vis * mapping(:species, :bill_depth_mm, color=:sex, dodge=:sex)
    AlgebraOfGraphics.draw_to_spec(p)
end
```
"""
macro manipulate(for_expr)
    if for_expr.head != :for
        error(
            """
            @manipulate syntax is:
            ```julia
            @manipulate for [<variable>=<domain>,]...
                <expression>
            end
            ```
            """
        )
    end
    block = for_expr.args[2]
    # remove trailing LineNumberNodes from loop body as to not just return `nothing`
    # ref https://github.com/JuliaLang/julia/pull/41857
    if Meta.isexpr(block, :block) && block.args[end] isa LineNumberNode
        pop!(block.args)
    end
    if for_expr.args[1].head == :block
        bindings = for_expr.args[1].args
    else
        bindings = [for_expr.args[1]]
    end
    syms = symbols(bindings)

    widgets = map(make_widget, bindings)
    symbols_esc = map(esc, syms)
    lambda = Expr(:(->), Expr(:tuple, symbols_esc...), esc(block))
    return quote
        ManipulateWidgets(
            Pair{Symbol, Any}[$(widgets...)],
            $(lambda)
        )
    end
end
export @manipulate


using AlgebraOfGraphics

function Bonito.jsrender(s::Session, value::AlgebraOfGraphics.Layers)
    spec = AlgebraOfGraphics.draw_to_spec(value)
    f, ax, pl = plot(spec)
    return Bonito.jsrender(s, f)
end

function Bonito.jsrender(s::Session, value::AlgebraOfGraphics.FigureGrid)
    return Bonito.jsrender(s, value.figure)
end

function Bonito.jsrender(s::Session, value::Observable{AlgebraOfGraphics.Layers})
    spec_obs = map(AlgebraOfGraphics.draw_to_spec, value)
    return Bonito.jsrender(s, spec_obs)
end

function Bonito.jsrender(s::Session, value::Observable{Makie.GridLayoutSpec})
    f, ax, pl = plot(value)
    return Bonito.jsrender(s, f)
end
