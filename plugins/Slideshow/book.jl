module SlideshowBooks

using Bonito
using BonitoBook

include("styles.jl")

# Slideshow Book - demonstrates presentation-style navigation through markdown content

struct SlideshowBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    branding_text::String
    branding_logo::Union{String, Nothing}
    footer_text::String

    function SlideshowBook(book::BonitoBook.Book; branding_text="", branding_logo=nothing, footer_text="")
        return new(book, branding_text, branding_logo, footer_text)
    end
end

"""
    create_book(book::BonitoBook.Book; branding_text="", branding_logo=nothing, footer_text="", kwargs...)

Create a SlideshowBook instance from a BonitoBook.Book.
"""
function create_book(book::BonitoBook.Book; branding_text="", branding_logo=nothing, footer_text="", kwargs...)
    # Default branding for the bundled example
    if isempty(branding_text) && isnothing(branding_logo) && isempty(footer_text)
        logo_path = joinpath(dirname(@__FILE__), "logo.svg")
        branding_text = "Makie.jl"
        branding_logo = isfile(logo_path) ? logo_path : nothing
        footer_text = "Interactive Data Visualization"
    end

    # Disable markdown click-to-edit for all markdown cells in slideshow mode
    for cell in book.cells
        if cell.language == "markdown"
            cell.editor.markdown_focus_edit[] = false
        end
    end

    return SlideshowBook(book; branding_text, branding_logo, footer_text)
end

function Bonito.jsrender(session::Session, slideshow::SlideshowBook)
    book = slideshow.book

    progress_container = DOM.div(
        DOM.div(class="progress-bar"),
        class="progress-container"
    )

    tooltip_content = "Slide navigation:\n• Arrow keys to navigate\n• Click progress bar to jump to position"
    progress_tooltip = BonitoBook.Tooltip(progress_container, tooltip_content)

    all_cells_container = DOM.div(
        book.cells...,
        class="slideshow-content"
    )

    slideshow_container = DOM.div(
        all_cells_container,
        progress_tooltip,
        class="slideshow-container"
    )

    navigation_js = js"""
        (function() {
            let current_slide = 1;
            let total_slides = 0;
            let slide_elements = [];
            function init_slideshow() {
                const slideshow_container = $(slideshow_container);

                const progress_container = slideshow_container.querySelector('.progress-container');
                const progress_bar = slideshow_container.querySelector('.progress-bar');
                const content_container = slideshow_container.querySelector('.slideshow-content');

                function find_slide_elements() {
                    const hr_elements = content_container.querySelectorAll('hr');
                    slide_elements = [];

                    if (hr_elements.length === 0) {
                        slide_elements = [content_container.firstElementChild || content_container];
                        total_slides = 1;
                        return;
                    }

                    const first_element = content_container.firstElementChild;
                    if (first_element) {
                        slide_elements.push(first_element);
                    }

                    hr_elements.forEach(function(hr) {
                        let next_element = hr.nextElementSibling;
                        while (next_element && (
                            next_element.style.display === 'none' ||
                            next_element.offsetHeight === 0 ||
                            next_element.tagName === 'SCRIPT' ||
                            next_element.tagName === 'STYLE' ||
                            (next_element.textContent && next_element.textContent.trim() === '')
                        )) {
                            next_element = next_element.nextElementSibling;
                        }

                        if (next_element && next_element.offsetHeight > 0) {
                            slide_elements.push(next_element);
                        }
                    });

                    total_slides = slide_elements.length;
                }

                function detect_current_slide_from_scroll() {
                    let closest_slide = 1;
                    let min_distance = Infinity;

                    slide_elements.forEach((element, index) => {
                        const rect = element.getBoundingClientRect();
                        const distance = Math.abs(rect.top);
                        if (distance < min_distance) {
                            min_distance = distance;
                            closest_slide = index + 1;
                        }
                    });

                    return closest_slide;
                }

                function update_slide() {
                    if (slide_elements.length === 0) return;

                    const target_element = slide_elements[current_slide - 1];
                    if (target_element) {
                        target_element.style.scrollMarginTop = "40px";
                        target_element.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start',
                        });
                    }

                    const progress = (current_slide / total_slides) * 100;
                    if (progress_bar) {
                        progress_bar.style.width = progress + '%';
                    }
                }

                function sync_slide_with_scroll() {
                    const detected_slide = detect_current_slide_from_scroll();
                    if (detected_slide !== current_slide) {
                        current_slide = detected_slide;
                        const progress = (current_slide / total_slides) * 100;
                        if (progress_bar) {
                            progress_bar.style.width = progress + '%';
                        }
                    }
                }

                function next_slide() {
                    if (current_slide < total_slides) {
                        current_slide++;
                        update_slide();
                    }
                }

                function prev_slide() {
                    if (current_slide > 1) {
                        current_slide--;
                        update_slide();
                    }
                }

                function go_to_slide(slide_number) {
                    if (slide_number >= 1 && slide_number <= total_slides) {
                        current_slide = slide_number;
                        update_slide();
                    }
                }

                if (progress_container) {
                    progress_container.addEventListener('click', function(e) {
                        const rect = progress_container.getBoundingClientRect();
                        const click_position = (e.clientX - rect.left) / rect.width;
                        const target_slide = Math.ceil(click_position * total_slides);
                        go_to_slide(target_slide);
                    });
                }

                let scroll_timeout;
                document.addEventListener('scroll', function() {
                    clearTimeout(scroll_timeout);
                    scroll_timeout = setTimeout(sync_slide_with_scroll, 150);
                });

                document.addEventListener('keydown', function(e) {
                    const active_element = document.activeElement;
                    const is_editing = active_element && (
                        active_element.tagName === 'INPUT' ||
                        active_element.tagName === 'TEXTAREA' ||
                        active_element.contentEditable === 'true' ||
                        active_element.closest('.monaco-editor') !== null ||
                        active_element.closest('.cell-editor') !== null
                    );

                    if (e.key === 'Enter') {
                        return;
                    }

                    if (!is_editing) {
                        if (e.key === 'ArrowRight') {
                            e.preventDefault();
                            next_slide();
                        } else if (e.key === 'ArrowLeft') {
                            e.preventDefault();
                            prev_slide();
                        }
                    }
                });

                find_slide_elements();
                update_slide();
            }

            init_slideshow();
        })();
    """

    final_container = DOM.div(
        slideshow_container,
        navigation_js,
        class="slideshow-wrapper"
    )

    elements = BonitoBook.standard_setup!(session, book)

    branding_elements = []
    if !isnothing(slideshow.branding_logo) && isfile(slideshow.branding_logo)
        push!(branding_elements, DOM.img(src=Asset(slideshow.branding_logo), style="height: 24px; margin-right: 8px;"))
    end
    if !isempty(slideshow.branding_text)
        push!(branding_elements, slideshow.branding_text)
    end
    branding = isempty(branding_elements) ? nothing : DOM.div(branding_elements..., class="slideshow-branding")

    footer = isempty(slideshow.footer_text) ? nothing : DOM.div(slideshow.footer_text, class="slideshow-footer")

    presentation_wrapper = DOM.div(
        elements, final_container, branding, footer,
        class="presentation-themed-slideshow"
    )
    return Bonito.jsrender(session, presentation_wrapper)
end

export SlideshowBook, create_book, generate_style

end
