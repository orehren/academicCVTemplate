// typst/partial-functions.typ
// Functions to create partials (header, footer, etc.) 

// -- Imports --
// -------------
// #import "@preview/fontawesome:0.5.0": *
// #import "helper-functions.typ": *
#import "styling.typ": *
#import "metadata.typ": author, title, position


// -- Partials Functions --
// ------------------------

// Creates the footer content.
#let create-footer(author) = {
    set text(..text-style-footer)
    
    grid(..grid-style-footer,

        [#author.firstname #author.lastname],

        render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em)),

        // `context` needed for reliable page counter evaluation.
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
        align(right + horizon)[
            #text(..text-style-label-accent)[#cell-content]
        ]
    } else if index == 1 { // Second column, first row
        align(left + horizon)[
            #text(..text-style-bold)[#cell-content]
        ]
    } else if calc.even(index) { // Even columns >= 2 
        align(right + horizon)[
            #text(..text-style-label)[#cell-content]
        ]
    } else if index == 3 { // Description
        align(left + horizon)[
            #text(..text-style-default)[#cell-content]
        ]
    } else { // Odd columns >= 5
        align(left + horizon)[
            #text(..text-style-details)[#cell-content]
        ]
    }
}

#let map-cv-entry-values(entry-values, startindex: 0) = {
  grid(
    ..entry-values.enumerate(start: startindex).map(((i, value)) => 
      format-section-cells(i, value)
    )
  )
}

// -- 5. Layout Component Functions --
// -----------------------------------

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


#let visualize-skills-list(
  skills_list
) = {
  let grouped_skills_map = group-by-field(skills_list, "area")
  
  if grouped_skills_map.len() == 0 {
    return
  }

  create-skill-table(grouped_skills_map)
}


// render the publication list
#let publication-list(entries) = {
  let cells = ()
  let prev-label = none

  for entry in entries {
    let is_new_label = prev-label == none or entry.label != prev-label

    if is_new_label and prev-label != none {
      // Abstand zwischen Gruppen
      cells.push(grid.cell(colspan: 2, inset: (top: 0.2em))[]) // Abstand inline
    }

    // Linke Zelle: Label (konsistente Formatierung)
    cells.push(
      if is_new_label {
        align(end + top)[ // Konsistente Ausrichtung
          #text(..text-style-label)[#entry.label] // Konsistenter Stil
        ]
      } else { [] }
    )

    // Rechte Zelle: Publikationseintrag
    cells.push(
      align(start + top)[ // Linksbündig
        // Verwende spezifischen Stil für Publikationen
        #text(..text-style-publication)[#eval(entry.item, mode: "markup")]
      ]
    )
    prev-label = entry.label
  }
  // Erstellt das Grid mit globalem Stil
  grid(
    ..grid-style-default,
    ..cells
  )
}