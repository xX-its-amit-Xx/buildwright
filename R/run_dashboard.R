#' Launch the interactive buildwright dashboard
#'
#' Starts the bundled Shiny application (`inst/shiny/app.R`) showing the
#' dependency DAG, the conflict table, the system-requirement checklist, and a
#' "will this install?" simulator. The diagnosis is computed up front and handed
#' to the app through a session option, so the app starts instantly and works
#' offline.
#'
#' @param x A `bw_library`, a `bw_diagnosis`, a path [scan_library()] accepts,
#'   or `NULL` to load the bundled example lockfile.
#' @param platform,host_libraries Forwarded to [diagnose()].
#' @param launch.browser Logical; open a browser. Defaults to `interactive()`.
#' @param port Optional port for [shiny::runApp()].
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return The value returned by [shiny::runApp()], invisibly. Called for its
#'   side effect of running the app.
#'
#' @seealso [report()], [diagnose()]
#' @export
#' @examples
#' \dontrun{
#' run_dashboard(bw_example("conflicted.lock"))
#' }
run_dashboard <- function(x = NULL, platform = bw_host_platform(),
                          host_libraries = NULL,
                          launch.browser = interactive(), port = NULL, ...) {
  bw_need(c("shiny", "bslib", "DT", "visNetwork"), "to run the buildwright dashboard")

  if (is.null(x)) x <- bw_example("conflicted.lock")
  diag <- if (inherits(x, "bw_diagnosis")) {
    x
  } else {
    diagnose(x, platform = platform, host_libraries = host_libraries)
  }

  appdir <- system.file("shiny", package = "buildwright")
  if (!nzchar(appdir) || !file.exists(file.path(appdir, "app.R"))) {
    cli::cli_abort("Bundled Shiny app not found at {.path {appdir}}.")
  }

  old <- options(buildwright.dashboard_data = diag)
  on.exit(options(old), add = TRUE)

  args <- list(appDir = appdir, launch.browser = launch.browser, ...)
  if (!is.null(port)) args$port <- port
  invisible(do.call(shiny::runApp, args))
}

#' Diagnosis currently handed to the dashboard
#'
#' Helper used by the bundled Shiny app to retrieve the [diagnose()] result set
#' by [run_dashboard()]. Falls back to the bundled example when run standalone.
#'
#' @return A `bw_diagnosis` object.
#' @export
#' @keywords internal
bw_dashboard_data <- function() {
  data <- getOption("buildwright.dashboard_data", default = NULL)
  if (is.null(data)) {
    data <- diagnose(bw_example("conflicted.lock"))
  }
  data
}
