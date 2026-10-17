# The Shiny modules for the two space-filling designs.
#
# They are separate because their options differ: the optimized design picks a
# type and then a run count that depends on it, while the random one takes any
# run count and has no type at all.

# ---- Optimized Latin hypercubes ---------------------------------------------------------------

# The factor count the panel opens on. Named, because the dependent dropdowns
# below are built from it and the two must not drift apart.
SPACEFILLING_OPT_DEFAULT_FACTORS <- 6L

spacefilling_opt_ui <- function(id,
                                num_factors = SPACEFILLING_OPT_DEFAULT_FACTORS) {
  ns <- shiny::NS(id)
  limits <- spacefilling_opt_get_limits()$num_factors
  # Populated here rather than left empty for the server to fill: the
  # observers only fire when their input *changes*, and returning to this
  # design rebuilds the UI with the same factor count, which Shiny's input
  # dedup suppresses.
  type_choices <- spacefilling_opt_get_types(num_factors)
  num_runs_choices <- spacefilling_opt_get_num_runs_choices(
    num_factors,
    type_choices[[1]]
  )
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = num_factors,
      min = limits[1],
      max = limits[2]
    ),
    shiny::selectInput(ns("type"), "Design", choices = type_choices),
    shiny::selectInput(
      ns("num_runs"),
      "Number of runs",
      choices = num_runs_choices
    ),
    # A text area rather than a single line: the list runs to one name per
    # factor, and the comma-separated form gets long.
    shiny::textAreaInput(
      ns("factor_names"),
      "Factor names",
      rows = 3,
      resize = "vertical",
      placeholder = "Temp, Pressure, Time — blank for A, B, C"
    )
  )
}

# Is this a factor count the sfd library covers?
usable_opt_factor_count <- function(num_factors) {
  limits <- spacefilling_opt_get_limits()$num_factors
  isTRUE(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors) &&
      num_factors >= limits[1] &&
      num_factors <= limits[2]
  )
}

spacefilling_opt_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$num_factors, {
      shiny::req(usable_opt_factor_count(input$num_factors))
      shiny::updateSelectInput(
        session,
        "type",
        choices = spacefilling_opt_get_types(input$num_factors)
      )
    })

    # The type the user picked, once it is one this factor count offers. Just
    # after the factor count changes the old value is briefly still there --
    # and it really does go stale here, since only uniform survives past ten
    # factors.
    type <- shiny::reactive({
      shiny::req(usable_opt_factor_count(input$num_factors), input$type)
      shiny::req(input$type %in% spacefilling_opt_get_types(input$num_factors))
      input$type
    })

    shiny::observeEvent(list(input$num_factors, type()), {
      shiny::updateSelectInput(
        session,
        "num_runs",
        choices = spacefilling_opt_get_num_runs_choices(
          input$num_factors,
          type()
        )
      )
    })

    shiny::reactive({
      shiny::validate(shiny::need(
        usable_opt_factor_count(input$num_factors),
        sprintf(
          "Enter a whole number of factors from %d to %d.",
          spacefilling_opt_get_limits()$num_factors[1],
          spacefilling_opt_get_limits()$num_factors[2]
        )
      ))
      shiny::req(input$num_runs)
      num_factors <- as.integer(input$num_factors)
      num_runs <- as.numeric(input$num_runs)
      shiny::req(
        num_runs %in%
          spacefilling_opt_get_num_runs_choices(num_factors, type())
      )

      design <- tryCatch(
        spacefilling_opt_create(
          num_factors = num_factors,
          num_runs = num_runs,
          type = type(),
          factor_names = rename_factors(input$factor_names, num_factors)
        ),
        error = function(e) e
      )
      if (inherits(design, "error")) {
        shiny::validate(shiny::need(FALSE, conditionMessage(design)))
      }
      design
    })
  })
}

# ---- Uniform -----------------------------------------------------------------

# The factor count the panel opens on.
SPACEFILLING_UNIF_DEFAULT_FACTORS <- 6L

spacefilling_unif_ui <- function(id,
                                 num_factors = SPACEFILLING_UNIF_DEFAULT_FACTORS) {
  ns <- shiny::NS(id)
  limits <- spacefilling_unif_get_limits()$num_factors
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = num_factors,
      min = limits[1],
      max = limits[2]
    ),
    # No type selector: there is one criterion here. Populated up front for
    # the same reason as everywhere else -- the observer below only fires on a
    # change, and reopening this panel is not one.
    shiny::selectInput(
      ns("num_runs"),
      "Number of runs",
      choices = spacefilling_unif_get_num_runs_choices(num_factors)
    ),
    # A text area rather than a single line: the list runs to one name per
    # factor, and the comma-separated form gets long.
    shiny::textAreaInput(
      ns("factor_names"),
      "Factor names",
      rows = 3,
      resize = "vertical",
      placeholder = "Temp, Pressure, Time \u2014 blank for A, B, C"
    )
  )
}

usable_unif_factor_count <- function(num_factors) {
  limits <- spacefilling_unif_get_limits()$num_factors
  isTRUE(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors) &&
      num_factors >= limits[1] &&
      num_factors <= limits[2]
  )
}

spacefilling_unif_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$num_factors, {
      shiny::req(usable_unif_factor_count(input$num_factors))
      shiny::updateSelectInput(
        session,
        "num_runs",
        choices = spacefilling_unif_get_num_runs_choices(input$num_factors)
      )
    })

    shiny::reactive({
      shiny::validate(shiny::need(
        usable_unif_factor_count(input$num_factors),
        sprintf(
          "Enter a whole number of factors from %d to %d.",
          spacefilling_unif_get_limits()$num_factors[1],
          spacefilling_unif_get_limits()$num_factors[2]
        )
      ))
      shiny::req(input$num_runs)
      num_factors <- as.integer(input$num_factors)
      num_runs <- as.numeric(input$num_runs)
      shiny::req(
        num_runs %in% spacefilling_unif_get_num_runs_choices(num_factors)
      )

      design <- tryCatch(
        spacefilling_unif_create(
          num_factors = num_factors,
          num_runs = num_runs,
          factor_names = rename_factors(input$factor_names, num_factors)
        ),
        error = function(e) e
      )
      if (inherits(design, "error")) {
        shiny::validate(shiny::need(FALSE, conditionMessage(design)))
      }
      design
    })
  })
}

# ---- Random ------------------------------------------------------------------

spacefilling_rand_ui <- function(id) {
  ns <- shiny::NS(id)
  limits <- spacefilling_rand_get_limits()
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = 6,
      min = limits$num_factors[1],
      max = limits$num_factors[2]
    ),
    # A plain number, not a dropdown: any run count in range is buildable, so
    # there is no list to choose from.
    shiny::numericInput(
      ns("num_runs"),
      "Number of runs",
      value = 60,
      min = limits$num_runs[1],
      max = limits$num_runs[2]
    ),
    shiny::numericInput(ns("seed"), "Random seed", value = 1, min = 1),
    # A text area rather than a single line: the list runs to one name per
    # factor, and the comma-separated form gets long.
    shiny::textAreaInput(
      ns("factor_names"),
      "Factor names",
      rows = 3,
      resize = "vertical",
      placeholder = "Temp, Pressure, Time — blank for A, B, C"
    )
  )
}

spacefilling_rand_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::reactive({
      shiny::req(input$num_factors, input$num_runs, input$seed)
      num_factors <- as.integer(input$num_factors)

      design <- tryCatch(
        spacefilling_rand_create(
          num_factors = num_factors,
          num_runs = as.integer(input$num_runs),
          seed = as.integer(input$seed),
          factor_names = rename_factors(input$factor_names, num_factors)
        ),
        error = function(e) e
      )
      if (inherits(design, "error")) {
        shiny::validate(shiny::need(FALSE, conditionMessage(design)))
      }
      design
    })
  })
}
