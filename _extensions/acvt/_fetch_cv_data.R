# _fetch_cv_data.R
# ------------------------------------------------------------------------------
# Dieses Script dient als "Pre-render" Hook für die Quarto Extension.
# Es lädt CV-Daten von Google Sheets und stellt sie als Metadaten bereit.
# ------------------------------------------------------------------------------

# --- 1. Bootstrapping: Notwendige Basis-Pakete prüfen ---
required_base <- c("yaml", "rmarkdown", "cli")
missing_base <- required_base[!sapply(required_base, requireNamespace, quietly = TRUE)]
if (length(missing_base) > 0) {
  stop(paste("Fehlende Basis-Pakete für das CV Template:", paste(missing_base, collapse = ", ")))
}

main <- function() {
  # --- 2. Pfad-Erkennung für "Vendored" Scripts ---
  # Wir suchen den Ordner, in dem 'load_cv_sheets.R' liegt.
  # Da wir in einer Extension sind, liegt das meist in _extensions/<user>/<ext>/R/
  # Wir suchen rekursiv, um robust gegen Ordnernamen zu sein.

  cli::cli_h1("CV Data Extension Setup")

  extension_r_files <- list.files(
    path = "_extensions",
    pattern = "^load_cv_sheets\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(extension_r_files) == 0) {
    cli::cli_abort(c(
      "x" = "Konnte die notwendigen R-Skripte nicht finden.",
      "i" = "Stelle sicher, dass der Ordner `R/` in der Extension existiert und `load_cv_sheets.R` enthält."
    ))
  }

  # Wir nehmen den ersten Treffer (falls mehrere Extensions installiert sind, könnte das heikel sein,
  # aber in einem normalen Projekt ist das okay. Ggf. Pfad spezifischer machen).
  script_dir <- dirname(extension_r_files[1])
  cli::cli_alert_info("Extension-Skripte gefunden in: {.path {script_dir}}")

  # --- 3. Scripts laden (Sourcing) ---
  # Die Reihenfolge ist wichtig, falls Abhängigkeiten bestehen
  files_to_source <- c(
    "validation_helpers.R",
    "read_cv_sheet.R",
    "read_cv_sheet_helpers.R",
    "load_cv_sheets_helpers.R",
    "load_cv_sheets.R"
  )

  for (f in files_to_source) {
    full_path <- file.path(script_dir, f)
    if (file.exists(full_path)) {
      source(full_path, local = TRUE)
    } else {
      cli::cli_abort("Kritisch: Datei {.file {f}} fehlt im Extension-Ordner.")
    }
  }

  # --- 4. Abhängigkeiten prüfen (Dependencies aus deinem Tools-Paket) ---
  # Diese Pakete werden von deinen gesourcten Funktionen genutzt
  pkg_deps <- c("googlesheets4", "googledrive", "purrr", "checkmate", "rlang", "janitor")
  missing_deps <- pkg_deps[!sapply(pkg_deps, requireNamespace, quietly = TRUE)]

  if (length(missing_deps) > 0) {
    cli::cli_abort(c(
      "x" = "Fehlende R-Pakete für die Datenverarbeitung.",
      "i" = "Bitte installiere: {paste(missing_deps, collapse = ', ')}",
      " " = "Befehl: install.packages(c({paste(shQuote(missing_deps), collapse = ', ')}))"
    ))
  }

  # --- 5. Konfiguration aus .qmd lesen ---
  qmd_files <- list.files(pattern = "\\.qmd$")
  cv_config <- NULL
  target_file <- NULL

  # Suche das erste qmd File, das 'google-document' im Header hat
  for (f in qmd_files) {
    front_matter <- rmarkdown::yaml_front_matter(f)
    if (!is.null(front_matter$`google-document`)) {
      target_file <- f
      cv_config <- front_matter$`google-document`
      break
    }
  }

  if (is.null(cv_config)) {
    cli::cli_alert_warning("Keine `google-document` Konfiguration in .qmd Dateien gefunden. Überspringe Datenabruf.")
    return(invisible(NULL))
  }

  # --- 6. Caching Logik ---
  cache_file <- ".cv_cache.rds"
  output_yaml_file <- "_cv_data.yml"
  cache_valid <- FALSE
  loaded_data <- NULL

  # Cache-Dauer (z.B. 2 Stunden)
  cache_timeout_hours <- 2

  if (file.exists(cache_file)) {
    info <- file.info(cache_file)
    age <- difftime(Sys.time(), info$mtime, units = "hours")

    if (age < cache_timeout_hours) {
      cli::cli_alert_success("Verwende lokalen Cache (Alter: {round(age, 2)} Std.)")
      tryCatch(
        {
          loaded_data <- readRDS(cache_file)
          cache_valid <- TRUE
        },
        error = function(e) {
          cli::cli_alert_warning("Cache-Datei korrupt. Lade neu.")
        }
      )
    } else {
      cli::cli_alert_info("Cache abgelaufen ({round(age, 2)} Std.). Aktualisiere Daten...")
    }
  }

  # --- 7. Datenabruf (falls Cache nicht valide) ---
  if (!cache_valid) {
    doc_id <- cv_config[["document-identifier"]]
    sheets_config <- cv_config[["sheets-to-load"]]
    auth_email <- cv_config[["auth-email"]]

    if (is.null(doc_id) || is.null(sheets_config)) {
      cli::cli_abort("`document-identifier` oder `sheets-to-load` fehlen in der YAML Konfiguration.")
    }

    # --- Authentifizierung (Single-Sign-On Strategie) ---
    cli::cli_process_start("Authentifiziere Google Services")

    tryCatch(
      {
        # 1. Authentifizierung über Google Drive
        # Wir nutzen Drive als "Master", da der Drive-Scope auch Sheets umfasst
        # und wir für die Namensauflösung zwingend die Drive API brauchen.
        googledrive::drive_auth(email = auth_email %||% TRUE)

        # 2. Token an Google Sheets weiterreichen
        # Das verhindert, dass gs4_auth nach einem eigenen Token sucht.
        # Wir nutzen das Token, das wir gerade via drive_auth geholt haben.
        googlesheets4::gs4_auth(token = googledrive::drive_token())

        cli::cli_process_done()
      },
      error = function(e) {
        cli::cli_process_failed()
        cli::cli_abort(c(
          "x" = "Authentifizierung fehlgeschlagen.",
          "i" = "Das Script benötigt Zugriff auf Google Drive (zum Finden der Datei) und Sheets (zum Lesen).",
          "!" = "Bitte führe EINMALIG folgenden Befehl interaktiv in R aus:",
          " " = "googledrive::drive_auth()", # Das ist der wichtige Befehl für den User
          "i" = "Wähle dabei das Google Konto: {.val {auth_email %||% 'Standard'}}",
          "x" = "Original Fehler: {e$message}"
        ))
      }
    )

    # Konfiguration aufbereiten für load_cv_sheets
    # YAML liest Listen ein, wir müssen sicherstellen, dass die Struktur passt.
    # Deine load_cv_sheets helpers sind hier ziemlich robust, wir übergeben es direkt.
    # Ein kleiner Pre-Processing Schritt für "sheets_to_load" falls es komplex ist:

    final_sheets_config <- list()
    for (item in sheets_config) {
      if (is.list(item) && !is.null(item$name) && !is.null(item$shortname)) {
        # Fall: - name: "Foo", shortname: "bar"
        final_sheets_config[[item$name]] <- item$shortname
      } else if (is.character(item)) {
        # Fall: - "Foo"
        # Wir fügen es als unbenanntes Element hinzu, damit load_cv_sheets es als Vektor behandelt?
        # Deine load_cv_sheets erwartet entweder named list ODER character vector.
        # YAML parsing macht hier oft eine Liste draus. Wir müssen aufpassen.

        # Wenn es ein gemischter Input ist, ist es schwer.
        # Wir nehmen an: Entweder alles "name/shortname" ODER einfache Liste.
        if (is.list(item)) {
          # Fall: einfaches Item in Liste verpackt durch YAML Parser
          val <- unlist(item)
          final_sheets_config <- append(final_sheets_config, val)
        } else {
          final_sheets_config <- append(final_sheets_config, item)
        }
      }
    }

    # Wenn final_sheets_config nur Namen ohne Keys hat, konvertieren wir zu Character Vector
    if (is.null(names(final_sheets_config)) || any(names(final_sheets_config) == "")) {
      final_sheets_config <- as.character(unlist(final_sheets_config))
    }

    cli::cli_process_start("Lade Daten von Google Sheet {.val {doc_id}}")

    tryCatch(
      {
        # Aufruf deiner importierten Funktion
        loaded_data <- load_cv_sheets(
          doc_identifier = doc_id,
          sheets_to_load = final_sheets_config
        )
        cli::cli_process_done()
      },
      error = function(e) {
        cli::cli_process_failed()
        cli::cli_abort("Fehler beim Laden der Daten: {e$message}")
      }
    )

    # Cache schreiben
    saveRDS(loaded_data, cache_file)
  }

  # --- 8. YAML Export für Quarto ---
  # Wir schreiben die Daten in die Datei, die Quarto via metadata-files einliest

  # Alles unter einem Top-Level Key verpacken
  export_list <- list(cv_data = loaded_data)

  # Spezielles Handling für NAs, damit YAML nicht meckert (optional, aber gut)
  # export_list <- rapply(export_list, function(x) ifelse(is.na(x), "", x), how = "replace")

  yaml::write_yaml(export_list, output_yaml_file)
  cli::cli_inform(c("v" = "Daten erfolgreich in {.file {output_yaml_file}} bereitgestellt."))
}

# Script ausführen
main()
