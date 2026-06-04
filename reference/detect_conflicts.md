# Detect unsatisfiable dependency constraints

Walks every declared requirement and reports the packages whose
constraints cannot be jointly satisfied. Four kinds of problem are
surfaced:

## Usage

``` r
detect_conflicts(x)
```

## Arguments

- x:

  A `bw_library`, a `bw_depgraph`, or a path
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  accepts.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) of class
`bw_conflicts`, one row per problem, with columns `package`, `type`,
`required_by` (list column), `constraints`, `installed_version`,
`satisfiable`, and `detail`. A healthy library yields a zero-row tibble.

## Details

- **missing** – a required package is absent from the scanned set and is
  not a base package, so nothing can depend on it successfully.

- **version_conflict** – two or more packages demand version ranges of
  the same dependency whose intersection is empty (no single version
  works).

- **version_drift** – a feasible range exists, but the version actually
  present (or pinned in the lockfile) falls outside it.

- **cycle** – packages form a dependency cycle, so no install order
  exists.

Version-range checks need version-qualified requirements.
Installed-library scans always carry them (parsed from `DESCRIPTION`);
`renv.lock` scans carry them only when the lockfile records them, so for
plain lockfiles this focuses on missing dependencies, cycles and
diamonds.

## See also

[`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md),
[`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md)

## Examples

``` r
detect_conflicts(bw_example("clean.lock"))
#> 
#> ── buildwright conflicts ───────────────────────────────────────────────────────
#> ✔ No dependency conflicts detected.
detect_conflicts(bw_example("conflicted.lock"))
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
