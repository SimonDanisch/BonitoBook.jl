# New Book

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
```julia (editor=true, logging=false, output=true)
Errorba
```
Why you not work?

```latex
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi} \mathbf{A} = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}
```

