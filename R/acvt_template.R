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

  # 2. Locate the source extension directory in the package
  source_dir <- system.file("quarto/_extensions/orehren/acvt", package = "acvt")
  if (source_dir == "") {
    stop("Could not find the Quarto extension directory in the acvt package.", call. = FALSE)
  }

  # 3. Copy the entire extension to its destination
  dest_ext_parent_dir <- file.path(path, "_extensions", "orehren")
  dir.create(dest_ext_parent_dir, recursive = TRUE)
  file.copy(from = source_dir, to = dest_ext_parent_dir, recursive = TRUE)

  # 4. Copy the project files from the *newly copied* extension to the project root (explicitly)
  newly_copied_ext_dir <- file.path(dest_ext_parent_dir, "acvt")
  file.copy(from = file.path(newly_copied_ext_dir, "_quarto.yml"), to = path)
  file.copy(from = file.path(newly_copied_ext_dir, "academicCV-template.qmd"), to = path)

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
    renv::init()
  }

  if (git) {
    if (Sys.which("git") == "") {
      warning("Git is not installed or not in the system's PATH. Cannot initialize a git repository.")
    } else {
      system("git init", ignore.stdout = TRUE, ignore.stderr = TRUE)
    }
  }
}
