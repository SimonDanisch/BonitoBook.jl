# Test file specifically for book_display function
using Test
using BonitoBook

@testset "book_display Function Tests" begin
    @testset "Basic Functionality" begin
        # Test nothing handling
        @test BonitoBook.book_display(nothing) === nothing
        
        # Test that non-nothing values return DOM.pre elements
        result = BonitoBook.book_display(42)
        @test result isa BonitoBook.Bonito.DOM.Node
        @test result.tag == "pre"
    end
    
    @testset "Array Formatting" begin
        # Simple array
        arr = [1, 2, 3, 4, 5]
        result = BonitoBook.book_display(arr)
        @test result isa BonitoBook.Bonito.DOM.Node
        @test result.tag == "pre"
        
        # Check that the content includes REPL-style formatting
        content = string(result.children[1])
        @test occursin("5-element Vector{Int64}:", content)
        @test occursin(" 1", content)  # Check proper spacing
        @test occursin(" 2", content)
        
        # Nested array
        nested = [[1, 2], [3, 4]]
        nested_result = BonitoBook.book_display(nested)
        nested_content = string(nested_result.children[1])
        @test occursin("2-element Vector{Vector{Int64}}:", nested_content)
        
        # String array
        strings = ["hello", "world"]
        string_result = BonitoBook.book_display(strings)
        string_content = string(string_result.children[1])
        @test occursin("2-element Vector{String}:", string_content)
        @test occursin("\"hello\"", string_content)
        @test occursin("\"world\"", string_content)
    end
    
    @testset "Matrix Formatting" begin
        # Matrix
        matrix = [1 2 3; 4 5 6]
        result = BonitoBook.book_display(matrix)
        content = string(result.children[1])
        @test occursin("2×3 Matrix{Int64}:", content)
        @test occursin("1  2  3", content)
        @test occursin("4  5  6", content)
    end
    
    @testset "Special Types" begin
        # Complex numbers
        complex_arr = [1+2im, 3+4im]
        result = BonitoBook.book_display(complex_arr)
        content = string(result.children[1])
        @test occursin("Complex{Int64}", content)
        @test occursin("1 + 2im", content)
        
        # Boolean array
        bool_arr = [true, false, true]
        result = BonitoBook.book_display(bool_arr)
        content = string(result.children[1])
        @test occursin("3-element Vector{Bool}:", content)
        
        # Empty array
        empty_arr = Int64[]
        result = BonitoBook.book_display(empty_arr)
        content = string(result.children[1])
        @test occursin("0-element Vector{Int64}", content)
    end
    
    @testset "CSS Styling" begin
        # Check that the DOM.pre element has proper styling for non-LaTeX output
        result = BonitoBook.book_display([1, 2, 3])
        @test result isa BonitoBook.Bonito.DOM.Node
        @test result.tag == "pre"
        @test haskey(result.attributes, :style)
        style = result.attributes[:style]
        @test occursin("white-space: pre", style)
        @test occursin("font-family: inherit", style)
        @test occursin("margin: 0", style)
    end
    
    @testset "Trailing Newline" begin
        # Check that trailing newline is added
        result = BonitoBook.book_display(42)
        content = string(result.children[1])
        @test endswith(content, "\n")
        
        # Check array also has trailing newline
        arr_result = BonitoBook.book_display([1, 2, 3])
        arr_content = string(arr_result.children[1])
        @test endswith(arr_content, "\n")
    end
    
    @testset "Large Array Truncation" begin
        # Test that large arrays get truncated with Julia's built-in limit
        large_array = collect(1:1000)
        result = BonitoBook.book_display(large_array)
        content = string(result.children[1])
        
        # Should contain the ellipsis for truncation
        @test occursin("⋮", content)
        
        # Should still show type information
        @test occursin("1000-element Vector{Int64}:", content)
        
        # Should be much shorter than full display
        lines = split(content, "\n")
        @test length(lines) < 50  # Much less than 1000+ lines
    end
    
    @testset "LaTeX Output Support" begin
        # Create a mock type that supports LaTeX output
        struct MockLatexType
            value::String
        end
        
        # Define show method for LaTeX MIME type
        function Base.show(io::IO, ::MIME"text/latex", obj::MockLatexType)
            print(io, "\\frac{1}{", obj.value, "}")
        end
        
        # Test that LaTeX output is detected and rendered
        latex_obj = MockLatexType("x")
        result = BonitoBook.book_display(latex_obj)
        
        # Should return a MathJax object, not a DOM.pre
        @test !isa(result, BonitoBook.Bonito.DOM.Node)
        # Note: We can't easily test the exact MathJax type without more complex setup
        # but we can verify it's not the fallback DOM.pre element
    end
end