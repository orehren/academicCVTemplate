#' Create a new Academic CV Project
#'
#' Implements the logic for the RStudio Project Wizard.
#' Accepts dynamic arguments via ellipsis.
#' Adds a temporary self-destructing hook to open the main file on first launch.
#'
#' @param path The path to the new project.
#' @param ... Dynamic arguments passed by RStudio based on the .dcf file.
#' @export
acvt_template <- function(path, ...) {

  # 1. Capture Arguments
  dots <- list(...)
  firstname <- dots$firstname
  lastname  <- dots$lastname
  renv_enabled <- isTRUE(dots$renv)
  git_enabled  <- isTRUE(dots$git)

  # 2. Create Project Directory
  path <- normalizePath(path, mustWork = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # 3. Locate Skeleton
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  if (!nzchar(skeleton_dir)) {
    stop("Could not find the project template skeleton in the 'acvt' package.")
  }

  # 4. Copy Extension Files
  source_ext_dir <- file.path(skeleton_dir, "_extensions")
  dest_ext_dir   <- file.path(path, "_extensions")

  if (!dir.exists(dest_ext_dir)) dir.create(dest_ext_dir, recursive = TRUE)
  file.copy(from = source_ext_dir, to = path, recursive = TRUE)

  # 5. Move Template Files to Root & Rename
  source_of_truth_dir <- file.path(dest_ext_dir, "orehren", "acvt")

  file.copy(from = file.path(source_of_truth_dir, "_quarto.yml"),
            to = file.path(path, "_quarto.yml"))

  target_qmd <- file.path(path, "cv.qmd")
  file.copy(from = file.path(source_of_truth_dir, "academicCV-template.qmd"),
            to = target_qmd)

  # 6. Personalize YAML Header
  .update_template_yaml(target_qmd, firstname, lastname)

  # 7. Initialize Version Control & Environment
  if (git_enabled && nzchar(Sys.which("git"))) {
    system(paste("git -C", shQuote(path), "init"), ignore.stdout = TRUE, ignore.stderr = TRUE)
  }

  if (renv_enabled && requireNamespace("renv", quietly = TRUE)) {
    renv::init(project = path, bare = TRUE, restart = FALSE)
  }

  # 8. Inject Temporary Self-Destructing Hook
  .add_temporary_open_hook(path, "cv.qmd")

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

  yaml_content <- lines[(delimiters[1] + 1):(delimiters[2] - 1)]
  body_content <- lines[(delimiters[2] + 1):length(lines)]

  yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))

  if (!is.null(firstname)) yaml_data$author$firstname <- firstname
  if (!is.null(lastname))  yaml_data$author$lastname  <- lastname

  new_yaml_str <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)

  new_content <- c("---", strsplit(new_yaml_str, "\n")[[1]], "---", body_content)
  writeLines(new_content, file_path)
}

.add_temporary_open_hook <- function(path, filename) {
  rprofile_path <- file.path(path, ".Rprofile")

  # Unique markers to identify the block for deletion
  marker_start <- "# <<< ACVT TEMPORARY HOOK START >>>"
  marker_end   <- "# <<< ACVT TEMPORARY HOOK END >>>"

  # The code injected into the new project's .Rprofile
  hook_code <- c(
    "",
    marker_start,
    "local({",
    "  if (interactive() && Sys.getenv('RSTUDIO') == '1') {",
    "    setHook('rstudio.sessionInit', function(newSession) {",
    sprintf("      if (newSession && file.exists('%s') && requireNamespace('rstudioapi', quietly = TRUE)) {", filename),
    sprintf("        rstudioapi::navigateToFile('%s')", filename),
    "        ",
    "        # --- SELF DESTRUCT SEQUENCE ---",
    "        # Reads .Rprofile, removes this block, and saves.",
    "        try({",
    "          p <- '.Rprofile'",
    "          if (file.exists(p)) {",
    "            l <- readLines(p)",
    sprintf("            s <- which(l == '%s')", marker_start),
    sprintf("            e <- which(l == '%s')", marker_end),
    "            if (length(s) > 0 && length(e) > 0) {",
    "              l <- l[-(s:e)]", # Remove lines between markers (inclusive)
    "              writeLines(l, p)",
    "            }",
    "          }",
    "        }, silent = TRUE)",
    "      }",
    "    }, action = 'append')",
    "  }",
    "})",
    marker_end
  )

  # Append to .Rprofile (create if not exists)
  write(paste(hook_code, collapse = "\n"), file = rprofile_path, append = TRUE)
}
