# Run the full buildwright diagnosis in one call

Convenience wrapper that runs
[`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md),
[`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md),
[`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md),
[`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md)
and
[`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md)
over a single input and bundles the results. This is what
[`report()`](https://ashenoy.github.io/buildwright/reference/report.md)
and
[`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md)
consume, and the most ergonomic entry point for scripting a pre-install
health check.

## Usage

``` r
diagnose(
  x,
  platform = bw_host_platform(),
  host_libraries = NULL,
  use_pak = FALSE
)
```

## Arguments

- x:

  A `bw_library` or a path
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  accepts.

- platform, host_libraries, use_pak:

  Passed to
  [`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md)
  and
  [`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md).

## Value

An object of class `bw_diagnosis`: a list with elements `library`,
`graph`, `conflicts`, `sysreqs`, `plan`, and `meta`.

## Examples

``` r
d <- diagnose(bw_example("conflicted.lock"))
d
#> 
#> ── buildwright diagnosis ───────────────────────────────────────────────────────
#> Input: /home/runner/work/_temp/Library/buildwright/extdata/conflicted.lock
#> (lockfile)
#> 9 packages, platform "linux"
#> 
#> ! Conflicts: 4 (missing, version_conflict, version_drift, cycle)
#> ✔ System requirements: no missing libraries detected
#> ✖ Install simulation: 6 packages predicted to fail/block
#> 
#> Inspect $library, $graph, $conflicts, $sysreqs, $plan; or report(x).
d$conflicts
#> 
#> ── buildwright conflicts ───────────────────────────────────────────────────────
#> ! 4 issues: missing (1), version_conflict (1), version_drift (1), cycle (1)
#> • missing -- 'zeta' is required by alpha but is not present in the scanned set.
#> • version_conflict -- No single version of 'rlang' satisfies all of: >= 1.1.0
#> (needsNewRlang); <= 0.4.12 (needsOldRlang).
#> • version_drift -- 'cli' 3.6.2 does not satisfy required range [>= 99.0.0]
#> (from wantsRecentCli).
#> • cycle -- Dependency cycle: boros -> ouroboros -> boros.
```
