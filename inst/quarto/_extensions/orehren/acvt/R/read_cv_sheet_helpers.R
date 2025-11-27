# R/read_cv_sheet_helpers.R

#' Attempt to resolve identifier as a URL
#' @param doc_identifier The potential URL string.
#' @return The extracted Sheet ID string if successful, otherwise NULL.
#'         Aborts via cli/tryCatch if as_sheets_id fails definitively.
#' @noRd
#' @importFrom googlesheets4 as_sheets_id
#' @importFrom cli cli_abort cli_inform
.resolve_identifier_as_url <- function(doc_identifier) {
  # Let as_sheets_id handle URL parsing and validation directly.
  # It provides a clear error message on failure.
  resolved_id <- googlesheets4::as_sheets_id(doc_identifier)

  cli::cli_inform("Interpreted identifier as URL, extracted ID: {resolved_id}")
  return(resolved_id)
}


#' Attempt to resolve identifier as a Sheet ID
#' Checks if the string looks like a potential ID and tries to use it.
#' Relies on googlesheets4::as_sheets_id for implicit validation during use.
#' @param doc_identifier The potential ID string.
#' @return The input string if it looks like an ID, otherwise NULL.
#' @noRd
.resolve_identifier_as_id <- function(doc_identifier) {
  # Heuristic check: Not a URL, no spaces/slashes, reasonably long
  is_potential_id <- !grepl("://", doc_identifier, fixed = TRUE) &&
    !grepl("[[:space:]/]", doc_identifier) &&
    nchar(doc_identifier) > 30 # Google IDs are typically 44 chars

  if (is_potential_id) {
    # We don't strictly validate the ID format here, as as_sheets_id or gs4_get
    # will fail later if it's invalid. We just return it if it *looks* like an ID.
    # cli::cli_inform("Treating identifier as potential ID: {doc_identifier}") # Optional message
    return(doc_identifier)
  } else {
    return(NULL) # Does not look like an ID
  }
}


#' Attempt to resolve identifier as a Sheet Name using Google Drive search
#' Assumes input is intended as a name. Searches Drive, checks uniqueness.
#' @param doc_identifier The potential Sheet name string.
#' @return A 1-row dribble if a unique match is found. Aborts otherwise.
#' @noRd
#' @importFrom googledrive drive_find
#' @importFrom cli cli_abort cli_inform
.resolve_identifier_as_name <- function(doc_identifier) {
  cli::cli_inform("Interpreting identifier as a name, searching Google Drive for: {.val {doc_identifier}}")

  # Perform search directly. drive_find provides informative errors.
  found_files_dribble <- googledrive::drive_find(
    q = sprintf(
      "name = '%s' and mimeType = 'application/vnd.google-apps.spreadsheet'",
      gsub("'", "\\\\'", doc_identifier)
    ),
    n_max = 2 # Find 0, 1, or >1
  )

  # --- Check search results using Guard Clauses ---

  # Guard 1: Nothing found?
  if (nrow(found_files_dribble) == 0) {
    cli::cli_abort("No Google Sheet document found with the exact name {.val {doc_identifier}}.", call. = FALSE)
  }

  # Guard 2: Too many found?
  if (nrow(found_files_dribble) > 1) {
    cli::cli_abort(
      c("Multiple Google Sheet documents found with the name {.val {doc_identifier}}.",
        "i" = "Please use the unique document ID or URL instead."
      ),
      call. = FALSE
    )
  }

  # --- Success: Exactly one found ---
  cli::cli_inform("Found unique document with name {.val {doc_identifier}}, using its dribble representation.")
  return(found_files_dribble) # Return the 1-row dribble
}


#' Resolve document identifier to a gs4-compatible object (Dispatcher)
#' Determines if the identifier is a URL, potential ID, or name, and calls
#' the appropriate helper function for resolution.
#' Assumes basic type validation (non-empty string) has already occurred.
#' @param doc_identifier User-provided identifier (string).
#' @return The resolved identifier (string ID or dribble). Aborts on failure.
#' @noRd
#' @importFrom cli cli_abort
.resolve_doc_identifier <- function(doc_identifier) {
  # --- 1. Check if it's a URL ---
  is_url <- grepl("://", doc_identifier, fixed = TRUE)
  if (is_url) {
    # Call URL resolver (aborts on failure)
    resolved_input <- .resolve_identifier_as_url(doc_identifier)
    # If successful, resolved_input is the ID string
    return(resolved_input)
  }

  # --- 2. If not URL, check if it looks like an ID ---
  # Call ID resolver (returns ID string or NULL)
  resolved_id <- .resolve_identifier_as_id(doc_identifier)
  if (!is.null(resolved_id)) {
    # Looks like an ID, return it directly.
    # Validation happens later when used by gs4_get/read_sheet.
    return(resolved_id)
  }

  # --- 3. If not URL or potential ID, assume it's a name ---
  # Call Name resolver (returns dribble or aborts)
  resolved_dribble <- .resolve_identifier_as_name(doc_identifier)
  return(resolved_dribble)
}


#' Check if a specific sheet exists within a Google Sheet document
#' @param ss_input Resolved gs4 identifier (ID string, URL string, or dribble).
#' @param sheet_name The name of the sheet to check.
#' @return TRUE invisibly if sheet exists. Issues warning if metadata is invalid. Aborts if sheet not found.
#' @noRd
#' @importFrom googlesheets4 gs4_get
#' @importFrom googledrive as_id
#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom googlesheets4 read_sheet
#' @importFrom googledrive as_id
#' @importFrom cli cli_abort
.read_sheet_data <- function(ss_input, sheet_name, na_strings, col_types, trim_ws) {
  # Let googlesheets4 handle errors directly for better user feedback.
  googlesheets4::read_sheet(
    ss = ss_input,
    sheet = sheet_name,
    na = na_strings,
    col_types = col_types,
    trim_ws = trim_ws,
    .name_repair = "minimal"
  )
}


#' Perform post-read checks (e.g., check for empty tibble)
#' @param sheet_data The tibble returned by .read_sheet_data.
#' @param sheet_name The name of the sheet (for warning message).
#' @param doc_id_for_msg The document ID (for warning message).
#' @return The input sheet_data (potentially empty). Issues warning if empty.
#' @noRd
#' @importFrom cli cli_warn
.check_read_result <- function(sheet_data, sheet_name, doc_id_for_msg) {
  # Note: NULL check already happened in .read_sheet_data
  if (nrow(sheet_data) == 0) {
    cli::cli_warn(
      "Sheet {.val {sheet_name}} in document (ID: {.val {doc_id_for_msg}}) has no data (0 rows)."
    )
  }
  return(sheet_data)
}
