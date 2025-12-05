#' Interactive Setup Wizard for CV Extension
#'
#' A CLI-based wizard that guides users through the initialization of the CV environment.
#' Uses the 'cli' package for a rich, colored terminal experience.
#'
#' @return Invisible NULL.
#' @export
setup_acvt <- function() {
  if (!interactive()) stop("This function must be run in an interactive R session.")

  # --- STEP 1: WELCOME ---
  if (!.step_welcome()) return(invisible(NULL))

  # --- STEP 2: PACKAGES ---
  # Returns TRUE (next), "skip_auth" (skip next), or FALSE (abort)
  pkg_result <- .step_packages()

  if (isFALSE(pkg_result)) return(invisible(NULL))

  # --- STEP 3: AUTHENTICATION ---
  if (!identical(pkg_result, "skip_auth")) {
    if (!.step_auth()) return(invisible(NULL))
  } else {
    cli::cli_alert_info("Skipping Google Authentication as requested.")
  }

  # --- STEP 4: FINISH ---
  .step_finish()
}


# ==============================================================================
# 0. CONSTANTS
# ==============================================================================

REQUIRED_PACKAGES <- c(
  "googlesheets4", "googledrive", "readxl", "jsonlite",
  "checkmate", "cli", "purrr", "rlang"
)


# ==============================================================================
# 1. WELCOME STEP
# ==============================================================================

.step_welcome <- function() {
  cli::cli_h1("CV Project Setup Wizard")

  cli::cli_text("Welcome! This wizard will help you to prepare your environment")
  cli::cli_text("for the use of the acvt Extension with the following steps:")
  cli::cli_ul()
  cli::cli_li("{.strong Step 1:} Check if all required R packages are installed.")
  cli::cli_li("{.strong Step 2:} Install any required R package that is not installed yet.")
  cli::cli_li("{.strong Step 3:} Authenticate with your Google Drive.")
  cli::cli_end()

  cli::cli_alert_info("All steps are optional and you can abort this wizard at any time by selecting 'Quit'.")
  cli::cli_text("──────────────────────────────────────────────────────────────")

  choice <- .ask_option(
    question = "How do you want to proceed?",
    options = c(
      "1" = "Start Setup",
      "2" = "Skip Package Check and Installation (Jump to Auth)",
      "q" = "Quit Wizard"
    )
  )

  if (choice == "q") {
    cli::cli_alert_danger("Setup aborted by user.")
    return(FALSE)
  }

  if (choice == "2") {
    cli::cli_alert_info("Skipping package check...")
    return(TRUE)
  }

  return(TRUE)
}


# ==============================================================================
# 2. PACKAGE INSTALLATION STEP
# ==============================================================================

.handle_all_packages_installed <- function() {
  cli::cli_alert_success("Great news! All required packages are already installed.")
  cli::cli_text("We are now ready to proceed with the Google Authentication setup.")
  cli::cli_text("──────────────────────────────────────────────────────────────")

  next_choice <- .ask_option(
    question = "How do you want to proceed?",
    options = c(
      "1" = "Proceed to Google Authentication",
      "2" = "Skip Google Authentication",
      "q" = "Quit Wizard"
    )
  )

  if (next_choice == "q") return(FALSE)
  if (next_choice == "2") return("skip_auth")

  return(TRUE)
}

.handle_missing_packages <- function(missing) {
  cli::cli_text("")
  cli::cli_alert_warning(paste("We Found", length(missing), "missing packages:"))
  cli::cli_ul(missing)
  cli::cli_text("──────────────────────────────────────────────────────────────")

  sub_choice <- .ask_option(
    question = "Do you want to install these packages now?",
    options = c(
      "1" = "Yes, install missing packages",
      "2" = "No, skip installation",
      "q" = "Quit Wizard"
    )
  )

  if (sub_choice == "q") return(FALSE)
  if (sub_choice == "2") return(TRUE)

  cli::cli_h3("Installing...")
  utils::install.packages(missing)
  cli::cli_alert_success("Packages installed successfully.")

  return(TRUE)
}

.step_packages <- function() {
  cli::cli_h2("Step 1: Package Check")

  cli::cli_text("To function correctly, this extension requires the following R packages:")
  cli::cli_ul(REQUIRED_PACKAGES)
  cli::cli_text("")

  cli::cli_alert_info("We will now scan your R library to check which of these are already installed.")
  cli::cli_text("──────────────────────────────────────────────────────────────")

  choice <- .ask_option(
    question = "How do you want to proceed?",
    options = c(
      "1" = "Start Scan",
      "2" = "Skip Package Check",
      "q" = "Quit Wizard"
    )
  )

  if (choice == "q") return(FALSE)
  if (choice == "2") {
    cli::cli_alert_warning("Skipping package installation.")
    return(TRUE)
  }

  cli::cli_progress_step("Scanning library...", spinner = TRUE)
  Sys.sleep(0.5)
  missing <- REQUIRED_PACKAGES[!purrr::map_lgl(REQUIRED_PACKAGES, requireNamespace, quietly = TRUE)]
  cli::cli_progress_done()

  if (length(missing) == 0) {
    return(.handle_all_packages_installed())
  }

  return(.handle_missing_packages(missing))
}


# ==============================================================================
# 3. AUTHENTICATION STEP
# ==============================================================================

.prompt_for_valid_email <- function() {
  email <- ""

  while (nchar(email) == 0) {
    sub_choice <- .ask_option(
      question = "Ready to enter email?",
      options = c(
        "1" = "Enter Email",
        "2" = "Skip Authentication",
        "q" = "Quit Wizard"
      )
    )

    if (sub_choice == "q") return(NULL) # Signal abort
    if (sub_choice == "2") {
      cli::cli_alert_warning("Skipping authentication.")
      return("SKIP") # Signal skip
    }

    cli::cli_alert_info("Please enter your email address explicitly to ensure the correct account is used.")
    input <- readline(prompt = "Google Email: ")
    email <- trimws(input)

    if (nchar(email) == 0) {
      cli::cli_alert_danger("Email cannot be empty. Please try again.")
    }
  }
  return(email)
}

.execute_auth_strategy <- function(is_global, email) {
  cli::cli_alert_info("Launching browser...")

  tryCatch({
    if (is_global) {
      .perform_global_auth(email)
    } else {
      .perform_local_auth(email)
    }
    return(TRUE)
  }, error = function(e) {
    cli::cli_alert_danger(paste("Authentication failed:", e$message))
    return(FALSE)
  })
}

.step_auth <- function() {
  cli::cli_h2("Step 2: Google Authentication")

  # --- DIALOG 1: INTRO ---
  cli::cli_text("To fetch data from Google Sheets, R needs to authenticate with the Google API.")
  cli::cli_text("This process involves:")
  cli::cli_ul()
  cli::cli_li("Identifying your account via your email address.")
  cli::cli_li("Creating a secure 'Token' that grants read-access to your sheets.")
  cli::cli_end()

  choice_1 <- .ask_option(
    question = "How do you want to proceed?",
    options = c(
      "1" = "Proceed with Authentication",
      "2" = "Skip Authentication",
      "q" = "Quit Wizard"
    )
  )

  if (choice_1 == "q") return(FALSE)
  if (choice_1 == "2") {
    cli::cli_alert_warning("Skipping authentication.")
    return(TRUE)
  }

  # --- DIALOG 2: MODE SELECTION ---
  cli::cli_h3("Authentication Options")
  cli::cli_text("You can store the credentials in two ways. Please choose the one that fits your needs:")
  cli::cli_text("")

  cli::cli_text("{.strong [1] Global Authentication (Recommended)}")
  cli::cli_ul()
  cli::cli_li("Credentials are stored in your system's user cache.")
  cli::cli_li("Works automatically for ALL your R projects.")
  cli::cli_li("Most secure for personal computers.")
  cli::cli_end()
  cli::cli_text("")

  cli::cli_text("{.strong [2] Local Authentication}")
  cli::cli_ul()
  cli::cli_li("Credentials are stored in this project folder ({.file .secrets}).")
  cli::cli_li("Makes the project portable (e.g., for USB drives).")
  cli::cli_li("Requires careful handling of .gitignore (handled automatically).")
  cli::cli_end()

  choice_2 <- .ask_option(
    question = "Select Authentication Mode:",
    options = c(
      "1" = "Global Auth (Recommended)",
      "2" = "Local Auth",
      "3" = "Skip Authentication",
      "q" = "Quit Wizard"
    )
  )

  if (choice_2 == "q") return(FALSE)
  if (choice_2 == "3") {
    cli::cli_alert_warning("Skipping authentication.")
    return(TRUE)
  }

  # --- DIALOG 3: EMAIL INPUT ---
  cli::cli_h3("Credentials & Browser Flow")
  cli::cli_text("We will now perform the authentication.")
  cli::cli_ul()
  cli::cli_li("1. You enter your Google Email address below.")
  cli::cli_li("2. A browser window will open.")
  cli::cli_li("3. There, You need to grant permissions.")
  cli::cli_li("4. You close the browser and return here.")
  cli::cli_end()

  email <- .prompt_for_valid_email()

  if (is.null(email)) return(FALSE) # User quit
  if (email == "SKIP") return(TRUE) # User skipped

  # --- EXECUTION ---
  if (!.execute_auth_strategy(choice_2 == "1", email)) {
    return(FALSE)
  }

  # --- DIALOG 4: SUCCESS & SECURITY INFO ---
  cli::cli_h3("Authentication Successful")

  if (choice_2 == "1") {
    cli::cli_alert_success("Credentials stored in: {.strong User System Cache}")
    cli::cli_text("You can now use this CV template without re-authenticating.")
  } else {
    cli::cli_alert_success("Credentials stored in: {.file .secrets/}")
    cli::cli_alert_warning("SECURITY NOTICE:")
    cli::cli_ul()
    cli::cli_li("The folder {.file .secrets} contains sensitive tokens.")
    cli::cli_li("We have added it to {.file .gitignore} to prevent upload to GitHub.")
    cli::cli_li("{.strong NEVER} force-add this folder to version control!")
    cli::cli_end()
  }

  choice_4 <- .ask_option(
    question = "How do you want to finish?",
    options = c(
      "1" = "Finish Setup",
      "2" = "Delete Credentials & Quit"
    )
  )

  if (choice_4 == "2") {
    .delete_credentials(choice_2)
    cli::cli_alert_warning("Credentials deleted. Setup aborted.")
    return(FALSE)
  }

  return(TRUE)
}


# ==============================================================================
# 4. FINISH STEP
# ==============================================================================

.step_finish <- function() {
  cli::cli_h1("Setup Complete")
  cli::cli_alert_success("Your CV environment is ready!")
  cli::cli_text("You can now run {.code quarto render} to build your CV.")
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Helper to ask user for a choice
#'
#' @param question String question.
#' @param options Named vector of options (e.g., c("1"="Yes", "q"="Quit")).
#' @return The key of the selected option.
.ask_option <- function(question, options) {
  cli::cli_text(paste0("\n{.strong ", question, "}"))

  for (key in names(options)) {
    label <- options[[key]]
    if (key == "q") {
      cli::cli_text(paste0("  {.red [", key, "]} ", label))
    } else {
      cli::cli_text(paste0("  {.blue [", key, "]} ", label))
    }
  }

  valid_keys <- names(options)
  selection <- ""

  while (!selection %in% valid_keys) {
    selection <- readline(prompt = "Selection > ")
    selection <- trimws(selection)
    if (!selection %in% valid_keys) {
      cli::cli_alert_danger("Invalid selection. Please try again.")
    }
  }

  return(selection)
}

.perform_global_auth <- function(email) {
  googledrive::drive_auth(email = email, use_oob = FALSE)
  googlesheets4::gs4_auth(token = googledrive::drive_token())
  cli::cli_alert_success("Global token cached.")
}

.perform_local_auth <- function(email) {
  secrets_dir <- ".secrets"

  if (!.secure_local_folder(secrets_dir)) cli::cli_abort("Gitignore error.")

  if (!dir.exists(secrets_dir)) {
    dir.create(secrets_dir)
    Sys.chmod(secrets_dir, mode = "0700")
  }

  options(gargle_oauth_cache = secrets_dir)

  googledrive::drive_auth(email = email, cache = secrets_dir, use_oob = FALSE)
  googlesheets4::gs4_auth(token = googledrive::drive_token())

  .add_to_rprofile(paste0("options(gargle_oauth_cache = '", secrets_dir, "')"))
  cli::cli_alert_success("Local token cached in .secrets")
}

.delete_credentials <- function(choice_key) {
  if (choice_key == "1") { # Global
    googledrive::drive_deauth()
    googlesheets4::gs4_deauth()
  } else { # Local
    if (dir.exists(".secrets")) unlink(".secrets", recursive = TRUE)
  }
}

.secure_local_folder <- function(folder_name) {
  git_path <- ".gitignore"
  if (!file.exists(git_path)) file.create(git_path)

  content <- readLines(git_path, warn = FALSE)
  if (!any(grepl(paste0("^", folder_name), content))) {
    prefix <- if (length(content) > 0 && nzchar(tail(content, 1))) "\n" else ""
    cat(paste0(prefix, folder_name, "\n"), file = git_path, append = TRUE)
  }
  return(TRUE)
}

.add_to_rprofile <- function(line) {
  profile_path <- ".Rprofile"
  if (!file.exists(profile_path)) file.create(profile_path)

  content <- readLines(profile_path, warn = FALSE)
  if (any(grepl(trimws(line), trimws(content), fixed = TRUE))) {
    return()
  }

  prefix <- if (length(content) > 0 && nzchar(tail(content, 1))) "\n" else ""
  cat(paste0(prefix, line, "\n"), file = profile_path, append = TRUE)
}
