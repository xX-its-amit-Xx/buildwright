#' Pre-install health gate for renv / pak workflows
#'
#' Runs a full [diagnose()] over a lockfile (or library) and, when `strict =
#' TRUE`, raises an error if any problems are predicted. This is designed to sit
#' *in front of* an install step so a broken dependency set fails fast instead
#' of part-way through building a few hundred packages.
#'
#' Typical wiring:
#'
#' ```r
#' # In a restore script, gate renv::restore() on a clean bill of health:
#' buildwright::bw_preinstall_check("renv.lock", strict = TRUE)
#' renv::restore()
#'
#' # As a CI step (non-zero exit fails the job):
#' # Rscript -e 'buildwright::bw_preinstall_check("renv.lock", strict = TRUE)'
#'
#' # Before a pak install, on a host where you know the libraries present:
#' bw_preinstall_check("renv.lock", strict = TRUE,
#'                     host_libraries = c("libcurl", "openssl"))
#' pak::pkg_install(...)
#' ```
#'
#' @param lockfile Path to an `renv.lock`, a library/project directory, a
#'   `bw_library`, or `NULL` for the current library.
#' @param strict Logical; if `TRUE`, abort (error) when conflicts, predicted
#'   install failures, or missing system libraries are found. If `FALSE`
#'   (default), report and return without erroring.
#' @param platform,host_libraries Passed to [diagnose()].
#' @param quiet Logical; suppress the printed summary.
#'
#' @return The `bw_diagnosis` object, invisibly. Called mainly for its gate
#'   (error under `strict`) and printed summary.
#'
#' @seealso [diagnose()], [simulate_install()]
#' @export
#' @examples
#' # Non-strict: never errors, just reports.
#' invisible(bw_preinstall_check(bw_example("clean.lock")))
#'
#' # Strict on a healthy lockfile returns silently; on a broken one it errors:
#' bw_preinstall_check(bw_example("clean.lock"), strict = TRUE, quiet = TRUE)
#' tryCatch(
#'   bw_preinstall_check(bw_example("conflicted.lock"), strict = TRUE, quiet = TRUE),
#'   error = function(e) cat("gate tripped:", conditionMessage(e), "\n")
#' )
bw_preinstall_check <- function(lockfile = "renv.lock", strict = FALSE,
                                platform = bw_host_platform(),
                                host_libraries = NULL, quiet = FALSE) {
  diag <- diagnose(lockfile, platform = platform, host_libraries = host_libraries)
  if (!quiet) print(diag)

  n_conf <- nrow(diag$conflicts)
  n_miss <- sum(diag$sysreqs$status == "missing")
  n_fail <- diag$plan$n_fail
  has_problem <- n_conf > 0L || n_fail > 0L || n_miss > 0L

  if (has_problem && strict) {
    cli::cli_abort(c(
      "buildwright pre-install check failed.",
      "x" = "{n_conf} conflict{?s}, {n_fail} predicted install failure{?s}, {n_miss} missing system librar{?y/ies}.",
      "i" = "Run {.code diagnose()} or {.code report()} for details, or set {.code strict = FALSE} to warn only."
    ))
  }
  if (has_problem && !quiet) {
    cli::cli_alert_warning("Pre-install check found problems (strict = FALSE, continuing).")
  } else if (!has_problem && !quiet) {
    cli::cli_alert_success("Pre-install check passed: dependency set looks installable.")
  }
  invisible(diag)
}
