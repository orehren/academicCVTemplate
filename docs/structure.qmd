---
title: "Structure & Layout"
---

# Extension Structure

This page explains the architecture of the `academicCVTemplate` extension.

## 1. Data Caching Mechanism

To avoid hitting Google API limits and to speed up rendering, the extension uses a caching system.

-   **Cache Files:** Fetched data is stored in two files: the hidden `.cv_cache.rds` (used by R for intermediate caching) and `_cv_data.yml` (used by the extension to inject data).
-   **Validity:** The cache is valid for **24 hours**.
-   **Forcing Update:** If you update your Google Sheet and want to see changes immediately, you must **delete** both the `.cv_cache.rds` and `_cv_data.yml` files from your project root. The next render will force a fresh fetch.

## 2. Extension Components

The extension operates as a Quarto Project Extension using several interacting components:

### Pre-render Script

*Files:* `_fetch_cv_data.R`

*Location:* `acvt/R/`

The script `_fetch_cv_data.R` runs **before** any content in your `.qmd` file is processed.
It handles authentication, fetches data from Google Sheets, and writes the structured data to `_cv_data.yml` and `.cv_cache.rds` in your project root folder.

### Filters

*Files:* `inject-metadata.lua`, `extract-cover-letter.lua`, `embed-attachments.lua`

*Location:* `acvt/filters/`

Lua filters intervene in the Pandoc conversion process to inject data and handle special content.
They do this by generating / modifying the `02-definitions-metadata.typ` file:

-   `inject-metadata.lua`: Reads the whole YAML data (including `_cv_data.yml`) and converts it into Typst variables.

-   `extract-cover-letter.lua`: Extracts the content under `## Coverletter` and makes it available to the template.

-   `embed-attachments.lua`: Handles the inclusion of appendix documents.

### Shortcodes

*Files:* `cv-section.lua`, `publication-list.lua`

*Location:* `acvt/shortcodes/`

Lua scripts that provide the user-facing commands in the `.qmd` file:

-   `cv-section.lua`: Implements `{{< cv-section >}}`. The default shortcode used to display most of sections of the cv.
-   `publication-list.lua`: Implements `{{< publication-list >}}`. Shortcode to implement a publication list.

### Template & Partials

*Files*: `template.typ`, `typst-template.typ`, `01-definitions-helper-functions.typ`, `02-definitions-metadata.typ`, `03-definitions-styling.typ`, `04-definitions-parts-functions.typ`, `page.typ`

*Location*: `acvt/typst/`

The main file `template.typ` orchestrates the rendering process.
It determines the sequence in which the template partials are loaded and processed.

**Note:** You should generally not modify `template.typ` directly.
Instead, modify the specific partials it loads:

| Partial File | Purpose |
|:-----------------------------------|:-----------------------------------|
| `typst-template.typ` | Defines the main document structure (Logic for Cover Letter vs CV). |
| `01-definitions-helper-functions.typ` | Helper functions for data processing and icons. |
| `02-definitions-metadata.typ` | **Auto-generated.** Contains the variables injected by filters. |
| `03-definitions-styling.typ` | Defines the visual identity (colors, fonts, text styles). |
| `04-definitions-parts-functions.typ` | Contains the layout functions (`resume-entry`, etc.). |
| `page.typ` | Configures page dimensions and margins. |

**Output:** By default, the generated Document is saved to the `_output/` directory.

### R Components

*Files:* `_fetch_data.R`, `load_cv_sheets.R`, `load_cv_sheets_helpers.R`, `read_cv_sheets.R`, `read_cv_sheets_helpers.R`, `validation_helpers.R`

*Location:* `acvt/R`

These R scripts handle data fetching and processing.

| Filename | Purpose |
|:-----------------------------------|:-----------------------------------|
| `_fetch_cv_data.R` | The main pre-render script. Orchestrates authentication and data loading. |
| `load_cv_sheets.R` | Functions to download sheets from Google Drive. |
| `load_cv_sheets_helpers.R` | Helper Functions to download sheets from Google Drive. |
| `read_cv_sheet.R` | Functions to parse individual sheets. |
| `read_cv_sheet_helpers.R` | Helper Functions to parse individual sheets. |
| `validation_helpers.R` | Input validation logic. |

### Assets

The extension includes several static assets in `_extensions/orehren/acvt/assets/`.

| Directory | Content |
|:------------------|:----------------------------------------------------|
| `bib/` | Bibliography files (`bibliography.bib|.json|.ris|.xml|.yml`, `apa-cv.csl`). |
| `images/` | Default profile picture (`picture.jpg|.png`) and example appendix files (`first_document.png`, `second_document.png`). |

## 3. Layout Logic (The Grid)

The template uses a consistent two-column grid as layout:

-   **Left Column (Sidebar):** Narrow, right-aligned.
-   **Right Column (Content):** Wide, left-aligned.

| Sidebar Column | Content Column |
|:---------------|:---------------|
| Cell 1         | Cell 2         |
| Cell 2         | Cell 3         |
| Cell 4         | Cell 5         |
| Cell ...       | ...            |

### Data Processing Sequence

When you use `{{< cv-section >}}`, it iterates through your data sheet row by row.
For each row, it calls the specified Typst function (e.g., `#resume-entry`).

**Important:** The `cv-section` shortcode does not know about layout.
It simply passes the column values to the function.
The layout is determined entirely by the Typst function, which maps the incoming content columns to grid cells **sequentially from left to right**.

### Example: `resume-entry` Mapping

The `resume-entry` function fills the grid cells sequencially in the following order with the columns it receives:

1.  **Column 1:** Maps to **Sidebar Column: Cell 1** (e.g., Date range).
2.  **Column 2:** Maps to **Content Column: Cell 2** (e.g., Job Title, bolded).
3.  **Column 3:** Maps to **Sidebar Column: Cell 3** (e.g., Sub-label or empty).
4.  **Column 4:** Maps to **Content Column: Cell 4** (e.g., Description text).
5.  **Column 5:** Maps to **Sidebar Column: Cell 5** (e.g., Bullet points/Details).

So without any manual ordering via a shortcode argument, the Typst function will row by row map the different content of the column cells sequencially one after the other, with the first column content going to the left column (Cell 1), the next to the right column (Cell 2), then again to the left column (Cell 3 - under the former entry in Cell 1), and so on.
Therefore to fully automate the whole document creation, in the Google Sheets you should place your content in the same sequence you want it to be displayed in the grid.

While this opens up the easiest way to implement sections into your cv, this would also require you to have clear vision on how you want to populate the whole document (or at least every section).
To alter the sequence of the columns in the Google Sheets on the fly, the shortcode allows to manipulate it with different arguments.
This is why, for example, the `column-order` argument in the shortcode is useful: it allows you to manually define the position of each column directly in the shortcode call to ensure that your "Date" column is passed as Column 1, your "Title" as Column 2, and so on, matching the function's layout logic.

## 4. Typst Function Reference

These layout functions are defined in `typst/04-definitions-parts-functions.typ`.
By allowing you to specify the `func` in the shortcode, the template gives you the flexibility to choose different layouts for different sections of your CV (e.g., a detailed list for jobs vs. a simple list for interests) without changing the underlying data structure.
This extension comes with the following typst functions to display different parts of the content.

| Function | Layout Behavior | Use Case | Shortcode |
|:-----------------|:-----------------|:-----------------|------------------|
| `resume-entry` | Maps arguments to the 2-column grid (Left, Right, Left, Right...). | Standard CV entries (Experience, Education). | `{{< cv-section >}}` |
| `research-interests` | Skips the first few grid positions to place content directly in the right column. | Simple lists or bullet points. | `{{< cv-section >}}` |
| `publication-list` | Renders a formatted bibliography list. | Publication sections. | `{{< publication-list >}}` |
| `visualize-skills-list` | Renders a graphical bar chart table. | Visualizing skill levels. | `{{< cv-section >}}` |

You can write and provide your own typst function.
For this, you would declare a new function in `typst/04-definitions-parts-functions.typ` and then call it via the `func` argument in the shortcodes.

See [**Shortcodes & Content**](./shortcodes.qmd) for usage examples.
