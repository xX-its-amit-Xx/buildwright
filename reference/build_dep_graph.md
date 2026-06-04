# Build a dependency graph from a library or lockfile

Constructs a directed
[igraph](https://r.igraph.org/reference/aaa-igraph-package.html)
dependency graph where an edge `A -> B` means "package A requires
package B". Vertices carry the package version, source and whether the
package is actually present in the scanned set, so that missing
dependencies show up as vertices with `present = FALSE`. The returned
object also gains the class `bw_depgraph` for a richer print method,
while remaining a fully functional `igraph` object.

## Usage

``` r
build_dep_graph(x, include_base = FALSE)
```

## Arguments

- x:

  A `bw_library` (from
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)),
  or a path that
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  understands.

- include_base:

  Logical; include edges to base/recommended packages that ship with R.
  Defaults to `FALSE` to keep the DAG focused on the distribution under
  management.

## Value

An `igraph` object of class `bw_depgraph`. Vertex attributes: `version`,
`source`, `present`, `is_base`. Edge attribute: `constraint` (the raw
requirement string, e.g. `">= 1.0.0"` or `""`).

## See also

[`bw_cycles()`](https://ashenoy.github.io/buildwright/reference/bw_cycles.md),
[`bw_diamonds()`](https://ashenoy.github.io/buildwright/reference/bw_diamonds.md),
[`detect_conflicts()`](https://ashenoy.github.io/buildwright/reference/detect_conflicts.md)

## Examples

``` r
g <- build_dep_graph(bw_example("clean.lock"))
g
#> 
#> ── buildwright dependency graph ────────────────────────────────────────────────
#> 14 packages, 23 dependency edges
#> 14 present / 0 referenced-but-missing
#> ✔ Acyclic (a valid install order exists)
#> 6 shared (diamond) dependencies
igraph::vcount(g)
#> [1] 14
bw_cycles(g)
#> list()
```
