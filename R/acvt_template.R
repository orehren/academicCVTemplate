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
  source_ext_dir <- file.path(skeleton_dir, "_extensions")
  dest_ext_dir   <- file.path(path, "_extensions")

  if (!dir.exists(dest_ext_dir)) dir.create(dest_ext_dir, recursive = TRUE)
  file.copy(from = source_ext_dir, to = path, recursive = TRUE)

  # 4. Move Template Files to Root & Rename
  # We copy directly to the target name 'cv.qmd' so it matches the .dcf OpenFiles directive immediately.
  source_of_truth_dir <- file.path(dest_ext_dir, "orehren", "acvt")

  file.copy(from = file.path(source_of_truth_dir, "_quarto.yml"),
            to = file.path(path, "_quarto.yml"))

  file.copy(from = file.path(source_of_truth_dir, "academicCV-template.qmd"),
            to = file.path(path, "academicCV-template.qmd"))

  # 5. Personalize YAML Header
  .update_template_yaml(file.path(path, "academicCV-template.qmd"), firstname, lastname)

  # 6. Initialize Version Control & Environment
  # FIX: We do NOT use setwd() here to avoid confusing RStudio's context switching.

  if (git && nzchar(Sys.which("git"))) {
    # Use -C to run git in the target directory without changing global WD
    system(paste("git -C", shQuote(path), "init"), ignore.stdout = TRUE, ignore.stderr = TRUE)
  }

  if (renv && requireNamespace("renv", quietly = TRUE)) {
    # Use the 'project' argument to target the new directory
    renv::init(project = path, bare = TRUE, restart = FALSE)
  }

  return(invisible(NULL))
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

.update_template_yaml <- function(file_path, firstname, lastname) {
  if (!requireNamespace("yaml", quietly = TRUE)) return()

  lines <- readLines(file_path)
  delimiters <- which(lines == "---")

  if (length(delimiters) < 2) return()

  yaml_content <- lines[(delimiters[1] + 1):(delimiters[2] - 1)]
  body_content <- lines[(delimiters[2] + 1):length(lines)]

  yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))
  yaml_data$author$firstname <- firstname
  yaml_data$author$lastname  <- lastname

  new_yaml_str <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)

  new_content <- c("---", strsplit(new_yaml_str, "\n")[[1]], "---", body_content)
  writeLines(new_content, file_path)
}
