# Pre-install health gate for renv / pak workflows

Runs a full
[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)
over a lockfile (or library) and, when `strict = TRUE`, raises an error
if any problems are predicted. This is designed to sit *in front of* an
install step so a broken dependency set fails fast instead of part-way
through building a few hundred packages.

## Usage

``` r
bw_preinstall_check(
  lockfile = "renv.lock",
  strict = FALSE,
  platform = bw_host_platform(),
  host_libraries = NULL,
  quiet = FALSE
)
```

## Arguments

- lockfile:

  Path to an `renv.lock`, a library/project directory, a `bw_library`,
  or `NULL` for the current library.

- strict:

  Logical; if `TRUE`, abort (error) when conflicts, predicted install
  failures, or missing system libraries are found. If `FALSE` (default),
  report and return without erroring.

- platform, host_libraries:

  Passed to
  [`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md).

- quiet:

  Logical; suppress the printed summary.

## Value

The `bw_diagnosis` object, invisibly. Called mainly for its gate (error
under `strict`) and printed summary.

## Details

Typical wiring:

    # In a restore script, gate renv::restore() on a clean bill of health:
    buildwright::bw_preinstall_check("renv.lock", strict = TRUE)
    renv::restore()

    # As a CI step (non-zero exit fails the job):
    # Rscript -e 'buildwright::bw_preinstall_check("renv.lock", strict = TRUE)'

    # Before a pak install, on a host where you know the libraries present:
    bw_preinstall_check("renv.lock", strict = TRUE,
                        host_libraries = c("libcurl", "openssl"))
    pak::pkg_install(...)

## See also

[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md),
[`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md)

## Examples

``` r
# Non-strict: never errors, just reports.
invisible(bw_preinstall_check(bw_example("clean.lock")))
#> 
#> ── buildwright diagnosis ───────────────────────────────────────────────────────
#> Input: /home/runner/work/_temp/Library/buildwright/extdata/clean.lock
#> (lockfile)
#> 14 packages, platform "linux"
#> 
#> ✔ Conflicts: none
#> ✔ System requirements: no missing libraries detected
#> ✔ Install simulation: feasible (0 warnings)
#> 
#> Inspect $library, $graph, $conflicts, $sysreqs, $plan; or report(x).
#> ✔ Pre-install check passed: dependency set looks installable.

# Strict on a healthy lockfile returns silently; on a broken one it errors:
bw_preinstall_check(bw_example("clean.lock"), strict = TRUE, quiet = TRUE)
tryCatch(
  bw_preinstall_check(bw_example("conflicted.lock"), strict = TRUE, quiet = TRUE),
  error = function(e) cat("gate tripped:", conditionMessage(e), "\n")
)
#> gate tripped: buildwright pre-install check failed.
#> ✖ 4 conflicts, 6 predicted install failures, 0 missing system libraries.
#> ℹ Run `diagnose()` or `report()` for details, or set `strict = FALSE` to warn
#>   only. 
```
