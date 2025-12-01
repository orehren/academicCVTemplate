// typst/partial-functions.typ
// This file contains functions that generate major sections of the document,
// such as the title page, footer, and publication list.

#let render-cover-letter(
  title: none,
  author: (:),           // Erwartet dictionary mit firstname, lastname, contact, socialmedia
  profile-photo: none,   // Pfad als String
  recipient: (:),        // Erwartet dictionary mit salutation, name, addressee, address, city, zip, valediction
  date: none,
  subject: none,
  position: none,
  famous-quote: none,    // Erwartet dictionary mit text, attribution
  style: (:),            // Erwartet dictionary mit color-accent, font-header, font-text
  cover_letter_content: [],
) = {

  let gray-text = rgb("#5d5d5d")
  let light-gray = rgb("#999999")

  // --- 2. Seiteneinstellungen ---
  set page(
    paper: "a4",
    margin: (top: 2cm, bottom: 2cm, left: 2cm, right: 2cm),
    footer: [
      #set text(fill: light-gray, size: 8pt)
      #upper(if date != none { date })
      #h(1fr)
      #upper(
        author.at("firstname", default: "") + " " +
        author.at("lastname", default: "") + sym.dot.op + " " + title
      )
    ]
  )

  set text(font: font-text, size: 10pt, lang: "en")
  set par(justify: true, leading: 0.8em)

  // --- 3. HEADER BEREICH (Awesome CV Style) ---
  grid(
    columns: (2.5cm, 1fr),
    gutter: 1cm,

    // Spalte 1: Profilbild
    if profile-photo != none and profile-photo != "" {
      box(
        radius: 50%,
        clip: true,
        stroke: 0.5pt + color-accent,
        width: 2.5cm,
        height: 2.5cm,
        image(profile-photo, fit: "cover")
      )
    } else {
      // Leerer Platzhalter, damit das Layout nicht springt, falls kein Bild da ist
      circle(radius: 1.25cm, fill: rgb("#eeeeee"))
    },

    // Spalte 2: Kopfdaten (Rechtsbündig)
    align(right)[
      // Name
      #text(font: font-header, size: 24pt, weight: "bold")[
        #author.at("firstname", default: "") #author.at("lastname", default: "")
      ]
      #v(-5pt)

      // Position
      #if position != none and position != "" {
        text(font: font-header, size: 9pt, fill: color-accent, weight: "bold", tracking: 1pt)[
          #upper(position)
        ]
      }
      #v(5pt)

      // Kontakt & Social Media
      #set text(size: 8pt, fill: gray-text)

      // Hier rufen wir die gewünschte Hilfsfunktion auf
      #if author.at("contact", default: none) != none and author.at("contact", default: none) != "" {
        render-author-details-list(author.at("contact"), color-accent, separator: h(0.5em))
      }

      #if author.at("socialmedia", default: none) != none and author.at("socialmedia", default: none) != "" {
        // Kleiner Abstand, falls beides existiert
        if author.at("contact", default: none) != none and author.at("socialmedia", default: none) != "" { v(2pt) }
        render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em))
      }

      // Zitat (Famous Quote)
      #if famous-quote != none and famous-quote != "" {
        v(5pt)
        let q-text = famous-quote.at("text", default: "")
        let q-attr = famous-quote.at("attribution", default: "")

        if q-text != "" {
          text(size: 9pt, fill: color-accent, style: "italic")[
            “#q-text” #if q-attr != "" { [- #q-attr] }
          ]
        }
      }
    ]
  )

  v(1.5cm) // Abstand nach Header

  // --- 4. EMPFÄNGER & DATUM ---
  grid(
    columns: (1fr, auto),
    // Linke Seite: Empfängeradresse
    align(left)[
      #set text(font: font-header)

      // Firmenname / Addressee
      #if recipient.at("addressee", default: none) != none and recipient.at("addressee", default: none) != "" {
        text(weight: "bold")[#recipient.at("addressee")]
      }

      // Straße
      #if recipient.at("address", default: none) != none and recipient.at("address", default: none) != "" {
        text(fill: gray-text)[#recipient.at("address")]
      }

      // PLZ & Stadt
      #let zip = recipient.at("zip", default: "")
      #let city = recipient.at("city", default: "")
      #if zip != "" or city != "" {
        text(fill: gray-text)[#zip #city]
      }
    ],
    // Rechte Seite: Datum
    align(right + bottom)[
      #text(fill: light-gray, style: "italic")[
        #if date != none and date != "" { date }
      ]
    ]
  )

  v(1cm)

  // --- 5. BETREFF & ANREDE ---

  if subject != none and subject != "" {
    text(font: font-header, weight: "bold")[#underline[#subject]]
    v(0.5em)
  }

  // Anrede (Salutation + Name)
  let salutation = recipient.at("salutation", default: "Dear")
  let name = recipient.at("name", default: "")

  text(fill: gray-text)[#salutation #name,]

  v(0.5em)

  // --- 6. BODY CONTENT ---

  if cover_letter_content != none and cover_letter_content != "" {
    cover_letter_content
  }

  v(1cm)

  // --- 7. GRUẞFORMEL (Valediction) ---

  let valediction = recipient.at("valediction", default: "Sincerely,")

  text(fill: black)[
    #valediction
    #text(font: font-header, weight: "bold")[
      #author.at("firstname", default: "") #author.at("lastname", default: "")
    ]
  ]
}


// Creates the footer content.
#let create-footer(author) = {
    set text(..text-style-footer)

    grid(..grid-style-footer,
        [#author.firstname #author.lastname],
        render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em)),
        context text()[#counter(page).display("1/1", both: true)]
    )
}

// -- Title Page Functions
// -------------------------

// Creates the title page layout.
#let title-page(author, profile-photo: none, position: none) = {
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

// -- Resume Entry Functions
// -------------------------

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

// Map cell values
#let map-cv-entry-values(entry-values, startindex: 0) = {
  grid(
    ..entry-values.enumerate(start: startindex).map(((i, value)) =>
      format-section-cells(i, value)
    )
  )
}

// Creates a dynamic two-column grid for CV entries.
#let resume-entry(..args) = {
    let entry-values = args.pos().map((value) => eval(value, mode: "markup"))

    map-cv-entry-values(entry-values)
}

// Creates research-interests
#let research-interests(..args) = {
    let entry-values = args.pos().map((value) => eval(value, mode: "markup"))

    map-cv-entry-values(entry-values, startindex: 4)
}


// -- Skillbar Functions
// ------------------------

// prepare skillbar
#let skill-bar-components(
  skill,
  value,
  level,
  bar_width: 80%,
  bar_height: 0.4em,
  bar_radius: 1.5pt,
  bar_stroke: (paint: color-nord4, thickness: 0.5pt),
  bar_fill_empty: luma(240),
  bar_fill_progress: color-accent
) = {
  assert(value >= 0.0 and value <= 1.0, message: "skill-bar: 'value' must be between 0.0 and 1.0.")

  let name_component = text(..text-style-skill-name)[#skill]


  let bar_component = box(
    width: bar_width,
    height: bar_height,
    radius: bar_radius,
    fill: none,
    stroke: bar_stroke,
    clip: true
  )[
    #grid(
      columns: (value * 100%, (1.0 - value) * 100%),
      rows: (100%),
      gutter: 0pt,
      if value > 0.0 {
        rect(width: 100%, height: 100%, fill: bar_fill_progress, stroke: none)
      },
      if value < 1.0 {
        rect(width: 100%, height: 100%, fill: bar_fill_empty, stroke: none)
      }
    )
  ]

  let level_component = text(..text-style-skill-level)[#level]

  return (name: name_component, bar: bar_component, level: level_component)
}

// combine skills to table
#let create-skill-table(grouped_skills) = {
  for (area, skills_in_area) in grouped_skills.pairs().sorted(key: p => p.at(0)) {
    if skills_in_area.len() == 0 { continue }

    let area_components = skills_in_area.map(entry =>
      skill-bar-components(
        entry.at("skill"),
        float(entry.at("value")),
        entry.at("level")
      )
    )

    let skill_row_cells = area_components.map(comp => comp.name)
    let bar_row_cells = area_components.map(comp => comp.bar)
    let level_row_cells = area_components.map(comp => comp.level)

    let inner_table_content = table(
      columns: skills_in_area.len(),
      stroke: none,
      fill: none,
      align: center + horizon,
      column-gutter: 0.1em,
      row-gutter: 0.04em,
      ..skill_row_cells,
      ..bar_row_cells,
      ..level_row_cells
    )

    map-cv-entry-values((area, inner_table_content))
  }
}

// visualiue skills table
#let visualize-skills-list(
  skills_list
) = {
  let grouped_skills_map = group-by-field(skills_list, "area")

  if grouped_skills_map.len() == 0 {
    return
  }

  create-skill-table(grouped_skills_map)
}

// -- Publications List Functions
// ------------------------------

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
