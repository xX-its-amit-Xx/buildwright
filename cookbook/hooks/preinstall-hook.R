#!/usr/bin/env Rscript

# buildwright pre-install hook
# ============================
#
# Drop this script into a project and run it BEFORE bringing the environment up
# to its lockfile (renv::restore()) or installing with pak. With strict = TRUE
# it aborts (non-zero exit) when buildwright predicts conflicts, install
# failures, or missing system libraries, so a broken dependency set fails fast
# instead of part-way through a long install.
#
# Run it directly:
#   Rscript cookbook/hooks/preinstall-hook.R
#
# ----------------------------------------------------------------------------
# Wiring it as an renv hook
# ----------------------------------------------------------------------------
# renv looks for a `renv::restore` hook in the project .Rprofile. Add this to
# the project's .Rprofile so every restore is gated:
#
#   if (requireNamespace("buildwright", quietly = TRUE)) {
#     setHook("renv::restore", function(...) {
#       buildwright::bw_preinstall_check("renv.lock", strict = TRUE)
#     })
#   }
#
# Alternatively, call this script explicitly at the top of your own restore.R
# before renv::restore(), or source it.
#
# ----------------------------------------------------------------------------
# Wiring it as a CI step
# ----------------------------------------------------------------------------
# Run it as its own job step; a non-zero exit fails the build. For example, in
# a GitHub Actions step:
#
#   - name: buildwright pre-install gate
#     run: Rscript cookbook/hooks/preinstall-hook.R
#
# Or inline, without a script file:
#
#   Rscript -e 'buildwright::bw_preinstall_check("renv.lock", strict = TRUE)'
#
# ----------------------------------------------------------------------------

# Lockfile to check (override by setting BW_LOCKFILE in the environment).
lockfile <- Sys.getenv("BW_LOCKFILE", unset = "renv.lock")

if (!requireNamespace("buildwright", quietly = TRUE)) {
  stop("buildwright is not installed; cannot run the pre-install check.", call. = FALSE)
}
if (!file.exists(lockfile)) {
  stop("Lockfile not found: ", lockfile, call. = FALSE)
}

# Optionally declare which system libraries are present on this host so the
# system-requirement check is deterministic (recommended in CI). Set
# BW_HOST_LIBRARIES to a comma-separated list, e.g. "libcurl,openssl".
host_env <- Sys.getenv("BW_HOST_LIBRARIES", unset = "")
host_libraries <- if (nzchar(host_env)) {
  trimws(strsplit(host_env, ",", fixed = TRUE)[[1L]])
} else {
  NULL
}

# strict = TRUE: abort on any predicted problem. This is the gate.
buildwright::bw_preinstall_check(
  lockfile,
  strict = TRUE,
  host_libraries = host_libraries
)

# If we reach here the dependency set looks installable; proceed with the
# install. Uncomment whichever you use:
#
#   renv::restore()
#   pak::pkg_install("local::.")
