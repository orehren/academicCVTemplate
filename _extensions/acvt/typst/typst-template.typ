// =============================================
//  TEMPLATE: Quarto Typst Modern-CV (Optimized)
// =============================================
// Version: 1.5
// Author: Oliver Rehren
// Description: An optimized Typst template for academic CVs,
//              addressing font override logic and show rule errors,
//              while preserving the original visual appearance.
// =============================================


// -- 1. Imports --
// ----------------
#import "_extensions/academicCVTemplate/typst/helper-functions.typ": *
#import "_extensions/academicCVTemplate/typst/metadata.typ": *
#import "_extensions/academicCVTemplate/typst/styling.typ": *
#import "_extensions/academicCVTemplate/typst/partial-functions.typ": *
#import "_extensions/academicCVTemplate/typst/cover-letter.typ": *

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

// -- 7. Main Document Function --
// -------------------------------
#let resume(doc) = {

    // --- Local Show Rules ---
    show quote.where(block: true): it => {
        set align(center)
        set text(..text-style-quote)
        let attribution = if it.attribution != none {
          align(end, [\~ #it.attribution \~])
          } else { none }

        block(
            width: 100%, inset: 1em,
            {
                if it.quotes == true { quote(it.body) } else { it.body }
                attribution
            }
        )
    }

    // --- Document Assembly ---
    // -------------------------

    // 1. Render Cover Letter (if requested)
    if render-output == "letter-only" or render-output == "combined" {
      render-cover-letter(author, color-accent, text-style-aboutme,
                          recipient: doc.at("recipient", default: none),
                          date: doc.at("date", default: datetime.today),
                          subject: doc.at("subject", default: none),
                          cover_letter_content: doc.at("cover_letter_content", default: none)
                          )
    }

    // 2. Render CV (if requested)
    if render-output == "cv-only" or render-output == "combined" {
      // Render the Title Page
      title-page(
        author,
        profile-photo: doc.at("profile-photo", default: none)
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
