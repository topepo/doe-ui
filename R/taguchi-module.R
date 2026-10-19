# The Shiny module wrapping taguchi_create(). The server returns a reactive
# yielding a doe_design, which is the whole contract the app depends on.

# The factor count the panel opens on. Named, because the run dropdown below is
# built from it and the two must not drift apart. Seven is what the L8, the
# smallest array offered for it, is saturated by.
TAGUCHI_DEFAULT_FACTORS <- 7L

taguchi_ui <- function(id, num_factors = TAGUCHI_DEFAULT_FACTORS) {
  ns <- shiny::NS(id)
  # Populated here rather than left empty for the server to fill. The observer
  # below only fires when num_factors *changes*, and returning to a design
  # rebuilds this UI with the same value, which Shiny's input dedup suppresses
  # -- so the dropdown would come back empty and stay empty until the factor
  # count was nudged.
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = num_factors,
      min = taguchi_get_limits()$num_factors[1],
      max = taguchi_get_limits()$num_factors[2]
    ),
    shiny::selectInput(
      ns("num_runs"),
      "Number of runs",
      choices = taguchi_get_num_runs_choices(num_factors)
    ),
    shiny::numericInput(ns("replications"), "Replications", value = 1, min = 1),
    shiny::textAreaInput(
      ns("factor_names"),
      "Factor names",
      rows = 3,
      resize = "vertical",
      placeholder = "Temp, Pressure, Time — blank for A, B, C"
    )
  )
}

# Is this a factor count we can build a design from? Guards every reactive
# below, because moduleServer() runs eagerly at startup and input$num_factors
# is NULL until the UI has been rendered and bound.
taguchi_usable_factor_count <- function(num_factors) {
  limits <- taguchi_get_limits()$num_factors
  isTRUE(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors) &&
      num_factors >= limits[1] &&
      num_factors <= limits[2]
  )
}

taguchi_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$num_factors, {
      shiny::req(taguchi_usable_factor_count(input$num_factors))
      shiny::updateSelectInput(
        session,
        "num_runs",
        choices = taguchi_get_num_runs_choices(input$num_factors)
      )
    })

    shiny::reactive({
      limits <- taguchi_get_limits()$num_factors
      shiny::validate(shiny::need(
        taguchi_usable_factor_count(input$num_factors),
        sprintf(
          "Enter a whole number of factors from %d to %d.",
          limits[1],
          limits[2]
        )
      ))
      shiny::req(input$num_runs, input$replications)
      num_factors <- as.integer(input$num_factors)
      # The run count the user picked, once it is one that suits the current
      # factor count. Just after num_factors changes the old value is briefly
      # still there.
      num_runs <- as.numeric(input$num_runs)
      shiny::req(num_runs %in% taguchi_get_num_runs_choices(num_factors))

      design <- tryCatch(
        taguchi_create(
          num_factors = num_factors,
          num_runs = num_runs,
          replications = as.integer(input$replications),
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
