"""
    SmallButton(; class="", kw...)

Create a small interactive button component.

# Arguments
- `class`: CSS class string to apply to the button
- `kw...`: Additional keyword arguments passed to the DOM button

# Returns
Tuple of (button_dom, click_observable) where click_observable fires when clicked.
"""
function SmallButton(; class = "", kw...)
    value = Observable(false)
    button_dom = DOM.button(
        "";
        onclick = js"event=> $(value).notify(true);",
        class = "small-button $(class)",
        kw...,
    )
    return button_dom, value
end

"""
    SmallToggle(active, args...; class="", kw...)

Create a small toggle button that reflects and controls a boolean observable.

# Arguments
- `active`: Observable{Bool} that controls the toggle state
- `args...`: Additional arguments passed to the button
- `class`: CSS class string
- `kw...`: Additional keyword arguments

# Returns
DOM element with toggle functionality.
"""
function SmallToggle(active, args...; class = "", kw...)
    class = active[] ? class : "toggled $class"
    value = Observable(false)
    button_dom = DOM.button(args...; class = "small-button $(class)", kw...)

    toggle_script = js"""
        const elem = $(button_dom);
        $(active).on((x) => {
            if (!x) {
                elem.classList.add("toggled");
            } else {
                elem.classList.remove("toggled");
            }
        })
        elem.addEventListener("click", event=> {
            $(value).notify(true);
        })
    """
    on(value) do click
        active[] = !active[]
    end
    return DOM.span(button_dom, toggle_script)
end


"""
    PopUp

Modal popup component with show/hide functionality.

# Fields
- `content::Observable{Any}`: Content to display in the popup
- `show::Observable{Bool}`: Whether the popup is visible
"""
struct PopUp
    content::Observable{Any}
    show::Observable{Bool}
end

"""
    PopUp(content; show=true)

Create a popup with the given content.

# Arguments
- `content`: Content to display (can be any renderable object)
- `show`: Whether the popup starts visible (default: true)

# Returns
`PopUp` instance.
"""
function PopUp(content; show = true)
    return PopUp(Observable(content), Observable(show))
end

function Bonito.jsrender(session::Session, popup::PopUp)
    button_style = Styles("position" => "absolute", "top" => "1px", "right" => "1px", "background-color" => "red")
    close_icon = icon("close")
    click = Observable(false)
    button = DOM.button(close_icon;
        class="small-button",
        style=button_style,
        onclick = js"event=> $(click).notify(true);"
    )
    on(click) do click
        popup.show[] = !popup.show[]
    end
    popup_style = Styles(
        "position" => "absolute", "top" => "100px",
        "left" => "50%", "transform" => "translateX(-50%)",
        "z-index" => "1000",
        "background-color" => "white",
        "display" => popup.show[] ? "block" : "none",
    )
    card = Card(
        Col(popup.content, button),
        style = popup_style
    )
    close_js = js"""
        const show = $(popup.show);
        const card = $(card);
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && card.style.display !== 'none') {
                $(popup.show).notify(false);
            }
        });
        show.on((show) => {
            console.log("Popup visibility changed")
            console.log(show);
            card.style.display = show ? "block" : "none";
        })
    """
    return Bonito.jsrender(session, DOM.div(card, close_js))
end
