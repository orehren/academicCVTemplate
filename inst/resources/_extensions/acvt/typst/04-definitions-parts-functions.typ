// typst/partial-functions.typ
// This file contains functions that generate major sections of the document,
// such as the title page, footer, and publication list.


// -- Footer Functions
// -------------------------
#let render-cover-letter(
  author,
  color-accent,
  text-style-header,
  recipient: none,
  date: datetime.today(),
  subject: none,
  cover_letter_content: [],
) = {

  // --- Header ---
  // Using a grid to align sender and recipient information.
  grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      #text(fill: color-accent, weight: "bold", author.firstname + " " + author.lastname) \
      #find_contact(author, "fa address-card") \
      #find_contact(author, "fa mobile-screen") \
      #find_contact(author, "fa envelope")
    ],
    [
    #if recipient != none or recipient == "" [
      #recipient.name \
      #recipient.address \
      #recipient.zip #recipient.city
      ]
    ]
  )

  // --- Date and Subject ---
  v(2em)
  align(right)[#date]
  v(2em)
  if subject != none or subject == "" {
    block(
      width: 100%,
      [
        #set text(..text-style-header)
        #align(left)[
            #strong[#text(fill: color-accent)[#subject.slice(0, 3)]#subject.slice(3)]
            #box(width: 1fr, line(length: 99%))
        ]
      ]
    )
    v(2em)
  }

  // --- Salutation ---
  if recipient != none or recipient == "" {
    "Dear " + recipient.salutation + ","
  }

  // --- Body ---
  v(1em)
  cover_letter_content

  // --- Closing ---
  v(2em)
  "Sincerely,"
  v(1em)
  author.firstname + " " + author.lastname
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
#let title-page(author, profile-photo: none) = {
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
    let cv-entries = args.named()
    let entry-values = cv-entries.values().map((value) => eval(value, mode: "markup"))
    map-cv-entry-values(entry-values)
}

// Creates research-interests
#let research-interests(..args) = {
    let cv-entries = args.named()
    let entry-values = cv-entries.values().map((value) => eval(value, mode: "markup"))
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
