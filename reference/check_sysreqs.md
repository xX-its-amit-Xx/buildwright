# Map packages to system requirements and flag likely-missing libraries

Translates each R package into the external system libraries it needs
(the `SystemRequirements` you only discover when a source install
explodes with "cannot find -lxml2"). Mappings come from three places, in
order: the package's own `SystemRequirements` field (for
installed-library scans), an optional authoritative lookup via `pak`,
and a curated offline table
([`bw_sysreq_package_map()`](https://ashenoy.github.io/buildwright/reference/bw_sysreq_library_db.md)).

## Usage

``` r
check_sysreqs(
  x,
  platform = bw_host_platform(),
  host_libraries = NULL,
  use_pak = FALSE
)
```

## Arguments

- x:

  A `bw_library` or a path
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  accepts.

- platform:

  One of `"linux"`, `"macos"`, `"windows"`; defaults to the host.
  Controls which install hint is emitted.

- host_libraries:

  Optional character vector of canonical library tokens known to be
  present on the target host (e.g. `c("libcurl", "openssl")`).

- use_pak:

  Logical; if `TRUE` and `pak` is installed, query
  [`pak::pkg_sysreqs()`](https://pak.r-lib.org/reference/pkg_sysreqs.html)
  for an authoritative mapping (requires network).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) of class
`bw_sysreqs` with one row per (package, system library): `package`,
`system_requirement`, `library`, `platform`, `present` (logical or
`NA`), `status` (`"ok"`/`"missing"`/ `"unknown"`), `install_hint`, and
`source`. Packages with no known system requirements are omitted.

## Details

Whether a library is *present* is resolved as follows: if
`host_libraries` is supplied, presence is membership in that set
(deterministic, ideal for CI and tests); otherwise on Linux buildwright
probes `pkg-config`, and on other platforms presence is reported as
unknown (`NA`) because CRAN binaries bundle their libraries.

## See also

[`simulate_install()`](https://ashenoy.github.io/buildwright/reference/simulate_install.md),
[`bw_sysreq_package_map()`](https://ashenoy.github.io/buildwright/reference/bw_sysreq_library_db.md)

## Examples

``` r
# Pretend only libcurl is installed on the target host:
check_sysreqs(bw_example("missing-sysreq.lock"),
              platform = "linux", host_libraries = "libcurl")
#> 
#> ── buildwright system requirements (linux) ─────────────────────────────────────
#> 12 requirements: 1 ok, 11 missing, 0 unknown
#> 
#> ── Likely-missing libraries ──
#> 
#> • PostgreSQL client (for RPostgres): apt-get install -y libpq-dev (or dnf
#> install libpq-devel)
#> • V8 engine (for V8): apt-get install -y libv8-dev (or dnf install v8-devel)
#> • OpenSSL (for askpass): apt-get install -y libssl-dev (or dnf install
#> openssl-devel)
#> • ImageMagick (for magick): apt-get install -y libmagick++-dev (or dnf install
#> ImageMagick-c++-devel)
#> • OpenSSL (for openssl): apt-get install -y libssl-dev (or dnf install
#> openssl-devel)
#> • Java JDK (for rJava): apt-get install -y default-jdk (or dnf install
#> java-11-openjdk-devel)
#> • GDAL (for sf): apt-get install -y libgdal-dev (or dnf install gdal-devel)
#> • GEOS (for sf): apt-get install -y libgeos-dev (or dnf install geos-devel)
#> • PROJ (for sf): apt-get install -y libproj-dev (or dnf install proj-devel)
#> • udunits2 (for units): apt-get install -y libudunits2-dev (or dnf install
#> udunits2-devel)
#> • libxml2 (for xml2): apt-get install -y libxml2-dev (or dnf install
#> libxml2-devel)
```
