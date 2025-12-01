#' Main Orchestration Function for CV Data Fetching
#'
#' This function serves as the main entry point for the Quarto pre-render script.
#' It orchestrates the process of fetching, transforming, and writing the CV data
#' to a hidden JSON file used by the Lua filters.
#'
#' @param ... This function does not take any direct arguments.
#'
#' @return No return value. Side effect: creates/updates `.cv_data.json`.
#' @importFrom rlang %||%
main <- function(...) {
  cli::cli_h1("CV Data Extension Setup")

  # --- 1. Helper Script Loading ---
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

  # --- 2. Configuration Discovery ---
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

  # --- 3. Cache Logic (JSON) ---
  # We use a single hidden JSON file as both cache and data source for Lua.
  data_file <- ".cv_data.json"

  if (file.exists(data_file)) {
    age <- difftime(Sys.time(), file.info(data_file)$mtime, units = "hours")

    # If cache is fresh (< 24h), we do nothing.
    # Lua will read the existing file. R doesn't need to load it.
    if (age < 24) {
      cli::cli_alert_success("Cached data found in {.file {data_file}} (fresh). Skipping fetch.")
      return(invisible(NULL))
    }
  }

  # --- 4. Fetching & Auth ---
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

  # --- 5. Transformation ---
  # We keep the transformation to list-of-lists (key/value) to preserve
  # column order for the Lua scripts, which expect this specific structure.
  cli::cli_alert_info("Transforming data structure...")

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

  # --- 6. Saving (JSON) ---
  cli::cli_alert_info("Saving to local JSON...")

  # Wrap in 'cv_data' key to match the structure expected by Lua logic later
  output_data <- list(cv_data = final_cv_data)

  # Write to hidden JSON file
  # auto_unbox=TRUE is important to keep simple strings as strings, not arrays
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cli::cli_abort("Package 'jsonlite' is required but not installed.")
  }

  jsonlite::write_json(output_data, data_file, auto_unbox = TRUE, pretty = FALSE)

  cli::cli_alert_success("Data successfully updated in {.file {data_file}}")
}

main()
