using Revise, BonitoBook, WGLMakie, Bonito

BonitoBook.book("bbook-presentation.md"; plugin=BonitoBook.SlideshowBooks)

book = BonitoBook.Book("data-cleaning.md");
app = App(book)


Server(app, "0.0.0.0", 8080)
