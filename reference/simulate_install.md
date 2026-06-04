# Simulate an installation and predict failures before running it

Produces a dependency-first (topological) install order and, for every
package, a predicted outcome based on the conflicts and system
requirements buildwright found. Failures propagate: if a dependency
cannot be installed, every package that (transitively) needs it is
marked `blocked`. This is the dry run you want before letting
`renv`/`pak` actually build a few hundred packages on a fresh machine.

## Usage

``` r
simulate_install(
  x,
  installed = NULL,
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

- installed:

  Character vector of packages already present on the target (treated as
  satisfied). Defaults to base/recommended packages.

- platform, host_libraries, use_pak:

  Passed to
  [`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md).

## Value

A list of class `bw_install_plan` with elements `order` (character),
`steps` (tibble: `step`, `package`, `version`, `source`,
`predicted_status`, `reason`), `predicted_failures` (the failing/blocked
subset), `feasible` (logical), `has_cycle` (logical), and the counts
`n_ok`, `n_warn`, `n_fail`.

## Details

Predicted statuses:

- `ok` – expected to install.

- `warn` – a system library looks missing, or the pinned version drifts
  from a feasible range; the install may still work but is risky.

- `fail` – directly unsatisfiable (version conflict, in a cycle, or a
  hard dependency is missing).

- `blocked` – depends, transitively, on something that fails.

## See also

[`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md),
[`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md),
[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)

## Examples

``` r
plan <- simulate_install(bw_example("clean.lock"))
plan
#> 
#> ── buildwright install simulation ──────────────────────────────────────────────
#> 14 packages to install from
#> /home/runner/work/_temp/Library/buildwright/extdata/clean.lock
#> ✔ Predicted feasible: 14 ok, 0 warnings
#> 
#> ── Install order (dependency-first) ──
#> 
#> rlang -> glue -> cli -> lifecycle -> vctrs -> utf8 -> fansi -> pkgconfig ->
#> pillar -> magrittr -> BiocGenerics -> tibble -> fastmap -> S4Vectors
plan$order
#>  [1] "rlang"        "glue"         "cli"          "lifecycle"    "vctrs"       
#>  [6] "utf8"         "fansi"        "pkgconfig"    "pillar"       "magrittr"    
#> [11] "BiocGenerics" "tibble"       "fastmap"      "S4Vectors"   

simulate_install(bw_example("conflicted.lock"))$predicted_failures
#> # A tibble: 6 × 6
#>    step package       version source predicted_status reason                    
#>   <int> <chr>         <chr>   <chr>  <chr>            <chr>                     
#> 1     1 alpha         1.0.0   CRAN   blocked          blocked by zeta           
#> 2     2 boros         0.3.0   CRAN   fail             in a dependency cycle     
#> 3     5 needsNewRlang 2.1.0   CRAN   blocked          blocked by rlang          
#> 4     6 needsOldRlang 0.9.0   CRAN   blocked          blocked by rlang          
#> 5     7 ouroboros     0.2.0   CRAN   fail             in a dependency cycle     
#> 6     8 rlang         1.0.0   CRAN   fail             unsatisfiable version con…
```
