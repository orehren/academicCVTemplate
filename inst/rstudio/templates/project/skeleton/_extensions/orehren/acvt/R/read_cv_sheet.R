#' Read a Specific Sheet from a Google Sheet
#'
#' Reads a single sheet from a Google Sheet document, handling identifier
#' resolution, data reading, and post-read checks.
#'
#' @details This function serves as the core data reading engine. It takes a
#'   flexible `doc_identifier` (which can be a URL, a sheet ID, or a document
#'   name), resolves it to a stable identifier, reads the specified `sheet_name`,
#'   and returns the data as a tibble.
#'
#' @param doc_identifier A character string representing the ID, URL, or a unique
#'   name of the target Google Sheets document.
#' @param sheet_name A character string of the exact sheet name (tab) to read.
#' @param na_strings A character vector of strings to be interpreted as `NA`.
#'   Defaults to `c("", "NA", "N/A")`.
#' @param col_types A character string specifying the column types for `googlesheets4`.
#'   Defaults to `NULL` for auto-detection.
#' @param trim_ws A logical value. If `TRUE` (the default), leading and trailing
#'   whitespace is trimmed from character cells.
#'
#' @return A `tibble` containing the data from the specified sheet.
#'
#' @export
read_cv_sheet <- function(doc_identifier,
                          sheet_name,
                          na_strings = c("", "NA", "N/A"),
                          col_types = NULL,
                          trim_ws = TRUE) {
  .validate_read_cv_sheet_args(
    doc_identifier, sheet_name, na_strings, col_types, trim_ws
  )

  ss_input <- .resolve_doc_identifier(doc_identifier)

  sheet_data <- .read_sheet_data(
    ss_input, sheet_name, na_strings, col_types, trim_ws
  )

  doc_id_for_msg <- tryCatch(
    googledrive::as_id(ss_input),
    error = function(e) "UNKNOWN_ID"
  )
  sheet_data <- .check_read_result(sheet_data, sheet_name, doc_id_for_msg)

  return(sheet_data)
}


#' Resolve Identifier as URL
#'
#' Internal helper to extract a Google Sheet ID from a URL string.
#'
#' @param doc_identifier A character string suspected to be a URL.
#'
#' @return The extracted Google Sheet ID as a character string.
#'
#' @noRd
.resolve_identifier_as_url <- function(doc_identifier) {
  resolved_id <- googlesheets4::as_sheets_id(doc_identifier)
  cli::cli_inform("Interpreted identifier as URL, extracted ID: {resolved_id}")
  return(resolved_id)
}

#' Resolve Identifier as ID
#'
#' Internal helper to heuristically check if a string could be a Google Sheet ID.
#'
#' @param doc_identifier A character string.
#'
#' @return The input string if it appears to be an ID, otherwise `NULL`.
#'
#' @noRd
.resolve_identifier_as_id <- function(doc_identifier) {
  is_potential_id <- !grepl("://", doc_identifier, fixed = TRUE) &&
    !grepl("[[:space:]/]", doc_identifier) &&
    nchar(doc_identifier) > 30

  if (is_potential_id) {
    return(doc_identifier)
  }
  return(NULL)
}

#' Resolve Identifier as Name
#'
#' Internal helper to find a unique Google Sheet by name using a Google Drive search.
#'
#' @param doc_identifier The sheet name to search for.
#'
#' @return A 1-row `dribble` if a unique match is found. Aborts with an error
#'   if no match or multiple matches are found.
#'
#' @noRd
.resolve_identifier_as_name <- function(doc_identifier) {
  cli::cli_inform("Interpreting identifier as a name, searching Google Drive for: {.val {doc_identifier}}")

  found_files <- .find_file_in_drive(doc_identifier)

  .validate_search_result(found_files, doc_identifier)

  cli::cli_inform("Found unique document with name {.val {doc_identifier}}, using its dribble representation.")
  return(found_files)
}

.find_file_in_drive <- function(name) {
  # Escape single quotes for the Drive query syntax
  safe_name <- gsub("'", "\\\\'", name)

  googledrive::drive_find(
    q = sprintf("name = '%s' and mimeType = 'application/vnd.google-apps.spreadsheet'", safe_name),
    n_max = 2
  )
}

.validate_search_result <- function(found_files, original_name) {
  if (nrow(found_files) == 0) {
    cli::cli_abort("No Google Sheet document found with the exact name {.val {original_name}}.", call. = FALSE)
  }

  if (nrow(found_files) > 1) {
    cli::cli_abort(
      c("Multiple Google Sheet documents found with the name {.val {original_name}}.",
        "i" = "Please use the unique document ID or URL instead."
      ),
      call. = FALSE
    )
  }
}

#' Resolve Document Identifier (Dispatcher)
#'
#' Internal helper that determines if an identifier is a URL, ID, or name and
#' calls the appropriate resolution helper.
#'
#' @param doc_identifier The user-provided identifier string.
#'
#' @return A resolved gs4-compatible object (either a string ID or a `dribble`).
#'
#' @noRd
.resolve_doc_identifier <- function(doc_identifier) {
  if (grepl("://", doc_identifier, fixed = TRUE)) {
    return(.resolve_identifier_as_url(doc_identifier))
  }

  resolved_id <- .resolve_identifier_as_id(doc_identifier)
  if (!is.null(resolved_id)) {
    return(resolved_id)
  }

  return(.resolve_identifier_as_name(doc_identifier))
}

#' Read Sheet Data
#'
#' Internal helper that wraps the `googlesheets4::read_sheet` call.
#'
#' @param ss_input The resolved gs4-compatible identifier.
#' @param sheet_name The name of the sheet to read.
#' @param na_strings A character vector of NA strings.
#' @param col_types A character string specifying column types.
#' @param trim_ws A logical value for trimming whitespace.
#'
#' @return A `tibble` of the sheet's data.
#'
#' @noRd
.read_sheet_data <- function(ss_input, sheet_name, na_strings, col_types, trim_ws) {
  googlesheets4::read_sheet(
    ss = ss_input,
    sheet = sheet_name,
    na = na_strings,
    col_types = col_types,
    trim_ws = trim_ws,
    .name_repair = "minimal"
  )
}

#' Perform Post-Read Checks
#'
#' Internal helper that checks if the data read from a sheet is empty and
#' issues a warning if it is.
#'
#' @param sheet_data The `tibble` returned from `read_sheet`.
#' @param sheet_name The name of the sheet, for the warning message.
#' @param doc_id_for_msg The document ID, for the warning message.
#'
#' @return The input `sheet_data`.
#'
#' @noRd
.check_read_result <- function(sheet_data, sheet_name, doc_id_for_msg) {
  if (nrow(sheet_data) == 0) {
    cli::cli_warn(
      "Sheet {.val {sheet_name}} in document (ID: {.val {doc_id_for_msg}}) has no data (0 rows)."
    )
  }
  return(sheet_data)
}


#' Validate Arguments for `read_cv_sheet`
#'
#' An internal helper function that uses `checkmate` assertions to validate all
#' arguments passed to the `read_cv_sheet` function.
#'
#' @param doc_identifier The Google Sheet identifier.
#' @param sheet_name The name of the sheet to read.
#' @param na_strings A vector of strings to treat as `NA`.
#' @param col_types The column type specification.
#' @param trim_ws A logical value for trimming whitespace.
#'
#' @return `TRUE` (invisibly) if all checks pass, otherwise aborts with an error.
#' @noRd
.validate_read_cv_sheet_args <- function(
    doc_identifier, sheet_name, na_strings, col_types, trim_ws) {
  checkmate::assert_string(doc_identifier, min.chars = 1)
  checkmate::assert_string(sheet_name, min.chars = 1)
  checkmate::assert_character(na_strings, null.ok = FALSE)
  if (!is.null(col_types)) {
    checkmate::assert_atomic(col_types)
  }
  checkmate::assert_logical(trim_ws, len = 1, any.missing = FALSE)
}
