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
