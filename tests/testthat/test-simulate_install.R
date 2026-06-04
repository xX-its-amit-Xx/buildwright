test_that("simulate_install() returns a well-formed plan for clean.lock", {
  plan <- simulate_install(
    bw_example("clean.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_s3_class(plan, "bw_install_plan")
  expect_type(plan$order, "character")
  expect_s3_class(plan$steps, "tbl_df")
  expect_equal(
    names(plan$steps),
    c("step", "package", "version", "source", "predicted_status", "reason")
  )
  expect_false(plan$has_cycle)
})

test_that("clean.lock is feasible and ordered dependency-first", {
  plan <- simulate_install(
    bw_example("clean.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_true(plan$feasible)
  expect_equal(nrow(plan$predicted_failures), 0L)

  # tibble depends (transitively) on rlang, so rlang installs first.
  ord <- plan$order
  expect_true("rlang" %in% ord)
  expect_true("tibble" %in% ord)
  expect_true(match("tibble", ord) > match("rlang", ord))
})

test_that("conflicted.lock is infeasible with failures and blocks", {
  plan <- simulate_install(
    bw_example("conflicted.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_false(plan$feasible)
  expect_true(plan$has_cycle)
  expect_true(plan$n_fail >= 3L)

  pf <- plan$predicted_failures
  expect_true(nrow(pf) >= 3L)
  expect_true("alpha" %in% pf$package)
  expect_true("rlang" %in% pf$package)

  # alpha is blocked (its missing dependency zeta cannot install); rlang fails
  # outright on unsatisfiable version constraints.
  expect_equal(pf$predicted_status[pf$package == "alpha"], "blocked")
  expect_equal(pf$predicted_status[pf$package == "rlang"], "fail")
})
