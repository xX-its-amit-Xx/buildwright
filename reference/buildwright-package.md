# buildwright: Dependency-Health and Build-Failure Diagnostics

buildwright scans installed libraries and `renv` lockfiles, builds a
dependency graph, detects version conflicts and cycles, maps packages to
their system requirements, and simulates installation order so that
build failures can be caught *before* an install is attempted. See
[`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md),
[`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md),
[`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md),
[`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md),
[`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md),
[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)
and
[`report()`](https://ashenoy.github.io/buildwright/reference/report.md).

## See also

Useful links:

- <https://github.com/ashenoy/buildwright>

- <https://ashenoy.github.io/buildwright/>

- Report bugs at <https://github.com/ashenoy/buildwright/issues>

## Author

**Maintainer**: Amit Shenoy <shenoy.am@husky.neu.edu>

Authors:

- Amit Shenoy <shenoy.am@husky.neu.edu>
