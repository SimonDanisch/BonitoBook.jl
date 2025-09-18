module SlideshowBooks

using Bonito, BonitoBook

# Slideshow Book - demonstrates presentation-style navigation through markdown content

struct SlideshowBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    presentation_style::BonitoBook.EvalFileOnChange

    function SlideshowBook(book::BonitoBook.Book, presentation_style::BonitoBook.EvalFileOnChange)
        return new(book, presentation_style)
    end
end

"""
    create_book(book::BonitoBook.Book; kwargs...)

Create a SlideshowBook instance from a BonitoBook.Book.
"""
function create_book(book::BonitoBook.Book; kwargs...)
    # Disable markdown click-to-edit for all markdown cells in slideshow mode
    for cell in book.cells
        if cell.language == "markdown"
            cell.editor.markdown_focus_edit[] = false
        end
    end

    # Set up presentation style evaluation
    presentation_style_path = joinpath(dirname(@__FILE__), "styles", "presentation-style.jl")
    presentation_style = BonitoBook.EvalFileOnChange(presentation_style_path; module_context = book.runner.mod)
    notify(presentation_style.file_watcher)

    return SlideshowBook(book, presentation_style)
end

function Bonito.jsrender(session::Session, slideshow::SlideshowBook)
    book = slideshow.book

    # Progress bar with container for tooltip area
    progress_container = DOM.div(
        DOM.div(class="progress-bar"),
        class="progress-container"
    )

    # Create tooltip widget for progress bar
    tooltip_content = "Slide navigation:\n• Arrow keys to navigate\n• Click progress bar to jump to position"
    progress_tooltip = BonitoBook.Tooltip(progress_container, tooltip_content)

    # Render all cells in one container - JavaScript will handle slide separation
    all_cells_container = DOM.div(
        book.cells...,
        class="slideshow-content"
    )

    # Main container first
    slideshow_container = DOM.div(
        all_cells_container,
        progress_tooltip,
        class="slideshow-container"
    )

    # JavaScript for slide navigation - following Bonito best practices
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
                // Find all elements to scroll to for each slide
                function find_slide_elements() {
                    const hr_elements = content_container.querySelectorAll('hr');
                    slide_elements = [];

                    if (hr_elements.length === 0) {
                        // No HR elements, just scroll to the top
                        slide_elements = [content_container.firstElementChild || content_container];
                        total_slides = 1;
                        return;
                    }

                    // First slide: scroll to first element
                    const first_element = content_container.firstElementChild;
                    if (first_element) {
                        slide_elements.push(first_element);
                    }

                    // Find elements that come after HR elements
                    hr_elements.forEach(function(hr) {
                        // Look for the next meaningful content element after the HR
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
                    // Find which slide is currently visible based on scroll position
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

                    // Scroll the target element to the top of the container
                    const target_element = slide_elements[current_slide - 1];
                    if (target_element) {
                        target_element.style.scrollMarginTop = "40px";
                        target_element.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start',
                        });
                    }

                    // Update progress bar
                    const progress = (current_slide / total_slides) * 100;
                    if (progress_bar) {
                        progress_bar.style.width = progress + '%';
                    }
                }

                function sync_slide_with_scroll() {
                    // Update current_slide based on actual scroll position
                    const detected_slide = detect_current_slide_from_scroll();
                    if (detected_slide !== current_slide) {
                        current_slide = detected_slide;
                        // Update progress bar without scrolling
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

                // Progress bar click navigation
                if (progress_container) {
                    progress_container.addEventListener('click', function(e) {
                        const rect = progress_container.getBoundingClientRect();
                        const click_position = (e.clientX - rect.left) / rect.width;
                        const target_slide = Math.ceil(click_position * total_slides);
                        go_to_slide(target_slide);
                    });
                }

                // Add scroll listener to sync slide position
                let scroll_timeout;
                document.addEventListener('scroll', function() {
                    clearTimeout(scroll_timeout);
                    scroll_timeout = setTimeout(sync_slide_with_scroll, 150);
                });

                // Keyboard navigation with better focus detection
                document.addEventListener('keydown', function(e) {
                    // Check if user is editing in Monaco editor or input field
                    const active_element = document.activeElement;
                    const is_editing = active_element && (
                        active_element.tagName === 'INPUT' ||
                        active_element.tagName === 'TEXTAREA' ||
                        active_element.contentEditable === 'true' ||
                        active_element.closest('.monaco-editor') !== null ||
                        active_element.closest('.cell-editor') !== null
                    );

                    // Only handle navigation if not editing
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

                // Initialize
                find_slide_elements();
                update_slide();
            }

            // Start initialization
            init_slideshow();
        })();
    """

    # Add JavaScript to the container
    final_container = DOM.div(
        slideshow_container,
        navigation_js,
        class="slideshow-wrapper"
    )

    # Standard BonitoBook setup
    elements = BonitoBook.standard_setup!(session, book)

    # Get presentation styles (will be re-evaluated if file changes)
    presentation_styles = slideshow.presentation_style.last_valid_output
    # Add branding elements with logo
    logo_path = joinpath(dirname(@__FILE__), "logo.svg")
    logo = isfile(logo_path) ? DOM.img(src=Asset(logo_path), style="height: 24px; margin-right: 8px;") : ""
    branding = DOM.div(logo, "Makie.jl", class="slideshow-branding")
    footer = DOM.div("Interactive Data Visualization", class="slideshow-footer")

    # Wrap everything in a presentation-themed container for higher CSS specificity
    presentation_wrapper = DOM.div(
        elements, final_container, branding, footer,
        class="presentation-themed-slideshow"
    )

    return Bonito.jsrender(session, DOM.div(presentation_styles, presentation_wrapper))
end


end
