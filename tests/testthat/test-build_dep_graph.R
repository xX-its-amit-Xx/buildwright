test_that("build_dep_graph() returns an igraph of class bw_depgraph", {
  g <- build_dep_graph(bw_example("clean.lock"))

  expect_s3_class(g, "bw_depgraph")
  expect_s3_class(g, "igraph")
  expect_true(igraph::vcount(g) > 0L)
  expect_true(igraph::ecount(g) > 0L)
})

test_that("build_dep_graph() carries the documented vertex attributes", {
  g <- build_dep_graph(bw_example("clean.lock"))

  vattrs <- igraph::vertex_attr_names(g)
  expect_true(all(c("version", "source", "present", "is_base") %in% vattrs))
  expect_true("constraint" %in% igraph::edge_attr_names(g))
  expect_type(igraph::vertex_attr(g, "present"), "logical")
})

test_that("clean.lock is acyclic", {
  g <- build_dep_graph(bw_example("clean.lock"))

  cycles <- bw_cycles(g)
  expect_type(cycles, "list")
  expect_length(cycles, 0L)
})

test_that("conflicted.lock has the ouroboros/boros cycle", {
  g <- build_dep_graph(bw_example("conflicted.lock"))

  cycles <- bw_cycles(g)
  expect_true(length(cycles) >= 1L)
  members <- unique(unlist(cycles))
  expect_true(all(c("ouroboros", "boros") %in% members))
})

test_that("bw_diamonds() returns a tibble of shared dependencies", {
  g <- build_dep_graph(bw_example("clean.lock"))
  dia <- bw_diamonds(g)

  expect_s3_class(dia, "tbl_df")
  expect_equal(names(dia), c("package", "n_dependents", "dependents"))
  expect_type(dia$n_dependents, "integer")
  expect_type(dia$dependents, "list")
  # rlang is required by many packages in clean.lock, so it is a diamond.
  expect_true("rlang" %in% dia$package)
  expect_true(all(dia$n_dependents >= 2L))
})

test_that("bw_graph_data() node count equals vcount", {
  g <- build_dep_graph(bw_example("clean.lock"))
  gd <- bw_graph_data(g)

  expect_named(gd, c("nodes", "edges"))
  expect_s3_class(gd$nodes, "tbl_df")
  expect_s3_class(gd$edges, "tbl_df")
  expect_equal(nrow(gd$nodes), igraph::vcount(g))
  expect_equal(nrow(gd$edges), igraph::ecount(g))
  expect_equal(names(gd$nodes), c("id", "label", "group", "present", "title", "color"))
  expect_equal(names(gd$edges), c("from", "to", "constraint", "arrows"))
})
