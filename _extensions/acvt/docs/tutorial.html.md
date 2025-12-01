---
title: "Tutorial: Your First CV"
---

# Tutorial: Creating Your First CV

This tutorial will guide you through the process of creating a complete CV and cover letter using the `academicCV-template.qmd` file.

## 1. The Template File

The template comes with a file named `academicCV-template.qmd`. This file serves as the control center for your CV. It contains:

1.  **YAML Header:** Metadata, configuration, and personal details.
2.  **Shortcodes:** Placeholders that tell Quarto where to insert your CV sections and publications.

Make a copy of this file and rename it to something like `my-cv.qmd`.

## 2. Configure Personal Details (YAML)

Open `my-cv.qmd`. The top section enclosed in `---` is the YAML header.

### 2.1. Basic Information

Update your name, position, and the document title.

```yaml
title: "Application for Assistant Professor"
author:
  firstname: "Jane"
  lastname: "Doe"
position: "PhD Candidate in Computational Biology"
```

### 2.2. Contact & Social Media

Add your contact & social media details. Each entry is a list, that consists of three information details. 

* `icon`: An icon to display for this contact or social media detail. You can use any [Font Awesome](https://fontawesome.com/) icon by specifying its class (e.g., `fa envelope`, `fa brands github`).
* `text`: The Text to be displayed for this contact or social media detail. You can choose any arbitrary text you like.
* `url`: The link address for this contact or social media detail. This is the address, that will be opened, when clicking on the contact detail in the final document.

Each of the detail informations are optional. For example:

```yaml
author:
  # ...
  contact:
    - icon: fa envelope
      text: "jane.doe@example.com"
      url: "mailto:jane.doe@example.com"
    - text: "New York, USA"
  socialmedia:
    - icon: fa brands github
      text: "github.com/janedoe"
      url: "https://github.com/janedoe"
```

This will render two contact details (e-mail address and the living location) and one social media detail (github profile) in the final document.

### 2.3. Profile Photo

To change the profile photo, replace the file at `_extensions/orehren/acvt/assets/images/picture.jpg` or update the path in the YAML:

```yaml
profile-photo: "path/to/your/photo.jpg"
# To disable the photo:
# profile-photo: null
```

**Note:** For this tutorial, we assume you want to use all features. However, if you don't have a profile photo or don't want it to be displayed, you can simply set this field to `null`. Just deleting the entry from the YAML header will not work in this case, as the default picture, which is just a placeholder image in form of a pictogram, will then be displayed.

## 3. The Cover Letter

This project gives you the possibility to include a cover letter, matching the design of the cv. To include a cover letter, first you need to set `render-output` in the YAML header of the document to either `"combined"`, which is the default value, or `"letter-only"`. While the first will output application documents, that include a cover letter as well as a cv, the latter one will output only a cover letter as final document. 

```yaml
render-output: "combined" | "letter-only"
```

To omit the renedring of a cover letter, choose `"cv-only"`, which will result in application documents, that only consist of the cv.

```yaml
render-output: "cv-only"
```

If you want to include a cover letter, configure the recipient details and write the content in the body of the document. 

### 3.1. Recipient Details

```yaml
recipient:
  name: "Dr. Turing"
  salutation: "Dear"
  valediction: "Sincerely
  addressee: Dr. Alan Turing"
  address: "Department of Computer Science"
  city: "Bletchley Park"
  zip: "MK3 6EB"
date: "October 24, 2025"
subject: "Application for Research Position"
```


### 3.2. Letter Content

Write your cover letter text under the `## Coverletter` heading in the main body of the document using standard Markdown.

```markdown
## Coverletter

I am writing to express my interest in...
```

Be aware, that you don't have to include the salutation or the valediction / complimentary close, as this will be automatically generated, based on the values in the YAML header. For the salutation, you can use `salutation: "Name of Person to address"`. The complimentary close will be generated from `author.firstname` and `author.lastname`.

## 4. Connecting Your Data

The power of this template comes from its integration with Google Sheets. Instead of typing your work history manually into the document, you manage it in a Google spreadsheet online.

1.  **Create your Sheet:** See the **[Data Integration](./data_integration.qmd)** guide for the expected format.
2.  **Configure YAML:**

```yaml
google-document:
  auth-email: "your.email@gmail.com"
  document-identifier: "Name_of_Your_Google_Sheet"
  sheets-to-load:
    - name: "Working Experiences" # Tab name in Google Sheets
      shortname: "working"        # ID to use in shortcodes
    - name: "Education"
      shortname: "education"
```

This allows you to automatically parse informations from sheets in a spreadsheet in your Google Drive and insert it into the document at any section.

## 5. Adding CV Sections (Shortcodes)

To display a section from your data (e.g., your work experience), use the `{{< cv-section >}}` shortcode. You place this directly in the document body.

```markdown
## Working Experience

{{< cv-section sheet="working" func="resume-entry" >}}
```

*   `sheet`: Matches the `shortname` you defined in the YAML.
*   `func`: The layout function to use (e.g., `resume-entry` for standard CV entries, `research-interests` for simple lists).

See the **[Shortcodes Reference: cv-section](./shortcodes.qmd#sec-cv-section)** for advanced options like filtering columns or combining bullet points.

## 6. Adding Publications

To add your publication list, configure the bibliography file in the YAML and use the `{{< publication-list >}}` shortcode.

```yaml
publication-list:
  bib-file: "my_pubs.bib"
  bib-style: "apa.csl"
```

*   `bib-file`: Path to your bibliography file(s), relative to your project root folder. Defaults to example bibliography files from different formats included in this extension.
*   `bib-style`: Path to your CSL Style file, relative to your project root folder. Defaults to an altered APA 7. Edition CSL style included in this extension.

You have the possibility to choose different bibliography file formats. This extension is able to handle the following bibliography formats:

| Format                            | File Suffix | Additional Informations |
| --------------------------------- | ----------- | ----------------------- |
| BibLaTeX                          | `.bib`      | [BibLaTeX - CTAN](https://ctan.org/pkg/biblatex) |
| BibTeX                            | `.bibtex`   | [BibTeX - CTAN](https://ctan.org/pkg/bibtex) |
| CSL YAML                          | `.yaml`     | [Citeproc CSL YAML Documentation](https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html) |
| CSL Json                          | `.json`     | [Citeproc CSL Json Documentation](https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html) |
| Research Information System (RIS) | `.ris`      | [RIS Documentation in RefDB Handbook](https://refdb.sourceforge.net/manual-0.9.6/sect1-ris-format.html) |
| EndNote XML                       | `.xml`      | [Official EndNote Documentation](https://docs.endnote.com/docs/endnote/2025/v1/windows/en/content/15independentbibs_export/independent_bibs_export.htm) |

To output the publication list, just insert the shortcode at the desired location in the document.

```markdown
## Publications

{{< publication-list >}}
```

See the **[Shortcodes Reference: publication-list](./shortcodes.qmd#sec-publication-list)** for advanced options like labeling of outlet groups or reordering.

## 7. Adding an Appendix (Attachments)

You can append documents (e.g., transcripts, certificates) to the end of your CV using the `attachments` YAML key.

```yaml
attachments:
  - name: "Master's Transcript"
    file: "assets/docs/transcript.png"
  - name: "Certificate"
    file: "assets/docs/cert.jpg"
```

### Supported File Types & Typst Version
The types of files you can include depend on the version of Typst installed on your system. You can check your version by running `quarto typst --version` in your terminal.

*   **Typst < 0.13.0:** Supports **Images only** (`.png`, `.jpg`, `.svg`).
*   **Typst >= 0.13.1:** Adds support for embedding **PDF** files (`.pdf`).

## 8. Render

To generate your PDF, run:

```bash
quarto render my-cv.qmd
```

