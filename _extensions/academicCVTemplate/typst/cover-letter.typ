// typst/cover-letter.typ
// This file contains the logic for rendering the cover letter.
#import "helper-functions.typ": find_contact

#let render-cover-letter(
  author,
  color-accent,
  text-style-header,
  recipient: none,
  date: datetime.today,
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
