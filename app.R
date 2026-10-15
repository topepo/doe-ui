# Design picker — a Shiny app for generating statistical experimental designs.
#
# Pick a design in the sidebar, set its options, and download the run table.
#
# Run with shiny::runApp() from this directory. Everything in R/ is sourced
# automatically before this file, so there is nothing to source by hand:
#
#   R/design.R            the design object and shared helpers
#   R/factorial-design.R  the generator, pure R
#   R/factorial-module.R  its Shiny module
#   R/registry.R          the registry and the sidebar picker
#   R/ui.R, R/server.R    the page and how it updates

REQUIRED_PACKAGES <- c("bslib", "DoE.base", "FrF2", "reactable", "shiny")

local({
  missing <- REQUIRED_PACKAGES[
    !vapply(REQUIRED_PACKAGES, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0) {
    stop(
      "Install the missing packages first: install.packages(c(",
      paste0("\"", missing, "\"", collapse = ", "),
      "))",
      call. = FALSE
    )
  }
})

shiny::shinyApp(app_ui(), app_server)
