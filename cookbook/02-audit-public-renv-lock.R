#!/usr/bin/env Rscript

# Cookbook recipe 02: auditing a real renv.lock from a public R project.
#
# Downloads a genuine renv.lock from the rstudio/renv test resources, scans and
# diagnoses it, and surfaces two real findings: a Local-source package (a
# reproducibility smell) and a Bioconductor release mismatch (BiocGenerics on
# RELEASE_3_13 vs limma on RELEASE_3_14). When offline, it falls back to the
# bundled copy so the recipe always runs.
#
# Run from the package root:
#   Rscript cookbook/02-audit-public-renv-lock.R

library(buildwright)

data_dir <- "cookbook/data"
output_dir <- "cookbook/output"
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

url <- paste0(
  "https://raw.githubusercontent.com/rstudio/renv/main/",
  "tests/testthat/resources/bioconductor.lock"
)
dest <- file.path(data_dir, "public-project.lock")
fallback <- system.file("extdata", "public-project.lock", package = "buildwright")

# Try the live download; fall back to the bundled fixture when offline.
ok <- tryCatch(
  {
    download.file(url, dest, quiet = TRUE, mode = "wb")
    TRUE
  },
  error = function(e) {
    message("Download failed (", conditionMessage(e), "); using bundled copy.")
    FALSE
  }
)
if (!ok || !file.exists(dest) || file.size(dest) == 0) {
  file.copy(fallback, dest, overwrite = TRUE)
  message("Using bundled lockfile: ", fallback)
} else {
  message("Downloaded live lockfile from ", url)
}

# Scan and show the source breakdown.
rlib <- scan_library(dest)
cat("\n== Scanned library ==\n")
print(rlib[, c("package", "version", "source", "repository")])
cat("\nSource breakdown:\n")
print(table(rlib$source))

# Finding 1: a Local-source package is not reproducible elsewhere.
cat("\n== Finding 1: Local-source package(s) ==\n")
local_rows <- rlib[rlib$source == "local", c("package", "version", "repository")]
if (nrow(local_rows) > 0) {
  print(local_rows)
  cat(
    "These are pinned to a path on the lock author's machine and cannot be\n",
    "restored on another host. Prefer a CRAN or pinned-GitHub version.\n",
    sep = ""
  )
} else {
  cat("No Local-source packages found.\n")
}

# Finding 2: a Bioconductor release mismatch, read from the raw lock JSON.
cat("\n== Finding 2: Bioconductor release mismatch ==\n")
raw <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
bioc <- Filter(function(p) identical(p$Source, "Bioconductor"), raw$Packages)
branch_of <- function(p) if (is.null(p$git_branch)) NA_character_ else p$git_branch
bioc_tbl <- data.frame(
  package = vapply(bioc, function(p) p$Package, character(1)),
  version = vapply(bioc, function(p) p$Version, character(1)),
  git_branch = vapply(bioc, branch_of, character(1)),
  row.names = NULL
)
print(bioc_tbl)
declared_bioc <- if (is.null(raw$Bioconductor$Version)) NA else raw$Bioconductor$Version
cat("\nDeclared Bioconductor version in lockfile:", declared_bioc, "\n")
if (length(unique(stats::na.omit(bioc_tbl$git_branch))) > 1) {
  cat(
    "Bioconductor packages are pinned to different release branches; restoring\n",
    "this lock would mix Bioconductor releases.\n",
    sep = ""
  )
}

# Structural diagnosis (clean) plus an HTML report.
cat("\n== Diagnosis ==\n")
diag <- diagnose(dest)
print(diag)

report_path <- file.path(output_dir, "02-public-project.html")
cat("\n== Rendering report ==\n")
out <- report(dest, format = "quarto", output = report_path, open = FALSE, quiet = TRUE)
message("Report written to ", out)
