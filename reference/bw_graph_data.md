# Convert a dependency graph to node/edge data frames

Produces the `nodes` and `edges` data frames used by the Shiny dashboard
(and anything else that wants to draw the DAG, e.g. `visNetwork`). Nodes
are grouped and coloured by source, with referenced-but-missing packages
highlighted.

## Usage

``` r
bw_graph_data(graph)
```

## Arguments

- graph:

  A `bw_depgraph`/`igraph` from
  [`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md).

## Value

A list with two
[tibbles](https://tibble.tidyverse.org/reference/tibble.html):

- `nodes`: `id`, `label`, `group` (source), `present`, `title` (HTML
  tooltip), `color`.

- `edges`: `from`, `to`, `constraint`, `arrows`.

## Examples

``` r
gd <- bw_graph_data(build_dep_graph(bw_example("clean.lock")))
gd$nodes
#> # A tibble: 14 × 6
#>    id           label        group        present title                    color
#>    <chr>        <chr>        <chr>        <lgl>   <chr>                    <chr>
#>  1 BiocGenerics BiocGenerics Bioconductor TRUE    <b>BiocGenerics</b><br>… #2ca…
#>  2 S4Vectors    S4Vectors    Bioconductor TRUE    <b>S4Vectors</b><br>sou… #2ca…
#>  3 cli          cli          CRAN         TRUE    <b>cli</b><br>source: C… #1f7…
#>  4 fansi        fansi        CRAN         TRUE    <b>fansi</b><br>source:… #1f7…
#>  5 fastmap      fastmap      GitHub       TRUE    <b>fastmap</b><br>sourc… #6f4…
#>  6 glue         glue         CRAN         TRUE    <b>glue</b><br>source: … #1f7…
#>  7 lifecycle    lifecycle    CRAN         TRUE    <b>lifecycle</b><br>sou… #1f7…
#>  8 magrittr     magrittr     CRAN         TRUE    <b>magrittr</b><br>sour… #1f7…
#>  9 pillar       pillar       CRAN         TRUE    <b>pillar</b><br>source… #1f7…
#> 10 pkgconfig    pkgconfig    CRAN         TRUE    <b>pkgconfig</b><br>sou… #1f7…
#> 11 rlang        rlang        CRAN         TRUE    <b>rlang</b><br>source:… #1f7…
#> 12 tibble       tibble       CRAN         TRUE    <b>tibble</b><br>source… #1f7…
#> 13 utf8         utf8         CRAN         TRUE    <b>utf8</b><br>source: … #1f7…
#> 14 vctrs        vctrs        CRAN         TRUE    <b>vctrs</b><br>source:… #1f7…
```
