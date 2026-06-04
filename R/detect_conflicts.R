#' Detect unsatisfiable dependency constraints
#'
#' Walks every declared requirement and reports the packages whose constraints
#' cannot be jointly satisfied. Four kinds of problem are surfaced:
#'
#' * **missing** -- a required package is absent from the scanned set and is not
#'   a base package, so nothing can depend on it successfully.
#' * **version_conflict** -- two or more packages demand version ranges of the
#'   same dependency whose intersection is empty (no single version works).
#' * **version_drift** -- a feasible range exists, but the version actually
#'   present (or pinned in the lockfile) falls outside it.
#' * **cycle** -- packages form a dependency cycle, so no install order exists.
#'
#' Version-range checks need version-qualified requirements. Installed-library
#' scans always carry them (parsed from `DESCRIPTION`); `renv.lock` scans carry
#' them only when the lockfile records them, so for plain lockfiles this focuses
#' on missing dependencies, cycles and diamonds.
#'
#' @param x A `bw_library`, a `bw_depgraph`, or a path [scan_library()] accepts.
#'
#' @return A [tibble][tibble::tibble] of class `bw_conflicts`, one row per
#'   problem, with columns `package`, `type`, `required_by` (list column),
#'   `constraints`, `installed_version`, `satisfiable`, and `detail`. A healthy
#'   library yields a zero-row tibble.
#'
#' @seealso [build_dep_graph()], [simulate_install()]
#' @export
#' @examples
#' detect_conflicts(bw_example("clean.lock"))
#' detect_conflicts(bw_example("conflicted.lock"))
detect_conflicts <- function(x) {
  if (inherits(x, "bw_depgraph")) {
    lib <- NULL
    graph <- x
  } else {
    lib <- bw_as_library(x)
    graph <- build_dep_graph(lib)
  }
  if (is.null(lib)) {
    lib <- bw_library_from_graph(graph)
  }

  reqtab <- bw_requirement_table(lib)
  versions <- stats::setNames(lib$version, lib$package)
  present_set <- lib$package
  rows <- list()

  # 1. missing dependencies ---------------------------------------------------
  if (nrow(reqtab) > 0L) {
    missing_targets <- unique(reqtab$to[
      !reqtab$to %in% present_set & !bw_is_base(reqtab$to)
    ])
    for (tgt in missing_targets) {
      reqd <- sort(unique(reqtab$from[reqtab$to == tgt]))
      cons <- reqtab[reqtab$to == tgt & !is.na(reqtab$op), ]
      cons_str <- if (nrow(cons) > 0L) {
        paste(sprintf("%s %s (%s)", cons$op, cons$version, cons$from), collapse = "; ")
      } else {
        "any"
      }
      rows[[length(rows) + 1L]] <- list(
        package = tgt, type = "missing", required_by = list(reqd),
        constraints = cons_str, installed_version = NA_character_,
        satisfiable = FALSE,
        detail = sprintf(
          "'%s' is required by %s but is not present in the scanned set.",
          tgt, paste(reqd, collapse = ", ")
        )
      )
    }

    # 2. version conflicts / drift -------------------------------------------
    check_targets <- unique(reqtab$to[
      reqtab$to %in% present_set & !bw_is_base(reqtab$to)
    ])
    for (tgt in check_targets) {
      grp <- reqtab[reqtab$to == tgt & !is.na(reqtab$op), ]
      if (nrow(grp) == 0L) next
      intervals <- Map(bw_constraint_interval, grp$op, grp$version)
      merged <- bw_intersect_intervals(intervals)
      reqd <- sort(unique(grp$from))
      cons_str <- paste(sprintf("%s %s (%s)", grp$op, grp$version, grp$from), collapse = "; ")
      installed_v <- versions[[tgt]]

      if (!merged$feasible) {
        rows[[length(rows) + 1L]] <- list(
          package = tgt, type = "version_conflict", required_by = list(reqd),
          constraints = cons_str, installed_version = installed_v,
          satisfiable = FALSE,
          detail = sprintf(
            "No single version of '%s' satisfies all of: %s.", tgt, cons_str
          )
        )
        next
      }
      if (!is.na(installed_v)) {
        in_range <- bw_version_in_interval(installed_v, merged)
        if (isFALSE(in_range)) {
          rows[[length(rows) + 1L]] <- list(
            package = tgt, type = "version_drift", required_by = list(reqd),
            constraints = cons_str, installed_version = installed_v,
            satisfiable = TRUE,
            detail = sprintf(
              "'%s' %s does not satisfy required range [%s] (from %s).",
              tgt, installed_v, bw_format_interval(merged),
              paste(reqd, collapse = ", ")
            )
          )
        }
      }
    }
  }

  # 3. cycles -----------------------------------------------------------------
  for (cyc in bw_cycles(graph)) {
    rows[[length(rows) + 1L]] <- list(
      package = paste(cyc, collapse = " -> "), type = "cycle",
      required_by = list(cyc), constraints = NA_character_,
      installed_version = NA_character_, satisfiable = FALSE,
      detail = sprintf("Dependency cycle: %s.", paste(c(cyc, cyc[[1L]]), collapse = " -> "))
    )
  }

  new_bw_conflicts(rows)
}

# ---- internals --------------------------------------------------------------

bw_requirement_table <- function(lib) {
  rows <- list()
  for (i in seq_len(nrow(lib))) {
    reqs <- lib$requirements[[i]]
    parsed <- bw_parse_requirements(reqs)
    if (nrow(parsed) == 0L) next
    rows[[length(rows) + 1L]] <- data.frame(
      from = lib$package[[i]],
      to = parsed$package,
      op = parsed$op,
      version = parsed$version,
      stringsAsFactors = FALSE
    )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      from = character(), to = character(), op = character(), version = character()
    ))
  }
  tibble::as_tibble(do.call(rbind, rows))
}

bw_version_in_interval <- function(v, merged) {
  vv <- tryCatch(numeric_version(v), error = function(e) NULL)
  if (is.null(vv)) return(NA)
  ok <- TRUE
  if (!is.na(merged$low)) {
    ok <- ok && (if (merged$low_closed) vv >= merged$low else vv > merged$low)
  }
  if (!is.na(merged$high)) {
    ok <- ok && (if (merged$high_closed) vv <= merged$high else vv < merged$high)
  }
  ok
}

# Reconstruct a minimal bw_library from a graph (used when detect_conflicts is
# handed a graph directly).
bw_library_from_graph <- function(graph) {
  present <- igraph::vertex_attr(graph, "present")
  names_v <- igraph::vertex_attr(graph, "name")
  keep <- present
  el <- igraph::as_edgelist(graph)
  reqs <- lapply(names_v[keep], function(v) {
    if (nrow(el) == 0L) return(character())
    el[el[, 1L] == v, 2L]
  })
  tbl <- tibble::tibble(
    package = names_v[keep],
    version = igraph::vertex_attr(graph, "version")[keep],
    source = igraph::vertex_attr(graph, "source")[keep],
    repository = NA_character_,
    requirements = reqs,
    is_base = igraph::vertex_attr(graph, "is_base")[keep],
    priority = NA_character_
  )
  new_bw_library(tbl, type = "graph", input = igraph::graph_attr(graph, "bw_input") %||% "<graph>",
                 r_version = NA_character_, bioc_version = NA_character_)
}

new_bw_conflicts <- function(rows) {
  if (length(rows) == 0L) {
    tbl <- tibble::tibble(
      package = character(), type = character(), required_by = list(),
      constraints = character(), installed_version = character(),
      satisfiable = logical(), detail = character()
    )
  } else {
    tbl <- tibble::tibble(
      package = vapply(rows, function(r) r$package, character(1)),
      type = vapply(rows, function(r) r$type, character(1)),
      required_by = lapply(rows, function(r) r$required_by[[1L]]),
      constraints = vapply(rows, function(r) r$constraints %||% NA_character_, character(1)),
      installed_version = vapply(rows, function(r) r$installed_version %||% NA_character_, character(1)),
      satisfiable = vapply(rows, function(r) r$satisfiable, logical(1)),
      detail = vapply(rows, function(r) r$detail, character(1))
    )
  }
  class(tbl) <- c("bw_conflicts", class(tibble::tibble()))
  tbl
}

#' @export
print.bw_conflicts <- function(x, ...) {
  cli::cli_h1("buildwright conflicts")
  if (nrow(x) == 0L) {
    cli::cli_alert_success("No dependency conflicts detected.")
    return(invisible(x))
  }
  lvls <- c("missing", "version_conflict", "version_drift", "cycle")
  tab <- table(factor(x$type, levels = lvls))
  tab <- tab[tab > 0L]
  counts <- paste(sprintf("%s (%d)", names(tab), as.integer(tab)), collapse = ", ")
  cli::cli_alert_warning("{nrow(x)} issue{?s}: {counts}")
  for (i in seq_len(nrow(x))) {
    cli::cli_li("{.strong {x$type[[i]]}} -- {x$detail[[i]]}")
  }
  invisible(x)
}
