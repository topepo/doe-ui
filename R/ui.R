# The page. Built once, when the app starts.

# The sidebar picker reads as a plain list of design names, not a set of radio
# buttons. The control underneath stays a radio group, which is what gives one
# selection per family for free, without a reactiveVal and an observer per
# design to track which name was last clicked.
#
# The input is moved out of sight rather than removed with display:none, so it
# keeps keyboard focus and stays readable to a screen reader; :focus-visible
# puts the ring back, on the label.
#
# Written as Sass rather than plain CSS so the colours follow the theme: swap
# the bootswatch preset and the highlight follows it.
#
# When editing these rules, hard-reload the browser. bslib serves the compiled
# theme at bootstrap-<version>/bootstrap.min.css, named for the Bootstrap
# version rather than content-hashed, so the URL does not change when the Sass
# does and a cached copy will be served instead.
PICKER_RULES <- "
.design-picker .radio { margin: 0; }

.design-picker label {
  display: block;
  width: 100%;
  margin: 0;
  font-weight: 400;
  cursor: pointer;
}

.design-picker input[type='radio'] {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: 0;
  opacity: 0;
}

.design-picker label > span {
  display: block;
  padding: .3rem .6rem;
  border-radius: .25rem;
}

.design-picker label:hover input:not(:checked) + span {
  background: rgba($black, .06);
}

.design-picker input:checked + span {
  background: $primary;
  color: color-contrast($primary);
}

.design-picker input:focus-visible + span {
  outline: 2px solid $primary;
  outline-offset: 2px;
}
"

app_theme <- function() {
  bslib::bs_add_rules(bslib::bs_theme(bootswatch = "yeti"), PICKER_RULES)
}

app_ui <- function() {
  bslib::page_sidebar(
    title = "Experimental Designs",
    theme = app_theme(),
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
