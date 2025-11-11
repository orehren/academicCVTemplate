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
