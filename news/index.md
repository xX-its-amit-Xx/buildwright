# Changelog

## buildwright 0.1.0

First release.

- [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  reads installed libraries and `renv.lock` files into a tidy
  `bw_library` inventory with canonical sources (CRAN / Bioconductor /
  GitHub / local / custom repositories).
- [`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md)
  constructs an `igraph` dependency DAG, with
  [`bw_cycles()`](https://ashenoy.github.io/buildwright/reference/bw_cycles.md)
  and
  [`bw_diamonds()`](https://ashenoy.github.io/buildwright/reference/bw_diamonds.md)
  helpers.
- [`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md)
  finds missing dependencies, unsatisfiable version ranges, version
  drift, and cycles.
- [`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md)
  maps packages to system libraries and flags likely-missing ones, with
  an offline knowledge base
  (\[[`bw_sysreq_library_db()`](https://ashenoy.github.io/buildwright/reference/bw_sysreq_library_db.md)\],
  \[[`bw_sysreq_package_map()`](https://ashenoy.github.io/buildwright/reference/bw_sysreq_library_db.md)\])
  and an optional `pak` path.
- [`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md)
  produces a dependency-first install order and predicts failures
  (including blocked-by-dependency propagation) before any install.
- [`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)
  runs the full pipeline;
  [`report()`](https://ashenoy.github.io/buildwright/reference/report.md)
  renders a parameterised Quarto (or R Markdown fallback) HTML report;
  [`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md)
  launches a Shiny app.
- [`bw_preinstall_check()`](https://ashenoy.github.io/buildwright/reference/bw_preinstall_check.md)
  gates `renv` / `pak` installs as a fail-fast hook.
