# Mime Tests

#### Printing

```julia (editor=true, logging=false, output=true, id=2)
]st
```
#### Tables

```julia (editor=true, logging=false, output=true)
using DataFrames
DataFrame(A=1:3, B=5:7, fixed=1)
```
```julia (editor=true, logging=false, output=true)
Bonito.Table(DataFrame(A=1:3, B=5:7, fixed=1))
```
```julia (editor=true, logging=false, output=true, id=6)
table = [
    (Name="Alice", Age=28, City="New York", Salary=75000),
    (Name="Bob", Age=34, City="San Francisco", Salary=95000),
    (Name="Charlie", Age=29, City="Chicago", Salary=68000),
    (Name="Diana", Age=31, City="Boston", Salary=82000),
    (Name="Eve", Age=26, City="Seattle", Salary=78000)
]
Bonito.Table(table, class_callback=(t, ir, ic, val) -> begin
    ic == 4 || return "cell-default"
    val < 78000 && return "cell-bad"
    return "cell-good"
end)
```
#### Markdown

```julia (editor=true, logging=false, output=true)
md"""
# Markdown output

|              Method | Order of Accuracy |                            Error Bound | Computational Cost |
| -------------------:| -----------------:| --------------------------------------:| ------------------:|
|         Trapezoidal |          $O(h^2)$ | $-\frac{h^2}{12}f^{\prime\prime}(\xi)$ |                Low |
|      Simpson's Rule |          $O(h^4)$ |          $-\frac{h^4}{90}f^{(4)}(\xi)$ |           Moderate |
| Gaussian Quadrature |       $O(h^{2n})$ |                       Depends on nodes |               High |
"""
```
```julia (editor=true, logging=false, output=true)
?chomp
```
#### Latex

```julia (editor=true, logging=false, output=true)
using Makie.LaTeXStrings
L"Trigonometric Functions: $\sin(x)$ and $\cos(x)$"
```
```julia (editor=true, logging=false, output=true)
L"1 + \alpha^2"
```
```julia (editor=true, logging=false, output=true, id=12)
struct LatexNum <: Number
end

function Base.show(io::IO, m::MIME"text/latex", num::LatexNum)
    show(io, m, L"""
    \int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi} \mathbf{A} = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}
    """)
end
LatexNum()
```
Latex inline

```latex
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi} \mathbf{A} = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}
```

#### Arrays

```julia (editor=true, logging=false, output=true)
using GeometryBasics
rand(Vec3f, 10000)
```
```julia (editor=true, logging=false, output=true)
rand(1000, 1000)
```
#### Strings

```julia (editor=true, logging=false, output=true)
"hello world"
```
```julia (editor=true, logging=false, output=true)
view("adasd", 1:2)
```
