// typst/cover-letter.typ
// This file contains the logic for rendering the cover letter.

#let render-cover-letter(
  author,
  recipient,
  date,
  subject,
  cover_letter_content
) = {
  // --- Header ---
  // Using a grid to align sender and recipient information.
  grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      #text(weight: "bold", author.firstname + " " + author.lastname) \
      #author.contact.at(0).text \
      #author.contact.at(1).text \
      #link("mailto:" + author.contact.at(2).text, author.contact.at(2).text)
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
  text(weight: "bold")[#subject]
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
