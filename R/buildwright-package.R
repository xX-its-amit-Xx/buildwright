#' buildwright: Dependency-Health and Build-Failure Diagnostics
#'
#' buildwright scans installed libraries and `renv` lockfiles, builds a
#' dependency graph, detects version conflicts and cycles, maps packages to
#' their system requirements, and simulates installation order so that build
#' failures can be caught *before* an install is attempted. See
#' [scan_library()], [build_dep_graph()], [detect_conflicts()],
#' [check_sysreqs()], [simulate_install()], [diagnose()] and [report()].
#'
#' @keywords internal
"_PACKAGE"

# buildwright calls every imported package via `pkg::fun()`, so the generated
# NAMESPACE needs no import() directives. The internal `%||%` (see
# aaa-utils.R) intentionally provides the operator for R (>= 4.2), which does
# not ship a base `%||%`.
NULL
