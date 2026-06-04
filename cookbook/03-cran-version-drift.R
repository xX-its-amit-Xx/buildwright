#!/usr/bin/env Rscript

# Cookbook recipe 03: catching a version-drift conflict between two CRAN
# packages.
#
# Builds a tiny installed-library directory in tempdir() with two packages that
# demand incompatible version ranges of a shared dependency (pkgA needs
# shared >= 2.0, pkgB needs shared <= 1.0, shared is present at 1.5). The ranges
# do not intersect, so buildwright reports a version_conflict and predicts the
# install failure. Nothing is written outside tempdir().
#
# Run from the package root:
#   Rscript cookbook/03-cran-version-drift.R

library(buildwright)

lib_dir <- file.path(tempdir(), "bw-cookbook-drift-lib")
dir.create(lib_dir, showWarnings = FALSE, recursive = TRUE)

# Write a minimal CRAN-style DESCRIPTION for a fixture package.
write_desc <- function(name, version, imports = NULL) {
  pkg_dir <- file.path(lib_dir, name)
  dir.create(pkg_dir, showWarnings = FALSE)
  lines <- c(
    paste0("Package: ", name),
    paste0("Version: ", version),
    "Title: Fixture",
    "Description: Fixture package for the buildwright cookbook.",
    "License: GPL-3"
  )
  if (!is.null(imports)) lines <- c(lines, paste0("Imports: ", imports))
  writeLines(lines, file.path(pkg_dir, "DESCRIPTION"))
}

write_desc("pkgA", "1.0.0", imports = "shared (>= 2.0)")
write_desc("pkgB", "1.0.0", imports = "shared (<= 1.0)")
write_desc("shared", "1.5.0")
message("Built fixture library at ", lib_dir)

# Scan the directory as an installed library.
lib <- scan_library(lib_dir)
cat("\n== Scanned library ==\n")
print(lib[, c("package", "version", "source", "requirements")])

# Detect the version conflict: intersection of >= 2.0 and <= 1.0 is empty.
cat("\n== Conflicts ==\n")
conf <- detect_conflicts(lib)
print(conf)
cat("\nConflict detail:\n")
cat(conf$detail, sep = "\n")

# Simulate the install: shared fails, pkgA and pkgB are blocked behind it.
cat("\n\n== Install simulation ==\n")
plan <- simulate_install(lib)
print(plan)
cat("\nFeasible:", plan$feasible, "\n")
cat("\nPredicted failures:\n")
print(plan$predicted_failures[, c("package", "predicted_status", "reason")])
