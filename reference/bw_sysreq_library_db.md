# The buildwright system-requirements knowledge base

`bw_sysreq_library_db()` lists the canonical system libraries
buildwright knows about and how to install each on Debian/Ubuntu
(`apt`), Fedora (`dnf`) and macOS (`brew`). `bw_sysreq_package_map()`
maps R packages to those libraries. Both are the offline fallback
consulted by
[`check_sysreqs()`](https://ashenoy.github.io/buildwright/reference/check_sysreqs.md);
platform teams can read them to audit the mapping or copy and extend it
for their own internal packages.

## Usage

``` r
bw_sysreq_library_db()

bw_sysreq_package_map()
```

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html). For
`bw_sysreq_library_db()`: one row per system library with `library`,
`label`, `apt`, `dnf`, `brew`, `pkgconfig`. For
`bw_sysreq_package_map()`: one row per (package, library) association.

## Examples

``` r
head(bw_sysreq_library_db())
#> # A tibble: 6 × 6
#>   library label   apt                  dnf           brew    pkgconfig 
#>   <chr>   <chr>   <chr>                <chr>         <chr>   <chr>     
#> 1 libcurl cURL    libcurl4-openssl-dev libcurl-devel curl    libcurl   
#> 2 openssl OpenSSL libssl-dev           openssl-devel openssl openssl   
#> 3 libxml2 libxml2 libxml2-dev          libxml2-devel libxml2 libxml-2.0
#> 4 libxslt libxslt libxslt1-dev         libxslt-devel libxslt libxslt   
#> 5 gdal    GDAL    libgdal-dev          gdal-devel    gdal    gdal      
#> 6 geos    GEOS    libgeos-dev          geos-devel    geos    geos      
head(bw_sysreq_package_map())
#> # A tibble: 6 × 2
#>   package library
#>   <chr>   <chr>  
#> 1 curl    libcurl
#> 2 httr    libcurl
#> 3 httr2   libcurl
#> 4 RCurl   libcurl
#> 5 openssl openssl
#> 6 askpass openssl
```
