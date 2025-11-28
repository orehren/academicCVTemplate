---
title: "YAML Reference"
---

---
title: "YAML Reference"
---

# Complete YAML Reference

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

**Note:** Set to `null` or `""` to disable the photo.

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

Configures the connection to your Google Sheet data source.

### `google-document`
**Type:** Object (`auth-email`, `document-identifier`, `sheets-to-load`)

**Fields:**

*   `auth-email`: The email address used for Google authentication. **Type:** String
*   `document-identifier`: The name or ID of your Google Sheet. **Type:** String
*   `sheets-to-load`: A list of sheets to import. **Type:** List of Objects (`name`, `shortname`)

#### `sheets-to-load` Items
You can define sheets using objects (recommended for control) or simple strings.

**Object Format:**

*   `name`: The exact name of the tab in your Google Sheet. **Type:** String
*   `shortname`: The unique ID you will use in the `{{< cv-section >}}` shortcode. **Type:** String

**String Format:**

*   You can simply list the tab names. The `shortname` will be automatically generated (lowercased, spaces replaced by underscores, special chars removed).
    *   Example: `"Working Experiences"` -> `working_experiences`

**Example:**
```yaml
google-document:
  auth-email: "me@gmail.com"
  document-identifier: "My_CV_Data"
  sheets-to-load:
    # Object Format
    - name: "Working Experiences"
      shortname: "working"
    # String Format
    - "Education" # shortname becomes 'education'
```

## Publication List (`publication-list`)

Configures the automated bibliography generation.

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
