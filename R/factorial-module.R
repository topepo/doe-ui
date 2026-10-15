# The Shiny module wrapping factorial_design(). The server returns a reactive
# yielding a doe_design, which is the whole contract the app depends on.

factorial_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::numericInput(
      ns("k"),
      "Number of factors",
      value = 6,
      min = factorial_factor_range[1],
      max = factorial_factor_range[2]
    ),
    # Choices are filled in by the server, because they depend on k.
    shiny::selectInput(ns("runs"), "Number of runs", choices = NULL),
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
    shiny::uiOutput(ns("alternatives"))
  )
}

# Is this a factor count we can build a design from? Guards every reactive
# below, because moduleServer() runs eagerly at startup and input$k is NULL
# until the UI has been rendered and bound.
usable_factor_count <- function(k) {
  isTRUE(
    length(k) == 1 &&
      !is.na(k) &&
      k == round(k) &&
      k >= factorial_factor_range[1] &&
      k <= factorial_factor_range[2]
  )
}

factorial_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$k, {
      shiny::req(usable_factor_count(input$k))
      shiny::updateSelectInput(session, "runs", choices = run_choices(input$k))
    })

    # The run count the user picked, once it is one that suits the current
    # factor count. Just after k changes the old value is briefly still there.
    runs <- shiny::reactive({
      shiny::req(usable_factor_count(input$k), input$runs)
      value <- as.numeric(input$runs)
      shiny::req(value %in% run_choices(input$k))
      value
    })

    # How many blocks are possible depends on the run count.
    shiny::observeEvent(runs(), {
      shiny::updateSelectInput(session, "blocks", choices = block_choices(runs()))
    })

    entries <- shiny::reactive({
      catalog_entries(as.integer(input$k), runs())
    })

    # With fewer than two equivalent fractions there is nothing to choose, so
    # the input is not drawn at all.
    output$alternatives <- shiny::renderUI({
      found <- entries()
      if (length(found) < 2) {
        return(NULL)
      }
      shiny::radioButtons(
        session$ns("alternative"),
        "Choose a design",
        choiceNames = unname(vapply(
          names(found),
          function(name) describe_entry(name, found[[name]]),
          character(1)
        )),
        choiceValues = seq_along(found),
        width = "100%"
      )
    })

    shiny::reactive({
      shiny::validate(shiny::need(
        usable_factor_count(input$k),
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
      shiny::req(blocks %in% block_choices(runs()))
      k <- as.integer(input$k)

      design <- tryCatch(
        factorial_design(
          k = k,
          runs = runs(),
          # Removing the radio does not clear the input, so a stale choice can
          # outlive the design it belonged to. factorial_design() clamps it.
          alternative = as.integer(input$alternative %||% 1),
          center = as.integer(input$center),
          blocks = blocks,
          replications = as.integer(input$replications),
          factor_names = parse_factor_names(input$factor_names, k)
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
