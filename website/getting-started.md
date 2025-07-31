# Getting Started with BonitoBook

Welcome to BonitoBook! This interactive guide will help you get up and running with creating beautiful, executable notebooks.

## Installation

Install BonitoBook using Julia's package manager:

```julia
using Pkg
Pkg.add("BonitoBook")
```

## Creating Your First Book

Let's create a simple book to demonstrate the basic functionality:

```julia
using BonitoBook

# Create a new book from a markdown file
book = Book("mybook.md")
```

## Basic Usage

BonitoBook supports multiple cell types. Here are some examples:
