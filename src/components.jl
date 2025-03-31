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


struct PopUp
    content::Observable{Any}
    show::Observable{Bool}
end

function PopUp(content; show = true)
    return PopUp(Observable(content), Observable(show))
end

function Bonito.jsrender(session::Session, popup::PopUp)
    button_style = Styles("position" => "absolute", "top" => "1px", "right" => "1px", "background-color" => "red")
    button, click = SmallButton(class = "codicon codicon-close", style = button_style)
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
            console.log("POOOPPIEEE")
            console.log(show);
            card.style.display = show ? "block" : "none";
        })
    """
    return Bonito.jsrender(session, DOM.div(card, close_js))
end
