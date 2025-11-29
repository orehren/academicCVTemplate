#' Main Orchestration Function for CV Data Fetching
#'
#' This function serves as the main entry point for the Quarto pre-render script.
#' It orchestrates the entire process of fetching, caching, transforming, and
#' writing the CV data. It is designed to be called directly when the script is
#' executed by Quarto.
#'
#' @param ... This function does not take any direct arguments.
#'
#' @return This function does not return a value. It operates by producing a
#'   side effect: writing the `_cv_data.yml` file to the project's root
#'   directory. It also creates a `.cv_cache.rds` file to cache results.
#' @importFrom rlang %||%
main <- function(...) {
  cli::cli_h1("CV Data Extension Setup")

  ext_r_files <- list.files(
    path = "_extensions",
    pattern = "^load_cv_sheets\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )

  script_dir <- NULL
  if (length(ext_r_files) > 0) {
    script_dir <- dirname(ext_r_files[1])
  } else if (file.exists("R/load_cv_sheets.R")) {
    script_dir <- "R"
  } else {
    cli::cli_abort("Could not find the 'R' folder containing helper scripts.")
  }

  helpers <- list.files(script_dir, pattern = "\\.[Rr]$", full.names = TRUE)
  helpers <- helpers[!grepl("_fetch_cv_data\\.R$", helpers)]

  for (h in helpers) {
    source(h, local = TRUE)
  }

  qmd_files <- list.files(pattern = "\\.qmd$")
  cv_config <- NULL

  for (f in qmd_files) {
    fm <- rmarkdown::yaml_front_matter(f)
    if (!is.null(fm$`google-document`)) {
      cv_config <- fm$`google-document`
      break
    }
  }

  if (is.null(cv_config)) {
    cli::cli_alert_warning("No 'google-document' configuration found. Skipping.")
    return(invisible(NULL))
  }

  cache_file <- ".cv_cache.rds"
  output_yaml_file <- "_cv_data.yml"

  final_cv_data <- NULL
  is_cached <- FALSE

  if (file.exists(cache_file)) {
    age <- difftime(Sys.time(), file.info(cache_file)$mtime, units = "hours")
    if (age < 24) is_cached <- TRUE
  }

  if (is_cached) {
    cli::cli_alert_success("Loading transformed data from cache.")
    final_cv_data <- readRDS(cache_file)
  } else {

    doc_identifier <- cv_config[["document-identifier"]]
    sheets_config <- cv_config[["sheets-to-load"]]
    auth_email <- cv_config[["auth-email"]]

    if (is.null(doc_identifier) || is.null(sheets_config)) {
      cli::cli_abort("Missing configuration: document-identifier or sheets-to-load.")
    }

    cli::cli_process_start("Authenticating with Google")
    tryCatch(
      {
        googledrive::drive_auth(email = auth_email %||% TRUE)
        googlesheets4::gs4_auth(token = googledrive::drive_token())
        cli::cli_process_done()
      },
      error = function(e) {
        cli::cli_process_failed()
        cli::cli_abort(c(
          "Authentication failed.",
          "i" = "Please run `googledrive::drive_auth()` interactively once.",
          "x" = e$message
        ))
      }
    )

    final_sheets_config <- list()
    for (item in sheets_config) {
      if (is.list(item)) {
        final_sheets_config[[item$name]] <- item$shortname
      } else {
        final_sheets_config[[item]] <- gsub("[^a-z0-9_]", "_", tolower(item))
      }
    }

    cli::cli_alert_info("Loading Sheets from Google...")

    real_doc_id <- doc_identifier
    if (!grepl("^[a-zA-Z0-9_-]{30,}$", doc_identifier)) {
      cli::cli_alert_info("Resolving name '{doc_identifier}'...")
      drive_res <- googledrive::drive_get(doc_identifier)
      if (nrow(drive_res) == 0) cli::cli_abort("Sheet '{doc_identifier}' not found.")
      real_doc_id <- drive_res$id[1]
    }

    raw_data_list <- load_cv_sheets(
      doc_identifier = real_doc_id,
      sheets_to_load = final_sheets_config
    )

    cli::cli_alert_info("Transforming data for sequential YAML export...")

    final_cv_data <- purrr::map(raw_data_list, function(sheet_content) {
      if (is.data.frame(sheet_content)) {
        rows <- purrr::transpose(sheet_content)

        list_of_ordered_rows <- purrr::map(rows, function(row) {
          purrr::imap(row, function(val, key) {
            list(key = key, value = val)
          }) |> unname()
        })

        return(list_of_ordered_rows)
      }
      return(sheet_content)
    })

    saveRDS(final_cv_data, cache_file)
  }

  yaml::write_yaml(list(cv_data = final_cv_data), output_yaml_file)
  cli::cli_alert_success("Data ready in {.file {output_yaml_file}}")
}

main()
