---
title: "Installation"
---

# Installation Guide

To use the `academicCVTemplate`, you need to install the extension and the necessary R packages for data integration.

## 1. Install the Extension

You can start a new project with the template or add it to an existing Quarto project.

### Option A: Create a New Project (Recommended)

To start fresh, run this command in your terminal:

```bash
quarto use template orehren/academicCVTemplate
```

Follow the prompts to name your directory (e.g., `my-cv`).

### Option B: Add to an Existing Project

If you already have a Quarto project, run this command in your project root:

```bash
quarto add orehren/academicCVTemplate
```

This downloads the extension files into the `_extensions/` directory.

## 2. Install R Packages

This extension uses R to fetch and process data from Google Sheets. Regardless of how you installed the extension, you **must** install the required R packages.

Open your R console (or RStudio) and run:

```r
install.packages(c(
  "googledrive",
  "googlesheets4",
  "yaml",
  "rmarkdown",
  "cli",
  "purrr",
  "checkmate",
  "rlang",
  "janitor"
))
```

## 3. Next Steps

Once installed, you need to connect your Google Sheet.

*   **Go to [Data Integration](./data_integration.qmd)** to set up authentication and your spreadsheet.
*   **Go to [Tutorial](./tutorial.qmd)** for a walkthrough of the template features.
