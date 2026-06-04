test_that("diagnose() returns a bw_diagnosis with all components", {
  diag <- diagnose(
    bw_example("conflicted.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_s3_class(diag, "bw_diagnosis")
  expect_true(all(
    c("library", "graph", "conflicts", "sysreqs", "plan", "meta") %in% names(diag)
  ))

  expect_s3_class(diag$library, "bw_library")
  expect_s3_class(diag$graph, "bw_depgraph")
  expect_s3_class(diag$conflicts, "bw_conflicts")
  expect_s3_class(diag$sysreqs, "bw_sysreqs")
  expect_s3_class(diag$plan, "bw_install_plan")
  expect_type(diag$meta, "list")
})

test_that("diagnose() meta records the input and package count", {
  diag <- diagnose(
    bw_example("conflicted.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_equal(diag$meta$type, "lockfile")
  expect_equal(diag$meta$platform, "linux")
  expect_equal(diag$meta$n_packages, nrow(diag$library))
  expect_equal(diag$meta$n_packages, 9L)
})

test_that("summary() of a diagnosis is a 2-column tibble", {
  diag <- diagnose(
    bw_example("clean.lock"),
    platform = "linux",
    host_libraries = character()
  )
  s <- summary(diag)

  expect_s3_class(s, "tbl_df")
  expect_equal(ncol(s), 2L)
  expect_equal(names(s), c("metric", "value"))
  expect_true("feasible" %in% s$metric)
})

test_that("print() of a diagnosis does not error", {
  diag <- diagnose(
    bw_example("clean.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_no_error(print(diag))
  # print() emits via cli to stderr, so capture with cli::cli_fmt rather than
  # expect_output() (which only sees stdout).
  out <- cli::cli_fmt(print(diag))
  expect_true(any(grepl("buildwright", out)))
})
