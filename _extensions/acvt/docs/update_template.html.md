---
title: "Template & Update Management"
---

Since Quarto extensions are file-based (files are copied into your project folder upon creation), existing projects do not automatically benefit from updates to the R package.

The `acvt` package provides three specialized functions to keep your templates and projects up to date.

## Overview: Which tool for which purpose?

| Function | Audience | Source | Destination | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`update_current_cv_project()`** | **User** | Installed R Package | Current Project (`_extensions/`) | Updates an **existing** CV after a package update. |
| **`update_template_from_git()`** | **User** | GitHub (Main Branch) | Installed R Package | Updates the template for **new** projects without reinstalling the package ("Hotfix"). |
| **`dev_sync_template()`** | **Developer** | Local Source (`inst/`) | Installed R Package | Tests changes to the template immediately in the "New Project" wizard. |

## 1. Updating Existing Projects

### `update_current_cv_project()`

This function is designed for end-users who are already working on a CV. If a new version of the `acvt` package is released (e.g., containing bug fixes for the Lua filter or CSS updates), your existing project will initially remain on the old version.

This function copies the extension files from your currently installed R library into your active project directory.

**Usage:**
Run this command in the R console while your CV project is open in RStudio:

```r
acvt::update_current_cv_project()
```

**What happens:**
1.  Checks if you are in a valid CV project (`_quarto.yml` exists).
2.  Deletes the folder `_extensions/orehren/acvt`.
3.  Copies the version from the installed R package to this location.

::: {.callout-warning}
## Warning: Overwrite
Any manual changes you have made directly to files inside the `_extensions/` folder will be lost. However, changes to your `cv.qmd` or `_quarto.yml` remain untouched.
:::

## 2. Updating the Template Installation (Hotfix)

### `update_template_from_git()`

This function updates the template ("Skeleton") stored inside the R package, which is used by the RStudio "New Project" wizard. It downloads the latest files directly from GitHub.

This is useful for quickly obtaining the latest version of the template without going through the process of a full package re-installation (`devtools::install_github(...)`).

**Usage:**

```r
# Standard: Downloads from the main branch
acvt::update_template_from_git()

# Optional: Choose a different branch or repository
acvt::update_template_from_git(branch = "develop")
```

**What happens:**
1.  Downloads the repository as a ZIP file from GitHub.
2.  Extracts the folder `inst/rstudio/templates/project/skeleton`.
3.  Overwrites the corresponding folder in your R library.

**Effect:**
All **future** projects created via the wizard will now use this version. Existing projects are not affected.

::: {.callout-note}
## Permissions
This function requires write access to your R library folder. On Windows and macOS (User Library), this is usually not an issue. In managed Linux environments (System Library), this might fail if you do not have sufficient permissions.
:::

## 3. Development & Testing

### `dev_sync_template()`

This function is a tool purely for package developers. It accelerates the "Edit-Test-Loop" when working on the template files (`cv.qmd`, `template.dcf`, etc.).

Instead of having to rebuild and reinstall the package (`Install & Restart`) after every change to `inst/`, this function synchronizes the files immediately.

**Usage:**
Must be run from the root directory of the `acvt` source package:

```r
acvt::dev_sync_template()
```

**What happens:**
1.  Takes the files from your local development folder `inst/rstudio/templates/project/skeleton`.
2.  Copies them directly into the package's installation folder in the R library.

**Workflow:**
1.  Make changes to `inst/.../academicCV-template.qmd`.
2.  Run `acvt::dev_sync_template()`.
3.  Open *File -> New Project* in RStudio -> The changes are visible immediately.
