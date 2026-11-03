module AutoPluginBook
using BonitoBook
using BonitoBook.SlideshowBooks

create_book(book::BonitoBook.Book; kwargs...) = BonitoBook.SlideshowBooks.create_book(book; kwargs...)

end
