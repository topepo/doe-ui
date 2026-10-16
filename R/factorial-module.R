# The Shiny module wrapping factorial_create(). The server returns a reactive
# yielding a doe_design, which is the whole contract the app depends on.

factorial_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = 6,
      min = factorial_get_limits()$num_factors[1],
      max = factorial_get_limits()$num_factors[2]
    ),
    # Choices are filled in by the server, because they depend on num_factors.
    shiny::selectInput(ns("num_runs"), "Number of runs", choices = NULL),
    shiny::selectInput(ns("center"), "Center points per block", choices = 0:5, selected = 0),
    # Choices depend on the run count, so the server fills them in.
    shiny::selectInput(ns("blocks"), "Blocks", choices = NULL),
    shiny::numericInput(ns("replications"), "Replications", value = 1, min = 1),
    shiny::textInput(
      ns("factor_names"),
      "Factor names",
      placeholder = "Temp, Pressure, Time — blank for A, B, C"
    ),
    # Unlike the dropdown above, this input's existence is conditional, not
    # just its choices, so it stays a renderUI.
    shiny::uiOutput(ns("types"))
  )
}

# Is this a factor count we can build a design from? Guards every reactive
# below, because moduleServer() runs eagerly at startup and input$num_factors
# is NULL until the UI has been rendered and bound.
usable_factor_count <- function(num_factors) {
  limits <- factorial_get_limits()$num_factors
  isTRUE(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors) &&
      num_factors >= limits[1] &&
      num_factors <= limits[2]
  )
}

factorial_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$num_factors, {
      shiny::req(usable_factor_count(input$num_factors))
      shiny::updateSelectInput(
        session,
        "num_runs",
        choices = factorial_get_num_runs_choices(input$num_factors)
      )
    })

    # The run count the user picked, once it is one that suits the current
    # factor count. Just after num_factors changes the old value is briefly
    # still there.
    num_runs <- shiny::reactive({
      shiny::req(usable_factor_count(input$num_factors), input$num_runs)
      value <- as.numeric(input$num_runs)
      shiny::req(value %in% factorial_get_num_runs_choices(input$num_factors))
      value
    })

    # How many blocks are possible depends on the run count.
    shiny::observeEvent(num_runs(), {
      shiny::updateSelectInput(
        session,
        "blocks",
        choices = factorial_get_blocks_choices(num_runs())
      )
    })

    types <- shiny::reactive({
      factorial_get_types(as.integer(input$num_factors), num_runs())
    })

    # With fewer than two variants there is nothing to choose, so the input is
    # not drawn at all.
    output$types <- shiny::renderUI({
      available <- types()
      if (length(available) < 2) {
        return(NULL)
      }
      shiny::radioButtons(
        session$ns("type"),
        "Choose a design",
        choiceNames = names(available),
        choiceValues = unname(available),
        width = "100%"
      )
    })

    shiny::reactive({
      shiny::validate(shiny::need(
        usable_factor_count(input$num_factors),
        sprintf(
          "Enter a whole number of factors from %d to %d.",
          factorial_factor_range[1],
          factorial_factor_range[2]
        )
      ))
      shiny::req(input$center, input$blocks, input$replications)
      # The block choices are repopulated when the run count changes, so the
      # old value can briefly outlive the run count it belonged to.
      blocks <- as.numeric(input$blocks)
      shiny::req(blocks %in% factorial_get_blocks_choices(num_runs()))
      num_factors <- as.integer(input$num_factors)

      design <- tryCatch(
        factorial_create(
          num_factors = num_factors,
          num_runs = num_runs(),
          # Removing the radio does not clear the input, so a type can outlive
          # the size it belonged to. Falling back to the best available one is
          # a UI concern; factorial_create() itself rejects an unknown id.
          type = if (isTRUE(input$type %in% types())) input$type else NULL,
          center = as.integer(input$center),
          blocks = blocks,
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
