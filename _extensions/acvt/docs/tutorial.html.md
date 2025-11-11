---
title: "Tutorial: Your First CV"
---

# Tutorial: Creating Your First CV

This tutorial will guide you through the process of creating a complete CV and cover letter using the `template.qmd` file provided with the extension.

## 1. The `template.qmd` File

The easiest way to get started is by using the `template.qmd` file that comes with this extension. It contains a pre-configured YAML header and the necessary R code chunks to get you started.

Make a copy of this file and rename it to something like `my-cv.qmd`.

## 2. Configure the YAML Header

Open your new `.qmd` file. The top section, enclosed in `---`, is the YAML header. This is where you will configure all your personal information.

### 2.1. Basic Information

Start by filling in your name and the document title.

```yaml
title: "Documents of Application"
author:
  firstname: "Your Firstname"
  lastname: "Your Lastname"
```

### 2.2. Contact and Social Media

Fill in your contact details. You can add or remove items from this list as you see fit. The `icon` field uses Font Awesome icons.

```yaml
author:
  # ...
  contact:
    - icon: fa address-card
      text: "Your Address"
    - icon: fa mobile-screen
      text: "Your Phone Number"
    - icon: fa envelope
      text: "your.email@example.com"
      url: "mailto:your.email@example.com"
  socialmedia:
    - icon: fa github
      text: "Your GitHub"
      url: "https://github.com/your-username"
```

### 2.3. The `profile-photo`

By default, the template includes a placeholder image. To use your own photo, replace the placeholder file at `assets/images/picture.jpg` with your own image.

If you prefer not to have a profile photo, you can disable it in the YAML header:

```yaml
profile-photo: null
```

## 3. The Cover Letter

The body of your cover letter is written directly in the `.qmd` file under a `## Coverletter` heading. You can use standard Markdown for formatting.

```markdown
## Coverletter

Dear Dr. Recipient,

This is the body of my cover letter. I can use **bold**, *italics*, and other Markdown features.

Sincerely,
Your Name
```

## 4. Adding CV Content with R

The template is designed to pull data from a Google Sheet.

### 4.1. Set Up Your Google Sheet

The R code in the `template.qmd` expects a Google Sheet with specific tabs (e.g., "Working Experiences", "Education"). Make a copy of the example sheet and fill it with your own data.

### 4.2. Link Your Sheet

In the first R code chunk, update the `doc_identifier` to the name of your Google Sheet.

```r
# In the [lst-setup] R chunk
cv_sheets <- load_cv_sheets(
  doc_identifier = "Your_Google_Sheet_Name",
  # ...
)
```

### 4.3. Render a Section

For each section of your CV, there is a small R chunk that takes the data and formats it. For example, to render your work experience:

```r
## Working Experiences

```r
#| output: asis
cv_sheets$`Working Experiences` |>
  format_typst_section(
    typst_func = "#resume-entry"
  ) |> cat()
```
You can add, remove, or reorder these sections to build your CV.

## 5. Render the Document

Once you have configured your YAML and set up your data, you can render the final PDF. Open your terminal in the project directory and run:

```bash
quarto render my-cv.qmd
```

This will generate a `my-cv.pdf` file containing your professional, typeset CV and cover letter. Congratulations!
