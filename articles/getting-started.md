# Getting started with buildwright

## The problem

Platform and DevOps teams that maintain a shared R distribution rarely
fail an install because of a typo. They fail because a few hundred
packages, pinned in an `renv.lock` and spread across CRAN, Bioconductor
and GitHub, quietly disagree: one package needs `rlang (>= 1.1.0)` while
another caps it at `<= 0.4.12`, a required package was never recorded, a
pair of packages depend on each other in a cycle, or a binary needs a
system library (`libcurl`, `GDAL`, `OpenSSL`) that the build image does
not ship. buildwright reads the lockfile *before* you build, models the
whole graph, and tells you exactly which packages will fail and why – so
the dry run happens in milliseconds instead of after twenty minutes of
compilation on a fresh machine.

Everything below runs against lockfiles bundled with the package,
reachable through
[`bw_example()`](https://ashenoy.github.io/buildwright/reference/scan_library.md),
so no network or installed library is required.

## Scan a lockfile

[`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
auto-detects its input – here, an `renv.lock` path – and returns a tidy
`bw_library` tibble with one row per package.

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
#>  2 cli          3.6.2   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  3 fansi        1.0.6   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  4 fastmap      1.1.1   GitHub       r-lib/fastma… <chr [0]>    FALSE   NA      
#>  5 glue         1.7.0   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  6 lifecycle    1.0.4   CRAN         CRAN          <chr [3]>    FALSE   NA      
#>  7 magrittr     2.0.3   CRAN         CRAN          <chr [0]>    FALSE   NA      
#>  8 pillar       1.9.0   CRAN         CRAN          <chr [7]>    FALSE   NA      
#>  9 pkgconfig    2.0.3   CRAN         CRAN          <chr [0]>    FALSE   NA      
#> 10 rlang        1.1.3   CRAN         CRAN          <chr [0]>    FALSE   NA      
#> 11 S4Vectors    0.40.2  Bioconductor Bioconductor… <chr [1]>    FALSE   NA      
#> 12 tibble       3.2.1   CRAN         CRAN          <chr [8]>    FALSE   NA      
#> 13 utf8         1.2.4   CRAN         CRAN          <chr [0]>    FALSE   NA      
#> 14 vctrs        0.6.5   CRAN         CRAN          <chr [4]>    FALSE   NA
```

Each package carries a normalised `source`. The clean fixture spans
three of them:

``` r

table(lib$source)
#> 
#> Bioconductor         CRAN       GitHub 
#>            2           11            1
```

## Build the dependency graph

[`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md)
turns the library into a directed `igraph` where an edge `A -> B` means
“A requires B”. From it you can ask for cycles and for diamond (shared)
dependencies – the packages that multiple others depend on, which are
exactly where version conflicts tend to arise.

``` r

g <- build_dep_graph(lib)
g
#> 
#> ── buildwright dependency graph ────────────────────────────────────────────────
#> 14 packages, 23 dependency edges
#> 14 present / 0 referenced-but-missing
#> ✔ Acyclic (a valid install order exists)
#> 6 shared (diamond) dependencies

bw_cycles(g)
#> list()
```

The clean lockfile is acyclic, so
[`bw_cycles()`](https://ashenoy.github.io/buildwright/reference/bw_cycles.md)
returns an empty list. The diamond dependencies, ordered by how many
packages need them, point at the highest-risk shared packages:

``` r

diamonds <- bw_diamonds(g)
head(diamonds[, c("package", "n_dependents")])
#> # A tibble: 6 × 2
#>   package   n_dependents
#>   <chr>            <int>
#> 1 cli                  4
#> 2 rlang                4
#> 3 glue                 3
#> 4 lifecycle            3
#> 5 fansi                2
#> 6 vctrs                2
```

## Detect conflicts

[`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md)
returns a zero-row tibble when a library is healthy. The clean fixture
is healthy:

``` r

detect_conflicts(bw_example("clean.lock"))
#> 
#> ── buildwright conflicts ───────────────────────────────────────────────────────
#> ✔ No dependency conflicts detected.
```

The `conflicted.lock` fixture is not. It surfaces four problems: a
missing dependency, a hard version conflict, a version drift, and a
cycle. The `required_by` column is a list column, so convert it to a
string before printing as a `data.frame`:

``` r

conf <- detect_conflicts(bw_example("conflicted.lock"))
conf$required_by <- vapply(conf$required_by, paste, character(1), collapse = ", ")
as.data.frame(conf[, c("package", "type", "required_by", "satisfiable")])
#>              package             type                  required_by satisfiable
#> 1               zeta          missing                        alpha       FALSE
#> 2              rlang version_conflict needsNewRlang, needsOldRlang       FALSE
#> 3                cli    version_drift               wantsRecentCli        TRUE
#> 4 boros -> ouroboros            cycle             boros, ouroboros       FALSE
```

Reading the rows: `zeta` is **missing** (needed by `alpha`); `rlang` is
a **version_conflict** (one package wants `>= 1.1.0`, another
`<= 0.4.12`); `cli` is a **version_drift** (a package wants `>= 99.0.0`
but the pinned `cli` is `3.6.2`); and `ouroboros`/`boros` form a
**cycle**.

## Check system requirements

[`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md)
maps packages to the OS libraries they need on a given platform. Passing
`host_libraries` as a character vector makes presence deterministic: a
library counts as present only if it appears in that vector. With an
empty vector, nothing is installed, so every requirement is reported
missing:

``` r

sys <- check_sysreqs(
  bw_example("missing-sysreq.lock"),
  platform = "linux",
  host_libraries = character()
)
as.data.frame(sys[, c("package", "system_requirement", "status")])
#>      package system_requirement  status
#> 1    askpass            OpenSSL missing
#> 2       curl               cURL missing
#> 3     magick        ImageMagick missing
#> 4    openssl            OpenSSL missing
#> 5      rJava           Java JDK missing
#> 6  RPostgres  PostgreSQL client missing
#> 7         sf               GDAL missing
#> 8         sf               GEOS missing
#> 9         sf               PROJ missing
#> 10     units           udunits2 missing
#> 11        V8          V8 engine missing
#> 12      xml2            libxml2 missing
```

Supplying, say, `host_libraries = c("libcurl", "openssl")` would flip
the matching rows to `status = "ok"`.

## Simulate the install

[`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md)
produces a dependency-first install order and predicts an outcome for
every package, propagating failures: anything that depends
(transitively) on a failing package is marked `blocked`.

``` r

plan <- simulate_install(bw_example("conflicted.lock"))
plan$feasible
#> [1] FALSE

as.data.frame(plan$predicted_failures[, c("package", "predicted_status", "reason")])
#>         package predicted_status                            reason
#> 1         alpha          blocked                   blocked by zeta
#> 2         boros             fail             in a dependency cycle
#> 3 needsNewRlang          blocked                  blocked by rlang
#> 4 needsOldRlang          blocked                  blocked by rlang
#> 5     ouroboros             fail             in a dependency cycle
#> 6         rlang             fail unsatisfiable version constraints
```

`feasible` is `FALSE`, and `predicted_failures` lists each package that
will fail or be blocked along with the reason – `alpha` blocked by the
missing `zeta`, `rlang` and its dependents tripped by the version
conflict, and the `ouroboros`/`boros` cycle.

## One-call diagnosis

[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)
runs the scan, graph, conflict, system-requirement and install steps
together and bundles the results. Its
[`summary()`](https://rdrr.io/r/base/summary.html) method returns a
compact two-column health tibble:

``` r

diag <- diagnose(
  bw_example("conflicted.lock"),
  platform = "linux",
  host_libraries = character()
)
summary(diag)
#> # A tibble: 5 × 2
#>   metric             value
#>   <chr>              <chr>
#> 1 packages           9    
#> 2 conflicts          4    
#> 3 missing_sysreqs    0    
#> 4 predicted_failures 6    
#> 5 feasible           FALSE
```

The individual pieces are available as `diag$library`, `diag$graph`,
`diag$conflicts`, `diag$sysreqs` and `diag$plan`.

From a diagnosis (or any path/library) you can also produce a shareable
artifact. `report(x, format = "quarto")` renders a self-contained HTML
report and returns its path, and `run_dashboard(x)` launches an
interactive Shiny dashboard. Both are omitted here because they render
or open a browser; call them from an interactive session:

``` r

# Renders inst/report to a standalone HTML file and returns the path
report(bw_example("conflicted.lock"), format = "quarto")

# Launches the interactive Shiny dashboard
run_dashboard(bw_example("conflicted.lock"))
```

## Gate an install with the pre-install hook

[`bw_preinstall_check()`](https://ashenoy.github.io/buildwright/reference/bw_preinstall_check.md)
is the hook to wire into a `renv`/`pak` workflow or CI step. It runs the
full diagnosis against a lockfile and, with `strict = TRUE`, aborts when
problems exist – failing the build before a single package is fetched:

``` r

# Returns a bw_diagnosis invisibly; aborts under strict = TRUE if problems exist
bw_preinstall_check("renv.lock", strict = TRUE)
```

That is the whole loop: scan a lockfile, inspect the graph and
conflicts, check system libraries, simulate the install, and gate on the
result – all before the real install runs.
