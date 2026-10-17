# The page. Built once, when the app starts.

app_ui <- function() {
  bslib::page_sidebar(
    title = "Experimental Designs",
    theme = bslib::bs_theme(bootswatch = "yeti"),
    fillable = FALSE,
    sidebar = bslib::sidebar(width = 300, picker_ui("picker")),
    bslib::card(
      bslib::card_header("Options"),
      # Filled by the selected design's module UI.
      shiny::uiOutput("options"),
      shiny::checkboxInput("randomize", "Randomize run order", value = FALSE)
    ),
    bslib::card(
      bslib::card_header("Design"),
      shiny::uiOutput("summary"),
      reactable::reactableOutput("table"),
      shiny::downloadButton("download", "Download CSV", class = "btn-sm mt-2")
    )
  )
}
