---
title: "Installation"
---

# Installation Guide

To use the `academicCVTemplate`, you need to install the Quarto extension itself and the `academicCVtools` R package, which provides the functions for data integration.

## 1. Get Started with the Template

There are two ways to use the template. The first way is to incorporate the template into an existing project; the other is to initialize a new project with it.

The following steps can be executed in the terminal (or command prompt) of your OS or in the terminal tab of an IDE like RStudio.

In your terminal, navigate to the directory where you want to create the new project, or to your project's root directory if you want to use it with an existing project.

In RStudio, simply switch to the Terminal tab. In most cases, you will already be in your project's root directory.

### 1.1 Add to an Existing Project

If you want to use the template with an existing project, type the following command into the terminal:

````bash
quarto add orehren/academicCVTemplate
````

You can also use the older, alternative command:

```bash
quarto install extension orehren/academicCVTemplate
```

This will download the extension and place it into an `_extensions/orehren/academicCVTemplate` directory within your project.

### 1.2 Create a New Project from the Template

To start a new project using this template, type in the following command:

```bash
quarto use template orehren/academicCVTemplate
```

This will prompt you to provide a name for the new project directory. It will then create this directory and populate it with the template's starter files (like `academicCV-template.qmd`), ready for you to edit.

## 2. Set Up the R Environment

This template uses R to fetch and process data from Google Sheets. The project relies on the `renv` package for dependency management and the `academicCVtools` package for its core functions.

### 2.1. Install the `academicCVtools` Package

The `academicCVtools` package is not on CRAN, so you will need to install it directly from GitHub. Open your R console and run the following commands:

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
