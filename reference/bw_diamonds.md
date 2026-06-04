# Find diamond (shared) dependencies in a graph

A diamond dependency is a package required by two or more other
packages. These are exactly the places where version conflicts arise, so
they are the first thing to inspect when an install misbehaves.

## Usage

``` r
bw_diamonds(graph)
```

## Arguments

- graph:

  A `bw_depgraph`/`igraph` from
  [`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with
columns `package`, `n_dependents`, and `dependents` (a list column),
ordered by `n_dependents` descending.

## Examples

``` r
bw_diamonds(build_dep_graph(bw_example("clean.lock")))
#> # A tibble: 6 × 3
#>   package   n_dependents dependents
#>   <chr>            <int> <list>    
#> 1 cli                  4 <chr [4]> 
#> 2 rlang                4 <chr [4]> 
#> 3 glue                 3 <chr [3]> 
#> 4 lifecycle            3 <chr [3]> 
#> 5 fansi                2 <chr [2]> 
#> 6 vctrs                2 <chr [2]> 
```
