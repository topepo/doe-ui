# How the pieces update each other.
#
#   picker ---> selected() ---+--> output$options     (the design's own inputs)
#                             |
#                             v
#   design inputs --> current() --+--> output$summary
#   randomize ------------------^ +--> output$table
#                                 +--> output$download

app_server <- function(input, output, session) {
  registry <- design_registry()
  selected <- picker_server("picker")

  # Every module's server is started once, here. Their reactives stay lazy, so
  # an unselected design never runs its generator; only the one read by
  # current() below does.
  designs <- lapply(names(registry), function(id) registry[[id]]$server(id))
  names(designs) <- names(registry)

  output$options <- shiny::renderUI({
    shiny::req(selected())
    registry[[selected()]]$ui(selected())
  })

  current <- shiny::reactive({
    # req() is load-bearing, not decoration: `list[[NULL]]` is an error rather
    # than NULL, and selected() is briefly NULL while one family is cleared
    # and another set.
    shiny::req(selected())
    with_run_order(designs[[selected()]](), isTRUE(input$randomize))
  })

  output$summary <- shiny::renderUI({
    design <- current()
    shiny::tagList(
      shiny::p(shiny::strong(design$title)),
      lapply(design$notes, function(note) {
        shiny::p(class = "text-muted small", note)
      })
    )
  })

  output$table <- reactable::renderReactable({
    table <- display_table(current())
    factors <- setdiff(names(table), ORDER_COLUMNS)
    reactable::reactable(
      table,
      # Factor columns left-justified; the order columns keep the centred
      # default so they read as the row labels they are.
      columns = stats::setNames(
        lapply(factors, function(...) reactable::colDef(align = "left")),
        factors
      ),
      # reactable paginates at 10 rows by default, which would cut a 16-run
      # design in half. Scroll inside a fixed height instead.
      pagination = FALSE,
      height = 480,
      compact = TRUE,
      striped = TRUE,
      defaultColDef = reactable::colDef(align = "center", minWidth = 80)
    )
  })

  # The CSV carries the numeric table, not the "+1" text the page shows.
  output$download <- shiny::downloadHandler(
    filename = function() paste0(selected(), ".csv"),
    content = function(file) {
      utils::write.csv(current()$table, file, row.names = FALSE)
    }
  )
}
