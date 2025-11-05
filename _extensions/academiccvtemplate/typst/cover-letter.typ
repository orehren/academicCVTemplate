// typst/cover-letter.typ
// This file contains the logic for rendering the cover letter.

#let render-cover-letter(
  author,
  recipient,
  date,
  subject,
  cover_letter_content,
  color-accent,
  text-style-header
) = {
  // --- Helper function to find contact info by icon ---
  let find_contact(icon_name) = {
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

  // --- Header ---
  // Using a grid to align sender and recipient information.
  grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      #text(fill: color-accent, weight: "bold", author.firstname + " " + author.lastname) \
      #find_contact("fa address-card") \
      #find_contact("fa mobile-screen") \
      #find_contact("fa envelope")
    ],
    [
      #recipient.name \
      #recipient.address \
      #recipient.zip #recipient.city
    ]
  )

  // --- Date and Subject ---
  v(2em)
  align(right)[#date]
  v(2em)
  block(
    width: 100%,
    [
      #set text(..text-style-header)
      #align(left)[
          #strong[#text(fill: color-accent)[#subject.slice(0, 3)]#text()[#subject.slice(3)]]
          #box(width: 1fr, line(length: 99%))
      ]
    ]
  )
  v(2em)

  // --- Salutation ---
  "Dear " + recipient.salutation + ","

  // --- Body ---
  v(1em)
  cover_letter_content

  // --- Closing ---
  v(2em)
  "Sincerely,"
  v(1em)
  author.firstname + " " + author.lastname
}
