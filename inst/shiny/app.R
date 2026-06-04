# buildwright interactive dashboard (single-file Shiny app).
#
# Launched by buildwright::run_dashboard(), which computes a bw_diagnosis up
# front and hands it to this app through options(buildwright.dashboard_data=).
# The app starts from that diagnosis and can re-run diagnose() on demand. It is
# fully offline: every value comes from the verified buildwright API and the
# bundled example data; no network calls and no file writes happen here.

# Local default-on-empty helper (mirrors rlang's %||%, kept self-contained so
# the app file has no hidden dependency on package internals).
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

# ---- initial diagnosis ------------------------------------------------------
initial <- buildwright::bw_dashboard_data()

# Canonical system-library tokens, used as the host_libraries choices.
host_lib_choices <- sort(unique(buildwright::bw_sysreq_library_db()$library))

# Default lockfile path to seed the textInput (the input the diagnosis came
# from). May be NA/empty for non-path inputs; fall back to a blank box.
initial_input <- initial$meta$input
if (is.null(initial_input) || length(initial_input) == 0L || is.na(initial_input)) {
  initial_input <- ""
}
initial_platform <- initial$meta$platform %||% "linux"

# ---- small helpers ----------------------------------------------------------

# Flatten a list column of character vectors into comma-joined strings so it can
# be shown by DT (list columns cannot be rendered directly).
bw_join_listcol <- function(col, collapse = ", ") {
  if (is.null(col) || length(col) == 0L) return(character())
  vapply(
    col,
    function(v) paste(as.character(v), collapse = collapse),
    character(1)
  )
}

# An empty DT placeholder table carrying a single friendly message.
bw_empty_table <- function(message) {
  DT::datatable(
    data.frame(status = message, check.names = FALSE),
    rownames = FALSE,
    colnames = "",
    options = list(dom = "t", ordering = FALSE),
    class = "table table-striped"
  )
}

# A compact DT for the dashboard panels.
bw_dt <- function(df) {
  DT::datatable(
    df,
    rownames = FALSE,
    selection = "none",
    class = "table table-striped table-hover",
    options = list(
      pageLength = 15,
      scrollX = TRUE,
      autoWidth = FALSE,
      dom = "ftip"
    )
  )
}

# Colour a status-like column (ok/missing/unknown or ok/warn/fail/blocked).
bw_style_status <- function(dt, column) {
  DT::formatStyle(
    dt,
    column,
    color = DT::styleEqual(
      c("ok", "missing", "unknown", "warn", "fail", "blocked"),
      c("#0a7d2c", "#b30000", "#8a6d00", "#8a6d00", "#b30000", "#b30000")
    ),
    fontWeight = "bold"
  )
}

# ---- UI ---------------------------------------------------------------------

bw_sidebar <- bslib::sidebar(
  title = "Inputs",
  width = 320,
  shiny::textInput(
    "lockfile",
    "renv.lock path",
    value = initial_input,
    placeholder = "path/to/renv.lock"
  ),
  shiny::selectInput(
    "platform",
    "Target platform",
    choices = c("linux", "macos", "windows"),
    selected = initial_platform
  ),
  shiny::selectizeInput(
    "host_libraries",
    "Host system libraries present",
    choices = host_lib_choices,
    selected = character(),
    multiple = TRUE,
    options = list(placeholder = "none selected (all treated as missing)")
  ),
  shiny::actionButton(
    "rerun",
    "Re-run diagnosis",
    class = "btn-primary",
    icon = shiny::icon("rotate")
  ),
  shiny::helpText(
    "Leave the path unchanged to re-use the lockfile this dashboard was",
    "launched with. Selecting host libraries marks them as present."
  )
)

ui <- bslib::page_navbar(
  title = "buildwright",
  theme = bslib::bs_theme(version = 5, primary = "#1f77b4"),
  sidebar = bw_sidebar,

  # 1. Dependency graph -------------------------------------------------------
  bslib::nav_panel(
    title = "Dependency graph",
    bslib::layout_columns(
      fill = FALSE,
      bslib::value_box(
        title = "Packages",
        value = shiny::textOutput("vb_packages"),
        showcase = shiny::icon("cubes"),
        theme = "primary"
      ),
      bslib::value_box(
        title = "Dependency edges",
        value = shiny::textOutput("vb_edges"),
        showcase = shiny::icon("diagram-project"),
        theme = "secondary"
      ),
      bslib::value_box(
        title = "Cycles",
        value = shiny::textOutput("vb_cycles"),
        showcase = shiny::icon("arrows-spin"),
        theme = "warning"
      ),
      bslib::value_box(
        title = "Missing / referenced",
        value = shiny::textOutput("vb_missing"),
        showcase = shiny::icon("triangle-exclamation"),
        theme = "danger"
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Dependency DAG (edge A -> B: A requires B)"),
      visNetwork::visNetworkOutput("depgraph", height = "640px")
    )
  ),

  # 2. Conflicts --------------------------------------------------------------
  bslib::nav_panel(
    title = "Conflicts",
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Unsatisfiable or drifting constraints"),
      DT::DTOutput("conflicts")
    )
  ),

  # 3. System requirements ----------------------------------------------------
  bslib::nav_panel(
    title = "System requirements",
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(shiny::textOutput("sysreq_header", inline = TRUE)),
      DT::DTOutput("sysreqs")
    )
  ),

  # 4. Will this install? -----------------------------------------------------
  bslib::nav_panel(
    title = "Will this install?",
    bslib::layout_columns(
      fill = FALSE,
      col_widths = c(6, 3, 3),
      # Rendered server-side so its colour (success/danger) tracks feasibility.
      shiny::uiOutput("feasible_box"),
      bslib::value_box(
        title = "Predicted failures",
        value = shiny::textOutput("vb_nfail"),
        showcase = shiny::icon("circle-xmark"),
        theme = "danger"
      ),
      bslib::value_box(
        title = "Warnings",
        value = shiny::textOutput("vb_nwarn"),
        showcase = shiny::icon("circle-exclamation"),
        theme = "warning"
      )
    ),
    bslib::card(
      bslib::card_header("Predicted failures (fail / blocked)"),
      DT::DTOutput("failures")
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Full install order (dependency-first)"),
      DT::DTOutput("steps")
    )
  )
)

# ---- server -----------------------------------------------------------------

server <- function(input, output, session) {

  # Reactive diagnosis: defaults to the handed-in diagnosis; recomputed on the
  # button press. diagnose() is wrapped so any failure surfaces as a
  # notification and keeps the previous good diagnosis on screen.
  diag_rv <- shiny::reactiveVal(initial)

  shiny::observeEvent(input$rerun, {
    path <- trimws(input$lockfile %||% "")
    host <- input$host_libraries
    if (is.null(host) || length(host) == 0L) host <- character()

    target <- if (nzchar(path)) path else (initial$meta$input %||% NULL)
    if (is.null(target) || (length(target) == 1L && is.na(target))) {
      shiny::showNotification(
        "No lockfile path given and the initial input was not a path.",
        type = "warning"
      )
      return(invisible(NULL))
    }

    new_diag <- tryCatch(
      buildwright::diagnose(
        target,
        platform = input$platform,
        host_libraries = host
      ),
      error = function(e) {
        shiny::showNotification(
          paste("diagnose() failed:", conditionMessage(e)),
          type = "error",
          duration = 8
        )
        NULL
      }
    )
    if (!is.null(new_diag)) {
      diag_rv(new_diag)
      shiny::showNotification("Diagnosis updated.", type = "message")
    }
  })

  # ---- Panel 1: dependency graph -------------------------------------------

  graph_data <- shiny::reactive({
    buildwright::bw_graph_data(diag_rv()$graph)
  })

  output$vb_packages <- shiny::renderText({
    as.character(diag_rv()$meta$n_packages %||% nrow(graph_data()$nodes))
  })

  output$vb_edges <- shiny::renderText({
    as.character(nrow(graph_data()$edges))
  })

  output$vb_cycles <- shiny::renderText({
    as.character(length(buildwright::bw_cycles(diag_rv()$graph)))
  })

  output$vb_missing <- shiny::renderText({
    nodes <- graph_data()$nodes
    present <- nodes$present
    n_missing <- sum(!present, na.rm = TRUE)
    sprintf("%d / %d", n_missing, nrow(nodes))
  })

  output$depgraph <- visNetwork::renderVisNetwork({
    gd <- graph_data()
    nodes <- gd$nodes
    edges <- gd$edges
    # Robust to an empty graph: hand visNetwork an empty-but-typed nodes frame.
    if (nrow(nodes) == 0L) {
      nodes <- data.frame(
        id = character(),
        label = character(),
        group = character(),
        color = character(),
        title = character(),
        stringsAsFactors = FALSE
      )
    }
    visNetwork::visNetwork(nodes, edges) |>
      visNetwork::visEdges(arrows = "to") |>
      visNetwork::visOptions(
        highlightNearest = TRUE,
        nodesIdSelection = TRUE
      ) |>
      visNetwork::visLegend() |>
      visNetwork::visPhysics(stabilization = TRUE)
  })

  # ---- Panel 2: conflicts ---------------------------------------------------

  output$conflicts <- DT::renderDT({
    conf <- diag_rv()$conflicts
    if (is.null(conf) || nrow(conf) == 0L) {
      return(bw_empty_table("No dependency conflicts detected."))
    }
    df <- data.frame(
      package = conf$package,
      type = conf$type,
      required_by = bw_join_listcol(conf$required_by),
      constraints = conf$constraints,
      installed_version = conf$installed_version,
      satisfiable = conf$satisfiable,
      detail = conf$detail,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    dt <- bw_dt(df)
    DT::formatStyle(
      dt,
      "type",
      color = DT::styleEqual(
        c("missing", "version_conflict", "version_drift", "cycle"),
        c("#b30000", "#b30000", "#8a6d00", "#8a4d9e")
      ),
      fontWeight = "bold"
    )
  })

  # ---- Panel 3: system requirements ----------------------------------------

  output$sysreq_header <- shiny::renderText({
    plat <- diag_rv()$meta$platform %||% "?"
    sprintf("System requirements (platform: %s)", plat)
  })

  output$sysreqs <- DT::renderDT({
    sr <- diag_rv()$sysreqs
    if (is.null(sr) || nrow(sr) == 0L) {
      return(bw_empty_table("No external system requirements detected."))
    }
    df <- data.frame(
      package = sr$package,
      system_requirement = sr$system_requirement,
      library = sr$library,
      status = sr$status,
      install_hint = sr$install_hint,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    bw_dt(df) |> bw_style_status("status")
  })

  # ---- Panel 4: will this install? -----------------------------------------

  plan <- shiny::reactive(diag_rv()$plan)

  # Prominent feasibility banner: green value box when feasible, red otherwise.
  output$feasible_box <- shiny::renderUI({
    p <- plan()
    feasible <- isTRUE(p$feasible)
    n_fail <- p$n_fail %||% 0L
    n_warn <- p$n_warn %||% 0L
    if (feasible) {
      headline <- "Feasible"
      sub <- sprintf("All packages can install (%s warning%s)",
                     n_warn, if (identical(n_warn, 1L)) "" else "s")
      box_theme <- "success"
      ic <- shiny::icon("circle-check")
    } else {
      headline <- "Not feasible"
      sub <- sprintf("%s package%s predicted to fail/block, %s warning%s",
                     n_fail, if (identical(n_fail, 1L)) "" else "s",
                     n_warn, if (identical(n_warn, 1L)) "" else "s")
      box_theme <- "danger"
      ic <- shiny::icon("circle-xmark")
    }
    bslib::value_box(
      title = "Predicted outcome",
      value = headline,
      showcase = ic,
      theme = box_theme,
      shiny::p(sub)
    )
  })

  output$vb_nfail <- shiny::renderText({
    as.character(plan()$n_fail %||% 0L)
  })

  output$vb_nwarn <- shiny::renderText({
    as.character(plan()$n_warn %||% 0L)
  })

  output$failures <- DT::renderDT({
    pf <- plan()$predicted_failures
    if (is.null(pf) || nrow(pf) == 0L) {
      return(bw_empty_table("No predicted failures: every package can install."))
    }
    df <- as.data.frame(pf, stringsAsFactors = FALSE)
    bw_dt(df) |> bw_style_status("predicted_status")
  })

  output$steps <- DT::renderDT({
    steps <- plan()$steps
    if (is.null(steps) || nrow(steps) == 0L) {
      return(bw_empty_table("No install steps (nothing to install)."))
    }
    df <- as.data.frame(steps, stringsAsFactors = FALSE)
    bw_dt(df) |> bw_style_status("predicted_status")
  })
}

shiny::shinyApp(ui, server)
