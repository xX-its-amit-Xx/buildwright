test_that("scan_library() reads clean.lock into a 14-row bw_library", {
  lib <- scan_library(bw_example("clean.lock"))

  expect_s3_class(lib, "bw_library")
  expect_s3_class(lib, "tbl_df")
  expect_equal(nrow(lib), 14L)
})

test_that("scan_library() returns the documented columns", {
  lib <- scan_library(bw_example("clean.lock"))

  expected_cols <- c(
    "package", "version", "source", "repository",
    "requirements", "is_base", "priority"
  )
  expect_equal(names(lib), expected_cols)

  expect_type(lib$package, "character")
  expect_type(lib$version, "character")
  expect_type(lib$source, "character")
  expect_type(lib$is_base, "logical")
})

test_that("scan_library() classifies CRAN, Bioconductor and GitHub sources", {
  lib <- scan_library(bw_example("clean.lock"))

  expect_true(all(lib$source %in% c(
    "CRAN", "Bioconductor", "GitHub", "local", "Repository", "base", "Unknown"
  )))
  expect_true("CRAN" %in% lib$source)
  expect_true("Bioconductor" %in% lib$source)
  expect_true("GitHub" %in% lib$source)

  # fastmap is the GitHub package; repository is rendered as user/repo@sha
  fastmap <- lib[lib$package == "fastmap", ]
  expect_equal(fastmap$source, "GitHub")
  expect_match(fastmap$repository, "r-lib/fastmap")
})

test_that("scan_library() attaches lockfile metadata as attributes", {
  lib <- scan_library(bw_example("clean.lock"))

  expect_equal(attr(lib, "bw_type"), "lockfile")
  expect_equal(attr(lib, "bw_input"), bw_example("clean.lock"))
  expect_equal(attr(lib, "bw_r_version"), "4.3.2")
  expect_equal(attr(lib, "bw_bioc_version"), "3.18")
})

test_that("scan_library() requirements is a list column", {
  lib <- scan_library(bw_example("clean.lock"))

  expect_type(lib$requirements, "list")
  expect_equal(length(lib$requirements), nrow(lib))
  # tibble depends on several packages; its requirements are character.
  tib <- lib$requirements[[which(lib$package == "tibble")]]
  expect_type(tib, "character")
  expect_true("rlang" %in% tib)
})

test_that("scan_library() errors on a non-existent path", {
  missing <- file.path(tempdir(), "definitely-not-here-bw", "renv.lock")
  expect_error(scan_library(missing))
})
