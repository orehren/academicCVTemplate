#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# QUARTO PRE-RENDER SCRIPT: GOOGLE SHEET DATA LOADER
#
# This script is executed by Quarto before the main document render. Its goal
# is to read the `google-document` configuration from the document's YAML
# header, fetch the specified data from a Google Sheet, and then output
# that data as a YAML string that Quarto will merge back into the document's
# metadata.
#
# This makes the Google Sheet data available to all subsequent stages of the
# render, including R code chunks and Lua filters, without requiring R code
# directly in the document.
# ------------------------------------------------------------------------------

# --- 1. Load Required Libraries -----------------------------------------------
# This script is self-contained and only relies on widely used packages.
library(jsonlite)
library(googlesheets4)
library(yaml)

# --- 2. Read and Parse Quarto Metadata ----------------------------------------
# Quarto passes metadata as a JSON string in an environment variable.
metadata_json <- Sys.getenv("QUARTO_INPUT_FILE_METADATA")
if (identical(metadata_json, "")) {
  # If no metadata is found, exit gracefully.
  quit()
}
metadata <- fromJSON(metadata_json)

# Check if the required configuration exists.
if (is.null(metadata) || is.null(metadata$`google-document`)) {
  message("INFO: `google-document` key not found in YAML. Skipping data fetch.")
  quit()
}

# --- 3. Extract and Validate Configuration ------------------------------------
cv_config <- metadata$`google-document`
doc_id <- cv_config[["document-identifier"]]
sheets_config <- cv_config[["sheets-to-load"]]
auth_email <- cv_config[["auth-email"]] # Will be NULL if not present

if (is.null(doc_id)) {
  stop("ERROR: `document-identifier` is missing under the `google-document` key.", call. = FALSE)
}
if (is.null(sheets_config)) {
  stop("ERROR: `sheets-to-load` is missing under the `google-document` key.", call. = FALSE)
}

# --- 4. Handle Authentication -------------------------------------------------
# This relies on a cached token. The user must have authenticated interactively
# at least once before running the pre-render script.
message("INFO: Authenticating with Google...")
gs4_auth(email = auth_email %||% TRUE, cache = TRUE, use_oob = TRUE)
message("INFO: Authentication successful.")

# --- 5. Process Sheet Configuration -------------------------------------------
# This logic prepares the list of sheets to load. The `names` of the list
# will be the full sheet names to read, and the `values` will be the
# target shortnames for the final output list.
sheets_to_load <- list()
for (item in sheets_config) {
  if (is.list(item)) {
    sheet_name <- item$name
    target_name <- item$shortname
    sheets_to_load[[sheet_name]] <- target_name
  } else {
    sheet_name <- item
    target_name <- gsub("[^[:alnum:]_]+", "_", tolower(sheet_name))
    sheets_to_load[[sheet_name]] <- target_name
  }
}

# --- 6. Load Data from Google Sheet -------------------------------------------
message("INFO: Loading data from Google Sheet: ", doc_id)

# Initialize an empty list to store the loaded data frames.
loaded_data <- list()

# Iterate over the prepared list of sheets.
for (sheet_name in names(sheets_to_load)) {
  target_name <- sheets_to_load[[sheet_name]]
  message("INFO: Reading sheet '", sheet_name, "' into '", target_name, "'...")

  # Use a tryCatch block to gracefully handle potential errors, such as a
  # sheet not being found in the Google Sheet document.
  tryCatch({
    sheet_data <- read_sheet(ss = doc_id, sheet = sheet_name, col_types = "c")
    loaded_data[[target_name]] <- sheet_data
  }, error = function(e) {
    warning("WARN: Failed to read sheet '", sheet_name, "'. Error: ", e$message, call. = FALSE)
  })
}
message("INFO: Data loading complete.")

# --- 7. Generate and Output YAML ----------------------------------------------
# The final step is to create a list with the desired top-level key (`cv_data`)
# and then convert it to a YAML string for Quarto to ingest.
output_list <- list(cv_data = loaded_data)
output_yaml <- as.yaml(output_list, indent.mapping.sequence = TRUE)

# Print the final YAML to standard output. Quarto will capture this.
cat(output_yaml)
