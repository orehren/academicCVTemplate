# Using the Academic CV Template

This guide provides a comprehensive overview of how to use this Quarto extension to create your own academic CV and cover letter.

## 1. Initial Setup

### 1.1. Installing the Extension

To use this template, you first need to install the Quarto extension. Open your terminal and run the following command:

```bash
quarto use template your-github-username/academiccvtemplate
```

This will download the extension into a `_extensions` directory in your project.

### 1.2. R Environment

This template relies on an R environment to fetch data (e.g., from Google Sheets) and process it. Ensure you have the necessary R packages installed. The project uses `renv` for dependency management. To restore the R environment, run the following command in your R console:

```r
renv::restore()
```

## 2. YAML Configuration

All configuration for your CV and cover letter is done in the YAML frontmatter of your `.qmd` file. Below is a detailed walkthrough of all available options.

### 2.1. Basic Document Information

```yaml
title: "Documents of Application"
author:
  firstname: "Your Firstname"
  lastname: "Your Lastname"
```

### 2.2. Contact and Social Media

This information is used to build the sidebar/header. It expects a list of items for `contact` and `socialmedia`.

```yaml
author:
  # ...
  contact:
    - icon: fa address-card
      text: "Your Address"
    - icon: fa mobile-screen
      text: "Your Phone Number"
    - icon: fa envelope
      text: "Your E-Mail-Address"
      url: "mailto:your.email@gmail.com"
  socialmedia:
    - icon: fa house
      text: "example.com"
      url: "https://example.com"
    - icon: fa github
      text: "Your GitHub Page"
      url: "https://github.com/your-username"
```

### 2.3. Cover Letter

These fields are used to generate the cover letter.

```yaml
recipient:
  name: "Recipient Name"
  salutation: "Dr. Recipient"
  address: "123 University Lane"
  city: "Scholartown"
  zip: "12345"
date: "January 1, 2024"
subject: "Application for the Postdoctoral Position"
```

The body of the cover letter is written directly in the `.qmd` document under a `## Coverletter` heading.

### 2.4. Core CV Content

```yaml
position: "Your Current Position or Position You Are Applying For"
profile-photo: "assets/images/picture.jpg" # Path relative to project root
aboutme: |
  A brief paragraph about yourself.
famous-quote:
  text: "A relevant quote."
  attribution: "Author of the quote"
```

### 2.5. Bibliography

The template uses Quarto's built-in bibliography support, with some defaults provided by the extension. You can override these in your `.qmd` file.

```yaml
bibliography: "assets/bib/my_bibliography.bib"
csl: "assets/bib/my_style.csl"
```

### 2.6. Styling and Output

```yaml
style:
  color-accent: "5e81ac" # A custom accent color
  font-header: "Lato"
  font-text: "Roboto"

render-output: "combined" # Options: "cv-only", "letter-only", or "combined"
```

## 3. Data Integration with Google Sheets

A key feature of this template is its ability to pull CV data directly from a Google Sheet.

### 3.1. Setup

The R code block in the `template.qmd` file handles the authentication and data loading. You will need to authenticate with your Google account the first time you render the document.

### 3.2. Configuration

In the setup R chunk, you need to specify the name of your Google Sheet and which tabs to load:

```r
cv_sheets <- load_cv_sheets(
  doc_identifier = "Your_Google_Sheet_Name",
  sheets_to_load = list(
    "Working Experiences",
    "Education",
    "IT Skills"
    # ... and so on
  )
)
```

### 3.3. Rendering Sections

Each section of your CV that is populated from the Google Sheet requires a small R code block. This block takes the data and passes it to the `format_typst_section` function, which converts it into the necessary Typst code.

```r
## Working Experiences

```{r}
#| output: asis
cv_sheets$working_experiences |>
  format_typst_section(
    typst_func = "#resume-entry"
  ) |> cat()
```

The `format_typst_section` function is highly customizable. Please refer to the `academicCVtools` package documentation for a full list of its arguments.

## 4. Rendering the Document

To render your CV and/or cover letter, simply use the Quarto `render` command in your terminal:

```bash
quarto render your_document.qmd
```

You can control what gets rendered using the `render-output` option in the YAML header.
