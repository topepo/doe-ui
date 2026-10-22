# The Shiny module wrapping rsm_ccd_create(). The server returns a reactive
# yielding a doe_design, which is the whole contract the app depends on.

# The factor count the panel opens on.
RSM_CCD_DEFAULT_FACTORS <- 3L

# Center points per block the panel opens on: rsm's own default for n0.
RSM_CCD_DEFAULT_CENTER <- 4L

# The value the axial-distance dropdown submits for a number typed by hand. Not
# one of rsm's ids, so it never reaches rsm_ccd_create() as a string.
RSM_CCD_CUSTOM_ALPHA <- "custom"

# No dependent dropdowns: the axial-distance choices do not depend on any other
# input, so the select is complete as built and needs no observer.
rsm_ccd_ui <- function(id) {
  ns <- shiny::NS(id)
  limits <- rsm_ccd_get_limits()
  shiny::tagList(
    shiny::numericInput(
      ns("num_factors"),
      "Number of factors",
      value = RSM_CCD_DEFAULT_FACTORS,
      min = limits$num_factors[1],
      max = limits$num_factors[2]
    ),
    shiny::numericInput(
      ns("center"),
      "Center points per block",
      value = RSM_CCD_DEFAULT_CENTER,
      min = limits$center[1],
      max = limits$center[2]
    ),
    shiny::selectInput(
      ns("alpha"),
      "Axial distance",
      choices = c(rsm_ccd_get_types(), "Custom value" = RSM_CCD_CUSTOM_ALPHA)
    ),
    shiny::conditionalPanel(
      sprintf("input.alpha == '%s'", RSM_CCD_CUSTOM_ALPHA),
      ns = ns,
      shiny::numericInput(
        ns("alpha_value"),
        "Axial distance (coded units)",
        value = 1.5,
        min = 0.01,
        step = 0.1
      )
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

# Is this a usable whole number within a range? Guards the reactive below,
# because moduleServer() runs eagerly at startup and the inputs are NULL until
# the UI has been rendered and bound.
rsm_usable_count <- function(value, range) {
  isTRUE(
    length(value) == 1 &&
      !is.na(value) &&
      value == round(value) &&
      value >= range[1] &&
      value <= range[2]
  )
}

rsm_ccd_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::reactive({
      limits <- rsm_ccd_get_limits()
      shiny::validate(
        shiny::need(
          rsm_usable_count(input$num_factors, limits$num_factors),
          sprintf(
            "Enter a whole number of factors from %d to %d.",
            limits$num_factors[1],
            limits$num_factors[2]
          )
        ),
        shiny::need(
          rsm_usable_count(input$center, limits$center),
          sprintf(
            "Enter a whole number of center points from %d to %d.",
            limits$center[1],
            limits$center[2]
          )
        )
      )
      shiny::req(input$alpha, input$replications)
      alpha <- if (identical(input$alpha, RSM_CCD_CUSTOM_ALPHA)) {
        shiny::req(input$alpha_value)
        as.numeric(input$alpha_value)
      } else {
        input$alpha
      }
      num_factors <- as.integer(input$num_factors)

      design <- tryCatch(
        rsm_ccd_create(
          num_factors = num_factors,
          center = as.integer(input$center),
          alpha = alpha,
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
