---
title: "Advanced Styling"
---

# Advanced Styling Guide

This template provides several ways to customize the visual appearance of your CV and cover letter, from simple YAML options to modifying the underlying Typst stylesheets.

## 1. Basic Styling with YAML

The easiest way to change the look of your document is by using the `style` object in the YAML header.

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

## 2. Advanced Styling (Modifying Typst)

For users who want more control, you can directly modify the Typst style files located in the `_extensions/academiccvtemplate/typst/` directory.

**Warning:** Modifying these files requires some knowledge of the Typst language. Always make a backup before making changes.

### Key Files

*   **`styling.typ`:** This is the main stylesheet. It defines all the core styles, such as colors and font sizes, as `#let` variables. This is the best place to start for most advanced changes. For example, you can change the default font sizes:
    ```typst
    // in styling.typ
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

*   **`partial-functions.typ`:** This file contains the functions that render larger components, like the `title-page`. You can modify the layout of these components here. For example, you could change the alignment or spacing of elements on the title page.

### How to Apply Changes

1.  Open the relevant `.typ` file in a text editor.
2.  Make your desired changes.
3.  Save the file.
4.  Re-render your `.qmd` document with `quarto render`.

Your changes will be immediately reflected in the new PDF output.
