# _fetch_cv_data.R
# ==============================================================================
# Quarto Pre-render Script
# ------------------------------------------------------------------------------
# 1. Authenticates with Google (Drive & Sheets).
# 2. Loads CV data based on the YAML configuration of the .qmd file.
# 3. Transforms dataframes into row-lists (for clean YAML output).
# 4. Caches data locally (.cv_cache.rds) for faster re-rendering.
# 5. Writes _cv_data.yml for access by Quarto/Lua.
# ==============================================================================

# --- Check Dependencies ---
required_pkgs <- c("yaml", "rmarkdown", "cli", "googledrive", "googlesheets4", "purrr", "checkmate", "rlang", "janitor")
missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(paste("Missing packages:", paste(missing_pkgs, collapse = ", ")))
}

main <- function() {
  # ----------------------------------------------------------------------------
  # 1. Setup & Paths
  # ----------------------------------------------------------------------------
  cli::cli_h1("CV Data Extension Setup")

  # We search for the 'R' folder within the extension to load helpers.
  # We look for 'load_cv_sheets.R' as an anchor.
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
    # Fallback for development (if working in the repo root)
    script_dir <- "R"
  } else {
    cli::cli_abort("Could not find the 'R' folder containing helper scripts.")
  }

  # Source all .R scripts in the found folder (except this script itself)
  helpers <- list.files(script_dir, pattern = "\\.[Rr]$", full.names = TRUE)
  helpers <- helpers[!grepl("_fetch_cv_data\\.R$", helpers)]

  for (h in helpers) {
    source(h, local = TRUE)
  }

  # ----------------------------------------------------------------------------
  # 2. Read Configuration
  # ----------------------------------------------------------------------------
  # We scan .qmd files for the 'google-document' key
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

  # ----------------------------------------------------------------------------
  # 3. Caching Logic
  # ----------------------------------------------------------------------------
  cache_file <- ".cv_cache.rds"
  output_yaml_file <- "_cv_data.yml"

  final_cv_data <- NULL
  is_cached <- FALSE

  # Cache is valid for 24 hours
  if (file.exists(cache_file)) {
    age <- difftime(Sys.time(), file.info(cache_file)$mtime, units = "hours")
    if (age < 24) is_cached <- TRUE
  }

  # ----------------------------------------------------------------------------
  # 4. Load Data (Cache or New)
  # ----------------------------------------------------------------------------

  if (is_cached) {
    cli::cli_alert_success("Loading transformed data from cache.")
    final_cv_data <- readRDS(cache_file)
  } else {
    # --- LIVE FETCH ---

    doc_identifier <- cv_config[["document-identifier"]]
    sheets_config <- cv_config[["sheets-to-load"]]
    auth_email <- cv_config[["auth-email"]]

    if (is.null(doc_identifier) || is.null(sheets_config)) {
      cli::cli_abort("Missing configuration: document-identifier or sheets-to-load.")
    }

    # Auth: Drive first (Master), then pass token to Sheets
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

    # Config normalization for load_cv_sheets helper
    final_sheets_config <- list()
    for (item in sheets_config) {
      if (is.list(item)) {
        final_sheets_config[[item$name]] <- item$shortname
      } else {
        final_sheets_config[[item]] <- gsub("[^a-z0-9_]", "_", tolower(item))
      }
    }

    # Load data (Result are Tibbles/Dataframes)
    cli::cli_alert_info("Loading Sheets from Google...")

    # Resolve ID if necessary (via Drive)
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

    # --- TRANSFORMATION ---
    cli::cli_alert_info("Transforming data for sequential YAML export...")

    final_cv_data <- purrr::map(raw_data_list, function(sheet_content) {
      if (is.data.frame(sheet_content)) {
        # 1. Transpose: Dataframe -> List of named rows
        rows <- purrr::transpose(sheet_content)

        # 2. IMPORTANT: Named row -> List of Key-Value pairs
        # We convert `list(a=1, b=2)` into `list(list(key="a", val=1), list(key="b", val=2))`
        # This forces YAML to write a list and Lua to preserve the order.

        list_of_ordered_rows <- purrr::map(rows, function(row) {
          # We iterate over names and values to build an unnamed list
          purrr::imap(row, function(val, key) {
            list(key = key, value = val)
          }) |> unname()
        })

        return(list_of_ordered_rows)
      }
      return(sheet_content)
    })

    # Save cache
    saveRDS(final_cv_data, cache_file)
  }

  # --- YAML EXPORT ---
  yaml::write_yaml(list(cv_data = final_cv_data), output_yaml_file)
  cli::cli_alert_success("Data ready in {.file {output_yaml_file}}")
}

main()
