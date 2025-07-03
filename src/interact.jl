struct LabeledWidget{T}
    label::Symbol
    value::Observable{T}
    widget
end

function LabeledWidget(label, widget)
    return LabeledWidget(label, widget.value, widget)
end

function Bonito.jsrender(s::Session, widget::LabeledWidget)
    return Bonito.jsrender(s, DOM.div(Bonito.Label(widget.label), widget.widget))
end

function create_widget(sym, data::AbstractVector{<:Real})
    s = Bonito.Slider(data)
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::AbstractVector)
    if length(data) < 1000
        s = Bonito.Dropdown(data)
    else
        s = Bonito.Slider(data, 0.0, 1.0, 0.01)
    end
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::AbstractDict)
    s = Bonito.Dropdown(data)
    return LabeledWidget(sym, s)
end

function create_widget(sym, data::NamedTuple)
    lookup = Dict(Pair.(values(data), keys(data)))
    s = Bonito.Dropdown(collect(values(data)); option_to_string = x -> lookup[x])
    return LabeledWidget(sym, s)
end


function make_widget(binding)
    if binding.head != :(=)
        error("@manipulate syntax error.")
    end
    sym, expr = binding.args
    return :(create_widget($(QuoteNode(sym)), $(esc(expr))))
end

function symbols(bindings)
    return map(x -> x.args[1], bindings)
end

macro manipulate(for_expr)
    if for_expr.head != :for
        error(
            "@manipulate syntax is @manipulate for ",
            " [<variable>=<domain>,]... <expression> end"
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
        widgets = ($(widgets...),)
        observies = map(x -> x.value, widgets)
        init = map(to_value, observies)
        func = $(lambda)
        obs = Observable(func(init...))
        l = Base.ReentrantLock()
        Bonito.onany(observies...) do args...
            @async begin
                lock(l) do
                    # Prevent reentrant calls to func
                    obs[] = func(args...)
                end
            end
        end
        DOM.div(
            widgets...,
            obs
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

function Bonito.jsrender(s::Session, value::Observable{AlgebraOfGraphics.Layers})
    spec_obs = map(AlgebraOfGraphics.draw_to_spec, value)
    return Bonito.jsrender(s, spec_obs)
end


function Bonito.jsrender(s::Session, value::Observable{Makie.GridLayoutSpec})
    f, ax, pl = plot(value)
    return Bonito.jsrender(s, f)
end
