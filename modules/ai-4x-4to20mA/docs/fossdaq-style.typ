// ============================================================
//  FOSSDAQ documentation style
//  Restrained, print-friendly layout for module manuals and
//  system-level documents. Derived from the original
//  Projektarbeit-1 report style (HTWG Konstanz, 2025/26).
//
//  Usage:
//      #import "fossdaq-style.typ": *
//      #show: doc => setup-doc(doc, doc-title: "pi-base — Build Manual")
// ============================================================

// --- Colors (deliberately reduced) ---
#let col-dark   = rgb("#000000")
#let col-grey   = rgb("#444444")
#let rule-grey  = rgb("#888888")
#let box-grey   = rgb("#bfbfbf")
#let box-bg     = rgb("#f5f5f5")
#let warn-red   = rgb("#8b1a1a")

// --- Fonts: sans-serif throughout (manual style), with fallbacks ---
#let font-main = ("Arial", "Helvetica Neue", "Calibri", "Carlito", "Liberation Sans")
#let font-sans  = font-main
#let font-mono  = ("Consolas", "Menlo", "JetBrainsMono NF", "Courier New")

#let project-name = "FOSSDAQ"

// --- Global page and text setup ---
#let setup-doc(doc, doc-title: "") = {
  set page(
    paper: "a4",
    margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
    header: context {
      if counter(page).get().first() > 1 [
        #set text(size: 9pt, font: font-main, fill: col-grey)
        #grid(
          columns: (1fr, 1fr),
          align(left)[#doc-title],
          align(right)[#project-name],
        )
        #line(length: 100%, stroke: 0.4pt + rule-grey)
      ]
    },
    footer: context {
      set text(size: 9pt, font: font-main, fill: col-grey)
      align(right)[Page #counter(page).display() / #counter(page).final().first()]
    },
  )

  set text(font: font-main, size: 11pt, lang: "en", hyphenate: true)
  set par(justify: true, leading: 0.65em, spacing: 1.1em, first-line-indent: 0pt)
  show raw: set text(font: font-mono, size: 9.5pt)

  // Levels 1 and 2 numbered (1, 1.1), level 3 unnumbered
  set heading(numbering: (..n) => {
    let nums = n.pos()
    if nums.len() >= 3 { none } else { numbering("1.1", ..nums) }
  }, supplement: [Section])
  show heading: set text(font: font-main, fill: col-dark, weight: "bold")
  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    v(0.4em)
    block(below: 0.8em)[
      #text(size: 18pt, weight: "bold")[#it]
    ]
  }
  show heading.where(level: 2): it => {
    v(0.4em)
    block(below: 0.75em)[
      #text(size: 13pt, weight: "bold", fill: col-dark)[#it]
    ]
  }
  show heading.where(level: 3): it => {
    v(0.3em)
    block(below: 0.6em, inset: 0pt)[
      #set par(first-line-indent: 0pt, hanging-indent: 0pt)
      #text(size: 11.5pt, weight: "bold", fill: col-dark)[#it.body]
    ]
  }

  show figure.caption: it => {
    set text(size: 9.5pt, font: font-main, style: "italic", fill: col-grey)
    it
  }

  doc
}

// --- Table: grey header row, subtle rules ---
#let spec-table(headers, ..rows) = {
  let data = rows.pos()
  let ncols = headers.len()
  set text(size: 10pt, font: font-main)
  table(
    columns: ncols * (auto,),
    inset: (x: 6pt, y: 4pt),
    stroke: 0.4pt + rule-grey,
    fill: (_, row) => {
      if row == 0 { rgb("#e6e6e6") } else { white }
    },
    ..headers.map(h => text(fill: col-dark, weight: "bold", size: 10pt, h)),
    ..data.flatten(),
  )
}

// --- Note boxes ---
#let box-base(title, body) = {
  block(
    width: 100%,
    fill: box-bg,
    stroke: 0.5pt + box-grey,
    inset: (x: 10pt, y: 8pt),
    spacing: 1.1em,
  )[
    #text(font: font-main, weight: "bold", size: 10.5pt, fill: col-dark)[#title]
    #v(0.2em)
    #set text(size: 10.5pt)
    #body
  ]
}

#let info-box(title: "Note", body) = box-base(title, body)
#let tip-box(title: "Tip", body) = box-base(title, body)

#let warn-box(title: "Warning", body) = block(
  width: 100%,
  fill: box-bg,
  stroke: 0.5pt + box-grey,
  inset: (x: 10pt, y: 8pt),
  spacing: 1.1em,
)[
  #text(font: font-main, weight: "bold", size: 10.5pt, fill: warn-red)[#title]
  #v(0.2em)
  #set text(size: 10.5pt)
  #body
]

// --- Numbered step list ---
#let steps(..items) = {
  let xs = items.pos()
  for (i, it) in xs.enumerate() {
    block(spacing: 0.9em, above: 0.5em)[
      #grid(
        columns: (1.6em, 1fr),
        column-gutter: 0.6em,
        align(right + top)[
          #text(font: font-main, weight: "bold", fill: col-dark)[#(i + 1).]
        ],
        it,
      )
    ]
  }
}

// --- Two images side by side ---
#let two-images(a, a-caption, b, b-caption, height: none) = {
  let img = p => if height == none { image(p, width: 100%) } else { image(p, height: height) }
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1em,
    align(horizon + center, figure(img(a), caption: a-caption)),
    align(horizon + center, figure(img(b), caption: b-caption)),
  )
}

// --- Intro block: italic summary with grey left rule ---
#let doc-intro(body) = {
  block(
    width: 100%,
    stroke: (left: 2pt + box-grey),
    inset: (x: 12pt, y: 4pt),
    spacing: 1.3em,
  )[
    #set text(size: 10.5pt, font: font-main, style: "italic", fill: col-grey)
    #body
  ]
}

// --- Simple cover block for module manuals ---
#let doc-cover(title, subtitle, meta) = {
  v(2cm)
  align(center)[
    #text(font: font-main, size: 15pt, fill: col-grey)[#project-name]
    #v(0.2cm)
    #text(font: font-main, size: 24pt, weight: "bold", fill: col-dark)[#title]
    #v(0.5cm)
    #text(font: font-main, size: 14pt, fill: col-dark)[#subtitle]
    #v(1.6cm)
    #table(
      columns: (auto, auto),
      stroke: none, inset: 7pt,
      align: (right, left),
      ..meta.map(((k, v)) => (
        text(font: font-main, weight: "bold")[#k],
        text(font: font-main)[#v],
      )).flatten(),
    )
  ]
  pagebreak()
}
