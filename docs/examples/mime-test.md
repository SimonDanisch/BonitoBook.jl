# New Book

1 + 1

```julia (editor=true, logging=false, output=true)

```
```julia (editor=true, logging=false, output=true)
]add DataFrames
```
```julia (editor=true, logging=false, output=true)

```
```julia (editor=true, logging=false, output=true)

```
```python (editor=true, logging=false, output=true)
1 + 1
```
```julia (editor=true, logging=false, output=true)

```
```julia (editor=true, logging=false, output=true)
using DataFrames
DataFrame(A=1:3, B=5:7, fixed=1)
```
```julia (editor=true, logging=false, output=true)
?pretty_table
```
```julia (editor=true, logging=false, output=true)
]add Tables 
```
```julia (editor=true, logging=false, output=true)
using Tables
table = Tables.columntable(collect(i == 5 ? (a = missing, b = "string", c = nothing) :
                                   (a = i, b = Float64(i), c = 'a'-1+i) for i in 1:10))
```
```julia (editor=true, logging=false, output=true)
?subsup
```
```julia (editor=true, logging=false, output=true)
using LaTeXStrings
L"Trigonometric Functions: $\sin(x)$ and $\cos(x)$"
```
```julia (editor=true, logging=false, output=true)
L"1 + \alpha^2"
```
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
rand(Vec3f, 10000)
```
```julia (editor=true, logging=false, output=true)
struct LatexNum <: Number
end

function Base.show(io::IO, m::MIME"text/latex", num::LatexNum)
    show(io, m, L"""
    \int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi} \mathbf{A} = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}
    """)
end
LatexNum()
```
```julia (editor=true, logging=false, output=true)
rand(1000, 1000)
```
```julia (editor=true, logging=false, output=true)
"hello world"
```
Latex inline

```latex
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi} \mathbf{A} = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}
```

