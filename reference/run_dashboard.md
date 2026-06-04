# Launch the interactive buildwright dashboard

Starts the bundled Shiny application (`inst/shiny/app.R`) showing the
dependency DAG, the conflict table, the system-requirement checklist,
and a "will this install?" simulator. The diagnosis is computed up front
and handed to the app through a session option, so the app starts
instantly and works offline.

## Usage

``` r
run_dashboard(
  x = NULL,
  platform = bw_host_platform(),
  host_libraries = NULL,
  launch.browser = interactive(),
  port = NULL,
  ...
)
```

## Arguments

- x:

  A `bw_library`, a `bw_diagnosis`, a path
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  accepts, or `NULL` to load the bundled example lockfile.

- platform, host_libraries:

  Forwarded to
  [`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md).

- launch.browser:

  Logical; open a browser. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

- port:

  Optional port for
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

The value returned by
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html),
invisibly. Called for its side effect of running the app.

## See also

[`report()`](https://ashenoy.github.io/buildwright/reference/report.md),
[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)

## Examples

``` r
if (FALSE) { # \dontrun{
run_dashboard(bw_example("conflicted.lock"))
} # }
```
