#' Convert a dependency graph to node/edge data frames
#'
#' Produces the `nodes` and `edges` data frames used by the Shiny dashboard
#' (and anything else that wants to draw the DAG, e.g. `visNetwork`). Nodes are
#' grouped and coloured by source, with referenced-but-missing packages
#' highlighted.
#'
#' @param graph A `bw_depgraph`/`igraph` from [build_dep_graph()].
#'
#' @return A list with two [tibbles][tibble::tibble]:
#'   * `nodes`: `id`, `label`, `group` (source), `present`, `title` (HTML
#'     tooltip), `color`.
#'   * `edges`: `from`, `to`, `constraint`, `arrows`.
#'
#' @export
#' @examples
#' gd <- bw_graph_data(build_dep_graph(bw_example("clean.lock")))
#' gd$nodes
bw_graph_data <- function(graph) {
  stopifnot(inherits(graph, "igraph"))
  names_v <- igraph::vertex_attr(graph, "name")
  source_v <- igraph::vertex_attr(graph, "source")
  present_v <- igraph::vertex_attr(graph, "present")
  version_v <- igraph::vertex_attr(graph, "version")

  palette <- c(
    CRAN = "#1f77b4", Bioconductor = "#2ca02c", GitHub = "#6f42c1",
    local = "#ff7f0e", Repository = "#17a2b8", base = "#adb5bd",
    missing = "#d62728", Unknown = "#7f7f7f"
  )
  colour <- unname(palette[source_v])
  colour[is.na(colour)] <- "#7f7f7f"

  nodes <- tibble::tibble(
    id = names_v,
    label = names_v,
    group = source_v,
    present = present_v,
    title = sprintf(
      "<b>%s</b><br>source: %s<br>version: %s<br>%s",
      names_v, source_v,
      ifelse(is.na(version_v), "&mdash;", version_v),
      ifelse(present_v, "present", "<span style='color:#d62728'>MISSING</span>")
    ),
    color = colour
  )

  el <- igraph::as_edgelist(graph)
  if (nrow(el) == 0L) {
    edges <- tibble::tibble(
      from = character(), to = character(), constraint = character(),
      arrows = character()
    )
  } else {
    edges <- tibble::tibble(
      from = el[, 1L],
      to = el[, 2L],
      constraint = igraph::edge_attr(graph, "constraint") %||% rep("", nrow(el)),
      arrows = "to"
    )
  }
  list(nodes = nodes, edges = edges)
}
