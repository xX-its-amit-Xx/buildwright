# Diagnosis currently handed to the dashboard

Helper used by the bundled Shiny app to retrieve the
[`diagnose()`](https://ashenoy.github.io/buildwright/reference/diagnose.md)
result set by
[`run_dashboard()`](https://ashenoy.github.io/buildwright/reference/run_dashboard.md).
Falls back to the bundled example when run standalone.

## Usage

``` r
bw_dashboard_data()
```

## Value

A `bw_diagnosis` object.
