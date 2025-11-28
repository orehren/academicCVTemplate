#' Create a new Academic CV Project
#'
#' @param path The path to the new project.
#' @param firstname The user's first name.
#' @param lastname The user's last name.
#' @param email The user's email address.
#' @param renv A boolean indicating whether to initialize renv.
#' @param git A boolean indicating whether to initialize a git repository.
#' @param ... Additional arguments (not used).
#' @export
acvt_template <- function(path, firstname, lastname, email, renv, git, ...) {
  # 1. Create the project directory
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # 2. Locate the source skeleton directory in the package
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  if (skeleton_dir == "") {
    stop("Could not find the project template skeleton directory in the acvt package.", call. = FALSE)
  }

  # 3. Copy the entire _extensions directory
  source_ext_dir <- file.path(skeleton_dir, "_extensions")
  dest_ext_dir <- file.path(path, "_extensions")
  dir.create(dest_ext_dir, recursive = TRUE)
  file.copy(from = source_ext_dir, to = path, recursive = TRUE)

  # 4. Copy project files from the single source of truth to the project root
  source_of_truth_dir <- file.path(dest_ext_dir, "orehren", "acvt")
  file.copy(from = file.path(source_of_truth_dir, "_quarto.yml"), to = path)
  file.copy(from = file.path(source_of_truth_dir, "academicCV-template.qmd"), to = path)

  # 5. Rename the template qmd file
  file.rename(from = file.path(path, "academicCV-template.qmd"), to = file.path(path, "cv.qmd"))

  # 6. Read and modify the new qmd file
  template_path <- file.path(path, "cv.qmd")
  template_content <- readLines(template_path)

  delimiters <- which(template_content == "---")
  yaml_content <- template_content[(delimiters[1] + 1):(delimiters[2] - 1)]
  body_content <- template_content[(delimiters[2] + 1):length(template_content)]

  yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))
  yaml_data$author$firstname <- firstname
  yaml_data$author$lastname <- lastname

  for (i in seq_along(yaml_data$author$contact)) {
    if (grepl("envelope", yaml_data$author$contact[[i]]$icon)) {
      yaml_data$author$contact[[i]]$text <- email
      yaml_data$author$contact[[i]]$url <- paste0("mailto:", email)
      break
    }
  }

  new_yaml_content <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)
  new_file_content <- c("---", strsplit(new_yaml_content, "\n")[[1]], "---", body_content)
  writeLines(new_file_content, template_path)

  # 7. Initialize renv and git
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(path)

  if (renv) {
    if (requireNamespace("renv", quietly = TRUE)) {
      renv::init()
    } else {
      warning("`renv` package not found. Please install it to use renv with this project.")
    }
  }

  if (git) {
    if (Sys.which("git") == "") {
      warning("Git is not installed or not in the system's PATH. Cannot initialize a git repository.")
    } else {
      system("git init", ignore.stdout = TRUE, ignore.stderr = TRUE)
    }
  }
}
