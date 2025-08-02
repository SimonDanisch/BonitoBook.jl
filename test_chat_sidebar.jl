using BonitoBook
using Bonito

# Create a custom chat agent for testing
struct TestChatAgent <: ChatAgent end

function BonitoBook.prompt(agent::TestChatAgent, question::String)
    if occursin("hello", lowercase(question))
        return "Hello! I'm your AI assistant in BonitoBook. How can I help you today?"
    elseif occursin("code", lowercase(question))
        return "I can help you with code! What programming language are you working with?"
    else
        return "I received your message: '$question'. Feel free to ask me anything!"
    end
end

# Create a simple markdown book to test with
book_content = """
# Test Book with Chat

This is a test book to demonstrate the chat integration in the sidebar.

## Code Cell

```julia
println("Hello from BonitoBook!")
```

## Another Cell

```julia
x = 1:10
y = x.^2
```
"""

# Write the test book
mkpath("test_book")
write("test_book/book.md", book_content)

# Create and run the book
book = Book("test_book/book.md")

println("Book created with chat sidebar integration!")
println("The chat is available in the sidebar - click the chat icon to open it.")
println("Try typing 'hello' or asking about 'code' to see responses.")

# Run the book app
App(book)