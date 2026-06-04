# Render a buildwright report or launch the dashboard

Two output formats share one entry point:

- `format = "quarto"` renders the parameterised report shipped at
  `inst/report/buildwright_report.qmd` to a self-contained HTML file. If
  the Quarto CLI is not available, buildwright transparently falls back
  to an equivalent R Markdown template (`buildwright_report.Rmd`)
  rendered with
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html),
  so you still get an HTML artifact.

- `format = "shiny"` launches the interactive dashboard via
  [`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md).

## Usage

``` r
report(
  x,
  format = c("quarto", "shiny"),
  output = NULL,
  platform = bw_host_platform(),
  host_libraries = NULL,
  open = interactive(),
  quiet = TRUE,
  ...
)
```

## Arguments

- x:

  A `bw_library`, a `bw_diagnosis`, or a path
  [`scan_library()`](https://ashenoy.github.io/buildwright/reference/scan_library.md)
  accepts.

- format:

  `"quarto"` (static HTML report) or `"shiny"` (dashboard).

- output:

  For the quarto/HTML report, the output file path. Defaults to a temp
  file. Ignored for the shiny format.

- platform, host_libraries:

  Forwarded to the diagnosis.

- open:

  Logical; open the rendered report / launch the browser when
  interactive.

- quiet:

  Logical; suppress rendering chatter.

- ...:

  Passed to
  [`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md)
  for the shiny format.

## Value

For `"quarto"`, the path to the rendered HTML (invisibly). For
`"shiny"`, the result of
[`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md).

## See also

[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md),
[`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Static HTML report from a lockfile
report(bw_example("conflicted.lock"), format = "quarto",
       output = "buildwright_report.html")

# Interactive dashboard
report(bw_example("conflicted.lock"), format = "shiny")
} # }
```
