# R/read_cv_sheet.R

#' Read a specific sheet from a Google Sheet for CV data
#'
#' This function reads data from a specified sheet (tab) within a Google Sheet
#' document, identified by its ID, URL, or name. It validates inputs, resolves
#' the identifier, checks sheet existence, reads the data, and performs post-read
#' checks, delegating most steps to internal helper functions.
#'
#' @param doc_identifier The ID, URL, or name of the Google Sheets document.
#'        Must be a single, non-empty string. If a name is provided,
#'        `googledrive::drive_find()` is used to find the unique document,
#'        and the result (a `dribble`) is passed to `googlesheets4`.
#'        Using ID or URL is generally more robust.
#' @param sheet_name The name of the specific sheet (tab) within the Google
#'        Sheet document to read (e.g., "Working Experiences", "Publications").
#'        Must be a single, non-empty string.
#' @param na_strings A character vector of strings to interpret as `NA` values.
#'        Defaults to `c("", "NA", "N/A")`. Passed to `googlesheets4::read_sheet`.
#'        Must be a character vector (can be empty `character(0)`), cannot be `NULL`.
#' @param col_types Column specification passed to `googlesheets4::read_sheet`.
#'        Defaults to `NULL`. Can be `NULL` or an atomic vector (e.g., a string like "c", "cc?i").
#'        Validation relies primarily on `googlesheets4`.
#' @param trim_ws Logical scalar (TRUE or FALSE), should leading/trailing whitespace
#'        be removed from character vectors? Defaults to `TRUE`. Passed to
#'        `googlesheets4::read_sheet`. Must not be `NA`.
#'
#' @return A `tibble` (data frame) containing the data from the specified sheet.
#'         Returns an empty tibble with a warning if the sheet is empty.
#'         Throws an error if arguments are invalid, the document/sheet cannot be
#'         accessed/read, or if a provided name is ambiguous.
#'
#' @importFrom googlesheets4 read_sheet gs4_get as_sheets_id
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Requires authentication beforehand, e.g., via googlesheets4::gs4_auth()
#' # or googledrive::drive_auth()
#'
#' # --- Setup: Define a valid Sheet ID/URL/Name ---
#' # Replace with your actual Sheet identifier that you can access
#' # Option 1: Use Sheet ID
#' my_doc_id <- "YOUR_SHEET_ID_HERE"
#' # Option 2: Use Sheet URL
#' # my_doc_url <- "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID_HERE/edit"
#' # Option 3: Use a unique Sheet Name (ensure it's unique in your Drive)
#' # my_doc_name <- "My Unique CV Data Sheet Name"
#'
#' # Choose one identifier for the examples:
#' my_doc_identifier <- my_doc_id # Or my_doc_url, or my_doc_name
#'
#' # Define sheet names that exist in your document
#' work_sheet <- "Working Experiences" # Replace with your actual sheet name
#' edu_sheet <- "Education" # Replace with your actual sheet name
#' proj_sheet <- "Projects" # Replace with your actual sheet name
#' skills_sheet <- "Skills" # Replace with your actual sheet name
#' missing_sheet <- "This Sheet Does Not Exist"
#' empty_sheet <- "Empty Sheet" # Assume this sheet exists but is empty
#'
#' # --- Example 1: Basic usage with ID ---
#' try(
#'   {
#'     work_experience <- read_cv_sheet(
#'       doc_identifier = my_doc_identifier,
#'       sheet_name = work_sheet
#'     )
#'     print(head(work_experience))
#'   },
#'   silent = TRUE
#' )
#'
#' # --- Example 2: Using a sheet URL (if defined above) ---
#' # try({
#' #   education <- read_cv_sheet(
#' #     doc_identifier = my_doc_url,
#' #     sheet_name = edu_sheet
#' #   )
#' #   print(head(education))
#' # }, silent = TRUE)
#'
#' # --- Example 3: Using the document name (if defined and unique) ---
#' # try({
#' #   projects <- read_cv_sheet(
#' #     doc_identifier = my_doc_name,
#' #     sheet_name = proj_sheet
#' #   )
#' #   print(head(projects))
#' # }, silent = TRUE)
#'
#' # --- Example 4: Specifying column types (read all as character) ---
#' try(
#'   {
#'     skills_data <- read_cv_sheet(
#'       doc_identifier = my_doc_identifier,
#'       sheet_name = skills_sheet,
#'       col_types = "c"
#'     )
#'     print(head(skills_data))
#'     print(lapply(skills_data, class)) # Verify column types
#'   },
#'   silent = TRUE
#' )
#'
#' # --- Example 5: Specifying different NA strings ---
#' try(
#'   {
#'     data_with_na <- read_cv_sheet(
#'       doc_identifier = my_doc_identifier,
#'       sheet_name = work_sheet, # Use a sheet with potential NAs
#'       na_strings = c("N/A", "Missing", "-", "") # Add "" if needed
#'     )
#'     print(head(data_with_na))
#'   },
#'   silent = TRUE
#' )
#'
#' # --- Example 6: Handling a non-existent sheet (should error) ---
#' try(
#'   {
#'     non_existent <- read_cv_sheet(
#'       doc_identifier = my_doc_identifier,
#'       sheet_name = missing_sheet
#'     )
#'   },
#'   error = function(e) {
#'     print(paste("Successfully caught expected error:", e$message))
#'   }
#' )
#'
#' # --- Example 7: Handling an empty sheet (should warn and return empty tibble) ---
#' try(
#'   {
#'     empty_data <- read_cv_sheet(
#'       doc_identifier = my_doc_identifier,
#'       sheet_name = empty_sheet
#'     )
#'     print(empty_data) # Should be a 0-row tibble
#'     print(paste("Is empty tibble:", nrow(empty_data) == 0))
#'   },
#'   silent = TRUE
#' )
#'
#' # --- Example 8: Invalid Argument (should error via checkmate) ---
#' try(
#'   {
#'     invalid_call <- read_cv_sheet(
#'       doc_identifier = my_doc_identifier,
#'       sheet_name = edu_sheet,
#'       trim_ws = "yes" # Invalid type for trim_ws
#'     )
#'   },
#'   error = function(e) {
#'     print(paste("Successfully caught expected error:", e$message))
#'   }
#' )
#' }
read_cv_sheet <- function(doc_identifier,
                          sheet_name,
                          na_strings = c("", "NA", "N/A"),
                          col_types = NULL,
                          trim_ws = TRUE) {
  # Phase 0: Validate Arguments (Aborts on failure)
  .validate_read_cv_sheet_args(
    doc_identifier, sheet_name, na_strings, col_types, trim_ws
  )

  # Phase 1: Resolve Identifier (Aborts on failure)
  ss_input <- .resolve_doc_identifier(doc_identifier)

  # Phase 2: Read Data (Aborts on failure from googlesheets4)
  sheet_data <- .read_sheet_data(
    ss_input, sheet_name, na_strings, col_types, trim_ws
  )

  # Phase 3: Post-Read Checks (Issues warning if empty)
  # Resolve doc ID for messaging now, only if needed.
  doc_id_for_msg <- tryCatch(
    googledrive::as_id(ss_input),
    error = function(e) "UNKNOWN_ID"
  )
  sheet_data <- .check_read_result(sheet_data, sheet_name, doc_id_for_msg)

  # Phase 4: Return Data
  return(sheet_data)
}
