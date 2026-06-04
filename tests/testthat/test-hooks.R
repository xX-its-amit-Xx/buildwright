test_that("strict pre-install check passes silently on a clean lockfile", {
  diag <- bw_preinstall_check(
    bw_example("clean.lock"),
    strict = TRUE,
    platform = "linux",
    host_libraries = character(),
    quiet = TRUE
  )

  expect_s3_class(diag, "bw_diagnosis")
})

test_that("strict pre-install check returns its diagnosis invisibly", {
  expect_invisible(
    bw_preinstall_check(
      bw_example("clean.lock"),
      strict = TRUE,
      platform = "linux",
      host_libraries = character(),
      quiet = TRUE
    )
  )
})

test_that("strict pre-install check aborts on a broken lockfile", {
  expect_error(
    bw_preinstall_check(
      bw_example("conflicted.lock"),
      strict = TRUE,
      platform = "linux",
      host_libraries = character(),
      quiet = TRUE
    )
  )
})

test_that("non-strict pre-install check never errors", {
  expect_no_error(
    diag <- bw_preinstall_check(
      bw_example("conflicted.lock"),
      strict = FALSE,
      platform = "linux",
      host_libraries = character(),
      quiet = TRUE
    )
  )
  expect_s3_class(diag, "bw_diagnosis")
})
