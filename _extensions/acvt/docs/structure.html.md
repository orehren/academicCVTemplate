---
title: "Structure & Layout"
---

# Extension Structure

This page explains the architecture of the `academicCVTemplate` extension.

## 1. Data Caching Mechanism

To avoid exceeding Google API limits and to speed up rendering, the extension uses a caching system.

-   **Cache Files:** Fetched data is stored in a hidden cache file. The file is called `.cv_data.json` is located in your project base directory and will be used by the shortcodes to inject the content of your sheets into the document.
-   **Validity:** The cache is valid for **24 hours**.
-   **Forcing Update:** If you update your Google Sheet and want to see changes immediately, you must **delete** the `.cv_data.json` file from your project root folder. The next render will force a fresh fetch.

## 2. Extension Components

The extension operates as a Quarto Project Extension using several interacting components:

### Pre-render Script

*Files:* `_fetch_cv_data.R`

*Location:* `acvt/R/`

The script `_fetch_cv_data.R` runs **before** any content in your `.qmd` file is processed.
It handles authentication, fetches data from Google Sheets, and writes the structured data to `.cv_data.json` in the project root folder.

### Filters

*Files:* `inject-metadata.lua`, `extract-cover-letter.lua`, `embed-attachments.lua`

*Location:* `acvt/filters/`

Lua filters intervene in the Pandoc conversion process to inject data and handle special content.

-   `inject-metadata.lua`: Reads the entire YAML data and converts it into Typst variables. The Variables are then passed to the typst template.
-   `extract-cover-letter.lua`: Extracts the content under `## Coverletter` and makes it available to the template.
-   `embed-attachments.lua`: Handles the inclusion of appendix documents.

### Shortcodes

*Files:* `cv-section.lua`, `publication-list.lua`

*Location:* `acvt/shortcodes/`

These Lua scripts provide the user-facing commands used in the `.qmd` file:

-   `cv-section.lua`: Implements `{{< cv-section >}}`. This is the default shortcode used to display most sections of the CV. It reads the content of your sheets from `.cv_data.json`
-   `publication-list.lua`: Implements `{{< publication-list >}}`. A shortcode for rendering publication lists.

### Template & Partials

*Files*: `template.typ`, `typst-template.typ`, `definitions-00a-helper-functions.typ`, `definitions-02a-styling.typ`, `definitions-03a-parts-functions.typ`, `page.typ`

*Location*: `acvt/typst/`

The main file, `template.typ`, orchestrates the rendering process.
It determines the sequence in which the template partials are loaded and processed.

**Note:** You should generally not modify `template.typ` directly.
Instead, modify the specific partials it loads:

| Partial File | Purpose |
|:-----------------------------------|:-----------------------------------|
| `typst-template.typ` | Defines the main document structure (Logic for Cover Letter vs. CV). |
| `definitions-00a-helper-functions.typ` | Helper functions for data processing and icons. |
| `definitions-02a-styling.typ` | Defines the visual identity (colors, fonts, text styles). |
| `definitions-03a-parts-functions.typ` | Contains the layout functions (`resume-entry`, etc.). |
| `page.typ` | Configures page dimensions and margins. |

**Output:** By default, the generated document is saved to the `_output/` directory.

### R Components (Package Logic)

*Files:* Located in `R/` (Source) or `acvt/R/` (Extension)

The R scripts are divided into two categories: **Runtime Scripts** (used during rendering) and **Package Utilities** (used for setup and maintenance).

**1. Runtime Scripts (Data Fetching)**

| Filename | Purpose |
|:-------------------------|:---------------------------------------------|
| `_fetch_cv_data.R` | The main pre-render script. Orchestrates authentication and data loading. |
| `load_cv_sheets.R` | Functions to download sheets from Google Drive. |
| `read_cv_sheet.R` | Functions to parse individual sheets. |
| `setup_acvt.R` | Contains `setup_acvt()`. The interactive wizard for installing dependencies and configuring Google Auth. |

**2. Package Utilities (Setup & Maintenance)**

| Filename | Purpose |
|:-------------------------|:---------------------------------------------|
| `acvt_template.R` | Contains `acvt_template()`. The logic behind the RStudio "New Project" wizard. |
| `update_template.R` | Contains `update_current_cv_project()`. Updates the extension files in an existing project. |
|  | Contains `update_template_from_git()`. Downloads the latest template version from GitHub. |
| `zzz_dev.R` | Contains `dev_sync_template()`. A developer tool to sync local source files to the installed library. |

### Assets

The extension includes several static assets in `_extensions/orehren/acvt/assets/`.

| Directory | Content |
|:-------------------|:---------------------------------------------------|
| `bib/` | Bibliography files (`bibliography.bib`, `.json`, `.ris`, `.xml`, or `.yml`). |
| `images/` | Default profile picture (`picture.jpg` or `.png`) and example appendix files (`first_document.png`, `second_document.png`). |

## 3. Layout Logic (The Grid)

The template uses a consistent two-column grid layout:

-   **Left Column (Sidebar):** Narrow, right-aligned.
-   **Right Column (Content):** Wide, left-aligned.

| Sidebar Column | Content Column |
|:---------------|:---------------|
| Cell 1         | Cell 2         |
| Cell 3         | Cell 4         |
| Cell 5         | Cell 6         |
| Cell ...       | ...            |

### Data Processing Sequence

When you use `{{< cv-section >}}`, the extension iterates through your data sheet row by row.
For each row, it calls the specified Typst function (e.g., `#resume-entry`).

**Important:** The `cv-section` shortcode is agnostic regarding layout.
It simply passes the column values to the function.
The layout is determined entirely by the Typst function, which maps the incoming content columns to grid cells **sequentially from left to right**.

### Example: `resume-entry` Mapping

The `resume-entry` function fills the grid cells sequentially using the columns it receives, in the following order:

1.  **Column 1:** Maps to **Sidebar Column: Cell 1** (e.g., Date range).
2.  **Column 2:** Maps to **Content Column: Cell 2** (e.g., Job Title, bolded).
3.  **Column 3:** Maps to **Sidebar Column: Cell 3** (e.g., Sub-label or empty).
4.  **Column 4:** Maps to **Content Column: Cell 4** (e.g., Description text).
5.  **Column 5:** Maps to **Sidebar Column: Cell 5** (e.g., Bullet points/Details).

Without any manual ordering via a shortcode argument, the Typst function maps the content of the columns sequentially, one after the other.
The first column content goes to the left column (Cell 1), the next to the right column (Cell 2), the third back to the left column (Cell 3—below the first entry), and so on.

Therefore, to fully automate document creation, the content in your Google Sheets should ideally be placed in the exact sequence you want it displayed in the grid.

However, relying solely on the spreadsheet order requires a clear vision of how you want to populate every section.
To alter the sequence of the columns dynamically, you can use the `column-order` argument in the shortcode.
This allows you to manually define the position of each column directly in the shortcode call, ensuring that your "Date" column is passed as Column 1, your "Title" as Column 2, and so on, regardless of their order in the source sheet.

## 4. Typst Function Reference

These layout functions are defined in `typst/04-definitions-parts-functions.typ`.
By allowing you to specify the `func` in the shortcode, the template provides the flexibility to choose different layouts for different sections of your CV (e.g., a detailed list for jobs vs. a simple list for interests) without changing the underlying data structure.
This extension comes with the following Typst functions to display different content types.

| Function | Layout Behavior | Use Case | Shortcode |
|:-----------------|:-----------------|:-----------------|------------------|
| `resume-entry` | Maps arguments to the 2-column grid (Left, Right, Left, Right...). | Standard CV entries (Experience, Education). | `{{< cv-section >}}` |
| `research-interests` | Skips the first few grid positions to place content directly in the right column. | Simple lists or bullet points. | `{{< cv-section >}}` |
| `publication-list` | Renders a formatted bibliography list. | Publication sections. | `{{< publication-list >}}` |
| `visualize-skills-list` | Renders a graphical bar chart table. | Visualizing skill levels. | `{{< cv-section >}}` |

You can also write and provide your own custom Typst functions.
To do this, declare a new function in `typst/04-definitions-parts-functions.typ` and then call it via the `func` argument in the shortcode.

See [**Shortcodes & Content**](./shortcodes.qmd) for usage examples.

## 5. Package Architecture & Maintenance

The `acvt` R package acts as a container and manager for the Quarto extension.
It ensures that users can easily create, configure, and update their CV projects.

### The "Source of Truth"

The master version of the template files (QMD, YAML, CSS, Lua) is stored inside the R package structure at: `inst/rstudio/templates/project/skeleton/`

### Update Workflows

The package provides three distinct mechanisms to handle template updates, depending on the target:

1.  **Project Update (`update_current_cv_project`):**
    -   *Source:* The installed R package library.
    -   *Target:* The `_extensions/` folder of your current project.
    -   *Use Case:* You updated the R package and want to apply fixes to an existing CV.
2.  **Template Hotfix (`update_template_from_git`):**
    -   *Source:* The GitHub repository (ZIP download).
    -   *Target:* The installed R package library.
    -   *Use Case:* You want to fetch the latest template version for *new* projects without reinstalling the full package.
3.  **Developer Sync (`dev_sync_template`):**
    -   *Source:* Your local source code folder (`inst/`).
    -   *Target:* The installed R package library.
    -   *Use Case:* For package developers to test changes in the "New Project" wizard immediately.
