---
title: "Data Integration"
---

This template separates content from layout by fetching data from Google Sheets.

## 1. Setup Data Integration

Before you can render your CV, you must authenticate with Google Drive. The extension's pre-render script runs non-interactively, so it relies on a **cached authentication token**.

### Step 1: Authenticate Interactively

Open your R console (in your project directory) and run:

```r
library(googledrive)
drive_auth()
```

1.  This will open a browser window.
2.  Log in with the Google account that has access to your CV spreadsheet.
3.  Grant the requested permissions.

### Step 2: Ensure Token Availability

The authentication token is typically stored in a user-level cache (e.g., `~/.cache/gargle`). The Quarto render process needs to access this token to fetch your data.

*   **Run in Project Context:** The most reliable method is to run the `drive_auth()` command in the R Console **of your project** (e.g., inside RStudio with your project open). This ensures that the token is cached in a location accessible to the project's environment.
*   **Match the Email:** Ensure that the email address you use to log in matches exactly with the `auth-email` you specify in the `google-document` YAML configuration. The pre-render script uses this email to look up the correct token.
*   **Persistence:** Once authenticated interactively *once*, the token persists. You do not need to run `drive_auth()` every time you render, only when the token expires or becomes invalid.

## 2. Configuration

In your `.qmd` file, configure the connection in the `google-document` YAML block.

```yaml
google-document:
  auth-email: "your.email@gmail.com" # The email you authenticated with
  document-identifier: "Name_of_Your_Sheet"
  sheets-to-load:
    - name: "Working Experiences"
      shortname: "working"
```

For a detailed explanation of all available configuration options, please refer to the **[`google-document` section in the YAML Reference](./yaml_reference.qmd#sec-google-document)**.

## 3. Spreadsheet Structure

Your Google Sheet should have separate tabs for each section. The first row must contain **Column Headers**.

### Example: Skills (Visualized)

For the visual skills bar (using `visualize-skills-list`), your data **must** include a `value` column (0.0 - 1.0):

| area | skill | value | level |
| :--- | :--- | :--- | :--- |
| Languages | English | 1.0 | Native |
| Tech | R | 0.9 | Expert |

### Example: Working Experience

| title | location | description | start | end |
| :--- | :--- | :--- | :--- | :--- |
| Researcher | Uni X | Project Y | 2020 | 2024 |

## 4. Connecting Data to Layout

Once your data is structured in Google Sheets, you need to tell the template where and how to display it. You do this using the `cv-section` shortcode.

This shortcode acts as a bridge: it fetches the data from the sheet you specify (e.g., `working`) and passes each row to a Typst layout function (e.g., `resume-entry`).

```markdown
{{< cv-section sheet="working" func="resume-entry" >}}
```

By default, the columns in your sheet are passed to the layout function in the order they appear. If you need to customize this mapping (e.g., if your sheet columns are in a different order than the layout expects), you can use the `column-order` argument.

For a complete guide on how to control this mapping, combine columns, and filter data, please consult the **[`cv-section` section in the Shortcodes Reference](./shortcodes.qmd#sec-cv-section)**.

