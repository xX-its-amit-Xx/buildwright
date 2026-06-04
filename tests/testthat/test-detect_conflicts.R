test_that("detect_conflicts() finds nothing wrong with clean.lock", {
  conf <- detect_conflicts(bw_example("clean.lock"))

  expect_s3_class(conf, "bw_conflicts")
  expect_s3_class(conf, "tbl_df")
  expect_equal(nrow(conf), 0L)
})

test_that("detect_conflicts() has the documented columns", {
  conf <- detect_conflicts(bw_example("conflicted.lock"))

  expected_cols <- c(
    "package", "type", "required_by", "constraints",
    "installed_version", "satisfiable", "detail"
  )
  expect_equal(names(conf), expected_cols)
  expect_type(conf$required_by, "list")
  expect_type(conf$satisfiable, "logical")
})

test_that("conflicted.lock surfaces all four conflict types", {
  conf <- detect_conflicts(bw_example("conflicted.lock"))

  expect_equal(nrow(conf), 4L)
  expect_setequal(
    conf$type,
    c("missing", "version_conflict", "version_drift", "cycle")
  )
})

test_that("zeta is the missing dependency and is unsatisfiable", {
  conf <- detect_conflicts(bw_example("conflicted.lock"))

  missing_row <- conf[conf$type == "missing", ]
  expect_equal(nrow(missing_row), 1L)
  expect_equal(missing_row$package, "zeta")
  expect_false(missing_row$satisfiable)
  # alpha is the package that requires zeta.
  expect_true("alpha" %in% missing_row$required_by[[1L]])
})

test_that("rlang is the version_conflict and is unsatisfiable", {
  conf <- detect_conflicts(bw_example("conflicted.lock"))

  vc_row <- conf[conf$type == "version_conflict", ]
  expect_equal(nrow(vc_row), 1L)
  expect_equal(vc_row$package, "rlang")
  expect_false(vc_row$satisfiable)
})

test_that("cli is the version_drift conflict", {
  conf <- detect_conflicts(bw_example("conflicted.lock"))

  drift_row <- conf[conf$type == "version_drift", ]
  expect_equal(nrow(drift_row), 1L)
  expect_equal(drift_row$package, "cli")
})

test_that("missing, version_conflict and cycle are all unsatisfiable", {
  conf <- detect_conflicts(bw_example("conflicted.lock"))

  unsat <- conf[conf$type %in% c("missing", "version_conflict", "cycle"), ]
  expect_equal(nrow(unsat), 3L)
  expect_false(any(unsat$satisfiable))
})
