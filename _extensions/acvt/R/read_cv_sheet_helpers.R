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
  } else {
    return(NULL)
  }
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

  found_files_dribble <- googledrive::drive_find(
    q = sprintf(
      "name = '%s' and mimeType = 'application/vnd.google-apps.spreadsheet'",
      gsub("'", "\\\\'", doc_identifier)
    ),
    n_max = 2
  )

  if (nrow(found_files_dribble) == 0) {
    cli::cli_abort("No Google Sheet document found with the exact name {.val {doc_identifier}}.", call. = FALSE)
  }

  if (nrow(found_files_dribble) > 1) {
    cli::cli_abort(
      c("Multiple Google Sheet documents found with the name {.val {doc_identifier}}.",
        "i" = "Please use the unique document ID or URL instead."
      ),
      call. = FALSE
    )
  }

  cli::cli_inform("Found unique document with name {.val {doc_identifier}}, using its dribble representation.")
  return(found_files_dribble)
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
  is_url <- grepl("://", doc_identifier, fixed = TRUE)
  if (is_url) {
    resolved_input <- .resolve_identifier_as_url(doc_identifier)
    return(resolved_input)
  }

  resolved_id <- .resolve_identifier_as_id(doc_identifier)
  if (!is.null(resolved_id)) {
    return(resolved_id)
  }

  resolved_dribble <- .resolve_identifier_as_name(doc_identifier)
  return(resolved_dribble)
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
