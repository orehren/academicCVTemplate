---
title: "YAML Reference"
---

# Complete YAML Reference

This page provides a comprehensive reference for all the configuration options available in the YAML frontmatter of your `.qmd` file.

## `title`

The main title for the generated PDF document.

**Type:** String
**Example:**
```yaml
title: "Application Documents of John Doe"
```

## `author`

A nested object containing information about you.

**Type:** Object
**Fields:**
*   `firstname`: Your first name. (String)
*   `lastname`: Your last name. (String)
*   `contact`: A list of your contact details. (See below)
*   `socialmedia`: A list of your social media profiles. (See below)

### `author.contact`

A list of contact items. Each item is an object with the following fields:

*   `icon`: A Font Awesome icon class (e.g., `fa envelope`).
*   `text`: The text to display.
*   `url`: (Optional) A URL to link to (e.g., `mailto:`, `tel:`).

**Example:**
```yaml
author:
  contact:
    - icon: fa envelope
      text: "your.email@example.com"
      url: "mailto:your.email@example.com"
    - icon: fa mobile-screen
      text: "+1 (555) 123-4567"
```

### `author.socialmedia`

Identical in structure to `contact`.

**Example:**
```yaml
author:
  socialmedia:
    - icon: fa github
      text: "GitHub Profile"
      url: "https://github.com/your-username"
```

## `recipient`

An object containing information about the cover letter recipient.

**Type:** Object
**Fields:**
*   `name`: Full name of the recipient.
*   `salutation`: Formal salutation (e.g., "Dr. Smith").
*   `address`: Street address.
*   `city`: City.
*   `zip`: Postal code.

## `date`

The date for the cover letter.

**Type:** String
**Example:** `date: "November 8, 2025"`

## `subject`

The subject line for the cover letter.

**Type:** String
**Example:** `subject: "Application for Postdoctoral Position"`

## `position`

The position you are applying for or your current title. Displayed on the CV title page.

**Type:** String

## `profile-photo`

The path to your profile photo, relative to the project root. To disable the photo, provide an empty string.

**Type:** String
**Examples:**
```yaml
# Use a photo
profile-photo: "assets/images/my_photo.jpg"

# Disable the photo
profile-photo: ""
```

## `aboutme`

A short paragraph about yourself, displayed on the CV.

**Type:** String (can be multi-line)

## `famous-quote`

An optional quote to display on the CV.

**Type:** Object
**Fields:**
*   `text`: The text of the quote.
*   `attribution`: The author of the quote.

## `render-output`

Controls which documents are generated.

**Type:** String
**Options:**
*   `"cv-only"`: Renders only the CV.
*   `"letter-only"`: Renders only the cover letter.
*   `"combined"`: Renders the cover letter followed by the CV in a single PDF.

## `attachments`

A list of documents to append to the end of the PDF, such as certificates or transcripts. Each item is an object with:

*   `name`: The title to display for the attachment.
*   `file`: The path to the image file of the attachment.

**Example:**
```yaml
attachments:
  - name: "Master's Degree Certificate"
    file: "attachments/master_cert.png"
  - name: "Bachelor's Degree Certificate"
    file: "attachments/bachelor_cert.png"
```

## `style`

An object for customizing visual styles.

**Type:** Object
**Fields:**
*   `color-accent`: The main accent color for the document (hex code).
*   `font-header`: A list of fonts for headings.
*   `font-text`: A list of fonts for body text.

**Example:**
```yaml
style:
  color-accent: "#005f73"
  font-header: ["Lato", "Helvetica", "sans-serif"]
```

## `bibliography` and `csl`

Standard Quarto options for controlling the bibliography.

**Type:** String (file path)
