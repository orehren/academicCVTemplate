---
title: "Data Integration"
---

# How-To: Data Integration with Google Sheets

A key feature of this template is its ability to populate your CV by pulling data directly from a Google Sheet. This allows you to maintain your CV content in a structured way, separate from the document itself.

This guide provides a brief overview. For a full list of options, please refer to the documentation for the `academicCVtools` R package.

## 1. The `academicCVtools` R Package

All data integration is handled by the `academicCVtools` R package. Ensure you have it installed as described in the **[Installation Guide](./installation.md)**.

The two key functions you will use are `load_cv_sheets()` and `format_typst_section()`.

## 2. Setting Up Your Google Sheet

The functions expect your Google Sheet to be organized with one sheet (tab) per CV section. For example:

*   A sheet named "Education"
*   A sheet named "Working Experiences"
*   A sheet named "Skills"

Each row in a sheet represents an entry in that section. The column headers in your sheet will become the field names for each entry (e.g., "Degree", "Institution", "Year").

## 3. Loading the Data

The first step in your `.qmd` file is to load the data from your Google Sheet. This is done in the R setup chunk.

```r
# In the [lst-setup] R chunk
cv_sheets <- load_cv_sheets(
  # The exact name of your Google Sheet
  doc_identifier = "My Academic CV Data",

  # A list of the sheets you want to load
  sheets_to_load = list(
    "Working Experiences",
    "Education",
    "Skills"
  )
)
```
The `load_cv_sheets` function will authenticate with Google, download the data, and store it in the `cv_sheets` R object.

## 4. Rendering a Section in Your CV

Once the data is loaded, you can render any section in your CV with a small R code chunk.

To render the "Education" section, you would add the following to your `.qmd` file:

```markdown
## Education

  ````r
  #| output: asis
  cv_sheets$Education |>
    format_typst_section(
      typst_func = "#resume-entry"
    ) |> cat()
  ````
```

### How it Works

1.  `cv_sheets$Education`: This selects the "Education" data that we loaded.
2.  `format_typst_section()`: This function takes the data and transforms it into the raw Typst code needed to render the section.
3.  `typst_func = "#resume-entry"`: This tells the function to format each row of data using the `#resume-entry` function defined in the Typst template, which is the standard layout for a CV item.
4.  `|> cat()`: This takes the generated Typst code and outputs it directly into the document.

You can create your entire CV by repeating this pattern for each section.
