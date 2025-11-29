#' Prepare Sheet Loading Configuration
#'
#' Internal helper to determine the exact sheet names to read and the desired
#' names for the output list elements based on the `sheets_to_load` argument.
#'
#' @param sheets_to_load A named list/vector, an unnamed character vector, or the
#'   string `"*"`.
#' @param ss_input The resolved Google Sheet identifier (ID string, URL string,
#'   or dribble), required if `sheets_to_load` is `"*"`.
#'
#' @return A list with two elements: `sheet_names_to_read` (character vector)
#'   and `target_list_names` (character vector).
#'
#' @noRd
.prepare_sheet_load_config <- function(sheets_to_load, ss_input = NULL) {

  sheet_names_to_read <- NULL
  target_list_names <- NULL

  is_special_wildcard <- is.character(sheets_to_load) && length(sheets_to_load) == 1 && sheets_to_load == "*"

  if (is_special_wildcard) {
    if (is.null(ss_input)) {
      cli::cli_abort("Internal error: {.arg ss_input} must be provided when {.arg sheets_to_load} is \"*\".", call. = FALSE)
    }
    cli::cli_inform("Fetching all sheet names from the document...")
    sheet_names_to_read <- tryCatch({
      googlesheets4::sheet_names(ss_input)
    }, error = function(e) {
      cli::cli_abort("Failed to retrieve sheet names from the document when 'sheets_to_load = \"*\"'.", parent = e, call. = FALSE)
    })

    if (length(sheet_names_to_read) == 0) {
      cli::cli_warn("No sheets found in the document or failed to retrieve names.")
      return(list(sheet_names_to_read = character(0), target_list_names = character(0)))
    }

    target_list_names <- gsub("[^[:alnum:]_]+", "_", tolower(sheet_names_to_read))
    cli::cli_inform("Using all {length(sheet_names_to_read)} sheets found: {paste(shQuote(sheet_names_to_read), collapse = ', ')}. Target list names: {.val {target_list_names}}")

  } else {
    if (rlang::is_named(sheets_to_load)) {
      sheet_names_to_read <- names(sheets_to_load)
      target_list_names <- as.character(unlist(sheets_to_load))
    } else {
      sheet_names_to_read <- sheets_to_load
      target_list_names <- gsub("[^[:alnum:]_]+", "_", tolower(sheet_names_to_read))
      cli::cli_inform(
        "Using cleaned sheet names as names for the returned list: {.val {target_list_names}}"
      )
    }
  }

  return(list(
    sheet_names_to_read = sheet_names_to_read,
    target_list_names = target_list_names
  ))
}

#' Load Data for Multiple Sheets
#'
#' Internal helper that iteratively calls `read_cv_sheet` for a list of sheet
#' names.
#'
#' @param sheet_names_to_read A character vector of sheet names to read.
#' @param doc_identifier The resolved document identifier (ID, URL, or dribble).
#' @param ... Additional arguments to pass down to `read_cv_sheet`.
#'
#' @return A list of tibbles, one for each sheet.
#'
#' @noRd
.load_sheets_data <- function(sheet_names_to_read, doc_identifier, ...) {
  cli::cli_inform("Starting data loading for {length(sheet_names_to_read)} sheet(s)...")

  read_from_specific_doc <- purrr::partial(
    read_cv_sheet,
    doc_identifier = doc_identifier,
    ...
  )

  loaded_data_list <- purrr::map(
    sheet_names_to_read,
    ~ {
      cli::cli_inform("--> Loading sheet {.val {.x}}...")
      read_from_specific_doc(sheet_name = .x)
    }
  )

  cli::cli_inform("...Data loading finished.")
  return(loaded_data_list)
}
