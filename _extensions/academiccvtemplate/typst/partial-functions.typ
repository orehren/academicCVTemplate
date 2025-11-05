// typst/partial-functions.typ
// This file contains functions that generate major sections of the document,
// such as the title page, footer, and publication list.

#import "styling.typ": *
#import "metadata.typ": author, title, position

// Creates the footer content.
#let create-footer(author) = {
    set text(..text-style-footer)
    
    grid(..grid-style-footer,
        [#author.firstname #author.lastname],
        render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em)),
        context text()[#counter(page).display("1/1", both: true)]
    )
}

// Creates the title page layout.
#let title-page(author, profile-photo) = {
    set page(footer: none)
    v(1fr)

    grid(..grid-style-titlepage,
        grid.cell(x: 1, y: 1, align: left + bottom)[
            #set text(..text-style-title-name)
            #text(weight: "light")[#author.firstname] #author.lastname \
            #text(..text-style-title-position)[#position]
        ],
        grid.cell(x: 2, y: 1, align: right + bottom)[
            #if profile-photo != none and profile-photo != "" {
                image(profile-photo, width: 100pt)
            }
        ],
        grid.cell(y: 3, colspan: 4)[ 
            #set text(..text-style-title-contacts)
            #render-author-details-list(author.at("contact"), color-accent, separator: h(0.5em))
        ],
        grid.cell(y: 4, colspan: 4)[ 
            #set text(..text-style-title-contacts)
            #render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em))
        ]
    )
    v(2fr)

    grid(..grid-style-toc,
        grid.cell(x: 1)[
            #outline(title: [Table of Contents], depth: 1)
        ]
    )
}

// Formats individual cells within a resume entry grid based on their index.
#let format-section-cells(index, value) = {
    let cell-content = value

    if index == 0 { // First column, first row
        align(right + horizon)[#text(..text-style-label-accent)[#cell-content]]
    } else if index == 1 { // Second column, first row
        align(left + horizon)[#text(..text-style-bold)[#cell-content]]
    } else if calc.even(index) { // Even columns >= 2 
        align(right + horizon)[#text(..text-style-label)[#cell-content]]
    } else if index == 3 { // Description
        align(left + horizon)[#text(..text-style-default)[#cell-content]]
    } else { // Odd columns >= 5
        align(left + horizon)[#text(..text-style-details)[#cell-content]]
    }
}

#let map-cv-entry-values(entry-values, startindex: 0) = {
  grid(
    ..entry-values.enumerate(start: startindex).map(((i, value)) => 
      format-section-cells(i, value)
    )
  )
}

// Creates a dynamic two-column grid for CV entries.
#let resume-entry(..args) = {
    let cv-entries = args.named()
    let entry-values = cv-entries.values().map((value) => eval(value, mode: "markup"))
    map-cv-entry-values(entry-values)
}

#let research-interests(..args) = {
    let cv-entries = args.named()
    let entry-values = cv-entries.values().map((value) => eval(value, mode: "markup"))
    map-cv-entry-values(entry-values, startindex: 4)
}

// Renders the publication list from a structured array of entries.
#let publication-list(entries) = {
  let cells = ()
  let prev-label = none

  for entry in entries {
    let is_new_label = prev-label == none or entry.label != prev-label

    if is_new_label and prev-label != none {
      // Add vertical spacing between groups.
      cells.push(grid.cell(colspan: 2, inset: (top: 0.2em))[])
    }

    // Left cell: Group label (e.g., "Journal Articles").
    cells.push(
      if is_new_label {
        align(end + top)[#text(..text-style-label)[#entry.label]]
      } else { [] }
    )

    // Right cell: The publication entry itself.
    cells.push(
      align(start + top)[
        #text(..text-style-publication)[#eval(entry.item, mode: "markup")]
      ]
    )
    prev-label = entry.label
  }

  grid(..grid-style-default, ..cells)
}
