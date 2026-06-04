# Package index

## Scan & graph

Read an installed library or renv lockfile into a tidy inventory and
build an igraph dependency DAG with cycle and diamond helpers.

- [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  [`bw_example()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  :

  Scan an R library or `renv` lockfile into a package inventory

- [`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md)
  : Build a dependency graph from a library or lockfile

- [`bw_cycles()`](https://ashenoy.github.io/buildwright/reference/bw_cycles.md)
  : Find dependency cycles in a graph

- [`bw_diamonds()`](https://ashenoy.github.io/buildwright/reference/bw_diamonds.md)
  : Find diamond (shared) dependencies in a graph

- [`bw_graph_data()`](https://ashenoy.github.io/buildwright/reference/bw_graph_data.md)
  : Convert a dependency graph to node/edge data frames

## Diagnose & report

Run the full diagnostic pipeline, render a static HTML report, or launch
the interactive Shiny dashboard.

- [`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)
  : Run the full buildwright diagnosis in one call
- [`report()`](https://ashenoy.github.io/buildwright/reference/report.md)
  : Render a buildwright report or launch the dashboard
- [`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md)
  : Launch the interactive buildwright dashboard

## Conflicts & system requirements

Detect missing packages, version conflicts, and cycles; map packages to
system libraries and flag those that are absent on the host.

- [`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md)
  : Detect unsatisfiable dependency constraints
- [`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md)
  : Map packages to system requirements and flag likely-missing
  libraries
- [`bw_sysreq_library_db()`](https://ashenoy.github.io/buildwright/reference/bw_sysreq_library_db.md)
  [`bw_sysreq_package_map()`](https://ashenoy.github.io/buildwright/reference/bw_sysreq_library_db.md)
  : The buildwright system-requirements knowledge base

## Install simulation & hooks

Predict install failures in dependency-first order and gate renv/pak
installs as a fail-fast pre-install hook.

- [`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md)
  : Simulate an installation and predict failures before running it
- [`bw_preinstall_check()`](https://ashenoy.github.io/buildwright/reference/bw_preinstall_check.md)
  : Pre-install health gate for renv / pak workflows

## Helpers & data

Access bundled fixture lockfiles for examples and tests, and retrieve
the current dashboard diagnosis object.

- [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  [`bw_example()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  :

  Scan an R library or `renv` lockfile into a package inventory

- [`bw_dashboard_data()`](https://ashenoy.github.io/buildwright/reference/bw_dashboard_data.md)
  : Diagnosis currently handed to the dashboard
