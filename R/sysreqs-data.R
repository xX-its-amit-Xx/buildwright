# Curated system-requirements knowledge base.
#
# This mirrors the kind of mapping that pak / the RStudio Package Manager
# sysreqs database maintain, kept deliberately small, honest and offline. When
# `pak` is available, check_sysreqs(use_pak = TRUE) can defer to it for an
# authoritative, platform-specific answer; this table is the fallback.

#' The buildwright system-requirements knowledge base
#'
#' `bw_sysreq_library_db()` lists the canonical system libraries buildwright
#' knows about and how to install each on Debian/Ubuntu (`apt`), Fedora (`dnf`)
#' and macOS (`brew`). `bw_sysreq_package_map()` maps R packages to those
#' libraries. Both are the offline fallback consulted by [check_sysreqs()];
#' platform teams can read them to audit the mapping or copy and extend it for
#' their own internal packages.
#'
#' @return A [tibble][tibble::tibble]. For `bw_sysreq_library_db()`: one row per
#'   system library with `library`, `label`, `apt`, `dnf`, `brew`, `pkgconfig`.
#'   For `bw_sysreq_package_map()`: one row per (package, library) association.
#' @export
#' @examples
#' head(bw_sysreq_library_db())
#' head(bw_sysreq_package_map())
bw_sysreq_library_db <- function() {
  # nolint start: line_length_linter.
  tibble::tribble(
    ~library,      ~label,                ~apt,                              ~dnf,                          ~brew,                ~pkgconfig,
    "libcurl",     "cURL",                "libcurl4-openssl-dev",            "libcurl-devel",               "curl",               "libcurl",
    "openssl",     "OpenSSL",             "libssl-dev",                      "openssl-devel",               "openssl",            "openssl",
    "libxml2",     "libxml2",             "libxml2-dev",                     "libxml2-devel",               "libxml2",            "libxml-2.0",
    "libxslt",     "libxslt",             "libxslt1-dev",                    "libxslt-devel",               "libxslt",            "libxslt",
    "gdal",        "GDAL",                "libgdal-dev",                     "gdal-devel",                  "gdal",               "gdal",
    "geos",        "GEOS",                "libgeos-dev",                     "geos-devel",                  "geos",               "geos",
    "proj",        "PROJ",                "libproj-dev",                     "proj-devel",                  "proj",               "proj",
    "udunits",     "udunits2",            "libudunits2-dev",                 "udunits2-devel",              "udunits",            "udunits",
    "freetype",    "FreeType",            "libfreetype6-dev",                "freetype-devel",              "freetype",           "freetype2",
    "harfbuzz",    "HarfBuzz",            "libharfbuzz-dev",                 "harfbuzz-devel",              "harfbuzz",           "harfbuzz",
    "fribidi",     "FriBidi",             "libfribidi-dev",                  "fribidi-devel",               "fribidi",            "fribidi",
    "fontconfig",  "Fontconfig",          "libfontconfig1-dev",              "fontconfig-devel",            "fontconfig",         "fontconfig",
    "libpng",      "libpng",              "libpng-dev",                      "libpng-devel",                "libpng",             "libpng",
    "cairo",       "Cairo",               "libcairo2-dev",                   "cairo-devel",                 "cairo",              "cairo",
    "imagemagick", "ImageMagick",         "libmagick++-dev",                 "ImageMagick-c++-devel",       "imagemagick@6",      "Magick++",
    "poppler",     "Poppler",             "libpoppler-cpp-dev",              "poppler-cpp-devel",           "poppler",            "poppler-cpp",
    "java",        "Java JDK",            "default-jdk",                     "java-11-openjdk-devel",       "openjdk",            NA,
    "v8",          "V8 engine",           "libv8-dev",                       "v8-devel",                    "v8",                 "v8",
    "libpq",       "PostgreSQL client",   "libpq-dev",                       "libpq-devel",                 "libpq",              "libpq",
    "mariadb",     "MariaDB client",      "libmariadb-dev",                  "mariadb-connector-c-devel",   "mariadb-connector-c", "libmariadb",
    "unixodbc",    "unixODBC",            "unixodbc-dev",                    "unixODBC-devel",              "unixodbc",           "odbc",
    "libgit2",     "libgit2",             "libgit2-dev",                     "libgit2-devel",               "libgit2",            "libgit2",
    "libsodium",   "libsodium",           "libsodium-dev",                   "libsodium-devel",             "libsodium",          "libsodium",
    "gsl",         "GNU GSL",             "libgsl-dev",                      "gsl-devel",                   "gsl",                "gsl",
    "glpk",        "GLPK",                "libglpk-dev",                     "glpk-devel",                  "glpk",               "glpk",
    "nlopt",       "NLopt",               "libnlopt-dev",                    "NLopt-devel",                 "nlopt",              "nlopt",
    "hdf5",        "HDF5",                "libhdf5-dev",                     "hdf5-devel",                  "hdf5",               "hdf5",
    "tesseract",   "Tesseract OCR",       "libtesseract-dev",               "tesseract-devel",             "tesseract",          "tesseract",
    "protobuf",    "Protocol Buffers",    "libprotobuf-dev",                "protobuf-devel",              "protobuf",           "protobuf",
    "ffmpeg",      "FFmpeg",              "libavfilter-dev",                 "ffmpeg-devel",                "ffmpeg",             "libavfilter"
  )
  # nolint end
}

#' @rdname bw_sysreq_library_db
#' @export
bw_sysreq_package_map <- function() {
  tibble::tribble(
    ~package,        ~library,
    "curl",          "libcurl",
    "httr",          "libcurl",
    "httr2",         "libcurl",
    "RCurl",         "libcurl",
    "openssl",       "openssl",
    "askpass",       "openssl",
    "xml2",          "libxml2",
    "xslt",          "libxslt",
    "sf",            "gdal",
    "sf",            "geos",
    "sf",            "proj",
    "terra",         "gdal",
    "terra",         "geos",
    "terra",         "proj",
    "rgdal",         "gdal",
    "rgdal",         "proj",
    "rgeos",         "geos",
    "units",         "udunits",
    "ragg",          "freetype",
    "ragg",          "libpng",
    "textshaping",   "harfbuzz",
    "textshaping",   "fribidi",
    "systemfonts",   "fontconfig",
    "svglite",       "libpng",
    "magick",        "imagemagick",
    "pdftools",      "poppler",
    "qpdf",          "poppler",
    "rJava",         "java",
    "V8",            "v8",
    "RPostgres",     "libpq",
    "RPostgreSQL",   "libpq",
    "RMariaDB",      "mariadb",
    "RMySQL",        "mariadb",
    "odbc",          "unixodbc",
    "RODBC",         "unixodbc",
    "gert",          "libgit2",
    "git2r",         "libgit2",
    "sodium",        "libsodium",
    "gsl",           "gsl",
    "RcppGSL",       "gsl",
    "igraph",        "glpk",
    "nloptr",        "nlopt",
    "hdf5r",         "hdf5",
    "tesseract",     "tesseract",
    "protolite",     "protobuf",
    "av",            "ffmpeg",
    "Cairo",         "cairo"
  )
}

#' Regex keywords found in SystemRequirements text -> canonical library
#' @noRd
bw_sysreq_keyword_map <- function() {
  tibble::tribble(
    ~pattern,                         ~library,
    "libcurl|curl",                   "libcurl",
    "openssl|libssl",                 "openssl",
    "libxml2|libxml-2|libxml",        "libxml2",
    "libxslt|xslt",                   "libxslt",
    "gdal",                           "gdal",
    "geos",                           "geos",
    "proj[^a-z]|proj$|libproj",       "proj",
    "udunits",                        "udunits",
    "freetype",                       "freetype",
    "harfbuzz",                       "harfbuzz",
    "fribidi",                        "fribidi",
    "fontconfig",                     "fontconfig",
    "libpng",                         "libpng",
    "cairo",                          "cairo",
    "imagemagick|magick\\+\\+",       "imagemagick",
    "poppler",                        "poppler",
    "\\bjava\\b|jdk|jre",             "java",
    "\\bv8\\b|libv8",                 "v8",
    "postgres|libpq",                 "libpq",
    "mariadb|mysql",                  "mariadb",
    "unixodbc|\\bodbc\\b",            "unixodbc",
    "libgit2",                        "libgit2",
    "libsodium|sodium",              "libsodium",
    "\\bgsl\\b|gnu scientific",       "gsl",
    "\\bglpk\\b",                     "glpk",
    "\\bnlopt\\b",                    "nlopt",
    "\\bhdf5\\b",                     "hdf5",
    "tesseract|leptonica",            "tesseract",
    "protobuf",                       "protobuf",
    "ffmpeg|libav",                   "ffmpeg"
  )
}
