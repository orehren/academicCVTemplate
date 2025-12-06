---
title: "Complete YAML Reference"
---

This page provides a comprehensive reference for all the configuration options available in the YAML frontmatter of your `.qmd` file.

## Document Metadata

These fields define the core identity of your document.

### `title`
The document title, often used in the PDF metadata.

**Type:** String

```yaml
title: "Application for Tenure Track Position"
```

### `position`
Your current job title or the position you are applying for. This appears prominently on the Title Page.

**Type:** String

```yaml
position: "Senior Data Scientist"
```

### `profile-photo`
The path to your profile photo, relative to the project root.

**Type:** String

::: {.callout-note}
Set to `null` or `""` to disable the photo.
:::

```yaml
profile-photo: "assets/images/my_photo.jpg"
```

### `aboutme`
A short bio or summary paragraph displayed on the Title Page.

**Type:** String (multiline)

```yaml
aboutme: |
  Passionate researcher with 5+ years of experience in...
  Dedicated to open science and reproducibility.
```

### `famous-quote`
An optional quote displayed in the document.

**Type:** Object (`text`, `attribution`)

**Fields:**

*   `text`: The quote text. **Type:** String
*   `attribution`: The author of the quote. **Type:** String

```yaml
famous-quote:
  text: "The most reliable way to predict the future is to create it."
  attribution: "Abraham Lincoln"
```

## Author Details

The `author` object contains your personal information and contact details.

### `author`
**Type:** Object (`firstname`, `lastename`, `contact`, `socialmedia`)

**Fields:**

*   `firstname`: Your first name. **Type:** String
*   `lastname`: Your last name. **Type:** String
*   `contact`: A list of contact details. **Type:** List of Objects (`icon`, `text`, `url`)
*   `socialmedia`: A list of social profiles. **Type:** List of Objects (`icon`, `text`, `url`)

#### Contact & Social Media Items
Each item in the list is an object with:

*   `icon`: A Font Awesome icon class (e.g., `fa envelope`, `fa brands github`). **Type:** String
*   `text`: The text to display. **Type:** String
*   `url`: (Optional) The link destination. **Type:** String

**Example:**
```yaml
author:
  firstname: "Jane"
  lastname: "Doe"
  contact:
    - icon: fa envelope
      text: "jane@example.com"
      url: "mailto:jane@example.com"
    - icon: fa mobile-screen
      text: "+1 234 567 890"
  socialmedia:
    - icon: fa brands github
      text: "github.com/janedoe"
      url: "https://github.com/janedoe"
    - icon: fa globe
      text: "janedoe.com"
      url: "https://janedoe.com"
```

## Cover Letter

Configuration for the cover letter section.

### `recipient`
Information about the addressee.

**Type:** Object (`name`, `salutation`, `valediction`, `addressee` `address`, `city`, `zip`)

**Fields:**

*   `salutation`: Form of greeting to use. **Type:** String
*   `valediction`: Form of complimentary close to use. **Type:** String
*   `name`: Name of the Person to address in salutation. **Type:** String
*   `addressee`: First line of the address (Name/Company). **Type:** String
*   `address`: Street address. **Type:** String
*   `city`: City. **Type:** String
*   `zip`: Postal code. **Type:** String

**Example:**
```yaml
recipient:
  salutation: "Dear,"
  valediction: "Sincerely,"
  name: "Dr. Turing"
  addressee: "Dr. Alan Turing"
  address: "Bletchley Park"
  city: "Milton Keynes"
  zip: "MK3 6EB"
```

### `date` & `subject`
**Type:** String

```yaml
date: "October 24, 2025"
subject: "Application for Research Position"
```

## Data Integration (`google-document`)

Configures the connection to your data sources. While the key is named `google-document` for historical reasons, it now supports a **hybrid approach**, allowing you to mix Google Sheets, local Excel/CSV/JSON files, and entire directories.

### `google-document`
**Type:** Object

**Fields:**

*   `auth-email`: The email address used for Google authentication (only required if using Google Sheets). **Type:** String
*   `document-identifier`: The source(s) of your data. Can be a single string or a list of strings. **Type:** String | List of Strings
*   `sheets-to-load`: A list of specific data sections to import from the defined sources. **Type:** List of Objects

### `document-identifier`
This field tells the system *where* to look for data. You can provide a single source or a list of multiple sources. The system will merge them together.

**Supported Source Types:**

1.  **Google Sheet:** Provide the unique **ID** (recommended) or the exact **Name** of the file on your Google Drive or the url to that file.
2.  **Local File:** Provide a relative path to a `.xlsx`, `.csv`, or `.json` file.
3.  **Local Directory:** Provide a relative path to a folder (e.g., `_data/`). The system will scan it for supported files.

**How Matching Works:**
*   **Google Sheets / Excel:** The system looks for a **Tab (Sheet)** matching the `name` defined in `sheets-to-load`.
*   **CSV / JSON:** The system looks for a **Filename** matching the `name` defined in `sheets-to-load` (ignoring the extension).

#### Examples

**1. Online Only (Classic)**
Fetches all data from a single Google Sheet.
```yaml
google-document:
  auth-email: "me@gmail.com"
  document-identifier: "1BxiMVs0XRA5nSLqo..." # or "My CV Data"
  sheets-to-load:
    - name: "Working Experiences"
      shortname: "working"
```

**2. Local File Only**
Uses a local Excel file instead of the cloud. No email required.
```yaml
google-document:
  document-identifier: "data/my_cv.xlsx"
  sheets-to-load:
    - name: "Education" # Looks for a tab named "Education" in the xlsx
      shortname: "edu"
```

**3. Mixed Sources (Hybrid)**
Combines public data from Google Sheets with private data from a local Excel file.
```yaml
google-document:
  auth-email: "me@gmail.com"
  document-identifier:
    - "My Public CV Data"   # Google Sheet
    - "private/details.xlsx" # Local Excel
  sheets-to-load:
    - name: "Working Experiences" # From Google
      shortname: "working"
    - name: "References"          # From local Excel
      shortname: "refs"
```

**4. Directory Scan**
Scans a folder. Useful if you prefer one CSV per section (e.g., `_data/skills.csv`, `_data/languages.csv`).
```yaml
google-document:
  document-identifier: "_data/"
  sheets-to-load:
    - name: "skills"    # Matches '_data/skills.csv'
      shortname: "skills"
    - name: "languages" # Matches '_data/languages.csv'
      shortname: "lang"
```

### `sheets-to-load`
Defines *what* data to extract from the sources configured above.

**Object Format (Recommended):**

*   `name`: The identifier used to find the data.
    *   *For Excel/Google:* The exact Tab Name.
    *   *For CSV/JSON:* The Filename (without extension).
*   `shortname`: The unique ID you will use in the `{{< cv-section >}}` shortcode to render this data.

**String Format:**
You can simply list names. The `shortname` will be automatically generated (lowercased, spaces replaced by underscores).

```yaml
sheets-to-load:
  # Object Format
  - name: "Working Experiences"
    shortname: "working"
  # String Format
  - "Education" # shortname becomes 'education'
```


## Publication List (`publication-list`)

Configures the automated bibliography generation.

::: {.callout-important}
The publication list generation does not use the standard citation framework from Quarto and Typst. This framework is disabled in this extension. Therefore, the usual YAML fields (`bibliography`, `csl`, etc.) have no effect, and citations in the traditional way are not possible. To restore this functionality, add `surpress-bibliography: true` to the document's YAML header.
:::

### `publication-list`
**Type:** Object (`bib_file`, `bib_style`, `author_name`, `typst_func_name`, `default_label`, `group_labels`, `group_order`)

**Basic Configuration:**

*   `bib_file`: Path to bibliography file(s). Use a list for multiple files. **Type:** String (or List of Strings)
*   `bib_style`: Path to the CSL style file. **Type:** String
*   `author_name`: The name to highlight (e.g., "Doe, J."). **Type:** String
*   `highlight_author`: Styling. **Type:** String (`bold`, `italic`, `color`, or format string)
*   `func_name`: The Typst function to render the list (Default: `"publication-list"`). Useful for advanced customization. **Type:** String

**Grouping & Sorting:**

*   `default_label`: The default label for items that don't match a group (Default: `"Other"`). **Type:** String
*   `group_labels`: A dictionary mapping **Pandoc types** to **Custom Labelss**. **Type:** Map (Key: String, Value: String)
    *   *Pandoc Types:* `article` (Journal), `book`, `conference` (Proceedings), `thesis`, `report`, `misc`.
*   `group_order`: A list defining the order of groups. **Type:** List of Strings
    *   **Indexing:** Use `Label=Index` strings to fix positions.
    *   **Note:** Use the *Custom Label* names here.

**Example:**
```yaml
publication-list:
  bib_file: ["pubs.bib", "talks.json"]
  bib_style: "assets/bib/apa-cv.csl"
  
  # Grouping
  default_label: "Miscellaneous"
  group_labels:
    article: "Journal Articles"
    conference: "Conference Proceedings"
  
  # Ordering: Put Journals 1st, Proceedings 3rd. 
  # "Miscellaneous" (default_label) will fill the 2nd slot.
  group_order: 
    - "Journal Articles=1"
    - "Conference Proceedings=3"
    - "Other"

  # Author Highlighting
  author_name: "Doe, J."
  highlight_author: "bold"
```

## Style & Output

### `style`
Customize the visual identity.

**Type:** Object (`color-accent`, `font-header`, `font-text`)

**Fields:**

*   `color-accent`: Hex color code (without `#`). **Type:** String
*   `font-header`: List of font families for headings. **Type:** List of Strings
*   `font-text`: List of font families for body text. **Type:** List of Strings

**Example:**
```yaml
style:
  color-accent: "5e81ac"
  font-header: ["Lato", "Helvetica", "sans-serif"]
  font-text: ["Roboto", "Arial", "sans-serif"]
```

### `render-output`
Controls which documents are generated.

**Options:** `"cv-only"`, `"letter-only"`, `"combined"`.

*   `cv-only`: Outputs the curriculum vitae only.
*   `letter-only`: Outputs the cover letter only.
*   `combined` (Default): Outputs both, the cover letter and the curriculum vitae.

```yaml
render-output: "combined"
```

### `attachments`
Appends documents to the end of the PDF.

**Type:** List of Objects (`name`, `file`)

**Fields:** (per item)

*   `name`: Display name. **Type:** String
*   `file`: Path to the image file. **Type:** String

```yaml
attachments:
  - name: "Transcript"
    file: "assets/docs/transcript.pdf"
```
