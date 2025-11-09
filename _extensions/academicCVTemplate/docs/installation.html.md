---
title: "Installation"
---

# Installation Guide

To use the `academicCVTemplate`, you need to install the Quarto extension itself and the `academicCVtools` R package, which provides the functions for data integration.

## 1. Install the Quarto Extension

The first step is to add the extension to your Quarto project. Open your terminal or command prompt, navigate to your project's root directory, and run the following command:

```bash
quarto use template orehren/academicCVTemplate
```

This will download the extension files into a `_extensions` directory within your project.

## 2. Set Up the R Environment

This template uses R to fetch and process data from Google Sheets. The project relies on the `renv` package for dependency management and the `academicCVtools` package for its core functions.

### 2.1. Install the `academicCVtools` Package

The `academicCVtools` package is not yet on CRAN, so you will need to install it directly from GitHub. Open your R console and run the following commands:

```r
# First, ensure you have the 'remotes' package installed
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

# Now, install the tools package from GitHub
remotes::install_github("orehren/academicCVtools")
```

### 2.2. Restore Project Dependencies

The project template comes with a `renv.lock` file that lists all the specific R package versions needed to ensure the template renders correctly.

To install these packages, open your R console in the project directory and run:

```r
# Restore the R environment using renv
renv::restore()
```

This command will install all the necessary packages, ensuring that your environment perfectly matches the one the template was designed for.

## Next Steps

With the extension and the R environment set up, you are now ready to start creating your CV. Head over to the **[Tutorial](./tutorial.qmd)** for a step-by-step guide.
