#' Create a new Academic CV Project
#'
#' Implements the logic for the RStudio Project Wizard.
#'
#' @param path The path to the new project.
#' @param firstname The user's first name.
#' @param lastname The user's last name.
#' @param email The user's email address.
#' @param renv A boolean indicating whether to initialize renv.
#' @param git A boolean indicating whether to initialize a git repository.
#' @param ... Additional arguments.
#' @export
acvt_template <- function(path, firstname, lastname, email, renv, git, ...) {

  # 1. Create Project Directory
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # 2. Locate Skeleton
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  if (!nzchar(skeleton_dir)) {
    stop("Could not find the project template skeleton in the 'acvt' package.")
  }

  # 3. Copy Extension Files
  # We copy the full _extensions folder structure to the new project
  source_ext_dir <- file.path(skeleton_dir, "_extensions")
  dest_ext_dir   <- file.path(path, "_extensions")

  if (!dir.exists(dest_ext_dir)) dir.create(dest_ext_dir, recursive = TRUE)
  file.copy(from = source_ext_dir, to = path, recursive = TRUE)

  # 4. Move Template Files to Root & Rename
  # Adjust 'orehren' and 'acvt' if your folder structure inside _extensions differs!
  source_of_truth_dir <- file.path(dest_ext_dir, "orehren", "acvt")

  # Copy Config
  file.copy(from = file.path(source_of_truth_dir, "_quarto.yml"),
            to = file.path(path, "_quarto.yml"))

  # Copy AND Rename Main File in one step
  # This ensures 'cv.qmd' exists immediately for RStudio to open it.
  file.copy(from = file.path(source_of_truth_dir, "academicCV-template.qmd"),
            to = file.path(path, "cv.qmd"))

  # 5. Personalize YAML Header
  .update_template_yaml(file.path(path, "cv.qmd"), firstname, lastname)

  # 6. Initialize Version Control & Environment
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(path)

  if (git && nzchar(Sys.which("git"))) {
    system("git init", ignore.stdout = TRUE, ignore.stderr = TRUE)
  }

  if (renv && requireNamespace("renv", quietly = TRUE)) {
    renv::init(bare = TRUE, restart = FALSE)
  }

  return(invisible(TRUE))
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

.update_template_yaml <- function(file_path, firstname, lastname) {
  if (!requireNamespace("yaml", quietly = TRUE)) return()

  lines <- readLines(file_path)
  delimiters <- which(lines == "---")

  if (length(delimiters) < 2) return()

  # Extract YAML block
  yaml_content <- lines[(delimiters[1] + 1):(delimiters[2] - 1)]
  body_content <- lines[(delimiters[2] + 1):length(lines)]

  # Parse, Modify, Dump
  yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))
  yaml_data$author$firstname <- firstname
  yaml_data$author$lastname  <- lastname

  new_yaml_str <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)

  # Reassemble
  new_content <- c("---", strsplit(new_yaml_str, "\n")[[1]], "---", body_content)
  writeLines(new_content, file_path)
}
