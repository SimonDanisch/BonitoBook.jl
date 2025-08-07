# BonitoBook

[![Build Status](https://github.com/SimonDanisch/BonitoBook.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SimonDanisch/BonitoBook.jl/actions/workflows/CI.yml?query=branch%3Amain)

[website](https://bonitobook.org/website/)

```julia
using Pkg
Pkg.add("https://github.com/SimonDanisch/BonitoBook.jl/")
using BonitoBook
# Usage:
BonitoBook.book("path-to-notebook-file")
# Example notebooks:
path = normpath(joinpath(dirname(pathof(BonitoBook)), "..", "docs", "examples"))
BonitoBook.book(joinpath(path, "intro.md"))
BonitoBook.book(joinpath(path, "sunny.md"))
BonitoBook.book(joinpath(path, "juliacon25.md"))
```


## License

BonitoBook.jl is dual-licensed:

- **Non-commercial use:** Licensed under the PolyForm Noncommercial License 1.0.0. See [LICENSE](LICENSE).
- **Commercial use:** Requires a commercial license. Contact info@makie.org for pricing and details.
