test_that("check_sysreqs() returns a bw_sysreqs with the documented columns", {
  sr <- check_sysreqs(
    bw_example("missing-sysreq.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_s3_class(sr, "bw_sysreqs")
  expect_s3_class(sr, "tbl_df")
  expected_cols <- c(
    "package", "system_requirement", "library", "platform",
    "present", "status", "install_hint", "source"
  )
  expect_equal(names(sr), expected_cols)
  expect_equal(attr(sr, "bw_platform"), "linux")
})

test_that("with no host libraries every requirement is missing", {
  sr <- check_sysreqs(
    bw_example("missing-sysreq.lock"),
    platform = "linux",
    host_libraries = character()
  )

  expect_true(nrow(sr) > 0L)
  expect_true(all(sr$status == "missing"))
  expect_true(all(sr$platform == "linux"))
  expect_true(all(c("libcurl", "openssl", "gdal") %in% sr$library))
})

test_that("supplying libcurl and openssl flips the right rows to ok", {
  sr <- check_sysreqs(
    bw_example("missing-sysreq.lock"),
    platform = "linux",
    host_libraries = c("libcurl", "openssl")
  )

  ok_rows <- sr[sr$status == "ok", ]
  # curl needs libcurl; openssl and askpass need openssl -> all three ok.
  expect_setequal(ok_rows$package, c("curl", "openssl", "askpass"))
  expect_true(all(ok_rows$present))

  # gdal is still absent, so sf rows remain missing.
  gdal_rows <- sr[sr$library == "gdal", ]
  expect_true(all(gdal_rows$status == "missing"))
})

test_that("linux install hints mention apt", {
  sr <- check_sysreqs(
    bw_example("missing-sysreq.lock"),
    platform = "linux",
    host_libraries = character()
  )

  curl_hint <- sr$install_hint[sr$library == "libcurl"][[1L]]
  expect_match(curl_hint, "apt")
})
