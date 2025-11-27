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
  # 1. Define the single source directory for all template files
  source_dir <- system.file("quarto/_extensions/orehren/acvt", package = "acvt")
  if (source_dir == "") {
    stop("Could not find the Quarto extension directory in the acvt package.", call. = FALSE)
  }

  # 2. Copy the core project files to the new project path
  files_to_copy <- c("_quarto.yml", "academicCV-template.qmd")
  file.copy(from = file.path(source_dir, files_to_copy), to = path)

  # 3. Rename the template qmd file
  file.rename(from = file.path(path, "academicCV-template.qmd"), to = file.path(path, "cv.qmd"))

  # 4. Copy the full extension directory
  dir.create(file.path(path, "_extensions/orehren"), recursive = TRUE)
  file.copy(from = source_dir, to = file.path(path, "_extensions/orehren"), recursive = TRUE)


  # 5. Read the copied template qmd file
  template_path <- file.path(path, "cv.qmd")
  template_content <- readLines(template_path)

  # 6. Separate YAML front matter
  delimiters <- which(template_content == "---")
  yaml_content <- template_content[(delimiters[1] + 1):(delimiters[2] - 1)]
  body_content <- template_content[(delimiters[2] + 1):length(template_content)]

  # 7. Parse and modify YAML
  yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))
  yaml_data$author$firstname <- firstname
  yaml_data$author$lastname <- lastname

  # Robustly find and update email
  for (i in seq_along(yaml_data$author$contact)) {
    if (grepl("envelope", yaml_data$author$contact[[i]]$icon)) {
      yaml_data$author$contact[[i]]$text <- email
      yaml_data$author$contact[[i]]$url <- paste0("mailto:", email)
      break
    }
  }

  # 8. Convert back to YAML and write the file
  new_yaml_content <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)
  new_file_content <- c("---", strsplit(new_yaml_content, "\n")[[1]], "---", body_content)
  writeLines(new_file_content, template_path)

  # 9. Initialize renv and git in the new project directory
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(path)

  if (renv) {
    renv::init()
  }

  if (git) {
    git_path <- Sys.which("git")
    if (git_path == "") {
      warning("Git is not installed or not in the system's PATH. Cannot initialize a git repository.")
    } else {
      system("git init", ignore.stdout = TRUE, ignore.stderr = TRUE)
    }
  }
}
