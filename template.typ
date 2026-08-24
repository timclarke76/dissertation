#let template(
  title: "Assignment Title",
  assignment: "Assignment Name",
  abstractTitle: "Abstract title",
  abstract: "Abstract text",
  body) = [
  #set page(
    margin: (x: 1.5cm, y: 2cm),

    header: [
      #set text(size: 8pt, fill: luma(120))
      #title
      #h(1fr)
      #assignment
    ],

    footer: [
      #set text(size: 8pt, fill: luma(120))
      #align(right)[#context {
        let current = counter(page).get().first()
        let total = counter(page).final().first()
        [Page #current of #total]
      }]
    ]
  )

  #set heading(numbering: "1.")
  #show heading.where(level: 1): set text(size: 11pt)
  #show heading.where(level: 2): set text(size: 10pt)
  #show heading.where(level: 3): set text(size: 9pt)
  #show heading.where(level: 4): set text(size: 9pt)

  #set par(
    justify: true,
    leading: 0.55em,
    spacing: 1.0em,
  )

  #set text(
    font: "Libertinus Serif",
    size: 9pt,
    kerning: true,
    ligatures: true,
  )

  #show figure.caption: set text(size: 0.8em, style: "italic")

  #show table.cell.where(y: 0): strong
  #set table(
    stroke: (x, y) => if y == 0 {
      (bottom: 1.2pt + black)
    },
  )

  /*
  #show raw.where(block: false): r => {
    let words = r.text.split(" ")
    for (idx, word) in words.enumerate() {
      let w-radius = if words.len() == 1 {
        0.5em
      } else if idx == 0 {
        (left: 0.5em)
      } else if idx == words.len() - 1 {
        (right: 0.5em)
      } else {
        0pt
      }

      box(
        fill: luma(230),
        outset: (y: 3pt),
        inset: (x: 2pt),
        radius: w-radius,
        word
      )
    }
  }
  */

  #show raw.where(block: true): set block(fill: luma(245),
    // outset: (left: -1em, right: -1em),
    inset: (left: 0.5em, right: 0.5em, top: 0.5em, bottom: 0.5em),
    radius: 0.25em, width: 100%)

  #set list(indent: 1em)
  #set enum(indent: 1em)

  #let col(body, color: rgb("#367E6A")) = {
    set text(fill: color)
    [#body]
  }

  #align(center)[
    *#abstractTitle*

    #v(0.5em)

    *Timothy Clarke* \
    School of Science and Engineering \
    University of Dundee \
    2712139\@dundee.ac.uk
    #v(0.5em)
    *Abstract / Executive Summary*
  ]
  #pad(x: 2em)[
    #abstract
  ]

  #align(center)[
    #v(0.5em)
    #line(stroke: (0.7pt + gray), length: 75%)
    #v(0.5em)
  ]

  #body
]

#let ct(body, color: rgb("#D80000")) = {
  set text(fill: color)
  [#body]
}

#let todo(body) = {ct([TODO: #body])}

#let wc(body) = word-count(total => [
  #body
  #set text(size: 0.8em, style: "italic")
  #align(right)[#{total.words - 1}]
])

