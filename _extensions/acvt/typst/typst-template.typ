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
    if meta-data.at("render-output", default: none) == "letter-only" or meta-data.at("render-output", default: none) == "combined" {
      render-cover-letter(title: meta-data.at("title", default: none),
                          author: meta-data.at("author", default: (:)),
                          profile-photo: meta-data.at("profile-photo", default: none),
                          recipient: meta-data.at("recipient", default: (:)),
                          date: meta-data.at("date", default: datetime.today()),
                          subject: meta-data.at("subject", default: none),
                          position: meta-data.at("position", default: none),
                          famous-quote: meta-data.at("famous-quote", default: none),
                          style: meta-data.at("style", default: (:)),
                          cover_letter_content: meta-data.at("cover_letter_content", default: none)
      )
    }

    // 2. Render CV (if requested)
    if meta-data.at("render-output", default: none) == "cv-only" or meta-data.at("render-output", default: none) == "combined" {
      // Render the Title Page
      title-page(
        meta-data.at("author", default: (:)),
        profile-photo: meta-data.at("profile-photo", default: none),
        position: meta-data.at("position", default: none)
      )

      // Set up page settings for the rest of document (page numbering + footer)
      set page(footer: create-footer(meta-data.at("author", default: (:))), numbering: "1")
      counter(page).update(1)

      // Display optional quote
      // if has-content(meta-data.at("famous-quote", default: (:)), "text") {
      if has-content(meta-data, "famous-quote", "text") {
          quote(attribution: meta-data.famous-quote.at("attribution", default: none), block: true, quotes: true)[#meta-data.famous-quote.at("text", default: none)]
      }

      // Display optional "About Me" section
      if has-content(meta-data, "aboutme") {
          set text(..text-style-aboutme)
          align(center)[#meta-data.at("aboutme", default: none)]
          v(1em)
      }

      doc
    }
}
