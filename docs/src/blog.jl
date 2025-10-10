# Blog page showing all BonitoBook blog posts

using BonitoSites
using BonitoSites.Dates

blogposts(files...) = normpath(joinpath(@__DIR__, "blogposts", files...))

function all_posts()
    folders = filter(isdir, readdir(blogposts(); join=true))
    entries = map(folders) do dir
        dir = normpath(dir)
        path = joinpath(dir, "post.xml")
        return dir => BonitoSites.from_xml(path)
    end
    return sort!(entries; by=x -> x[2].date, rev=true)
end

function add_blogposts!(routes)
    entries = all_posts()
    for (dir, entry) in entries
        route = replace(entry.link, "./" => "/")
        routes[route] = App(title=entry.title) do
            # Use BonitoBook's InlineBook to render the markdown file
            post_file = joinpath(dir, "post.md")
            book = BonitoBook.InlineBook(post_file)

            # Add metadata header
            human_date = Dates.format(entry.date, "e, d u Y")
            date_div = DOM.div(human_date; class="post-date", style="color: #666; margin-bottom: 1rem; text-align: center;")

            # Bluesky comments if available
            bsky = isempty(entry.bsky_link) ? nothing : BonitoSites.BlueSkyComment(entry.bsky_link)

            content = DOM.div(
                date_div,
                book,
                bsky,
                class="blog-post-content"
            )

            return Page(content, entry.title)
        end
    end
    return routes
end

function blog()
    intro = DOM.section(
        DOM.h1("Blog", class="section-title"),
        DOM.p(
            "Stay updated with the latest BonitoBook news, features, and tutorials.",
            class="section-content"
        )
    )

    # RSS feed link
    rss_link = DOM.link(
        rel="alternate",
        type="application/rss+xml",
        title="BonitoBook Blog RSS feed",
        href="./rss.xml"
    )

    entries = all_posts()
    blog_cards = map(entries) do (dir, entry)
        # Create a card for each blog post
        human_date = Dates.format(entry.date, "e, d u Y")
        route = replace(entry.link, "./" => "/")

        DOM.div(
            DOM.h3(entry.title, class="example-title"),
            DOM.p(entry.description, class="example-description"),
            DOM.p(human_date, class="blog-date", style="color: var(--site-text-secondary); font-size: 0.9rem; margin-bottom: 1rem;"),
            DOM.a(
                "Read More",
                href=Bonito.Link(route),
                class="example-link"
            ),
            class="example-card"
        )
    end

    blog_grid = DOM.div(
        blog_cards...,
        class="examples-grid"
    )

    content = DOM.div(
        rss_link,
        intro,
        blog_grid;
        class="example-content"
    )

    return Page(content, "BonitoBook Blog")
end

export blog, add_blogposts!, all_posts
