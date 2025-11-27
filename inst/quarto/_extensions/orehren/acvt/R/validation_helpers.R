# R/validation_helpers.R

#' Validate arguments for create_publication_list
#'
#' @param bib_file Path to the .bib file.
#' @param author_name Author's full name.
#' @param csl_file Path to the .csl file.
#' @param group_labels Named character vector for group labels.
#' @param default_label Default label string.
#' @param group_order Optional character vector for sort order.
#' @param pandoc_path Optional path to Pandoc executable.
#' @param author_highlight_markup Typst markup string.
#' @param typst_func_name Typst function name.
#'
#' @return `TRUE` (invisibly) if all checks pass.
#' @importFrom checkmate assert_file_exists assert_string assert_character assert_named
#' @noRd
.validate_create_publication_list_args <- function(
    bib_file, author_name, csl_file, group_labels, default_label,
    group_order, pandoc_path, author_highlight_markup, typst_func_name) {
  checkmate::assert_file_exists(bib_file, extension = "bib")
  checkmate::assert_string(author_name, min.chars = 1)
  checkmate::assert_file_exists(csl_file, extension = "csl")
  checkmate::assert_character(group_labels, min.len = 1, names = "unique")
  checkmate::assert_string(default_label, min.chars = 1)
  if (!is.null(group_order)) {
    checkmate::assert_character(group_order, unique = TRUE)
  }
  if (!is.null(pandoc_path)) {
    checkmate::assert_string(pandoc_path, min.chars = 1)
  }
  checkmate::assert_string(
    author_highlight_markup,
    pattern = "%s"
  )
  checkmate::assert_string(
    typst_func_name,
    pattern = "^[a-zA-Z0-9_-]+$"
  )
  invisible(TRUE)
}

#' Validate arguments for format_typst_section
#'
#' @param data A data frame or tibble.
#' @param typst_func The name of the Typst function.
#' @param combine_cols Tidyselect expression.
#' @param combine_as Name of the new combined column.
#' @param combine_sep Separator for combined columns.
#' @param combine_prefix Prefix for combined column values.
#' @param exclude_cols Tidyselect expression.
#' @param na_action How to handle `NA` values.
#' @param output_mode Output structure.
#'
#' @return `TRUE` (invisibly) if all checks pass.
#' @importFrom checkmate assert_data_frame assert_string assert_character assert_choice
#' @importFrom rlang quo_is_null
#' @noRd
.validate_format_typst_section_args <- function(
    data, typst_func, combine_cols, combine_as, combine_sep,
    combine_prefix, exclude_cols, na_action, output_mode) {
  checkmate::assert_data_frame(data)
  checkmate::assert_string(typst_func, pattern = "^#")
  checkmate::assert_string(combine_as)
  checkmate::assert_string(combine_sep)
  checkmate::assert_string(combine_prefix)
  checkmate::assert_choice(na_action, c("omit", "keep", "string"))
  checkmate::assert_choice(output_mode, c("rowwise", "array"))
  invisible(TRUE)
}

#' Validate arguments for load_cv_sheets
#' @noRd
.validate_load_cv_sheets_args <- function(doc_identifier, sheets_to_load, ...) {
  # Validate doc_identifier
  checkmate::assert_string(doc_identifier, min.chars = 1)

  # Validate sheets_to_load
  if (is.character(sheets_to_load)) {
    checkmate::assert_character(sheets_to_load, min.chars = 1, min.len = 1)
  } else if (rlang::is_named(sheets_to_load)) {
    checkmate::assert_list(sheets_to_load, types = "character", names = "unique")
  } else {
    checkmate::assert_list(sheets_to_load, types = "character")
  }
}

#' Validate arguments for read_cv_sheet
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

#' Find and validate an executable, returning its path
#'
#' @param exec_name The name of the executable (e.g., "pandoc").
#' @param path_arg An optional user-provided path to the executable.
#' @param arg_name The name of the argument providing `path_arg` (for error messages).
#'
#' @return The validated, absolute path to the executable.
#' @importFrom cli cli_abort
#' @importFrom checkmate assert_string test_file_exists
#' @noRd
.validate_executable_found <- function(exec_name, path_arg = NULL, arg_name = "path_arg") {
  if (!is.null(path_arg)) {
    if (!checkmate::test_file_exists(path_arg)) {
      cli::cli_abort(
        c(
          "x" = "Executable not found at the path you provided.",
          " " = "Argument: {.arg {arg_name}}",
          " " = "Path: {.path {path_arg}}"
        ),
        call = NULL
      )
    }
    return(path_arg)
  }

  exec_path <- Sys.which(exec_name)
  if (exec_path == "") {
    cli::cli_abort(
      c(
        "x" = "{.val {exec_name}} executable not found in your system's PATH.",
        "i" = "Please install {exec_name} or provide a direct path via the {.arg {arg_name}} argument."
      ),
      call = NULL
    )
  }
  exec_path
}

#' Validate the corrected column_order argument
#'
#' @param column_order A list for reordering, e.g., `list("col_a" = 1)`.
#' @param data The data frame to check against.
#'
#' @return `TRUE` (invisibly) if checks pass.
#' @importFrom checkmate assert_list assert_numeric
#' @importFrom cli cli_abort
#' @noRd
.validate_column_order_corrected <- function(column_order, data) {
  if (is.null(column_order)) {
    return(invisible(TRUE))
  }

  checkmate::assert_list(column_order, names = "unique")

  # Check that names (column names) exist in the data
  specified_cols <- names(column_order)
  missing_cols <- setdiff(specified_cols, colnames(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      c(
        "x" = "Columns specified in {.arg column_order} not found in the data.",
        "i" = "Missing column{?s}: {.val {missing_cols}}"
      ),
      call = NULL
    )
  }

  # Check that values (positions) are unique positive integers
  order_indices <- unlist(column_order)
  checkmate::assert_numeric(order_indices, lower = 1, unique = TRUE, any.missing = FALSE)
  if (any(order_indices %% 1 != 0)) {
    cli::cli_abort(
      c(
        "x" = "The values of the {.arg column_order} list must be positive integers.",
        "i" = "Example: {.code list(\"col_a\" = 1, \"col_b\" = 3)}"
      ),
      call = NULL
    )
  }

  invisible(TRUE)
}
