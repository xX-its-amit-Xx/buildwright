# Scan an R library or `renv` lockfile into a package inventory

`scan_library()` is the entry point for every other buildwright
function. It reads either an installed library (a directory of installed
packages) or an `renv.lock` file and returns a tidy inventory of
packages, their versions, where they came from (CRAN / Bioconductor /
GitHub / local / custom repository), and their direct requirements.

## Usage

``` r
scan_library(path = NULL, include_base = FALSE)

bw_example(name = c("clean.lock", "conflicted.lock", "missing-sysreq.lock"))
```

## Arguments

- path:

  Path to an `renv.lock` file, a project/library directory, or `NULL` to
  scan the current library.

- include_base:

  Logical; include base-priority packages that ship with R. Defaults to
  `FALSE` because they are always available and only add noise.

- name:

  Fixture name shipped with the package.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) of class
`bw_library` with one row per package and the columns:

- package:

  Package name.

- version:

  Resolved version string.

- source:

  Canonical source: `"CRAN"`, `"Bioconductor"`, `"GitHub"`, `"local"`,
  `"Repository"`, `"base"`, or `"Unknown"`.

- repository:

  Human-readable origin (e.g. `"CRAN"`, `"user/repo@sha"`).

- requirements:

  List column of direct dependency strings, possibly version-qualified
  (e.g. `"rlang (>= 1.0.0)"`).

- is_base:

  Whether the package ships with R.

- priority:

  Install priority for library scans (`NA` for lockfiles).

Useful metadata is attached as attributes: `bw_type` (`"lockfile"` or
`"library"`), `bw_input`, `bw_r_version`, and `bw_bioc_version`.

`bw_example()` returns the file path to a bundled fixture lockfile.

## Details

The input is auto-detected:

- `NULL` (the default) scans the first library on
  [`.libPaths()`](https://rdrr.io/r/base/libPaths.html).

- A path to an `renv.lock` (or any `*.lock` / `*.json`) is parsed as a
  lockfile.

- A directory containing an `renv.lock` is parsed as a lockfile.

- Any other existing directory is treated as an installed library and
  scanned with
  [`utils::installed.packages()`](https://rdrr.io/r/utils/installed.packages.html).

## See also

[`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md),
[`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md),
[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)

## Examples

``` r
lib <- scan_library(bw_example("clean.lock"))
lib
#> 
#> ── buildwright library scan ────────────────────────────────────────────────────
#> 14 packages from lockfile
#> /home/runner/work/_temp/Library/buildwright/extdata/clean.lock
#> R version: "4.3.2"
#> Bioconductor: "3.18"
#> Sources: CRAN (11), Bioconductor (2), GitHub (1)
#> 
#> # A tibble: 14 × 7
#>    package      version source       repository    requirements is_base priority
#>    <chr>        <chr>   <chr>        <chr>         <list>       <lgl>   <chr>   
#>  1 BiocGenerics 0.48.1  Bioconductor Bioconductor… <chr [0]>    FALSE   NA      
#>  2 S4Vectors    0.40.2  Bioconductor Bioconductor… <chr [1]>    FALSE   NA      
#>  3 cli          3.6.2   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  4 fansi        1.0.6   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  5 fastmap      1.1.1   GitHub       r-lib/fastma… <chr [0]>    FALSE   NA      
#>  6 glue         1.7.0   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  7 lifecycle    1.0.4   CRAN         CRAN          <chr [3]>    FALSE   NA      
#>  8 magrittr     2.0.3   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  9 pillar       1.9.0   CRAN         CRAN          <chr [7]>    FALSE   NA      
#> 10 pkgconfig    2.0.3   CRAN         CRAN          <chr [0]>    FALSE   NA      
#> 11 rlang        1.1.3   CRAN         CRAN          <chr [0]>    FALSE   NA      
#> 12 tibble       3.2.1   CRAN         CRAN          <chr [8]>    FALSE   NA      
#> 13 utf8         1.2.4   CRAN         CRAN          <chr [0]>    FALSE   NA      
#> 14 vctrs        0.6.5   CRAN         CRAN          <chr [4]>    FALSE   NA      
nrow(lib)
#> [1] 14
table(lib$source)
#> 
#> Bioconductor         CRAN       GitHub 
#>            2           11            1 
bw_example("conflicted.lock")
#> [1] "/home/runner/work/_temp/Library/buildwright/extdata/conflicted.lock"
```
