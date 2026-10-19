# The Shiny module wrapping mixture_sld_create(). The server returns a reactive
# yielding a doe_design, which is the whole contract the app depends on.

# The factor count the panel opens on.
MIXTURE_SLD_DEFAULT_FACTORS <- 3L

# The number of levels the panel opens on.
MIXTURE_SLD_DEFAULT_LEVELS <- 2L

# Both counts are plain numeric inputs, with no dependent dropdown to fill:
# every whole number in range is valid for the other, so there is no list of
# choices for an observer to keep in step.
mixture_sld_ui <- function(id) {
  ns <- shiny::NS(id)
  limits <- mixture_sld_get_limits()
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = MIXTURE_SLD_DEFAULT_FACTORS,
      min = limits$num_factors[1],
      max = limits$num_factors[2]
    ),
    shiny::numericInput(
      ns("num_levels"),
      "Number of levels",
      value = MIXTURE_SLD_DEFAULT_LEVELS,
      min = limits$num_levels[1],
      max = limits$num_levels[2]
    ),
    shiny::numericInput(ns("replications"), "Replications", value = 1, min = 1),
    shiny::textAreaInput(
      ns("factor_names"),
      "Factor names",
      rows = 3,
      resize = "vertical",
      placeholder = "Oil, Water, Soap — blank for A, B, C"
    )
  )
}

# Is this a usable whole number within a range? Guards the reactive below,
# because moduleServer() runs eagerly at startup and the inputs are NULL until
# the UI has been rendered and bound.
mixture_sld_usable_count <- function(value, range) {
  isTRUE(
    length(value) == 1 &&
      !is.na(value) &&
      value == round(value) &&
      value >= range[1] &&
      value <= range[2]
  )
}

mixture_sld_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::reactive({
      limits <- mixture_sld_get_limits()
      shiny::validate(
        shiny::need(
          mixture_sld_usable_count(input$num_factors, limits$num_factors),
          sprintf(
            "Enter a whole number of factors from %d to %d.",
            limits$num_factors[1],
            limits$num_factors[2]
          )
        ),
        shiny::need(
          mixture_sld_usable_count(input$num_levels, limits$num_levels),
          sprintf(
            "Enter a whole number of levels from %d to %d.",
            limits$num_levels[1],
            limits$num_levels[2]
          )
        )
      )
      shiny::req(input$replications)
      num_factors <- as.integer(input$num_factors)

      design <- tryCatch(
        mixture_sld_create(
          num_factors = num_factors,
          num_levels = as.integer(input$num_levels),
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
