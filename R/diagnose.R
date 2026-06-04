#' Run the full buildwright diagnosis in one call
#'
#' Convenience wrapper that runs [scan_library()], [build_dep_graph()],
#' [detect_conflicts()], [check_sysreqs()] and [simulate_install()] over a
#' single input and bundles the results. This is what [report()] and
#' [run_dashboard()] consume, and the most ergonomic entry point for scripting a
#' pre-install health check.
#'
#' @param x A `bw_library` or a path [scan_library()] accepts.
#' @param platform,host_libraries,use_pak Passed to [check_sysreqs()] and
#'   [simulate_install()].
#'
#' @return An object of class `bw_diagnosis`: a list with elements `library`,
#'   `graph`, `conflicts`, `sysreqs`, `plan`, and `meta`.
#'
#' @export
#' @examples
#' d <- diagnose(bw_example("conflicted.lock"))
#' d
#' d$conflicts
diagnose <- function(x, platform = bw_host_platform(),
                     host_libraries = NULL, use_pak = FALSE) {
  lib <- bw_as_library(x)
  graph <- build_dep_graph(lib)
  conflicts <- detect_conflicts(lib)
  sysreqs <- check_sysreqs(lib, platform = platform,
                           host_libraries = host_libraries, use_pak = use_pak)
  plan <- simulate_install(lib, platform = platform,
                           host_libraries = host_libraries, use_pak = use_pak)
  structure(
    list(
      library = lib,
      graph = graph,
      conflicts = conflicts,
      sysreqs = sysreqs,
      plan = plan,
      meta = list(
        input = attr(lib, "bw_input"),
        type = attr(lib, "bw_type"),
        platform = platform,
        r_version = attr(lib, "bw_r_version"),
        bioc_version = attr(lib, "bw_bioc_version"),
        n_packages = nrow(lib)
      )
    ),
    class = "bw_diagnosis"
  )
}

#' @export
print.bw_diagnosis <- function(x, ...) {
  cli::cli_h1("buildwright diagnosis")
  cli::cli_text("Input: {.path {x$meta$input %||% '?'}} ({x$meta$type})")
  cli::cli_text("{x$meta$n_packages} packages, platform {.val {x$meta$platform}}")
  cli::cli_text("")

  n_conf <- nrow(x$conflicts)
  if (n_conf == 0L) {
    cli::cli_alert_success("Conflicts: none")
  } else {
    cli::cli_alert_warning("Conflicts: {n_conf} ({paste(unique(x$conflicts$type), collapse = ', ')})")
  }

  n_miss <- sum(x$sysreqs$status == "missing")
  if (n_miss == 0L) {
    cli::cli_alert_success("System requirements: no missing libraries detected")
  } else {
    cli::cli_alert_warning("System requirements: {n_miss} likely-missing librar{?y/ies}")
  }

  if (x$plan$feasible) {
    cli::cli_alert_success("Install simulation: feasible ({x$plan$n_warn} warning{?s})")
  } else {
    cli::cli_alert_danger("Install simulation: {x$plan$n_fail} package{?s} predicted to fail/block")
  }

  cli::cli_text("")
  cli::cli_text(cli::col_grey("Inspect $library, $graph, $conflicts, $sysreqs, $plan; or report(x)."))
  invisible(x)
}

#' @export
summary.bw_diagnosis <- function(object, ...) {
  tibble::tibble(
    metric = c("packages", "conflicts", "missing_sysreqs", "predicted_failures", "feasible"),
    value = c(
      as.character(object$meta$n_packages),
      as.character(nrow(object$conflicts)),
      as.character(sum(object$sysreqs$status == "missing")),
      as.character(object$plan$n_fail),
      as.character(object$plan$feasible)
    )
  )
}
