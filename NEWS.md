# buildwright 0.1.0

First release.

* `scan_library()` reads installed libraries and `renv.lock` files into a tidy
  `bw_library` inventory with canonical sources (CRAN / Bioconductor / GitHub /
  local / custom repositories).
* `build_dep_graph()` constructs an `igraph` dependency DAG, with `bw_cycles()`
  and `bw_diamonds()` helpers.
* `detect_conflicts()` finds missing dependencies, unsatisfiable version ranges,
  version drift, and cycles.
* `check_sysreqs()` maps packages to system libraries and flags likely-missing
  ones, with an offline knowledge base ([`bw_sysreq_library_db()`],
  [`bw_sysreq_package_map()`]) and an optional `pak` path.
* `simulate_install()` produces a dependency-first install order and predicts
  failures (including blocked-by-dependency propagation) before any install.
* `diagnose()` runs the full pipeline; `report()` renders a parameterised Quarto
  (or R Markdown fallback) HTML report; `run_dashboard()` launches a Shiny app.
* `bw_preinstall_check()` gates `renv` / `pak` installs as a fail-fast hook.
