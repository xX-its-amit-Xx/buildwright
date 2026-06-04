#' Map packages to system requirements and flag likely-missing libraries
#'
#' Translates each R package into the external system libraries it needs (the
#' `SystemRequirements` you only discover when a source install explodes with
#' "cannot find -lxml2"). Mappings come from three places, in order: the
#' package's own `SystemRequirements` field (for installed-library scans), an
#' optional authoritative lookup via `pak`, and a curated offline table
#' ([bw_sysreq_package_map()]).
#'
#' Whether a library is *present* is resolved as follows: if `host_libraries`
#' is supplied, presence is membership in that set (deterministic, ideal for CI
#' and tests); otherwise on Linux buildwright probes `pkg-config`, and on other
#' platforms presence is reported as unknown (`NA`) because CRAN binaries bundle
#' their libraries.
#'
#' @param x A `bw_library` or a path [scan_library()] accepts.
#' @param platform One of `"linux"`, `"macos"`, `"windows"`; defaults to the
#'   host. Controls which install hint is emitted.
#' @param host_libraries Optional character vector of canonical library tokens
#'   known to be present on the target host (e.g. `c("libcurl", "openssl")`).
#' @param use_pak Logical; if `TRUE` and `pak` is installed, query
#'   [pak::pkg_sysreqs()] for an authoritative mapping (requires network).
#'
#' @return A [tibble][tibble::tibble] of class `bw_sysreqs` with one row per
#'   (package, system library): `package`, `system_requirement`, `library`,
#'   `platform`, `present` (logical or `NA`), `status` (`"ok"`/`"missing"`/
#'   `"unknown"`), `install_hint`, and `source`. Packages with no known system
#'   requirements are omitted.
#'
#' @seealso [simulate_install()], [bw_sysreq_package_map()]
#' @export
#' @examples
#' # Pretend only libcurl is installed on the target host:
#' check_sysreqs(bw_example("missing-sysreq.lock"),
#'               platform = "linux", host_libraries = "libcurl")
check_sysreqs <- function(x, platform = bw_host_platform(),
                          host_libraries = NULL, use_pak = FALSE) {
  platform <- match.arg(platform, c("linux", "macos", "windows"))
  lib <- bw_as_library(x)
  libdb <- bw_sysreq_library_db()

  rows <- list()
  for (i in seq_len(nrow(lib))) {
    pkg <- lib$package[[i]]
    mapped <- bw_lookup_sysreqs(pkg, lib, use_pak = use_pak)
    if (length(mapped$library) == 0L) next
    for (k in seq_along(mapped$library)) {
      libname <- mapped$library[[k]]
      meta <- libdb[libdb$library == libname, , drop = FALSE]
      label <- if (nrow(meta) == 1L) meta$label else libname
      hint <- bw_install_hint(meta, platform)
      present <- bw_library_present(libname, meta, platform, host_libraries)
      status <- if (is.na(present)) "unknown" else if (present) "ok" else "missing"
      rows[[length(rows) + 1L]] <- list(
        package = pkg,
        system_requirement = label,
        library = libname,
        platform = platform,
        present = present,
        status = status,
        install_hint = hint,
        source = mapped$source[[k]]
      )
    }
  }
  new_bw_sysreqs(rows, platform = platform)
}

# ---- internals --------------------------------------------------------------

# Resolve the canonical libraries a package needs, with provenance.
bw_lookup_sysreqs <- function(pkg, lib, use_pak = FALSE) {
  libs <- character()
  srcs <- character()

  # (1) authoritative via pak, if requested and available
  if (use_pak && requireNamespace("pak", quietly = TRUE)) {
    pk <- tryCatch(
      pak::pkg_sysreqs(pkg),
      error = function(e) NULL
    )
    # pak's structure varies by version; fall through to other sources too
    if (!is.null(pk)) {
      txt <- paste(unlist(pk), collapse = " ")
      kw <- bw_keywords_to_libs(txt)
      libs <- c(libs, kw)
      srcs <- c(srcs, rep("pak", length(kw)))
    }
  }

  # (2) SystemRequirements from an installed DESCRIPTION
  sysreq_txt <- bw_get_sysreq_string(pkg, lib)
  if (!is.na(sysreq_txt) && nzchar(sysreq_txt)) {
    kw <- bw_keywords_to_libs(sysreq_txt)
    libs <- c(libs, kw)
    srcs <- c(srcs, rep("DESCRIPTION", length(kw)))
  }

  # (3) curated package map
  pmap <- bw_sysreq_package_map()
  mapped <- pmap$library[pmap$package == pkg]
  if (length(mapped) > 0L) {
    libs <- c(libs, mapped)
    srcs <- c(srcs, rep("map", length(mapped)))
  }

  if (length(libs) == 0L) return(list(library = character(), source = character()))
  keep <- !duplicated(libs)
  list(library = libs[keep], source = srcs[keep])
}

bw_keywords_to_libs <- function(txt) {
  kmap <- bw_sysreq_keyword_map()
  hit <- vapply(kmap$pattern, function(p) {
    grepl(p, txt, ignore.case = TRUE, perl = TRUE)
  }, logical(1))
  unique(kmap$library[hit])
}

# Read SystemRequirements from an installed library DESCRIPTION when possible.
bw_get_sysreq_string <- function(pkg, lib) {
  if (!identical(attr(lib, "bw_type"), "library")) return(NA_character_)
  base <- attr(lib, "bw_input")
  if (is.null(base) || is.na(base) || !dir.exists(base)) return(NA_character_)
  descfile <- file.path(base, pkg, "DESCRIPTION")
  if (!file.exists(descfile)) return(NA_character_)
  val <- tryCatch(desc::desc(file = descfile)$get("SystemRequirements"),
                  error = function(e) NA_character_)
  if (length(val) == 0L || is.na(val)) NA_character_ else as.character(val)
}

bw_install_hint <- function(meta, platform) {
  if (nrow(meta) != 1L) {
    return(switch(platform,
      windows = "Bundled with the CRAN Windows binary.",
      macos = "Install via Homebrew.",
      "Install via your system package manager."
    ))
  }
  switch(platform,
    linux = sprintf("apt-get install -y %s   (or dnf install %s)", meta$apt, meta$dnf),
    macos = sprintf("brew install %s", meta$brew),
    windows = "Bundled with the CRAN Windows binary (no action needed)."
  )
}

bw_library_present <- function(libname, meta, platform, host_libraries) {
  if (!is.null(host_libraries)) {
    return(libname %in% host_libraries)
  }
  if (identical(platform, "linux") && nrow(meta) == 1L && !is.na(meta$pkgconfig)) {
    return(bw_probe_pkgconfig(meta$pkgconfig))
  }
  NA
}

bw_probe_pkgconfig <- function(module) {
  has_pc <- nzchar(Sys.which("pkg-config"))
  if (!has_pc) return(NA)
  ok <- tryCatch(
    suppressWarnings(system2("pkg-config", c("--exists", module),
                             stdout = FALSE, stderr = FALSE)) == 0L,
    error = function(e) NA
  )
  ok
}

new_bw_sysreqs <- function(rows, platform) {
  if (length(rows) == 0L) {
    tbl <- tibble::tibble(
      package = character(), system_requirement = character(),
      library = character(), platform = character(), present = logical(),
      status = character(), install_hint = character(), source = character()
    )
  } else {
    tbl <- tibble::tibble(
      package = vapply(rows, function(r) r$package, character(1)),
      system_requirement = vapply(rows, function(r) r$system_requirement, character(1)),
      library = vapply(rows, function(r) r$library, character(1)),
      platform = vapply(rows, function(r) r$platform, character(1)),
      present = vapply(rows, function(r) r$present, logical(1)),
      status = vapply(rows, function(r) r$status, character(1)),
      install_hint = vapply(rows, function(r) r$install_hint, character(1)),
      source = vapply(rows, function(r) r$source, character(1))
    )
  }
  class(tbl) <- c("bw_sysreqs", class(tibble::tibble()))
  attr(tbl, "bw_platform") <- platform
  tbl
}

#' @export
print.bw_sysreqs <- function(x, ...) {
  platform <- attr(x, "bw_platform") %||% "?"
  cli::cli_h1("buildwright system requirements ({platform})")
  if (nrow(x) == 0L) {
    cli::cli_alert_success("No external system requirements detected.")
    return(invisible(x))
  }
  n_missing <- sum(x$status == "missing")
  n_ok <- sum(x$status == "ok")
  n_unknown <- sum(x$status == "unknown")
  cli::cli_text("{nrow(x)} requirement{?s}: {n_ok} ok, {n_missing} missing, {n_unknown} unknown")
  miss <- x[x$status == "missing", , drop = FALSE]
  if (nrow(miss) > 0L) {
    cli::cli_h2("Likely-missing libraries")
    for (i in seq_len(nrow(miss))) {
      cli::cli_li("{.strong {miss$system_requirement[[i]]}} (for {.pkg {miss$package[[i]]}}): {miss$install_hint[[i]]}")
    }
  }
  invisible(x)
}
