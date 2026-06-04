#' Simulate an installation and predict failures before running it
#'
#' Produces a dependency-first (topological) install order and, for every
#' package, a predicted outcome based on the conflicts and system requirements
#' buildwright found. Failures propagate: if a dependency cannot be installed,
#' every package that (transitively) needs it is marked `blocked`. This is the
#' dry run you want before letting `renv`/`pak` actually build a few hundred
#' packages on a fresh machine.
#'
#' Predicted statuses:
#' * `ok` -- expected to install.
#' * `warn` -- a system library looks missing, or the pinned version drifts
#'   from a feasible range; the install may still work but is risky.
#' * `fail` -- directly unsatisfiable (version conflict, in a cycle, or a hard
#'   dependency is missing).
#' * `blocked` -- depends, transitively, on something that fails.
#'
#' @param x A `bw_library` or a path [scan_library()] accepts.
#' @param installed Character vector of packages already present on the target
#'   (treated as satisfied). Defaults to base/recommended packages.
#' @param platform,host_libraries,use_pak Passed to [check_sysreqs()].
#'
#' @return A list of class `bw_install_plan` with elements `order` (character),
#'   `steps` (tibble: `step`, `package`, `version`, `source`,
#'   `predicted_status`, `reason`), `predicted_failures` (the failing/blocked
#'   subset), `feasible` (logical), `has_cycle` (logical), and the counts
#'   `n_ok`, `n_warn`, `n_fail`.
#'
#' @seealso [detect_conflicts()], [check_sysreqs()], [diagnose()]
#' @export
#' @examples
#' plan <- simulate_install(bw_example("clean.lock"))
#' plan
#' plan$order
#'
#' simulate_install(bw_example("conflicted.lock"))$predicted_failures
simulate_install <- function(x, installed = NULL,
                             platform = bw_host_platform(),
                             host_libraries = NULL, use_pak = FALSE) {
  lib <- bw_as_library(x)
  graph <- build_dep_graph(lib)
  conflicts <- detect_conflicts(lib)
  sysreqs <- check_sysreqs(lib, platform = platform,
                           host_libraries = host_libraries, use_pak = use_pak)

  installed <- unique(c(installed %||% character(), bw_base_packages()))
  satisfied <- unique(c(lib$package, installed))

  # Dependency-first install order ------------------------------------------
  cycles <- bw_cycles(graph)
  has_cycle <- length(cycles) > 0L
  order_all <- tryCatch(
    rev(names(suppressWarnings(igraph::topo_sort(graph, mode = "out")))),
    error = function(e) lib$package
  )
  install_targets <- lib$package[!lib$is_base]
  order <- order_all[order_all %in% install_targets]
  # any targets topo_sort dropped (e.g. inside a cycle) still get a step
  order <- unique(c(order, install_targets))

  # Failure sets -------------------------------------------------------------
  cycle_members <- unique(unlist(cycles))
  hard_conflict <- conflicts$package[conflicts$type == "version_conflict"]
  missing_targets <- conflicts$package[conflicts$type == "missing"]
  drift <- conflicts$package[conflicts$type == "version_drift"]

  direct_fail <- intersect(unique(c(hard_conflict, cycle_members)), order)

  # Packages blocked because they depend on a failing or missing dependency
  block_roots <- unique(c(direct_fail, missing_targets))
  blocked <- character()
  for (root in block_roots) {
    if (!root %in% igraph::V(graph)$name) next
    anc <- names(igraph::subcomponent(graph, root, mode = "in"))
    blocked <- c(blocked, setdiff(anc, root))
  }
  blocked <- intersect(unique(blocked), order)
  blocked <- setdiff(blocked, direct_fail)

  missing_lib_pkgs <- unique(sysreqs$package[sysreqs$status == "missing"])

  # Per-package status + reason ---------------------------------------------
  status <- character(length(order))
  reason <- character(length(order))
  for (i in seq_along(order)) {
    pkg <- order[[i]]
    if (pkg %in% direct_fail) {
      status[[i]] <- "fail"
      reason[[i]] <- if (pkg %in% cycle_members) {
        "in a dependency cycle"
      } else {
        "unsatisfiable version constraints"
      }
    } else if (pkg %in% blocked) {
      status[[i]] <- "blocked"
      missdep <- bw_blocking_dep(graph, pkg, block_roots)
      reason[[i]] <- sprintf("blocked by %s", paste(missdep, collapse = ", "))
    } else {
      msgs <- character()
      st <- "ok"
      if (pkg %in% missing_lib_pkgs) {
        st <- "warn"
        libs <- sysreqs$system_requirement[sysreqs$package == pkg & sysreqs$status == "missing"]
        msgs <- c(msgs, sprintf("system library missing: %s", paste(libs, collapse = ", ")))
      }
      if (pkg %in% drift) {
        st <- "warn"
        msgs <- c(msgs, "pinned version drifts from required range")
      }
      status[[i]] <- st
      reason[[i]] <- if (length(msgs)) paste(msgs, collapse = "; ") else "ready"
    }
  }

  idx <- match(order, lib$package)
  steps <- tibble::tibble(
    step = seq_along(order),
    package = order,
    version = lib$version[idx],
    source = lib$source[idx],
    predicted_status = status,
    reason = reason
  )

  predicted_failures <- steps[steps$predicted_status %in% c("fail", "blocked"), , drop = FALSE]
  new_bw_install_plan(
    order = order,
    steps = steps,
    predicted_failures = predicted_failures,
    feasible = nrow(predicted_failures) == 0L,
    has_cycle = has_cycle,
    input = attr(lib, "bw_input")
  )
}

# ---- internals --------------------------------------------------------------

# Which block-root does `pkg` actually depend on (transitively)?
bw_blocking_dep <- function(graph, pkg, roots) {
  if (!pkg %in% igraph::V(graph)$name) return(roots[[1L]])
  reach <- names(igraph::subcomponent(graph, pkg, mode = "out"))
  hit <- intersect(roots, reach)
  if (length(hit) == 0L) roots[[1L]] else hit
}

new_bw_install_plan <- function(order, steps, predicted_failures, feasible,
                                has_cycle, input) {
  structure(
    list(
      order = order,
      steps = steps,
      predicted_failures = predicted_failures,
      feasible = feasible,
      has_cycle = has_cycle,
      n_ok = sum(steps$predicted_status == "ok"),
      n_warn = sum(steps$predicted_status == "warn"),
      n_fail = sum(steps$predicted_status %in% c("fail", "blocked")),
      input = input
    ),
    class = "bw_install_plan"
  )
}

#' @export
print.bw_install_plan <- function(x, ...) {
  cli::cli_h1("buildwright install simulation")
  cli::cli_text("{length(x$order)} package{?s} to install from {.path {x$input %||% '?'}}")
  if (x$feasible) {
    cli::cli_alert_success("Predicted feasible: {x$n_ok} ok, {x$n_warn} warning{?s}")
  } else {
    cli::cli_alert_danger("Predicted to fail: {x$n_fail} blocked/failing, {x$n_warn} warning{?s}, {x$n_ok} ok")
  }
  if (x$has_cycle) cli::cli_alert_warning("Dependency cycle present (no clean order).")
  if (nrow(x$predicted_failures) > 0L) {
    cli::cli_h2("Predicted failures")
    pf <- x$predicted_failures
    for (i in seq_len(nrow(pf))) {
      cli::cli_li("{.pkg {pf$package[[i]]}} [{pf$predicted_status[[i]]}] -- {pf$reason[[i]]}")
    }
  }
  cli::cli_h2("Install order (dependency-first)")
  cli::cli_text(paste(utils::head(x$order, 20L), collapse = " -> "))
  if (length(x$order) > 20L) cli::cli_text("... and {length(x$order) - 20L} more")
  invisible(x)
}
