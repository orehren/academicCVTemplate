// ================
// 1. Definitions
// ================

// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false,
    fill: background_color,
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%,
      below: 0pt,
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt,
          width: 100%,
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

// typst/helper-functions.typ
// Defines helper functions for the template
#import "@preview/fontawesome:0.5.0": *

// Checks, if a variable is in the global scope and sets a default value if not
#let get-optional(value, default) = {
  if value == none { default } else { value }
}

// Cleans up text potentially escaped from external sources (e.g., Pandoc).
#let unescape_text(text) = {
  let cleaned = text

  // Replaces non-breaking spaces (U+00A0) with regular spaces (U+0020)
  cleaned = cleaned.replace(" ", " ")

  // Removes literal backslashes (e.g., from Pandoc escaping)
  cleaned = cleaned.replace("\\", "")

  // Fixes a hyper-specific artifact (e.g., "end.~NextSentence")
  cleaned = cleaned.replace(".~", ". ")

  return cleaned
}


// Renders the fontawesome icons based on their string identifier.
#let render-icon(icon_string, color) = {
  if icon_string.starts-with("fa ") {
    let parts = icon_string.split(" ")
    if parts.len() == 2 {
      fa-icon(parts.at(1), fill: color)
    } else if parts.len() == 3 and parts.at(1) == "brands" {
      fa-icon(parts.at(2), fa-set: "Brands", fill: color)
    } else {
      assert(false, message: "Invalid FontAwesome icon string format: " + icon_string)
    }
  } else if icon_string.ends-with(".svg") {
    // Fallback for local SVG images
    box(image(icon_string))
  } else {
    assert(false, message: "Invalid icon string (expected 'fa ...' or '*.svg'): " + icon_string)
  }
}

// Renders a single author detail item (e.g., icon + link).
// This is defined as a code block {...} and builds content
// with '+' to create a robust, horizontal, non-breaking layout.
#let render-author-detail(item_data, item_accent_color) = {
  // 1. Get data from the dictionary
  let item_icon = item_data.at("icon", default: none)
  let item_url = item_data.at("url", default: none)
  let item_text_raw = item_data.at("text", default: "")
  let item_text = unescape_text(item_text_raw)

  // 2. Build the icon part
  let icon_part = if item_icon != none {
    render-icon(item_icon, item_accent_color) + h(0.2em)
  } else {
    [] // empty content
  }

  // 3. Build the text part
  let text_part = if item_url != none {
    link(item_url)[#item_text]
  } else if item_text != "" {
    item_text
  } else {
    [] // empty content
  }

  // 4. Return the combined, horizontal content
  return icon_part + text_part
}

// Renders a list of author details, joined by a separator.
#let render-author-details-list(
  list_data,
  item_accent_color,
  separator: h(0.5em) // Default separator is horizontal space
) = {
  // Guard clause for empty or non-existent list
  if list_data != none and list_data.len() > 0 {
    // 1. Map each data item to a rendered, boxed item
    let rendered_items = list_data.map(item =>
      // 'box()' ensures each item is treated as a single layout unit
      box(render-author-detail(item, item_accent_color))
    )
    // 2. Join the list of items with the separator
    rendered_items.join(separator)
  } else {
    [] // Return empty content if list is empty
  }
}

// --- Helper function to find contact info by icon ---
#let find_contact(author, icon_name) = {
  let item = author.contact.find(item => item.icon == icon_name)
  if item != none {
    if "url" in item {
      link(item.url, item.text)
    } else {
      item.text
    }
  } else {
    ""
  }
}

// Groups a list of dictionaries by a specific field.
#let group-by-field(raw_fields_list, grouping_field) = {
  let grouped = (:) // Initialize an empty dictionary

  if raw_fields_list == none or raw_fields_list.len() == 0 {
    return grouped
  }

  for field_entry in raw_fields_list {
    // Get the value of the field we are grouping by
    let current_field = field_entry.at(grouping_field, default: "Uncategorized")

    if not (current_field in grouped) {
      // This is the first entry for this category; create a new array
      grouped.insert(current_field, (field_entry,))
    } else {
      // This category already exists; append to its array
      let existing_list = grouped.at(current_field)
      // Create a new array by concatenating the old list and the new item
      grouped.insert(current_field, existing_list + (field_entry,))
    }
  }

  return grouped
}

// typst/03-definitions-styling.typ
// defines color palett, typography and styles



// -- 2. Color Palett Definition --
// ----------------

#let color-accent = rgb( unescape_text( style.at("color-accent", default: "#dc3522") ) )

// -- Colors (using the nord color palett) --
#let color-nord0 = rgb("#2e3440")
#let color-nord1 = rgb("#3b4252")
#let color-nord2 = rgb("#434c5e")
#let color-nord3 = rgb("#4c566a")
#let color-nord4 = rgb("#d8dee9")


// -- 3. Typography Definition --
// ------------------------------
#let font-header = style.at("font-header", default: ("Roboto", "Arial", "Dejavu Sans") )
#let font-text = style.at("font-text", default: ("Source Sans Pro", "Arial", "Dejavu Sans") )

// -- Font Sizes --
#let font-size-xl = 22pt
#let font-size-large = 16pt
#let font-size-middle = 12pt
#let font-size-normal = 11pt
#let font-size-small = 10pt
#let font-size-footer = 9pt
#let font-size-label = 8pt
#let font-size-skill = 7pt


// -- 4. Styles Definition --
// ------------------------------

// Global Styles
#let text-style-default = (
	font: font-text,
	size: font-size-normal,
	weight: "regular",
	style: "normal",
	fill: color-nord1,
)

#let text-style-bold = (
	font: font-text,
	size: font-size-normal,
	weight: "bold",
	style: "normal",
	fill: color-nord1,
)

// Styles for Page Partials (Header and Footer)
#let text-style-header = (
	font: font-header,
	size: font-size-large,
	weight: "bold",
	style: "normal",
	// fill: style.color-accent
	fill: color-nord1
)

#let text-style-footer = (
	font: font-header,
	size: font-size-footer,
	weight: "regular",
	style: "oblique",
	fill: color-accent
)

// Style for Tables
#let text-style-table = (
  font: font-text,
  size: font-size-label,
  weight: "regular",
  style: "oblique",
  fill: color-nord2
)

// Styles for Title Page Partials
#let text-style-title-name = (
	font: font-header,
	size: font-size-xl,
	weight: "medium",
	style: "normal",
	fill: color-nord0
)

#let text-style-title-position = (
	font: font-header,
	size: font-size-normal,
	weight: "regular",
	style: "normal",
	fill: color-accent
)

#let text-style-title-contacts = (
  font: font-header,
  size: font-size-label,
  weight: "regular",
  style: "oblique",
  fill: color-nord3
)

// Style for Famous Quote Partial
#let text-style-quote = (
  font: font-header,
  size: font-size-middle,
  weight: "regular",
  style: "italic",
  fill: color-accent
)

// Style for About Me Partial
#let text-style-aboutme = (
  font: font-text,
  size: font-size-small,
  weight: "regular",
  style: "oblique",
  fill: color-nord0
)

// Style for Publication List Entries
#let text-style-publication = (
  font: font-text,
  size: font-size-small,
  weight: "regular",
  style: "normal",
  fill: color-nord1
)

// Style for Labels (left grid pane)
#let text-style-label = (
	font: font-header,
	size: font-size-label,
	weight: "light",
	style: "normal",
	fill: color-nord3
)

#let text-style-label-accent = (
	font: font-header,
	size: font-size-label,
	weight: "regular",
	style: "italic",
	fill: color-accent
)

// Style for Skills
#let text-style-skill-name = (
	font: font-header,
	size: font-size-skill,
	weight: "bold",
	style: "normal",
	fill: color-nord3
)

#let text-style-skill-level = (
	font: font-header,
	size: font-size-skill,
	weight: "regular",
	style: "italic",
	fill: color-accent
)

#let text-style-details = (
  font: font-text,
  size: font-size-label,
  weight: "light",
  style: "normal",
  fill: color-nord1
)

#let grid-style-default = (
  align: center + horizon,
  columns: (2fr, 6fr),
  rows: auto,
  gutter: 1em,
  row-gutter: 1em
)

#let grid-style-footer = (
  ..grid-style-default,
  columns: (1fr, auto, 1fr)
)

#let grid-style-titlepage = (
  ..grid-style-default,
  columns: (2cm, 2fr, 1fr, 2cm),
)

#let grid-style-toc = (
  ..grid-style-default,
  columns: (1fr,1fr)
)

#let table-style-default = (
  columns: (30%, 35%, 35%),
  align: left + horizon,
  stroke: none
)

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
// ================
// 2. Content
// ================

// =============================================
//  TEMPLATE: Quarto Typst Modern-CV (Optimized)
// =============================================
// Version: 1.5
// Author: Oliver Rehren
// Description: An optimized Typst template for academic CVs,
//              addressing font override logic and show rule errors,
//              while preserving the original visual appearance.
// =============================================


// -- 7. Main Document Function --
// -------------------------------
#let resume(doc) = {

    // --- Document Assembly ---
    // -------------------------

    // 1. Render Cover Letter (if requested)
    if render-output == "letter-only" or render-output == "combined" {
      render-cover-letter(author, color-accent, text-style-aboutme,
                          recipient: get-optional(recipient, none),
                          date: get-optional(date, datetime.today()),
                          subject: get-optional(subject, none),
                          cover_letter_content: get-optional(cover_letter_content, none)
                          )
    }

    // 2. Render CV (if requested)
    if render-output == "cv-only" or render-output == "combined" {
      // Render the Title Page
      title-page(
        author,
        profile-photo: get-optional(profile-photo, none)
      )

      // Set up page settings for the rest of document (page numbering + footer)
      set page(footer: create-footer(author), numbering: "1")
      counter(page).update(1)

      // Display optional quote
      if famous-quote.text != none {
          quote(attribution: famous-quote.attribution, block: true, quotes: true)[#famous-quote.text]
      }

      // Display optional "About Me" section
      if aboutme != none {
          set text(..text-style-aboutme)
          align(center)[#aboutme]
          v(1em)
      }

      doc
    }
}
#set text(..text-style-default)
#set grid(..grid-style-default)
#set table(..table-style-default)
#set par(justify: true, leading: 0.5em)

#set page(
    paper: "a4",
    margin: (x: 2cm, y: 1.5cm),
    header: align(right)[
        #box(width: 1fr, line(length: 100%))
        #set text(..text-style-header)
        #text(fill: color-accent)[#title.slice(0, 3)]#title.slice(3)
    ],
)


// typst/typst-show.typ
// forwards yaml metadata to typst template


#show quote.where(block: true): it => {
    set align(center)
    set text(..text-style-quote)
    let attribution = if famous-quote.at("attribution") != none {
      align(end, [\~ #famous-quote.at("attribution") \~])
      } else { none }

    block(
        width: 100%, inset: 1em,
        {
            if it.quotes == true { quote(it.body) } else { it.body }
            attribution
        }
    )
}

#show heading: set text(..text-style-header)
#show heading.where(level: 1): it => [
    #set block(above: 1.5em, below: 1em)
    #set text(..text-style-header)
    #align(left)[
        #strong[#text(fill: color-accent)[#it.body.text.slice(0, 3)]#it.body.text.slice(3)]
        #box(width: 1fr, line(length: 99%))
    ]
]

#show heading.where(level: 2): it => {
    set text(fill: color-nord2, size: font-size-middle, weight: "thin")
    it.body
}

#show heading.where(level: 3): it => {
    set text(size: font-size-small, fill: color-nord3)
    smallcaps[#it.body]
}

#show: resume.with(

)

= Advanced Styling Guide
<advanced-styling-guide>
This template provides several ways to customize the visual appearance of your CV and cover letter, from simple YAML options to modifying the underlying Typst stylesheets.

== 1. Basic Styling with YAML
<basic-styling-with-yaml>
The easiest way to change the look of your document is by using the `style` object in the YAML header.

=== `color-accent`
<color-accent>
This sets the primary color used for heading accents, links, and other highlighted elements.

#strong[Type:] String (Hex color code) #strong[Example:]

```yaml
style:
  color-accent: "#2a9d8f" # A dark teal color
```

=== `font-header` and `font-text`
<font-header-and-font-text>
These options allow you to change the fonts used in the document. Provide a list of font names. Typst will try each font in order until it finds one installed on your system.

#strong[Type:] List of Strings #strong[Example:]

```yaml
style:
  font-header: ["Calibri", "Arial", "sans-serif"]
  font-text: ["Garamond", "Times New Roman", "serif"]
```

== 2. Advanced Styling (Modifying Typst)
<advanced-styling-modifying-typst>
For users who want more control, you can directly modify the Typst style files located in the `_extensions/academiccvtemplate/typst/` directory.

#strong[Warning:] Modifying these files requires some knowledge of the Typst language. Always make a backup before making changes.

=== Key Files
<key-files>
- #strong[`styling.typ`:] This is the main stylesheet. It defines all the core styles, such as colors and font sizes, as `#let` variables. This is the best place to start for most advanced changes. For example, you can change the default font sizes: `typst     // in styling.typ     #let font-size-large = 18pt     #let font-size-middle = 12pt     #let font-size-small = 10pt`

- #strong[`typst-show.typ`:] This file controls the appearance of specific document elements, like headings, using `#show` rules. For example, you could change the style of a level-2 heading: `typst     // in typst-show.typ     #show heading.where(level: 2): it => {         set text(fill: blue, weight: "bold") // Change to bold and blue         it.body     }`

- #strong[`partial-functions.typ`:] This file contains the functions that render larger components, like the `title-page`. You can modify the layout of these components here. For example, you could change the alignment or spacing of elements on the title page.

=== How to Apply Changes
<how-to-apply-changes>
+ Open the relevant `.typ` file in a text editor.
+ Make your desired changes.
+ Save the file.
+ Re-render your `.qmd` document with `quarto render`.

Your changes will be immediately reflected in the new PDF output.
