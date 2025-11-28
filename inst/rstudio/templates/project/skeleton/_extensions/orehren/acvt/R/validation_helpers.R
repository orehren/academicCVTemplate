#' Validate Arguments for `load_cv_sheets`
#'
#' An internal helper function that uses `checkmate` assertions to validate all
#' arguments passed to the `load_cv_sheets` function.
#'
#' @param doc_identifier The Google Sheet identifier.
#' @param sheets_to_load The specification of sheets to load.
#' @param ... Additional arguments (currently unused, for extensibility).
#'
#' @return `TRUE` (invisibly) if all checks pass, otherwise aborts with an error.
#' @noRd
.validate_load_cv_sheets_args <- function(doc_identifier, sheets_to_load, ...) {
  checkmate::assert_string(doc_identifier, min.chars = 1)
  if (is.character(sheets_to_load)) {
    checkmate::assert_character(sheets_to_load, min.chars = 1, min.len = 1)
  } else if (rlang::is_named(sheets_to_load)) {
    checkmate::assert_list(sheets_to_load, types = "character", names = "unique")
  } else {
    checkmate::assert_list(sheets_to_load, types = "character")
  }
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
