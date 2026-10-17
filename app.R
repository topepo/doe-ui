# Design picker — a Shiny app for generating statistical experimental designs.
#
# Pick a design in the sidebar, set its options, and download the run table.
#
# Run with shiny::runApp() from this directory. Everything in R/ is sourced
# automatically before this file, so there is nothing to source by hand:
#
#   R/design.R            the design object and shared helpers
#   R/{name}-design.R     the generator, pure R
#   R/{name}-module.R     its Shiny module
#   R/registry.R          the registry and the sidebar picker
#   R/ui.R, R/server.R    the page and how it updates

# What the app itself needs. Each design names its own packages through
# {design}_get_packages(), so adding a design that wraps a new package does not
# mean editing a list here.

require(shiny)
require(bslib)
require(reactable)
require(tibble)

shiny::shinyApp(app_ui(), app_server)
