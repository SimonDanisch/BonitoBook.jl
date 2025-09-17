module SlideshowBooks

using Bonito, BonitoBook

# Slideshow Book - demonstrates presentation-style navigation through markdown content

struct SlideshowBook <: BonitoBook.AbstractBook
    book::BonitoBook.Book
    function SlideshowBook(book::BonitoBook.Book)
        # Disable markdown click-to-edit for all markdown cells in slideshow mode
        for cell in book.cells
            if cell.language == "markdown"
                cell.editor.markdown_focus_edit[] = false
            end
        end
        return new(book)
    end
end

# Slideshow styles - scroll-based approach
const SLIDESHOW_STYLES = Styles(
    # Main slideshow container
    CSS(
        ".slideshow-container",
        "position" => "relative",
        "width" => "100%",
        "min-height" => "100vh", # Use min-height instead of fixed height
        "background-color" => "var(--bg-primary)",
        "overflow" => "visible" # Allow content to expand beyond container
    ),

    # When embedded in a container, use container height instead of viewport
    CSS(
        ".slideshow-container:not(:root)",
        "min-height" => "100%"
    ),

    # Content container - optimized for presentation (only apply within slideshow-container)
    CSS(
        ".slideshow-container .slideshow-content",
        "position" => "absolute",
        "top" => "0",
        "left" => "0",
        "right" => "0",
        "bottom" => "20px", # Leave space for progress bar
        "padding" => "80px 120px", # More side padding for centering
        "padding-bottom" => "150vh", # Extra space at bottom for last slide
        "overflow-y" => "auto",
        "scroll-behavior" => "smooth",
        "background-color" => "var(--bg-primary)",
        "font-size" => "18px", # Larger font for presentations
        "line-height" => "1.6",
        "display" => "flex",
        "flex-direction" => "column",
        "align-items" => "center", # Center content horizontally
        "max-width" => "1200px", # Limit content width
        "margin" => "0 auto" # Center the container
    ),

    # HR elements create large gaps to separate slides
    CSS(
        ".slideshow-container .slideshow-content hr",
        "margin" => "100vh 0", # Full viewport height margins
        "border" => "none",
        "height" => "2px",
        "background-color" => "var(--accent-blue)",
        "opacity" => "0.3"
    ),

    # Elements after HR should be positioned at top when scrolled to
    CSS(
        ".slideshow-container .slideshow-content hr + *",
        "scroll-margin-top" => "0"
    ),

    # Progress bar with hover area
    CSS(
        ".progress-bar",
        "position" => "fixed",
        "bottom" => "0",
        "left" => "0",
        "height" => "6px",
        "background-color" => "var(--accent-blue)",
        "transition" => "width 0.5s ease, height 0.2s ease",
        "z-index" => "1000",
        "cursor" => "pointer"
    ),

    # Progress bar container for tooltip
    CSS(
        ".progress-container",
        "position" => "fixed",
        "bottom" => "0",
        "left" => "0",
        "right" => "0",
        "height" => "20px",
        "background-color" => "rgba(0,0,0,0.1)",
        "z-index" => "999",
        "cursor" => "pointer"
    ),

    CSS(
        ".progress-container:hover .progress-bar",
        "height" => "10px"
    ),

    # Presentation-optimized content styling
    CSS(
        ".slideshow-container .slideshow-content h1",
        "color" => "var(--text-primary)",
        "font-size" => "3.5rem",
        "font-weight" => "700",
        "margin-bottom" => "2rem",
        "margin-top" => "1rem",
        "line-height" => "1.2",
        "text-align" => "center",
        "width" => "100%"
    ),

    CSS(
        ".slideshow-content h2",
        "color" => "var(--text-primary)",
        "font-size" => "2.8rem",
        "font-weight" => "600",
        "margin-bottom" => "1rem",
        "margin-top" => "1rem",
        "line-height" => "1.3",
        "text-align" => "center",
        "width" => "100%"
    ),

    CSS(
        ".slideshow-content h3",
        "color" => "var(--text-primary)",
        "font-size" => "2.2rem",
        "font-weight" => "600",
        "margin-bottom" => "0.8rem",
        "margin-top" => "0.8rem",
        "line-height" => "1.3",
        "text-align" => "center",
        "width" => "100%"
    ),

    CSS(
        ".slideshow-content h4, .slideshow-content h5, .slideshow-content h6",
        "color" => "var(--text-primary)",
        "font-size" => "1.6rem",
        "font-weight" => "600",
        "margin-bottom" => "1rem",
        "margin-top" => "0.8rem"
    ),

    CSS(
        ".slideshow-content p",
        "color" => "var(--text-primary)",
        "font-size" => "1.3rem",
        "line-height" => "1.6",
        "margin-bottom" => "1rem",
        "max-width" => "800px", # Limit line length for readability
        "text-align" => "left",
        "width" => "100%"
    ),

    CSS(
        ".slideshow-content li",
        "color" => "var(--text-primary)",
        "font-size" => "1.3rem",
        "line-height" => "1.6",
        "margin-bottom" => "0.8rem"
    ),

    CSS(
        ".slideshow-content ul, .slideshow-content ol",
        "margin-bottom" => "1.5rem",
        "padding-left" => "2rem"
    ),

    # Code blocks - optimized for presentation, override base width constraints
    CSS(
        ".slideshow-container .slideshow-content .cell-editor-container",
        "width" => "95%",
        "max-width" => "1000px",
    ),

    CSS(
        ".slideshow-container .slideshow-content .cell-editor",
        "font-size" => "1.1rem",
        "line-height" => "1.4",
        "border-radius" => "12px",
        "box-shadow" => "0 4px 12px rgba(0, 0, 0, 0.15)",
        "width" => "100%",
        "max-width" => "none"
    ),

    # Cell outputs - presentation optimized
    CSS(
        ".slideshow-container .slideshow-content .cell-output-container",
        "max-width" => "1000px",
        "overflow" => "visible",
        "margin" => "1rem auto",
        "width" => "95%",
        "box-sizing" => "border-box",
        "max-height" => "none", # Remove any height constraints
        "height" => "auto" # Let content determine height
    ),

    CSS(
        ".slideshow-container .slideshow-content .cell-output",
        "font-size" => "1.2rem",
        "line-height" => "1.5",
        "margin" => "0.5rem 0",
        "width" => "100%",
        "max-height" => "none", # Remove any height constraints on output
        "overflow" => "visible" # Ensure content is fully visible
    ),

    # Markdown content in cells
    CSS(
        ".slideshow-content .markdown-body",
        "font-size" => "inherit",
        "line-height" => "inherit"
    ),

    CSS(
        ".slideshow-content .markdown-body h1",
        "font-size" => "3.5rem"
    ),

    CSS(
        ".slideshow-content .markdown-body h2",
        "font-size" => "2.8rem"
    ),

    CSS(
        ".slideshow-content .markdown-body h3",
        "font-size" => "2.2rem"
    ),

    CSS(
        ".slideshow-content .markdown-body p",
        "font-size" => "1.3rem",
        "margin-bottom" => "1.5rem"
    ),

    # Images and figures - exclude button icons
    CSS(
        ".slideshow-container .slideshow-content img:not(.small-button img):not(.small-button svg)",
        "max-width" => "100%",
        "height" => "auto",
        "margin" => "1rem 0",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 8px rgba(0, 0, 0, 0.1)"
    ),

    # Also ensure SVGs in content (but not in buttons) get the same treatment
    CSS(
        ".slideshow-container .slideshow-content svg:not(.small-button svg):not(.codicon svg)",
        "max-width" => "100%",
        "height" => "auto",
        "margin" => "1rem 0",
        "border-radius" => "8px",
        "box-shadow" => "0 2px 8px rgba(0, 0, 0, 0.1)"
    ),

    # Tables
    CSS(
        ".slideshow-content table",
        "font-size" => "1.1rem",
        "margin" => "1.5rem 0",
        "border-collapse" => "collapse",
        "width" => "100%"
    ),

    CSS(
        ".slideshow-content table th, .slideshow-content table td",
        "padding" => "0.8rem 1rem",
        "border" => "1px solid var(--border-primary)"
    ),

    CSS(
        ".slideshow-content table th",
        "background-color" => "var(--hover-bg)",
        "font-weight" => "600"
    )
)

function Bonito.jsrender(session::Session, slideshow::SlideshowBook)
    book = slideshow.book

    # Progress bar with container for tooltip area
    progress_container = DOM.div(
        DOM.div(class="progress-bar"),
        class="progress-container"
    )

    # Create tooltip widget for progress bar
    tooltip_content = "Slide navigation:\n• Arrow keys or spacebar to navigate\n• Click progress bar to jump to position"
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

            // Wait for DOM to be ready
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

                function update_slide() {
                    if (slide_elements.length === 0) return;

                    // Scroll the target element to the top of the container
                    const target_element = slide_elements[current_slide - 1];
                    if (target_element) {
                        target_element.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }

                    // Update progress bar
                    const progress = (current_slide / total_slides) * 100;
                    if (progress_bar) {
                        progress_bar.style.width = progress + '%';
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

                // Keyboard navigation
                document.addEventListener('keydown', function(e) {
                    if (e.key === 'ArrowRight' || e.key === ' ') {
                        e.preventDefault();
                        next_slide();
                    } else if (e.key === 'ArrowLeft') {
                        e.preventDefault();
                        prev_slide();
                    }
                });

                // Recalculate positions when content changes
                const observer = new MutationObserver(function(mutations) {
                    let needs_recalc = false;
                    mutations.forEach(function(mutation) {
                        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                            needs_recalc = true;
                        }
                    });

                    if (needs_recalc) {
                        setTimeout(function() {
                            find_slide_elements();
                            update_slide();
                        }, 100);
                    }
                });

                observer.observe(content_container, {
                    childList: true,
                    subtree: true
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

    return Bonito.jsrender(session, DOM.div(elements, SLIDESHOW_STYLES, final_container))
end


end
