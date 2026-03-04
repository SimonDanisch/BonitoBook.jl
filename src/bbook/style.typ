// BonitoBook default Typst template
// Customize by creating .bbook/style.typ in your book folder

#set page(margin: 2cm, paper: "a4")
#set text(font: "New Computer Modern", size: 11pt)
#set heading(numbering: "1.1")
#set par(justify: true, leading: 0.65em)

#show raw.where(block: true): set block(
  fill: luma(245), inset: 8pt, radius: 4pt, width: 100%
)

#show link: underline
