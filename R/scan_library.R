#' Scan an R library or `renv` lockfile into a package inventory
#'
#' `scan_library()` is the entry point for every other buildwright function. It
#' reads either an installed library (a directory of installed packages) or an
#' `renv.lock` file and returns a tidy inventory of packages, their versions,
#' where they came from (CRAN / Bioconductor / GitHub / local / custom
#' repository), and their direct requirements.
#'
#' The input is auto-detected:
#' * `NULL` (the default) scans the first library on `.libPaths()`.
#' * A path to an `renv.lock` (or any `*.lock` / `*.json`) is parsed as a
#'   lockfile.
#' * A directory containing an `renv.lock` is parsed as a lockfile.
#' * Any other existing directory is treated as an installed library and scanned
#'   with [utils::installed.packages()].
#'
#' @param path Path to an `renv.lock` file, a project/library directory, or
#'   `NULL` to scan the current library.
#' @param include_base Logical; include base-priority packages that ship with R.
#'   Defaults to `FALSE` because they are always available and only add noise.
#'
#' @return A [tibble][tibble::tibble] of class `bw_library` with one row per
#'   package and the columns:
#'   \describe{
#'     \item{package}{Package name.}
#'     \item{version}{Resolved version string.}
#'     \item{source}{Canonical source: `"CRAN"`, `"Bioconductor"`, `"GitHub"`,
#'       `"local"`, `"Repository"`, `"base"`, or `"Unknown"`.}
#'     \item{repository}{Human-readable origin (e.g. `"CRAN"`, `"user/repo@sha"`).}
#'     \item{requirements}{List column of direct dependency strings, possibly
#'       version-qualified (e.g. `"rlang (>= 1.0.0)"`).}
#'     \item{is_base}{Whether the package ships with R.}
#'     \item{priority}{Install priority for library scans (`NA` for lockfiles).}
#'   }
#'   Useful metadata is attached as attributes: `bw_type` (`"lockfile"` or
#'   `"library"`), `bw_input`, `bw_r_version`, and `bw_bioc_version`.
#'
#' @seealso [build_dep_graph()], [detect_conflicts()], [diagnose()]
#' @export
#' @examples
#' lib <- scan_library(bw_example("clean.lock"))
#' lib
#' nrow(lib)
#' table(lib$source)
scan_library <- function(path = NULL, include_base = FALSE) {
  src <- bw_resolve_source(path)
  out <- switch(src$type,
    lockfile = bw_scan_lockfile(src$path),
    library  = bw_scan_installed(src$path, include_base = include_base),
    cli::cli_abort("Unsupported source type {.val {src$type}}.")
  )
  out$tbl <- out$tbl[order(out$tbl$package), , drop = FALSE]
  new_bw_library(
    out$tbl,
    type = src$type,
    input = src$input,
    r_version = out$r_version,
    bioc_version = out$bioc_version
  )
}

#' @rdname scan_library
#' @param name Fixture name shipped with the package.
#' @return `bw_example()` returns the file path to a bundled fixture lockfile.
#' @export
#' @examples
#' bw_example("conflicted.lock")
bw_example <- function(name = c("clean.lock", "conflicted.lock", "missing-sysreq.lock")) {
  name <- match.arg(name)
  system.file("extdata", name, package = "buildwright", mustWork = TRUE)
}

# ---- internals --------------------------------------------------------------

bw_resolve_source <- function(path) {
  if (is.null(path)) {
    return(list(type = "library", path = .libPaths()[[1L]], input = "<current library>"))
  }
  if (!file.exists(path)) {
    cli::cli_abort("Path {.path {path}} does not exist.")
  }
  if (dir.exists(path)) {
    lock <- file.path(path, "renv.lock")
    if (file.exists(lock)) {
      return(list(type = "lockfile", path = lock, input = lock))
    }
    return(list(type = "library", path = path, input = path))
  }
  ext <- tolower(tools::file_ext(path))
  if (identical(basename(path), "renv.lock") || ext %in% c("lock", "json")) {
    return(list(type = "lockfile", path = path, input = path))
  }
  cli::cli_abort(c(
    "Could not determine how to read {.path {path}}.",
    "i" = "Pass an {.file renv.lock} file, a directory, or {.code NULL}."
  ))
}

bw_scan_lockfile <- function(file) {
  data <- tryCatch(
    jsonlite::fromJSON(file, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to parse lockfile {.path {file}}.",
        "x" = conditionMessage(e)
      ))
    }
  )
  pkgs <- data$Packages %||% list()
  if (length(pkgs) == 0L) {
    cli::cli_warn("Lockfile {.path {file}} contains no packages.")
  }
  rows <- lapply(pkgs, function(rec) {
    cls <- bw_classify_source(rec)
    reqs <- unlist(rec$Requirements %||% character(), use.names = FALSE)
    reqs <- reqs[!is.na(reqs) & nzchar(reqs) & reqs != "R"]
    list(
      package = bw_chr1(rec$Package),
      version = bw_chr1(rec$Version),
      source = cls$source,
      repository = cls$repository,
      requirements = list(as.character(reqs)),
      is_base = bw_is_base(bw_chr1(rec$Package)),
      priority = NA_character_
    )
  })
  tbl <- bw_bind_rows(rows)
  list(
    tbl = tbl,
    r_version = bw_chr1(data$R$Version),
    bioc_version = bw_chr1(data$Bioconductor$Version)
  )
}

bw_scan_installed <- function(libpath, include_base = FALSE) {
  # Scan package directories directly from their DESCRIPTION files. This is more
  # robust than utils::installed.packages() (which only sees fully *installed*
  # packages) and also handles a directory of unbuilt package sources -- useful
  # for vetting a library before it is built.
  subdirs <- list.dirs(libpath, recursive = FALSE, full.names = TRUE)
  has_desc <- subdirs[file.exists(file.path(subdirs, "DESCRIPTION"))]
  if (length(has_desc) == 0L) {
    cli::cli_abort(c(
      "No packages found under {.path {libpath}}.",
      "i" = "Expected package subdirectories each containing a {.file DESCRIPTION}."
    ))
  }
  rows <- lapply(has_desc, function(dir) {
    d <- tryCatch(desc::desc(file = file.path(dir, "DESCRIPTION")),
                  error = function(e) NULL)
    if (is.null(d)) return(NULL)
    pkg <- d$get_field("Package", default = basename(dir))
    priority <- d$get_field("Priority", default = NA_character_)
    cls <- bw_classify_installed(d, priority = priority)
    list(
      package = pkg,
      version = d$get_field("Version", default = NA_character_),
      source = cls$source,
      repository = cls$repository,
      requirements = list(bw_desc_requirements(d)),
      is_base = bw_is_base(pkg),
      priority = if (is.na(priority)) NA_character_ else as.character(priority)
    )
  })
  rows <- Filter(Negate(is.null), rows)
  tbl <- bw_bind_rows(rows)
  if (!include_base) {
    tbl <- tbl[!(tbl$priority %in% "base"), , drop = FALSE]
  }
  list(
    tbl = tbl,
    r_version = as.character(getRversion()),
    bioc_version = NA_character_
  )
}

# Version-qualified hard requirements (Depends/Imports/LinkingTo) from a desc.
bw_desc_requirements <- function(d) {
  deps <- tryCatch(d$get_deps(), error = function(e) NULL)
  if (is.null(deps) || nrow(deps) == 0L) return(character())
  keep <- deps$type %in% c("Depends", "Imports", "LinkingTo") & deps$package != "R"
  deps <- deps[keep, , drop = FALSE]
  if (nrow(deps) == 0L) return(character())
  reqs <- vapply(seq_len(nrow(deps)), function(i) {
    v <- deps$version[[i]]
    if (is.na(v) || !nzchar(v) || identical(v, "*")) {
      deps$package[[i]]
    } else {
      paste0(deps$package[[i]], " (", v, ")")
    }
  }, character(1))
  unique(reqs)
}

bw_classify_installed <- function(d, priority = NA) {
  if (!is.na(priority) && priority %in% c("base", "recommended")) {
    return(list(source = if (priority == "base") "base" else "Repository",
                repository = as.character(priority)))
  }
  get1 <- function(key) {
    v <- tryCatch(d$get_field(key, default = NA_character_), error = function(e) NA_character_)
    if (length(v) == 0L || is.na(v)) NA_character_ else as.character(v)
  }
  rec <- list(
    Package = get1("Package"),
    Repository = get1("Repository"),
    biocViews = if (!is.na(get1("biocViews"))) get1("biocViews") else NULL,
    RemoteType = get1("RemoteType"),
    RemoteUsername = get1("RemoteUsername"),
    RemoteRepo = get1("RemoteRepo"),
    RemoteSha = get1("RemoteSha"),
    Source = get1("Repository")
  )
  cls <- bw_classify_source(rec)
  # source packages without remote/biocViews/Repository metadata are local
  if (is.na(cls$source) || cls$source == "Unknown") cls$source <- "local"
  cls
}

# Bind a list of single-row named lists into a tibble, preserving list columns.
bw_bind_rows <- function(rows) {
  if (length(rows) == 0L) {
    return(tibble::tibble(
      package = character(), version = character(), source = character(),
      repository = character(), requirements = list(), is_base = logical(),
      priority = character()
    ))
  }
  # `rows` can be a named list (renv.lock Packages map); drop names so the
  # vapply()-built columns below are clean, unnamed vectors.
  rows <- unname(rows)
  tibble::tibble(
    package = vapply(rows, function(x) x$package %||% NA_character_, character(1)),
    version = vapply(rows, function(x) x$version %||% NA_character_, character(1)),
    source = vapply(rows, function(x) x$source %||% NA_character_, character(1)),
    repository = vapply(rows, function(x) x$repository %||% NA_character_, character(1)),
    requirements = lapply(rows, function(x) x$requirements[[1L]]),
    is_base = vapply(rows, function(x) isTRUE(x$is_base), logical(1)),
    priority = vapply(rows, function(x) x$priority %||% NA_character_, character(1))
  )
}

new_bw_library <- function(tbl, type, input, r_version, bioc_version) {
  class(tbl) <- c("bw_library", class(tibble::tibble()))
  attr(tbl, "bw_type") <- type
  attr(tbl, "bw_input") <- input
  attr(tbl, "bw_r_version") <- r_version
  attr(tbl, "bw_bioc_version") <- bioc_version
  tbl
}

#' @export
print.bw_library <- function(x, ...) {
  type <- attr(x, "bw_type") %||% "library"
  input <- attr(x, "bw_input") %||% "?"
  rv <- attr(x, "bw_r_version")
  bioc <- attr(x, "bw_bioc_version")
  cli::cli_h1("buildwright library scan")
  cli::cli_text("{.strong {nrow(x)}} packages from {.field {type}} {.path {input}}")
  if (!is.null(rv) && !is.na(rv)) cli::cli_text("R version: {.val {rv}}")
  if (!is.null(bioc) && !is.na(bioc)) cli::cli_text("Bioconductor: {.val {bioc}}")
  if (nrow(x) > 0L && "source" %in% names(x)) {
    tab <- sort(table(x$source), decreasing = TRUE)
    cli::cli_text("Sources: {paste(sprintf('%s (%d)', names(tab), as.integer(tab)), collapse = ', ')}")
  }
  cli::cli_text("")
  NextMethod()
}
