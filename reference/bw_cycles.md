# Find dependency cycles in a graph

Find dependency cycles in a graph

## Usage

``` r
bw_cycles(graph)
```

## Arguments

- graph:

  A `bw_depgraph`/`igraph` from
  [`build_dep_graph()`](https://ashenoy.github.io/buildwright/reference/build_dep_graph.md).

## Value

A list of character vectors, each the packages in one cycle (strongly
connected component of size \> 1, or a self-loop). Empty list when the
graph is acyclic.

## Examples

``` r
bw_cycles(build_dep_graph(bw_example("clean.lock")))
#> list()
```
