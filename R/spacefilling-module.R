# Scaffolding for space-filling designs.
#
# The registry entry, the family heading and the module contract are in place;
# the computation is not. When it is added, it goes in R/spacefilling-design.R
# as a pure function returning new_design(), and this server calls it — the
# same split as R/factorial-design.R and R/factorial-module.R.
#
# Nothing here decides which package generates the design, or what options it
# takes. Those arrive together with the generator.

spacefilling_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::p(
      class = "text-muted small mb-0",
      "Options appear here once this design is implemented."
    )
  )
}

spacefilling_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # The contract is a reactive yielding a doe_design. Until there is one,
    # this pauses with a message, which the app shows in place of the table.
    shiny::reactive({
      shiny::validate(shiny::need(
        FALSE,
        "Space-filling designs are not implemented yet."
      ))
    })
  })
}
