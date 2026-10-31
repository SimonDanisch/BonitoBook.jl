# New Book

```julia (editor=true, logging=false, output=true)
categories = ["Deciduous", "Deciduous", "Evergreen", "Evergreen", "Evergreen"]
species = ["Beech", "Oak", "Fir", "Spruce", "Pine"]
fake_data = [
    "35m" "40m" "38m" "27m" "29m"
    "10k" "12k" "18k" "9k" "7k"
    "500yr" "800yr" "600yr" "700yr" "400yr"
    "80\$" "150\$" "40\$" "70\$" "50\$"
]
labels = ["", "", "Size", Annotated("Water consumption", "Liters per year"), "Age", "Value"]

body = [
    Cell.(categories, bold = true, merge = true, border_bottom = true)';
    Cell.(species)';
    Cell.(fake_data)
]

Table(hcat(
    Cell.(labels, italic = true, halign = :right),
    body
))
```
