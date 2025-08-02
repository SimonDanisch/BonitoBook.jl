using BonitoBook
using Bonito

# Create a simple test book
book_content = """
# Test Sidebar Switching

This is a test to verify the sidebar widget switching works correctly.

## Test Cell

```julia
println("Testing sidebar switching...")
```
"""

# Write the test book
mkpath("test_sidebar_book")
write("test_sidebar_book/book.md", book_content)

# Create the book
book = Book("test_sidebar_book/book.md")

println("Book created with sidebar containing File Editor and AI Chat widgets.")
println("Instructions:")
println("1. Click the file icon to open the File Editor")
println("2. Click the chat icon to switch to AI Chat")
println("3. Click the active icon again to close the sidebar")
println("4. Use the sidebar toggle button (right arrow) when sidebar is closed")

# Run the book app
App(book)