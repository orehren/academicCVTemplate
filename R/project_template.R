#' Create a new Academic CV Project
#'
#' This function is called by the RStudio New Project wizard.
#'
#' @param path The path to the new project directory.
#' @param author The author name provided by the user.
#' @param ... Additional arguments.
#'
#' @export
create_acvt_project <- function(path, author = "Your Name", ...) {
  # 1. Create directory
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  # 2. Locate resources
  # When running from source (devtools::load_all), system.file might not work as expected
  # for 'inst' content unless we use 'load_all' which handles it.
  # For installed package, system.file("resources", ...) works.

  resources_path <- system.file("resources", package = "academicCVtools")

  # Fallback for dev mode (if system.file returns empty or we are running locally)
  if (resources_path == "") {
    # Try to find it relative to current working directory if we are testing locally
    if (dir.exists("inst/resources")) {
      resources_path <- "inst/resources"
    } else {
      stop("Could not find template resources. Ensure the package is installed correctly.")
    }
  }

  # 3. Copy files
  # file.copy with recursive=TRUE copies the FOLDER if it's a directory.
  # We want to copy the CONTENTS of resources into path.

  files <- list.files(resources_path, full.names = TRUE)

  # Filter out hidden files if necessary, but we want _quarto.yml and _extensions
  # list.files(all.files=TRUE) gets . files too.
  files <- list.files(resources_path, full.names = TRUE, all.files = TRUE, no.. = TRUE)

  if (length(files) == 0) {
     stop("No files found in resources directory.")
  }

  # Copy each top-level item
  for (f in files) {
    file.copy(f, path, recursive = TRUE)
  }

  # 4. Update Author Name
  if (!missing(author) && author != "Your Name" && author != "") {
    index_file <- file.path(path, "index.qmd")
    if (file.exists(index_file)) {
      lines <- readLines(index_file)

      # Simple heuristic to split name
      parts <- strsplit(author, "\\s+")[[1]]
      if (length(parts) > 0) {
        first <- parts[1]
        last <- if (length(parts) > 1) paste(parts[-1], collapse = " ") else ""

        # Regex replacement trying to match the specific template format
        # firstname: "Arthur"
        lines <- sub('^\\s*firstname:\\s*"Arthur"', sprintf('  firstname: "%s"', first), lines)
        lines <- sub('^\\s*lastname:\\s*"Author"', sprintf('  lastname: "%s"', last), lines)

        writeLines(lines, index_file)
      }
    }
  }

  message("Project created successfully at ", path)
}
