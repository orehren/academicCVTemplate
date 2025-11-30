// typst/03-definitions-styling.typ
// defines color palett, typography and styles

// -- 1. Color Palett Definition --
// ----------------

#let color-accent = rgb( unescape_text( meta-data.style.at("color-accent", default: "#dc3522") ) )

// -- Colors (using the nord color palett) --
#let color-nord0 = rgb("#2e3440")
#let color-nord1 = rgb("#3b4252")
#let color-nord2 = rgb("#434c5e")
#let color-nord3 = rgb("#4c566a")
#let color-nord4 = rgb("#d8dee9")


// -- 2. Typography Definition --
// ------------------------------

// --- Define Global Safe Fallbacks ---
#let fallback-text = ("Libertinus Serif",)
#let fallback-header = ("New Computer Modern",)

// --- Load User Fonts & Merge with Fallbacks ---

// 1. Header Font
#let user-font-header = meta-data.style.at("font-header", default: "Roboto")
#let font-header = to-array(user-font-header) + fallback-header

// 2. Text Font
#let user-font-text = meta-data.style.at("font-text", default: "Source Sans Pro")
#let font-text = to-array(user-font-text) + fallback-text

// -- Font Sizes --
#let font-size-xl = 22pt
#let font-size-large = 16pt
#let font-size-middle = 12pt
#let font-size-normal = 11pt
#let font-size-small = 10pt
#let font-size-footer = 9pt
#let font-size-label = 8pt
#let font-size-skill = 7pt


// -- 3. Styles Definition --
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
