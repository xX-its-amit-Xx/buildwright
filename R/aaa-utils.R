# Internal helpers shared across buildwright. No exports in this file.

#' Default value for `NULL` / empty
#'
#' @param x,y Values; `x` unless it is `NULL` or length zero, otherwise `y`.
#' @return `x` when it is non-`NULL` and has length, otherwise `y`.
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

#' Coerce a scalar-ish value to a single character string
#' @noRd
bw_chr1 <- function(x, default = NA_character_) {
  if (is.null(x) || length(x) == 0L) return(default)
  x <- x[[1L]]
  if (is.na(x)) return(default)
  as.character(x)
}

#' Base and recommended package names
#'
#' Used to decide which dependencies ship with R and therefore never need to be
#' installed or resolved. Falls back to a static list so results do not depend
#' on what happens to be installed on the host.
#' @noRd
bw_base_packages <- function(recommended = TRUE) {
  base <- c(
    "base", "compiler", "datasets", "graphics", "grDevices", "grid",
    "methods", "parallel", "splines", "stats", "stats4", "tcltk", "tools",
    "translations", "utils"
  )
  rec <- c(
    "boot", "class", "cluster", "codetools", "foreign", "KernSmooth",
    "lattice", "MASS", "Matrix", "mgcv", "nlme", "nnet", "rpart", "spatial",
    "survival"
  )
  installed <- tryCatch(
    rownames(utils::installed.packages(priority = if (recommended) c("base", "recommended") else "base")),
    error = function(e) character()
  )
  out <- unique(c(base, if (recommended) rec, installed))
  sort(out)
}

#' Is `pkg` a base/recommended package shipped with R?
#' @noRd
bw_is_base <- function(pkg, recommended = TRUE) {
  pkg %in% bw_base_packages(recommended = recommended)
}

#' Detect the host platform in the vocabulary buildwright uses for sysreqs
#' @return One of "linux", "macos", "windows".
#' @noRd
bw_host_platform <- function() {
  sysname <- tolower(Sys.info()[["sysname"]])
  if (identical(sysname, "windows") || .Platform$OS.type == "windows") {
    "windows"
  } else if (identical(sysname, "darwin")) {
    "macos"
  } else {
    "linux"
  }
}

#' Require a suggested package or stop with an actionable message
#' @noRd
bw_need <- function(pkg, what = NULL, call = rlang::caller_env()) {
  rlang::check_installed(
    pkg,
    reason = what %||% sprintf("for this buildwright feature"),
    call = call
  )
  invisible(TRUE)
}

#' Parse a single dependency string such as "rlang (>= 1.0.0)"
#'
#' Returns the package name, comparison operator and version. Plain names
#' (no version, as found in `renv.lock` "Requirements") yield `NA` op/version.
#' @return A list with elements `package`, `op`, `version`.
#' @noRd
bw_parse_requirement <- function(x) {
  x <- trimws(x)
  m <- regmatches(x, regexec(
    "^([A-Za-z][A-Za-z0-9.]*)\\s*(?:\\(\\s*(>=|<=|==|>|<|!=)\\s*([0-9][0-9.\\-]*)\\s*\\))?$",
    x
  ))[[1L]]
  if (length(m) == 0L) {
    return(list(package = x, op = NA_character_, version = NA_character_))
  }
  list(
    package = m[[2L]],
    op = if (nzchar(m[[3L]])) m[[3L]] else NA_character_,
    version = if (nzchar(m[[4L]])) m[[4L]] else NA_character_
  )
}

#' Vectorised dependency-string parser into a tibble (package, op, version)
#' @noRd
bw_parse_requirements <- function(x) {
  x <- x[!is.na(x)]
  x <- x[nzchar(trimws(x))]
  x <- x[trimws(x) != "R"]
  if (length(x) == 0L) {
    return(tibble::tibble(
      package = character(), op = character(), version = character()
    ))
  }
  parts <- lapply(x, bw_parse_requirement)
  tibble::tibble(
    package = vapply(parts, `[[`, character(1), "package"),
    op = vapply(parts, `[[`, character(1), "op"),
    version = vapply(parts, `[[`, character(1), "version")
  )
}

#' Split a raw DESCRIPTION dependency field ("a (>= 1), b") into atoms
#' @noRd
bw_split_deps <- function(field) {
  if (is.null(field) || length(field) == 0L) return(character())
  field <- paste(field, collapse = ", ")
  if (is.na(field) || !nzchar(field)) return(character())
  parts <- strsplit(field, ",", fixed = TRUE)[[1L]]
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

#' Classify an `renv.lock` package record into a canonical source + repository
#'
#' @param record A named list (one entry of the lockfile `Packages` map).
#' @return A list with `source` and `repository` character scalars.
#' @noRd
bw_classify_source <- function(record) {
  src <- bw_chr1(record$Source)
  repo <- bw_chr1(record$Repository)
  remote_type <- bw_chr1(record$RemoteType)

  is_github <- !is.na(remote_type) && tolower(remote_type) %in% c("github", "git")
  if (!is_github && !is.na(src) && tolower(src) == "github") is_github <- TRUE

  if (is_github) {
    user <- bw_chr1(record$RemoteUsername)
    rrepo <- bw_chr1(record$RemoteRepo) %||% bw_chr1(record$Package)
    sha <- bw_chr1(record$RemoteSha)
    ref <- if (!is.na(user)) paste0(user, "/", rrepo) else rrepo
    if (!is.na(sha)) ref <- paste0(ref, "@", substr(sha, 1L, 7L))
    return(list(source = "GitHub", repository = ref))
  }

  src_l <- if (is.na(src)) NA_character_ else tolower(src)
  repo_l <- if (is.na(repo)) NA_character_ else tolower(repo)

  is_bioc <- (!is.na(src_l) && src_l == "bioconductor") ||
    (!is.na(repo_l) && grepl("bioc", repo_l)) ||
    !is.null(record$biocViews)
  if (is_bioc) {
    bioc_repo <- if (!is.na(repo)) repo else bw_chr1(record$git_url, "Bioconductor")
    return(list(source = "Bioconductor", repository = bioc_repo))
  }

  if (!is.na(src_l) && src_l == "local") {
    return(list(source = "local", repository = bw_chr1(record$RemoteUrl) %||% "local"))
  }

  if (!is.na(src_l) && src_l %in% c("repository", "cran", "standard")) {
    if (!is.na(repo) && toupper(repo) == "CRAN") {
      return(list(source = "CRAN", repository = "CRAN"))
    }
    if (!is.na(repo)) {
      return(list(source = "Repository", repository = repo))
    }
    return(list(source = "CRAN", repository = "CRAN"))
  }

  list(
    source = if (is.na(src)) "Unknown" else src,
    repository = repo
  )
}

#' Convert a comparison operator + version into a numeric_version interval
#'
#' Returns `low`, `low_closed`, `high`, `high_closed`. Bounds are
#' `numeric_version` objects or `NA` for an open (unbounded) side.
#' @noRd
bw_constraint_interval <- function(op, version) {
  inf <- list(low = NA, low_closed = FALSE, high = NA, high_closed = FALSE)
  if (is.na(op) || is.na(version)) return(inf)
  v <- tryCatch(numeric_version(version), error = function(e) NULL)
  if (is.null(v)) return(inf)
  switch(op,
    ">=" = list(low = v, low_closed = TRUE, high = NA, high_closed = FALSE),
    ">"  = list(low = v, low_closed = FALSE, high = NA, high_closed = FALSE),
    "<=" = list(low = NA, low_closed = FALSE, high = v, high_closed = TRUE),
    "<"  = list(low = NA, low_closed = FALSE, high = v, high_closed = FALSE),
    "==" = list(low = v, low_closed = TRUE, high = v, high_closed = TRUE),
    "!=" = inf, # treated as no hard bound for feasibility purposes
    inf
  )
}

#' Intersect a list of intervals; return feasibility and the merged interval
#' @noRd
bw_intersect_intervals <- function(intervals) {
  low <- NA
  low_closed <- FALSE
  high <- NA
  high_closed <- FALSE
  for (iv in intervals) {
    if (!is.na(iv$low)) {
      if (is.na(low) || iv$low > low || (iv$low == low && !iv$low_closed)) {
        low <- iv$low
        low_closed <- iv$low_closed
      }
    }
    if (!is.na(iv$high)) {
      if (is.na(high) || iv$high < high || (iv$high == high && !iv$high_closed)) {
        high <- iv$high
        high_closed <- iv$high_closed
      }
    }
  }
  feasible <- TRUE
  if (!is.na(low) && !is.na(high)) {
    if (low > high) {
      feasible <- FALSE
    } else if (low == high && !(low_closed && high_closed)) {
      feasible <- FALSE
    }
  }
  list(
    feasible = feasible, low = low, low_closed = low_closed,
    high = high, high_closed = high_closed
  )
}

#' Pretty-print a merged interval, e.g. ">= a, <= b"
#' @noRd
bw_format_interval <- function(merged) {
  parts <- character()
  if (!is.na(merged$low)) {
    parts <- c(parts, paste0(if (merged$low_closed) ">= " else "> ", merged$low))
  }
  if (!is.na(merged$high)) {
    parts <- c(parts, paste0(if (merged$high_closed) "<= " else "< ", merged$high))
  }
  if (length(parts) == 0L) "any" else paste(parts, collapse = ", ")
}

#' Does a concrete version satisfy (op, version)?
#' @noRd
bw_version_satisfies <- function(installed, op, required) {
  if (is.na(op) || is.na(required) || is.na(installed)) return(NA)
  iv <- tryCatch(numeric_version(installed), error = function(e) NULL)
  rv <- tryCatch(numeric_version(required), error = function(e) NULL)
  if (is.null(iv) || is.null(rv)) return(NA)
  switch(op,
    ">=" = iv >= rv,
    ">"  = iv >  rv,
    "<=" = iv <= rv,
    "<"  = iv <  rv,
    "==" = iv == rv,
    "!=" = iv != rv,
    NA
  )
}
