# R/format_typst_section.R

#' Format a single value for Typst based on NA handling rules
#'
#' This helper encapsulates the logic for handling NA values and escaping
#' special characters for Typst strings.
#'
#' @param values A vector of values to format.
#' @param na_action The NA handling strategy: "omit", "keep", or "string".
#'
#' @return A character vector of formatted values. `NA` is used to mark
#'   values that should be filtered out in a later step.
#' @importFrom dplyr case_when
#' @noRd
.format_typst_value <- function(values, na_action) {
  # The `case_when` is vectorized and handles the logic for each value.
  dplyr::case_when(
    is.na(values) & na_action == "omit"   ~ NA_character_,
    is.na(values) & na_action == "keep"   ~ "none",
    is.na(values) & na_action == "string" ~ '"NA"',
    !is.na(values)                        ~ paste0('"', .escape_typst_string(as.character(values)), '"'),
    # This default case should ideally not be reached with the logic above.
    TRUE                                  ~ NA_character_
  )
}

#' Reorder data frame columns based on a named list (corrected syntax)
#'
#' @param data The data frame to reorder.
#' @param column_order A named list where names are column names and values are
#'   positions.
#'
#' @return The reordered data frame.
#' @importFrom dplyr relocate all_of
#' @noRd
.reorder_columns_corrected <- function(data, column_order) {
  original_cols <- colnames(data)
  cols_to_order <- names(column_order)

  # Start with columns that are NOT being reordered
  remaining_cols <- setdiff(original_cols, cols_to_order)

  # Dynamically insert the specified columns at their new positions
  final_cols <- remaining_cols
  # Sort by position to ensure correct insertion order
  sorted_order <- column_order[order(unlist(column_order))]

  for (col_name in names(sorted_order)) {
    pos <- sorted_order[[col_name]]
    # `append` is safe for positions beyond the current length
    final_cols <- append(final_cols, col_name, after = pos - 1)
  }

  dplyr::relocate(data, dplyr::all_of(final_cols))
}

#' Format CV section data into a Typst string
#'
#' Takes a data frame (tibble) representing a CV section and formats it into
#' a single string suitable for Typst. Each row of the data frame is converted
#' into a Typst function call. Columns can be combined or excluded using
#' tidyselect syntax.
#'
#' @param data A data frame or tibble where each row is a CV entry.
#' @param typst_func The name of the Typst function to call for each entry.
#' @param combine_cols Tidyselect expression for columns to combine.
#' @param combine_as Name of the new combined column.
#' @param combine_sep Separator for combined columns.
#' @param combine_prefix Prefix for combined column values.
#' @param exclude_cols Tidyselect expression for columns to exclude.
#' @param column_order A named list to specify column order. The list names must
#'   be the column names as strings, and the values should be positive integers
#'   representing the desired column position. Any columns not specified will be
#'   placed after the ordered columns in their original relative order.
#'   Example: `list("date" = 1, "location" = 3)`
#' @param na_action How to handle `NA` values: "omit", "keep", or "string".
#' @param output_mode Output structure: "rowwise" or "array".
#'
#' @return A single character string containing Typst code.
#'
#' @importFrom dplyr select mutate across all_of relocate row_number
#' @importFrom tidyr unite pivot_longer
#' @importFrom rlang enquo arg_match sym
#' @importFrom tidyselect everything
#' @export
format_typst_section <- function(data,
                                 typst_func,
                                 combine_cols = NULL,
                                 combine_as = "details",
                                 combine_sep = "\\ ",
                                 combine_prefix = "- ",
                                 exclude_cols = NULL,
                                 column_order = NULL,
                                 na_action = c("omit", "keep", "string"),
                                 output_mode = c("rowwise", "array")) {
  # --- Phase 0: Argument Matching and Validation ---
  na_action <- rlang::arg_match(na_action)
  output_mode <- rlang::arg_match(output_mode)

  combine_cols_quo <- rlang::enquo(combine_cols)
  exclude_cols_quo <- rlang::enquo(exclude_cols)

  .validate_format_typst_section_args(
    data, typst_func, combine_cols_quo, combine_as, combine_sep,
    combine_prefix, exclude_cols_quo, na_action, output_mode
  )
  .validate_column_order_corrected(column_order, data)

  # --- Phase 1: Handle Empty Data ---
  if (nrow(data) == 0) {
    return("```{=typst}\n```")
  }

  # --- Phase 2: Data Preparation ---
  combine_col_names <- evaluate_tidyselect_safely(combine_cols_quo, data, "combine_cols")
  exclude_col_names <- evaluate_tidyselect_safely(exclude_cols_quo, data, "exclude_cols")

  data_proc <- data

  if (length(combine_col_names) > 0) {
    data_proc <- data_proc |>
      dplyr::mutate(dplyr::across(dplyr::all_of(combine_col_names), ~ifelse(is.na(.), NA, paste0(combine_prefix, .)))) |>
      tidyr::unite(
        col = !!rlang::sym(combine_as),
        dplyr::all_of(combine_col_names),
        sep = combine_sep,
        na.rm = TRUE,
        remove = TRUE
      )
  }

  if (length(exclude_col_names) > 0) {
    data_proc <- dplyr::select(data_proc, -dplyr::all_of(exclude_col_names))
  }

  if (!is.null(column_order)) {
    data_proc <- .reorder_columns_corrected(data_proc, column_order)
  }

  # --- Phase 3: Vectorized String Generation ---
  # This pipeline transforms the data frame into a vector of Typst dictionaries.
  # 1. Pivot data longer to get key-value pairs for each original row.
  # 2. Format the 'value' column into a Typst-safe string using the helper.
  # 3. Filter out any key-value pairs that should be omitted (where value is now NA).
  # 4. Group by the original row ID and summarize to build the dictionary string.
  typst_dictionaries <- data_proc |>
    dplyr::mutate(.row_id = dplyr::row_number()) |>
    tidyr::pivot_longer(
      cols = -".row_id",
      names_to = "key",
      values_to = "value",
      values_transform = as.character
    ) |>
    # Use the helper to handle NA values and string escaping
    dplyr::mutate(
      formatted_value = .format_typst_value(.data$value, na_action = na_action)
    ) |>
    # Omit values that the helper marked as NA
    dplyr::filter(!is.na(.data$formatted_value)) |>
    dplyr::group_by(.data$.row_id) |>
    dplyr::summarise(
      # Create the dictionary string: (key1: "value1", key2: "value2")
      dict_str = paste0(
        "(", paste(.data$key, .data$formatted_value, sep = ": ", collapse = ", "), ")"
      )
    ) |>
    dplyr::pull(.data$dict_str)


  # --- Phase 4: Final Output Assembly ---
  if (length(typst_dictionaries) == 0) {
    return(if (output_mode == "array") sprintf("```{=typst}\n%s(())\n```", typst_func) else "```{=typst}\n```")
  }

  if (output_mode == "rowwise") {
    content <- paste0(typst_func, typst_dictionaries, collapse = "\n")
    return(sprintf("```{=typst}\n%s\n```", content))
  }

  # Else, array mode
  content <- paste0("  ", typst_dictionaries, collapse = ",\n")
  return(sprintf("```{=typst}\n%s((\n%s\n))\n```", typst_func, content))
}
