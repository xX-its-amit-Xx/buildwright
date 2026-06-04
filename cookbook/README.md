# buildwright cookbook

These are the full, network-enabled versions of the recipes in the package
vignette (`vignette("cookbook", package = "buildwright")`). Unlike the vignette,
the scripts here are **not** built by `R CMD check`: they are allowed to touch
the network, write rendered HTML reports, and create throwaway libraries. Run
them by hand when you want to see buildwright work end to end against real or
freshly-constructed inputs.

## Running

Run each script from the **package root** with `Rscript`, e.g.

```sh
Rscript cookbook/01-broken-bioconductor.R
Rscript cookbook/02-audit-public-renv-lock.R
Rscript cookbook/03-cran-version-drift.R
```

The scripts assume buildwright is installed (`R CMD INSTALL .` or
`devtools::install()` / `pak::pkg_install("local::.")`). They write any
generated lockfiles under `cookbook/data/` and any rendered HTML reports under
`cookbook/output/`. Both of those locations are gitignored, so re-running a
recipe never dirties the working tree.

`cookbook/output/` is created on demand by the scripts that render reports. If
you have cloned a fresh checkout, the empty `cookbook/data/.gitkeep` keeps the
data directory present.

## The recipes

### 01-broken-bioconductor.R

Constructs a deliberately-broken Bioconductor `renv.lock` (a Bioconductor
package whose required Bioconductor dependency is missing, plus a package with a
known system requirement), writes it to `cookbook/data/`, runs `diagnose()`, and
prints `detect_conflicts()`, `check_sysreqs()`, and `simulate_install()`. It
then renders a self-contained HTML report to
`cookbook/output/01-broken-bioc.html` via
`report(format = "quarto", ...)`. If the Quarto CLI is not installed,
`report()` transparently falls back to the bundled R Markdown template, so you
still get HTML. If `BiocManager` is installed, the script also prints the
Bioconductor release it is aware of.

**Expect:** a `missing` conflict for the absent Bioconductor dependency, a
`missing` system library for the libcurl-dependent package, an infeasible
install plan with blocked packages, and a written HTML report path.

### 02-audit-public-renv-lock.R

Downloads a real `renv.lock` live from GitHub
(`rstudio/renv` -> `tests/testthat/resources/bioconductor.lock`), saves it to
`cookbook/data/public-project.lock`, then scans, diagnoses, and renders a report
for it. It prints the source breakdown and points out two real findings: a
**Local**-source package (a reproducibility smell) and a **Bioconductor release
mismatch** (`BiocGenerics` on `RELEASE_3_13` vs `limma` on `RELEASE_3_14`). The
download is wrapped in `tryCatch()`; when offline it falls back to the bundled
copy at `system.file("extdata", "public-project.lock", package = "buildwright")`,
so the recipe always runs.

**Expect:** a 3-package scan (2 Bioconductor + 1 Local), a clean structural
diagnosis, a printed note about the Local source and the release mismatch, and a
report at `cookbook/output/02-public-project.html`.

### 03-cran-version-drift.R

Creates two tiny CRAN-style packages in a temp directory with conflicting
version ranges on a shared dependency (`pkgA` imports `shared (>= 2.0)`, `pkgB`
imports `shared (<= 1.0)`, `shared` present at `1.5`), scans that directory as an
installed library, runs `detect_conflicts()` to surface the `version_conflict`,
and runs `simulate_install()` to show the predicted failure. Everything is
printed; nothing is written outside `tempdir()`.

**Expect:** one `version_conflict` row for `shared`, and an install plan that
fails `shared` and blocks `pkgA`/`pkgB`.

### hooks/preinstall-hook.R

A ready-to-drop-in script that runs
`buildwright::bw_preinstall_check("renv.lock", strict = TRUE)` and is meant to be
called *before* `renv::restore()` or `pak::pkg_install()`. The header comments
show how to wire it as an renv hook and as a CI step. It is not one of the
numbered recipes; copy it into your own project.
