#' Render a buildwright report or launch the dashboard
#'
#' Two output formats share one entry point:
#' * `format = "quarto"` renders the parameterised report shipped at
#'   `inst/report/buildwright_report.qmd` to a self-contained HTML file. If the
#'   Quarto CLI is not available, buildwright transparently falls back to an
#'   equivalent R Markdown template (`buildwright_report.Rmd`) rendered with
#'   [rmarkdown::render()], so you still get an HTML artifact.
#' * `format = "shiny"` launches the interactive dashboard via
#'   [run_dashboard()].
#'
#' @param x A `bw_library`, a `bw_diagnosis`, or a path [scan_library()] accepts.
#' @param format `"quarto"` (static HTML report) or `"shiny"` (dashboard).
#' @param output For the quarto/HTML report, the output file path. Defaults to a
#'   temp file. Ignored for the shiny format.
#' @param platform,host_libraries Forwarded to the diagnosis.
#' @param open Logical; open the rendered report / launch the browser when
#'   interactive.
#' @param quiet Logical; suppress rendering chatter.
#' @param ... Passed to [run_dashboard()] for the shiny format.
#'
#' @return For `"quarto"`, the path to the rendered HTML (invisibly). For
#'   `"shiny"`, the result of [run_dashboard()].
#'
#' @seealso [diagnose()], [run_dashboard()]
#' @export
#' @examples
#' \dontrun{
#' # Static HTML report from a lockfile
#' report(bw_example("conflicted.lock"), format = "quarto",
#'        output = "buildwright_report.html")
#'
#' # Interactive dashboard
#' report(bw_example("conflicted.lock"), format = "shiny")
#' }
report <- function(x, format = c("quarto", "shiny"), output = NULL,
                   platform = bw_host_platform(), host_libraries = NULL,
                   open = interactive(), quiet = TRUE, ...) {
  format <- match.arg(format)
  if (format == "shiny") {
    return(run_dashboard(x, platform = platform, host_libraries = host_libraries, ...))
  }

  # Persist the diagnosis so the template can load it without recomputation.
  diag <- if (inherits(x, "bw_diagnosis")) {
    x
  } else {
    diagnose(x, platform = platform, host_libraries = host_libraries)
  }
  data_rds <- tempfile("buildwright-diag-", fileext = ".rds")
  saveRDS(diag, data_rds)

  output <- output %||% tempfile("buildwright-report-", fileext = ".html")
  output <- normalizePath(output, winslash = "/", mustWork = FALSE)

  use_quarto <- bw_quarto_available()
  template <- bw_report_template(if (use_quarto) "qmd" else "rmd")
  if (is.na(template)) {
    cli::cli_abort(c(
      "Report template not found in the installed package.",
      "i" = "Expected {.file inst/report/buildwright_report.qmd} or {.file .Rmd}."
    ))
  }

  if (use_quarto) {
    bw_render_quarto(template, output, data_rds, quiet = quiet)
  } else {
    if (!quiet) {
      cli::cli_alert_info("Quarto CLI not found; rendering the R Markdown fallback template.")
    }
    bw_render_rmarkdown(template, output, data_rds, quiet = quiet)
  }

  if (!file.exists(output)) {
    cli::cli_abort("Rendering reported success but {.path {output}} was not produced.")
  }
  cli::cli_alert_success("Report written to {.path {output}}")
  if (isTRUE(open) && interactive()) utils::browseURL(output)
  invisible(output)
}

# ---- internals --------------------------------------------------------------

#' Is a usable Quarto installation available?
#' @noRd
bw_quarto_available <- function() {
  if (nzchar(Sys.which("quarto"))) return(TRUE)
  if (requireNamespace("quarto", quietly = TRUE)) {
    p <- tryCatch(quarto::quarto_path(), error = function(e) NULL)
    return(!is.null(p) && nzchar(p))
  }
  FALSE
}

bw_report_template <- function(kind = c("qmd", "rmd")) {
  kind <- match.arg(kind)
  file <- if (kind == "qmd") "buildwright_report.qmd" else "buildwright_report.Rmd"
  path <- system.file("report", file, package = "buildwright")
  if (nzchar(path) && file.exists(path)) path else NA_character_
}

bw_render_quarto <- function(template, output, data_rds, quiet = TRUE) {
  bw_need("quarto", "to render the Quarto report")
  work <- tempfile("bw-qmd-")
  dir.create(work)
  local_qmd <- file.path(work, basename(template))
  file.copy(template, local_qmd, overwrite = TRUE)
  quarto::quarto_render(
    input = local_qmd,
    execute_params = list(data_rds = data_rds),
    quiet = quiet
  )
  rendered <- file.path(work, sub("\\.qmd$", ".html", basename(template)))
  file.copy(rendered, output, overwrite = TRUE)
  invisible(output)
}

bw_render_rmarkdown <- function(template, output, data_rds, quiet = TRUE) {
  bw_need("rmarkdown", "to render the report")
  rmarkdown::render(
    input = template,
    output_file = basename(output),
    output_dir = dirname(output),
    params = list(data_rds = data_rds),
    envir = new.env(parent = globalenv()),
    quiet = quiet
  )
  invisible(output)
}
