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
  # 1. Copy skeleton files to the new project path
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  if (skeleton_dir == "") {
    stop("Could not find the project template skeleton directory in the acvt package.", call. = FALSE)
  }
  files_to_copy <- list.files(skeleton_dir, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  file.copy(from = files_to_copy, to = path, recursive = TRUE)

  # 2. Read the copied template qmd file
  template_path <- file.path(path, "cv.qmd")
  template_content <- readLines(template_path)

  # 3. Separate YAML front matter
  delimiters <- which(template_content == "---")
  yaml_content <- template_content[(delimiters[1] + 1):(delimiters[2] - 1)]
  body_content <- template_content[(delimiters[2] + 1):length(template_content)]

  # 4. Parse and modify YAML
  yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))
  yaml_data$author$firstname <- firstname
  yaml_data$author$lastname <- lastname

  # Robustly find and update email
  for (i in seq_along(yaml_data$author$contact)) {
    if (!is.null(yaml_data$author$contact[[i]]$icon) && grepl("envelope", yaml_data$author$contact[[i]]$icon)) {
      yaml_data$author$contact[[i]]$text <- email
      yaml_data$author$contact[[i]]$url <- paste0("mailto:", email)
      break
    }
  }

  # 5. Convert back to YAML and write the file
  new_yaml_content <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)
  new_file_content <- c("---", strsplit(new_yaml_content, "\n")[[1]], "---", body_content)
  writeLines(new_file_content, template_path)

  # 6. Initialize renv and git in the new project directory
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
