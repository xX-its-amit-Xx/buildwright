#' Build a dependency graph from a library or lockfile
#'
#' Constructs a directed [igraph][igraph::igraph] dependency graph where an edge
#' `A -> B` means "package A requires package B". Vertices carry the package
#' version, source and whether the package is actually present in the scanned
#' set, so that missing dependencies show up as vertices with `present = FALSE`.
#' The returned object also gains the class `bw_depgraph` for a richer print
#' method, while remaining a fully functional `igraph` object.
#'
#' @param x A `bw_library` (from [scan_library()]), or a path that
#'   [scan_library()] understands.
#' @param include_base Logical; include edges to base/recommended packages that
#'   ship with R. Defaults to `FALSE` to keep the DAG focused on the
#'   distribution under management.
#'
#' @return An `igraph` object of class `bw_depgraph`. Vertex attributes:
#'   `version`, `source`, `present`, `is_base`. Edge attribute: `constraint`
#'   (the raw requirement string, e.g. `">= 1.0.0"` or `""`).
#'
#' @seealso [bw_cycles()], [bw_diamonds()], [detect_conflicts()]
#' @export
#' @examples
#' g <- build_dep_graph(bw_example("clean.lock"))
#' g
#' igraph::vcount(g)
#' bw_cycles(g)
build_dep_graph <- function(x, include_base = FALSE) {
  lib <- bw_as_library(x)
  pkgs <- lib$package

  edge_list <- list()
  for (i in seq_len(nrow(lib))) {
    reqs <- lib$requirements[[i]]
    if (length(reqs) == 0L) next
    parsed <- bw_parse_requirements(reqs)
    for (j in seq_len(nrow(parsed))) {
      target <- parsed$package[[j]]
      if (!include_base && bw_is_base(target)) next
      constraint <- if (!is.na(parsed$op[[j]])) {
        paste(parsed$op[[j]], parsed$version[[j]])
      } else {
        ""
      }
      edge_list[[length(edge_list) + 1L]] <- c(
        from = lib$package[[i]], to = target, constraint = constraint
      )
    }
  }

  if (length(edge_list) > 0L) {
    edges <- as.data.frame(do.call(rbind, edge_list), stringsAsFactors = FALSE)
  } else {
    edges <- data.frame(
      from = character(), to = character(), constraint = character(),
      stringsAsFactors = FALSE
    )
  }

  all_names <- unique(c(pkgs, edges$from, edges$to))
  all_names <- all_names[!is.na(all_names) & nzchar(all_names)]
  idx <- match(all_names, lib$package)
  verts <- data.frame(
    name = unname(all_names),
    version = unname(lib$version[idx]),
    source = unname(ifelse(is.na(idx),
      ifelse(bw_is_base(all_names), "base", "missing"),
      lib$source[idx]
    )),
    present = unname(!is.na(idx)),
    is_base = unname(bw_is_base(all_names)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )

  g <- igraph::graph_from_data_frame(d = edges, directed = TRUE, vertices = verts)
  g <- igraph::set_graph_attr(g, "bw_input", attr(lib, "bw_input"))
  g <- igraph::set_graph_attr(g, "bw_type", attr(lib, "bw_type"))
  new_bw_depgraph(g)
}

#' Find dependency cycles in a graph
#'
#' @param graph A `bw_depgraph`/`igraph` from [build_dep_graph()].
#' @return A list of character vectors, each the packages in one cycle
#'   (strongly connected component of size > 1, or a self-loop). Empty list when
#'   the graph is acyclic.
#' @export
#' @examples
#' bw_cycles(build_dep_graph(bw_example("clean.lock")))
bw_cycles <- function(graph) {
  if (igraph::vcount(graph) == 0L) return(list())
  comp <- igraph::components(graph, mode = "strong")
  cycles <- list()
  for (k in seq_len(comp$no)) {
    members <- names(comp$membership)[comp$membership == k]
    if (length(members) > 1L) {
      cycles[[length(cycles) + 1L]] <- members
    }
  }
  # self-loops are 1-vertex cycles
  loops <- igraph::which_loop(graph)
  if (any(loops)) {
    el <- igraph::as_edgelist(graph)
    for (nm in unique(el[loops, 1L])) {
      cycles[[length(cycles) + 1L]] <- nm
    }
  }
  cycles
}

#' Find diamond (shared) dependencies in a graph
#'
#' A diamond dependency is a package required by two or more other packages.
#' These are exactly the places where version conflicts arise, so they are the
#' first thing to inspect when an install misbehaves.
#'
#' @param graph A `bw_depgraph`/`igraph` from [build_dep_graph()].
#' @return A [tibble][tibble::tibble] with columns `package`, `n_dependents`,
#'   and `dependents` (a list column), ordered by `n_dependents` descending.
#' @export
#' @examples
#' bw_diamonds(build_dep_graph(bw_example("clean.lock")))
bw_diamonds <- function(graph) {
  if (igraph::vcount(graph) == 0L) {
    return(tibble::tibble(
      package = character(), n_dependents = integer(), dependents = list()
    ))
  }
  indeg <- igraph::degree(graph, mode = "in")
  shared <- names(indeg)[indeg >= 2L]
  if (length(shared) == 0L) {
    return(tibble::tibble(
      package = character(), n_dependents = integer(), dependents = list()
    ))
  }
  deps <- lapply(shared, function(v) {
    nb <- igraph::neighbors(graph, v, mode = "in")
    sort(names(nb))
  })
  ord <- order(vapply(deps, length, integer(1)), decreasing = TRUE)
  tibble::tibble(
    package = shared[ord],
    n_dependents = vapply(deps, length, integer(1))[ord],
    dependents = deps[ord]
  )
}

# ---- internals --------------------------------------------------------------

#' Coerce flexible input to a `bw_library`
#' @noRd
bw_as_library <- function(x) {
  if (inherits(x, "bw_library")) return(x)
  if (inherits(x, "bw_diagnosis")) return(x$library)
  if (is.character(x) && length(x) == 1L) return(scan_library(x))
  if (is.null(x)) return(scan_library(NULL))
  cli::cli_abort(c(
    "Cannot interpret {.arg x} as a library.",
    "i" = "Pass a {.cls bw_library}, a path, or {.code NULL}."
  ))
}

new_bw_depgraph <- function(g) {
  class(g) <- unique(c("bw_depgraph", class(g)))
  g
}

#' @export
print.bw_depgraph <- function(x, ...) {
  nv <- igraph::vcount(x)
  ne <- igraph::ecount(x)
  present <- sum(igraph::vertex_attr(x, "present"))
  cli::cli_h1("buildwright dependency graph")
  cli::cli_text("{.strong {nv}} packages, {.strong {ne}} dependency edges")
  cli::cli_text("{present} present / {nv - present} referenced-but-missing")
  cyc <- bw_cycles(x)
  if (length(cyc) > 0L) {
    cli::cli_alert_warning("{length(cyc)} cycle{?s} detected")
  } else {
    cli::cli_alert_success("Acyclic (a valid install order exists)")
  }
  dia <- bw_diamonds(x)
  cli::cli_text("{nrow(dia)} shared (diamond) dependenc{?y/ies}")
  invisible(x)
}
