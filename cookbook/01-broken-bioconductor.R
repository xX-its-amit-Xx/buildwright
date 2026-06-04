#!/usr/bin/env Rscript

# Cookbook recipe 01: diagnosing a deliberately-broken Bioconductor install.
#
# Constructs an renv.lock for a small Bioconductor environment that is missing
# one of its required Bioconductor dependencies (S4Vectors needs IRanges, but
# IRanges is absent) and also pins a package with a known system requirement
# (RCurl -> libcurl). buildwright catches both before any install is attempted,
# and we render an HTML report of the diagnosis.
#
# Run from the package root:
#   Rscript cookbook/01-broken-bioconductor.R

library(buildwright)

# Bioconductor awareness: if BiocManager is installed, show the release it
# would target. Guarded so the recipe runs without it.
if (requireNamespace("BiocManager", quietly = TRUE)) {
  message("BiocManager Bioconductor version: ", as.character(BiocManager::version()))
} else {
  message("BiocManager not installed; skipping Bioconductor version probe.")
}

data_dir <- "cookbook/data"
output_dir <- "cookbook/output"
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# A broken Bioconductor lockfile: S4Vectors requires IRanges, which is not in
# the Packages map. RCurl carries a libcurl system requirement.
broken_lock <- '{
  "R": { "Version": "4.3.2" },
  "Bioconductor": { "Version": "3.18" },
  "Packages": {
    "BiocGenerics": {
      "Package": "BiocGenerics",
      "Version": "0.48.1",
      "Source": "Bioconductor",
      "Repository": "Bioconductor 3.18",
      "Requirements": []
    },
    "S4Vectors": {
      "Package": "S4Vectors",
      "Version": "0.40.2",
      "Source": "Bioconductor",
      "Repository": "Bioconductor 3.18",
      "Requirements": ["BiocGenerics", "IRanges"]
    },
    "RCurl": {
      "Package": "RCurl",
      "Version": "1.98-1.14",
      "Source": "Repository",
      "Repository": "CRAN",
      "Requirements": ["bitops"]
    },
    "bitops": {
      "Package": "bitops",
      "Version": "1.0-7",
      "Source": "Repository",
      "Repository": "CRAN",
      "Requirements": []
    }
  }
}'

lock_path <- file.path(data_dir, "broken-bioconductor.lock")
writeLines(broken_lock, lock_path)
message("Wrote broken lockfile to ", lock_path)

# Scan and show the source breakdown.
lib <- scan_library(lock_path)
cat("\n== Scanned library ==\n")
print(lib[, c("package", "version", "source")])
cat("\nSource breakdown:\n")
print(table(lib$source))

# Detect conflicts: the missing Bioconductor dependency (IRanges) shows up.
cat("\n== Conflicts ==\n")
conf <- detect_conflicts(lib)
print(conf)

# Map system requirements on a host with no libraries installed: RCurl -> libcurl.
cat("\n== System requirements (linux, no host libraries) ==\n")
sr <- check_sysreqs(lib, platform = "linux", host_libraries = character())
print(sr)

# Simulate the install: blocked by the missing dependency, so infeasible.
cat("\n== Install simulation ==\n")
plan <- simulate_install(lock_path, platform = "linux", host_libraries = character())
print(plan)
cat("\nFeasible:", plan$feasible, "\n")

# Render an HTML report. Falls back to the R Markdown template when no Quarto
# CLI is present; either way an HTML file is produced.
report_path <- file.path(output_dir, "01-broken-bioc.html")
cat("\n== Rendering report ==\n")
out <- report(
  lock_path,
  format = "quarto",
  output = report_path,
  platform = "linux",
  host_libraries = character(),
  open = FALSE,
  quiet = TRUE
)
message("Report written to ", out)
