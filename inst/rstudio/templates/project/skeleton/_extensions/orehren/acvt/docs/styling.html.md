---
title: "Styling"
---

---
title: "Advanced Styling"
---

# Advanced Styling Guide

This template provides several ways to customize the visual appearance of your CV and cover letter, from simple YAML options to modifying the underlying Typst stylesheets.

## 1. Basic Styling with YAML

The easiest way to change the look of your document is by using the `style` object in the YAML header. For a complete list of options, see the **[YAML Reference](./yaml_reference.qmd#style)**.

### `color-accent`

This sets the primary color used for heading accents, links, and other highlighted elements.

**Type:** String (Hex color code)
**Example:**
```yaml
style:
  color-accent: "#2a9d8f" # A dark teal color
```

### `font-header` and `font-text`

These options allow you to change the fonts used in the document. Provide a list of font names. Typst will try each font in order until it finds one installed on your system.

**Type:** List of Strings
**Example:**
```yaml
style:
  font-header: ["Calibri", "Arial", "sans-serif"]
  font-text: ["Garamond", "Times New Roman", "serif"]
```

### Fonts & Rendering
This template is designed to look best with the Roboto, Source Sans and Lato font families.

**Recommendation:**

For the intended visual result, please install these fonts on your system:

*   [Download Robto](https://fonts.google.com/specimen/Roboto)
*   [Download Source Sans Pro](https://fonts.google.com/specimen/Source+Sans+3)
*   [Download Lato](https://fonts.google.com/specimen/Lato)

**Understanding Font Warnings:**

When rendering, you might see warnings in the console like:

`warning: unknown font family: lato`

This is **normal behavior** if you haven't installed the specific fonts. It means:

1.  Typst looked for "Lato" but couldn't find it on your system.
2.  Typst is now automatically falling back to the built-in fonts (Libertinus Serif).
3.  Your PDF will still be generated correctly, but it will use a serif font style instead of the intended sans-serif style.

## 2. Advanced Styling (Typst Inline Code)

A powerful feature is the ability to use **Typst inline code** directly within your Google Sheet data.

### How it Works

The template processes data in `markup` mode. You can use the `#` symbol to call Typst functions or standard Typst syntax (like `\` for line breaks).

**Example:**
Highlight a project name and force a line break.

**In Google Sheets:**

| title | location |
| :--- | :--- |
| Research Associate in `#text(fill: rgb("5e81ac"), weight: "bold")[My Project]` | University \ of Science |

**Rendered Result:**
*   "My Project" appears in the accent color and bold.
*   "University" and "of Science" appear on separate lines.

**Context:**
The content is handled as if it is in Typst markup mode.
*   `#text(...)[]` works.
*   `text(...)[]` (without hash) does **not** work.

For available functions, see the **[Official Typst Documentation](https://typst.app/docs/)**.

## 3. Advanced Styling (Modifying Typst)

For users who want more control, you can directly modify the Typst style files located in the `_extensions/orehren/acvt/typst/` directory.

**Warning:** Modifying these files requires some knowledge of the Typst language. Always make a backup before making changes.

### Key Files

*   **`03-definitions-styling.typ`:** This is the main stylesheet. It defines all the core styles, such as colors and font sizes, as `#let` variables. This is the best place to start for most advanced changes. For example, you can change the default font sizes:
    ```typst
    // in 03-definitions-styling.typ
    #let font-size-large = 18pt
    #let font-size-middle = 12pt
    #let font-size-small = 10pt
    ```

*   **`typst-show.typ`:** This file controls the appearance of specific document elements, like headings, using `#show` rules. For example, you could change the style of a level-2 heading:
    ```typst
    // in typst-show.typ
    #show heading.where(level: 2): it => {
        set text(fill: blue, weight: "bold") // Change to bold and blue
        it.body
    }
    ```

*   **`04-definitions-parts-functions.typ`:** This file contains the functions that render larger components, like the `title-page`. You can modify the layout of these components here. For example, you could change the alignment or spacing of elements on the title page.

### How to Apply Changes

1.  Open the relevant `.typ` file in a text editor.
2.  Make your desired changes.
3.  Save the file.
4.  Re-render your `.qmd` document with `quarto render`.

Your changes will be immediately reflected in the new PDF output.

### Typst Template Structure

For users who want to modify the core layout, the Typst files are located in the `typst/` subdirectory of the extensions root folder.

### File Overview

| File | Purpose |
| :--- | :--- |
| `template.typ` | The main entry point. Orchestrates the loading of partials. |
| `typst-template.typ` | Contains the main document structure and logic. |
| `01-definitions-helper-functions.typ` | Helper functions for data processing and icons. |
| `02-definitions-metadata.typ` | **Auto-generated.** Contains the metadata injected from your YAML. |
| `03-definitions-styling.typ` | Defines colors, fonts, and text styles. |
| `04-definitions-parts-functions.typ` | Defines the layout components (`resume-entry`, `visualize-skills-list`, title page, footer). |
| `page.typ` | Page setup (margins, size). |
| `typst-show.typ` | Global show rules. |

To customize these files, you can copy them to your project root and update the `template-partials` in your `_extension.yml` (or `_quarto.yml`) to point to your local versions.
