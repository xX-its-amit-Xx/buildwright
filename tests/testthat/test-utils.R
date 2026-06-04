test_that("bw_parse_requirement() splits a version-qualified requirement", {
  parsed <- buildwright:::bw_parse_requirement("rlang (>= 1.0.0)")

  expect_type(parsed, "list")
  expect_equal(parsed$package, "rlang")
  expect_equal(parsed$op, ">=")
  expect_equal(parsed$version, "1.0.0")
})

test_that("bw_parse_requirement() leaves op/version NA for a bare name", {
  parsed <- buildwright:::bw_parse_requirement("cli")

  expect_equal(parsed$package, "cli")
  expect_true(is.na(parsed$op))
  expect_true(is.na(parsed$version))
})

test_that("bw_parse_requirement() handles other operators", {
  le <- buildwright:::bw_parse_requirement("rlang (<= 0.4.12)")
  expect_equal(le$op, "<=")
  expect_equal(le$version, "0.4.12")
})

test_that("bw_classify_source() recognises a GitHub record", {
  rec <- list(
    Package = "fastmap",
    RemoteType = "github",
    RemoteUsername = "r-lib",
    RemoteRepo = "fastmap",
    RemoteSha = "8a4e2f1c9d7b6a5e4f3c2b1a0d9e8f7c6b5a4d3e"
  )
  cls <- buildwright:::bw_classify_source(rec)

  expect_equal(cls$source, "GitHub")
  expect_match(cls$repository, "r-lib/fastmap")
})

test_that("bw_classify_source() recognises CRAN and Bioconductor records", {
  cran <- buildwright:::bw_classify_source(
    list(Package = "cli", Source = "Repository", Repository = "CRAN")
  )
  expect_equal(cran$source, "CRAN")

  bioc <- buildwright:::bw_classify_source(
    list(Package = "S4Vectors", Source = "Bioconductor",
         Repository = "Bioconductor 3.18")
  )
  expect_equal(bioc$source, "Bioconductor")
})

test_that("bw_constraint_interval() builds bounded intervals", {
  ge <- buildwright:::bw_constraint_interval(">=", "1.0.0")
  expect_true(ge$low_closed)
  expect_equal(ge$low, numeric_version("1.0.0"))
  expect_true(is.na(ge$high))

  none <- buildwright:::bw_constraint_interval(NA_character_, NA_character_)
  expect_true(is.na(none$low))
  expect_true(is.na(none$high))
})

test_that("bw_intersect_intervals() reports feasibility", {
  feasible <- buildwright:::bw_intersect_intervals(list(
    buildwright:::bw_constraint_interval(">=", "1.0.0"),
    buildwright:::bw_constraint_interval("<=", "2.0.0")
  ))
  expect_true(feasible$feasible)

  # mirrors the rlang conflict: >= 1.1.0 and <= 0.4.12 cannot both hold.
  empty <- buildwright:::bw_intersect_intervals(list(
    buildwright:::bw_constraint_interval(">=", "1.1.0"),
    buildwright:::bw_constraint_interval("<=", "0.4.12")
  ))
  expect_false(empty$feasible)
})

test_that("bw_version_in_interval() respects the merged bounds", {
  merged <- buildwright:::bw_intersect_intervals(list(
    buildwright:::bw_constraint_interval(">=", "1.0.0"),
    buildwright:::bw_constraint_interval("<=", "2.0.0")
  ))

  expect_true(buildwright:::bw_version_in_interval("1.5.0", merged))
  expect_false(buildwright:::bw_version_in_interval("3.0.0", merged))
  expect_false(buildwright:::bw_version_in_interval("0.9.0", merged))
})

test_that("bw_version_satisfies() compares a version to a constraint", {
  expect_true(buildwright:::bw_version_satisfies("1.5.0", ">=", "1.0.0"))
  expect_false(buildwright:::bw_version_satisfies("0.9.0", ">=", "1.0.0"))
  expect_true(is.na(buildwright:::bw_version_satisfies("1.0.0", NA, NA)))
})
