---
title: "Installation"
---

# Installation Guide

There are two ways to install and use the `acvt` project: via the R package (recommended) or via manual Quarto installation.

## Method 1: Installation via R Package (Recommended)

This is the easiest and most powerful way to use the template. This method installs all R package dependencies automatically and makes the project available as a template in the RStudio "New Project" wizard.

### 1. Install the R Package from GitHub

Open your R console (or RStudio) and run the following commands:

```r
# Install devtools if you don't have it already
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

# Install the acvt package from GitHub
devtools::install_github("orehren/academicCVTemplate")
```

### 2. Restart RStudio

You must restart your RStudio session for the project template to appear in the wizard.

### 3. Create a New Project

After restarting, go to **File > New Project... > New Directory**. You will now see "Academic CV Project" in the list of project types. Select it, fill in your details, and a new, ready-to-use CV project will be created. All R package dependencies will be installed and available to the project.

## Method 2: Alternative Manual Installation

If you prefer not to use the R package or the RStudio template, you can install the Quarto extension manually.

## 1. Install the Extension

You can start a new project with the template or add it to an existing Quarto project.

### Option A: Create a New Project (Recommended)

To start fresh, run this command in your terminal:

```bash
quarto use template orehren/acvt
```

Follow the prompts to name your directory (e.g., `my-cv`).

### Option B: Add to an Existing Project

If you already have a Quarto project, run this command in your project root:

```bash
quarto add orehren/acvt
```

This downloads the extension files into the `_extensions/` directory. You then need to copy the files `_quarto.yml` from the `orehren/acvt` folder to the project base folder.

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
  "rlang"
))
```

## 3. Next Steps

Once installed, you need to connect your Google Sheet.

*   **Go to [Data Integration](./data_integration.qmd)** to set up authentication and your spreadsheet.
*   **Go to [Tutorial](./tutorial.qmd)** for a walkthrough of the template features.
