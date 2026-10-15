# Design picker (the Shiny app) -----------------------------------------------
#
# A Shiny app for generating experimental designs. Pick a design in the side
# list, set its options, and edit or download the resulting design table.
#
# This file is the app: the pipeline that turns options into a sheet, the page
# (UI), and the server. What is specific to each design (generators, option
# inputs, and the registry) is in designs.R, which this file loads.
#
# Run with: shiny::runApp("design_picker.R")
# Both files must be in the same folder.
#
# Contents (search for the section banners):
#   1. Packages and constants   loads designs.R
#   2. Design pipeline          options -> design -> sheet -> CSV
#   3. Styles                   the app's CSS
#   4. UI components            make_*(), the pieces of the page
#   5. Server                   how the pieces update each other
#   6. App                      puts the UI and the server together
#
# Conventions:
#   - Every function and object has a roxygen-style comment (#') above it that
#     says what it is, what its arguments mean, and what it returns.
#   - Calls to non-base packages are always written package::function().
#   - Functions use braces, even when short.
#
# To add a design, edit designs.R only (see the header of its section 6).

# 1. Packages and constants ----------------------------------------------------

# The design information lives in its own file, which must be in the same folder
# as this one (Shiny runs the app from its own folder). Sourcing it defines what
# the app needs from it:
#   design_catalog     the designs as a table (the side list)
#   design_generators  each design's generator function, by design name
#   setup_panels       each design's option-inputs function, by design name
#   setup_servers      each design's option server, by design name
#   check_packages()   used just below
# `local = TRUE` defines them in this file's own environment rather than in the
# global environment.
source("designs.R", local = TRUE)

#' Packages the app needs, apart from the ones the designs need.
#'
#' Checked when the app starts, by `check_packages()` (from designs.R). Calls to
#' these packages are always written as `package::function()`, so none of them
#' is attached with `library()`.
APP_PACKAGES <- c("bslib", "excelR", "htmltools", "shiny")

# Fail early, before anything below needs one of the packages.
check_packages(APP_PACKAGES)

#' The design shown when the app opens.
#'
#' Must be one of the names in `design_registry`.
DEFAULT_DESIGN <- "Two-level factorial"

# The design shown first must exist; otherwise the app would open on nothing.
stopifnot(
  "DEFAULT_DESIGN must be a registered design." = DEFAULT_DESIGN %in%
    design_catalog$name
)

#' Names of the two order columns at the front of every design table.
#'
#' `with_run_order()` adds them; the sheet code uses these names to tell them
#' apart from a design's own columns.
ORDER_COLUMNS <- c("Standard order", "Run order")

#' Use a default when a value is `NULL`.
#'
#' `x %||% y` is `x`, unless `x` is `NULL`, in which case it is `y`. (Base R has
#' this operator from version 4.4; it is defined here so older versions work.)
#'
#' @param x A value, possibly `NULL`.
#' @param y The value to use when `x` is `NULL`.
#' @return `x` or `y`.
`%||%` <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

# 2. Design pipeline -----------------------------------------------------------
#
# The steps between the option inputs and the sheet, as plain functions that do
# not depend on how the page is laid out:
#
#   collect_design_options()  read the options a generator takes from the inputs
#   build_design()            run the generator and add the order columns
#   make_sheet_data(), make_sheet_columns()  format the table for the sheet
#   merge_sheet_titles(), make_download_table()  turn what the user did in the
#                                            sheet into the CSV

#' Turn numeric-looking text into a number.
#'
#' Dropdowns report their value as text (`"16"`); generators want numbers.
#' Anything that is not a single number, such as `"rotatable"`, is left alone.
#'
#' @param value An input value.
#' @return A number if `value` is a single number or numeric text, otherwise
#'   `value` unchanged.
coerce_option <- function(value) {
  number <- suppressWarnings(as.numeric(value))
  if (length(number) == 1 && !is.na(number)) {
    number
  } else {
    value
  }
}

#' The current values of the inputs a generator takes.
#'
#' For each argument of `generator`, reads the input whose id is `prefix` plus
#' the argument name (so `k` reads `"ccd_k"`). Reading only these inputs keeps
#' the design from being rebuilt when an unrelated input appears, such as the
#' sheet's own. Inputs that do not exist yet are left out, so an argument with a
#' default falls back to it.
#'
#' @param input The session's `input`.
#' @param prefix The design's input-id prefix.
#' @param generator The design's generator function.
#' @return A named list of values, named by generator argument.
collect_design_options <- function(input, prefix, generator) {
  arguments <- names(formals(generator))
  values <- lapply(arguments, function(argument) {
    input[[paste0(prefix, argument)]]
  })
  names(values) <- arguments
  lapply(Filter(Negate(is.null), values), coerce_option)
}

#' Is a value empty or `NA`?
#'
#' An empty number box reports `NA`.
#'
#' @param value A single input value.
#' @return `TRUE` or `FALSE`.
is_blank <- function(value) {
  length(value) == 0 || (length(value) == 1 && is.na(value))
}

#' Names of the arguments a function has no default for.
#'
#' @param fun A function.
#' @return A character vector of argument names, possibly empty.
required_arguments <- function(fun) {
  arguments <- formals(fun)
  needs_value <- vapply(
    names(arguments),
    function(name) {
      identical(arguments[[name]], quote(expr = ))
    },
    logical(1)
  )
  names(arguments)[needs_value]
}

#' Add the two order columns to a design.
#'
#' Rows stay in standard (canonical) order. Randomizing permutes the run order,
#' the order in which the runs are performed, and never the rows.
#'
#' @param design A design object from `new_design()`.
#' @param randomize `TRUE` to use a random run order, `FALSE` to use the
#'   standard order.
#' @return `design`, with `Standard order` and `Run order` columns added to the
#'   front of its table.
with_run_order <- function(design, randomize) {
  n <- nrow(design$table)
  run_order <- if (randomize) {
    sample(n)
  } else {
    seq_len(n)
  }
  design$table <- cbind(
    `Standard order` = seq_len(n),
    `Run order` = run_order,
    design$table
  )
  design
}

#' Run a design's generator and add the order columns.
#'
#' Waits quietly while the option inputs are still loading, and shows the
#' generator's own message in place of the table if the options are not valid.
#' It uses `shiny::req()` and `shiny::validate()`, so call it inside a reactive.
#'
#' @param name Design name, a name in `design_registry`.
#' @param options Named list from `collect_design_options()`.
#' @param randomize `TRUE` to randomize the run order.
#' @return A design object whose table has the order columns.
build_design <- function(name, options, randomize) {
  generator <- design_generators[[name]]
  shiny::req(all(required_arguments(generator) %in% names(options)))
  shiny::req(!any(vapply(options, is_blank, logical(1))))
  design <- tryCatch(do.call(generator, options), error = function(error) {
    error
  })
  failed <- inherits(design, "error")
  shiny::validate(shiny::need(
    !failed,
    if (failed) conditionMessage(design) else ""
  ))
  with_run_order(design, randomize)
}

#' Format coded levels with signs: +1, 0, -1.
#'
#' @param x A numeric vector.
#' @return A character vector, with `"0"` for zero and a sign on everything
#'   else, such as `"+1.682"`.
format_signed <- function(x) {
  ifelse(x == 0, "0", sprintf("%+.4g", x))
}

#' The design table as the sheet shows it.
#'
#' Coded designs show signed text (`"+1"`); other designs show numbers rounded
#' to four decimals, and labels stay as text. The order columns are untouched.
#'
#' @param design A design object whose table has the order columns.
#' @return A data frame ready for the sheet.
make_sheet_data <- function(design) {
  table <- design$table
  for (column in setdiff(names(table), ORDER_COLUMNS)) {
    values <- table[[column]]
    table[[column]] <- if (!is.numeric(values)) {
      as.character(values)
    } else if (design$coded) {
      format_signed(values)
    } else {
      round(values, 4)
    }
  }
  table
}

#' Column definitions for the sheet.
#'
#' @param data The data frame from `make_sheet_data()`.
#' @return A data frame with `title`, `type` (`"numeric"` or `"text"`), `width`
#'   and `align` for each column, in the form excelR expects.
make_sheet_columns <- function(data) {
  is_number <- vapply(data, is.numeric, logical(1))
  data.frame(
    title = names(data),
    type = ifelse(is_number, "numeric", "text"),
    width = ifelse(names(data) == "Standard order", 130, 100),
    align = "center",
    stringsAsFactors = FALSE
  )
}

#' Combine the sheet's reported column titles with earlier renames.
#'
#' excelR reports the original titles with only the renamed column changed, so
#' reading it directly would forget earlier renames. This keeps them and takes
#' each newly changed title. (Renaming a column back to its original title is
#' not noticed.)
#'
#' @param previous Titles kept so far, or `NULL`.
#' @param reported Titles as reported by the sheet.
#' @param original Titles the sheet was drawn with.
#' @return A character vector of titles.
merge_sheet_titles <- function(previous, reported, original) {
  reported <- unlist(reported)
  titles <- previous %||% original
  if (length(reported) != length(original)) {
    return(titles)
  }
  changed <- reported != original
  titles[changed] <- reported[changed]
  titles
}

#' The table to write to the CSV.
#'
#' It holds what is in the sheet: edited cells, renamed titles, and sorting.
#' Signed text such as `"+1"` is turned back into numbers where possible.
#'
#' @param edited The edited table from the sheet, or `NULL` if nothing has been
#'   edited yet.
#' @param design The current design object, used when `edited` is `NULL`.
#' @param titles Column titles from `merge_sheet_titles()`, or `NULL`.
#' @return A data frame.
make_download_table <- function(edited, design, titles) {
  table <- if (is.null(edited)) {
    design$table
  } else {
    edited[] <- lapply(edited, function(column) {
      numbers <- suppressWarnings(as.numeric(as.character(column)))
      if (anyNA(numbers)) column else numbers
    })
    edited
  }
  if (length(titles) == ncol(table)) {
    names(table) <- titles
  }
  table
}

# 3. Styles --------------------------------------------------------------------

#' The app's stylesheet.
#'
#' - `.design-link`: the links in the side list. `.active` marks the chosen
#'   design.
#' - `.options-rows`: the option rows. Each Shiny input becomes a row with the
#'   label on the left (`--label-width` wide) and the control on the right.
#'   Radio lists use the full remaining width and align to the top.
#' - `.option-checkbox`: lines the randomize checkbox up with the controls.
#'
#' It must be wrapped in `shiny::HTML()` when added to the page; otherwise the
#' `>` characters are escaped and the rules stop working.
APP_CSS <- "
.design-link { display: block; padding: .3rem .6rem; border-radius: .25rem;
               color: inherit; text-decoration: none; }
.design-link:hover { background: rgba(0, 0, 0, .06); }
.design-link.active { background: var(--bs-primary); color: #fff; }

.options-rows { --label-width: 12rem; --row-gap: 1rem; }
.options-rows .shiny-input-container {
  display: flex; align-items: center; gap: var(--row-gap);
  width: 100%; max-width: 40rem; margin-bottom: .5rem;
}
.options-rows .shiny-input-container > label {
  flex: 0 0 var(--label-width); margin: 0;
}
.options-rows .shiny-input-container > :not(label) {
  flex: 1 1 auto; min-width: 0; max-width: 18rem;
}
.options-rows .shiny-input-radiogroup { align-items: flex-start; }
.options-rows .shiny-input-radiogroup > .shiny-options-group { max-width: none; }
.options-rows .option-checkbox {
  padding-left: calc(var(--label-width) + var(--row-gap));
}
"

# 4. UI components -------------------------------------------------------------
#
# Everything the user sees is built by a small make_*() function. Each returns
# plain Shiny UI (HTML tags) and never touches the server, so each can be read,
# tested, and changed on its own.
#
# Some pieces are built once when the app starts; others are filled in later by
# the server. The quoted ids are the contract between the two: a
# `uiOutput("options_ui")` in this section is filled by
# `output$options_ui <- ...` in make_app_server().
#
#   Built once (make_app_ui)           Filled in by the server
#   ------------------------           ------------------------------------
#   page, sidebar, headings            "design_nav_ui"   the side list
#   hint text, download button         "options_ui"      the option rows
#                                      "design_summary"  title and notes
#                                      "design_sheet"    the editable table
#
# Layout of the page:
#
#   +----------------+-----------------------------------------------+
#   | side list      |  Options        (make_options_section)        |
#   | (design_nav_ui)|    one row per option                         |
#   |                |  Design         (make_design_section)         |
#   |                |    title, notes, sheet, hint, download button |
#   +----------------+-----------------------------------------------+

#' The input id of the link that picks a design.
#'
#' Every design in the side list is an `actionLink`, and Shiny needs a unique
#' input id for each. The id is built from the design's name so it is stable;
#' the server builds the same id to listen for clicks.
#'
#' @param name Design name.
#' @return A string such as `"pick_two_level_factorial"`.
design_link_id <- function(name) {
  paste0("pick_", gsub("[^a-z0-9]+", "_", tolower(name)))
}

#' The side list: one collapsible panel per family, one link per design.
#'
#' This is rendered by the server (as `design_nav_ui`) rather than built once,
#' because the highlight has to follow the selection. The list is redrawn each
#' time a design is chosen, which is why the family of the chosen design is the
#' one left open.
#'
#' @param catalog Data frame with `name` and `family` columns, one row per
#'   design.
#' @param selected Name of the design to highlight.
#' @return A bslib accordion.
make_design_nav <- function(
  catalog = design_catalog,
  selected = DEFAULT_DESIGN
) {
  # One accordion panel per family. `lapply` returns a list of panels.
  panels <- lapply(unique(catalog$family), function(family) {
    # One link per design in this family. A click on a link raises its input
    # (input$pick_...), which make_app_server() watches. The "design-link" class
    # gives it the look in APP_CSS; "active" marks the chosen design.
    links <- lapply(catalog$name[catalog$family == family], function(name) {
      shiny::actionLink(
        design_link_id(name),
        name,
        class = paste("design-link", if (identical(name, selected)) "active")
      )
    })
    bslib::accordion_panel(title = family, value = family, links)
  })

  # accordion() takes panels as separate arguments, so do.call() spreads the
  # list `panels` into the call.
  #   id        - lets bslib track which panel is open
  #   open      - the family of the selected design
  #   multiple  - FALSE means opening one family closes the others
  do.call(
    bslib::accordion,
    c(
      list(
        id = "design_family",
        open = catalog$family[catalog$name == selected],
        multiple = FALSE
      ),
      panels
    )
  )
}

#' Lay the option inputs out as rows (label on the left, control on the right).
#'
#' The randomize checkbox belongs to every design, so it is added here instead
#' of in each `{design}_list()`. It is always the last row. The row look comes
#' from the `options-rows` and `option-checkbox` rules in `APP_CSS`.
#'
#' @param elements The list returned by a design's `{design}_list()`.
#' @param randomize The checkbox's current value, so it survives a redraw for
#'   another design. `NULL` the first time.
#' @return A `div` of rows.
make_options_panel <- function(elements, randomize = FALSE) {
  randomize_input <- shiny::div(
    class = "option-checkbox",
    shiny::checkboxInput(
      "randomize",
      "Randomize run order",
      # `randomize` is NULL the first time the panel is drawn; isTRUE() turns
      # that into FALSE.
      value = isTRUE(randomize)
    )
  )
  shiny::div(class = "options-rows", elements, randomize_input)
}

#' The "Options" part of the page.
#'
#' A heading and a placeholder that the server fills with the option rows for
#' the selected design (`output$options_ui`).
#'
#' @return A `section` tag.
make_options_section <- function() {
  shiny::tags$section(
    class = "mb-4",
    shiny::h5("Options"),
    shiny::uiOutput("options_ui")
  )
}

#' The "Design" part of the page.
#'
#' From top to bottom:
#' - `design_summary`: the design's title and notes (server).
#' - `design_sheet`: the editable table (server).
#' - A line of hint text (built once).
#' - `design_download`: the CSV button (built once; the server supplies the
#'   file through `output$design_download`).
#'
#' @return A `section` tag.
make_design_section <- function() {
  shiny::tags$section(
    shiny::h5("Design"),
    shiny::uiOutput("design_summary"),
    # height = "auto" lets the sheet size itself (see tableHeight in
    # make_design_sheet()).
    excelR::excelOutput("design_sheet", height = "auto"),
    shiny::p(
      class = "text-muted small mt-2 mb-0",
      "Right-click a column title to rename or sort it. Double-click a cell to edit it."
    ),
    shiny::downloadButton(
      "design_download",
      "Download CSV",
      class = "btn-sm mt-2"
    )
  )
}

#' The main (right-hand) part of the page: Options above Design, with no boxes.
#'
#' @return A tag list.
make_main_page <- function() {
  shiny::tagList(make_options_section(), make_design_section())
}

#' The text above the sheet.
#'
#' The design's title in bold, then each note in small grey text (for example
#' the defining relation of a fractional factorial).
#'
#' @param design A design object.
#' @return A tag list.
make_design_summary <- function(design) {
  shiny::tagList(
    shiny::p(shiny::strong(design$title)),
    lapply(design$notes, function(note) {
      shiny::p(class = "text-muted small", note)
    })
  )
}

#' The editable table (an excelR spreadsheet) for a design.
#'
#' The arguments after `columns` switch features on or off:
#' - `columnSorting`, `columnResize`: sort and resize columns from the header.
#' - `allowRenameColumn`: lets the user rename a column title.
#' - `rowDrag = FALSE`: rows cannot be dragged around.
#' - `allowInsert...` and `allowDelete...`: the shape of the design is fixed, so
#'   rows and columns cannot be added or removed.
#' - `tableOverflow`, `tableHeight`: scroll inside a 480px-high table so long
#'   designs do not push the page down.
#' - `showToolbar = FALSE`: hide the toolbar, which is not needed.
#' - `autoWidth = FALSE`: use the widths from `columns`.
#'
#' @param design A design object whose table has the order columns.
#' @return An excelR widget.
make_design_sheet <- function(design) {
  data <- make_sheet_data(design)
  excelR::excelTable(
    data = data,
    columns = make_sheet_columns(data),
    columnSorting = TRUE,
    columnResize = TRUE,
    rowDrag = FALSE,
    allowInsertRow = FALSE,
    allowInsertColumn = FALSE,
    allowDeleteRow = FALSE,
    allowDeleteColumn = FALSE,
    allowRenameColumn = TRUE,
    tableOverflow = TRUE,
    tableHeight = "480px",
    showToolbar = FALSE,
    autoWidth = FALSE
  )
}

#' The whole page. This runs once, when the app starts.
#'
#' - `title`: the bar across the top.
#' - `theme`: a Bootswatch theme ("flatly") on Bootstrap 5.
#' - `fillable = FALSE`: the page scrolls normally instead of stretching its
#'   content to fit the window.
#' - The head holds the app's CSS (`APP_CSS`), wrapped in `shiny::HTML()` so the
#'   characters in it, such as `>`, are not escaped.
#' - `sidebar`: the side list. `design_nav_ui` is filled by the server.
#' - Last, the main content: Options and Design.
#'
#' @return A bslib page.
make_app_ui <- function() {
  bslib::page_sidebar(
    title = "Design picker",
    theme = bslib::bs_theme(bootswatch = "flatly"),
    fillable = FALSE,
    shiny::tags$head(shiny::tags$style(shiny::HTML(APP_CSS))),
    sidebar = bslib::sidebar(width = 300, shiny::uiOutput("design_nav_ui")),
    make_main_page()
  )
}

# 5. Server --------------------------------------------------------------------
#
# The server connects the UI above to the design pipeline (section 2). It is a
# graph of reactive pieces: when something upstream changes, everything
# downstream of it updates, and nothing else does.
#
#   link clicks ----> selected() ----> output$design_nav_ui   (highlight)
#                        |
#                        +-----------> output$options_ui      (option rows)
#                        |
#                        v
#   option inputs --> current_design() --+--> output$design_summary
#   randomize ------^                    +--> output$design_sheet
#                                        +--> resets edited() and titles()
#
#   sheet edits --> edited(), titles() --> output$design_download
#
# Reading the code in that order (selection, options, design, sheet, download)
# follows the graph from top to bottom.

#' Build the server function.
#'
#' Shiny calls the returned function once for every browser session, handing it
#' that session's `input`, `output`, and `session`. Everything created inside
#' belongs to that one visitor. See the diagram above for how the pieces update
#' each other.
#'
#' @return A function of `input`, `output`, and `session`.
make_app_server <- function() {
  function(input, output, session) {
    # ---- 1. Which design is selected ---------------------------------------
    # A reactiveVal is a single value that other code can read and that
    # re-runs the code reading it when it changes. It starts at the default.
    selected <- shiny::reactiveVal(DEFAULT_DESIGN)

    # Listen to the link for every design. When one is clicked, store its name.
    # local() gives each observer its own copy of `chosen`; without it, all the
    # observers would share the loop variable and every click would pick the
    # last design. A link that has never been clicked counts as "nothing
    # happened", so redrawing the list does not trigger a selection.
    for (name in design_catalog$name) {
      local({
        chosen <- name
        shiny::observeEvent(input[[design_link_id(chosen)]], {
          selected(chosen)
        })
      })
    }

    # The side list depends on `selected`, so it is redrawn with the new
    # highlight whenever the selection changes.
    output$design_nav_ui <- shiny::renderUI({
      make_design_nav(selected = selected())
    })

    # ---- 2. Options --------------------------------------------------------
    # Some designs need server logic of their own (for example, the factorial's
    # list of run counts depends on its number of factors). Each registers its
    # own outputs here, once, at startup. See section 5 of designs.R.
    for (register in setup_servers) {
      register(input, output, session)
    }

    # The option rows for the selected design. `setup_panels[[...]]` looks up
    # that design's {design}_list() function, and the () calls it.
    # isolate() reads the randomize checkbox without making this block depend
    # on it: the rows are redrawn when the design changes, not every time the
    # box is ticked. (It is read at all so the tick survives a design change.)
    output$options_ui <- shiny::renderUI({
      elements <- setup_panels[[selected()]]()
      make_options_panel(elements, randomize = shiny::isolate(input$randomize))
    })

    # ---- 3. The design -----------------------------------------------------
    # The design for the current options. This re-runs whenever the selected
    # design, one of ITS options, or the randomize checkbox changes.
    #
    # collect_design_options() reads only the inputs the generator takes, which
    # is why unrelated inputs (the sheet's own, for example) cannot trigger a
    # rebuild. build_design() runs the generator; if the inputs are not ready
    # yet it waits quietly, and if the options are invalid it shows the
    # generator's message in place of the table.
    current_design <- shiny::reactive({
      prefix <- design_catalog$prefix[design_catalog$name == selected()]
      options <- collect_design_options(
        input,
        prefix,
        design_generators[[selected()]]
      )
      build_design(selected(), options, isTRUE(input$randomize))
    })

    # The title and notes above the sheet.
    output$design_summary <- shiny::renderUI({
      make_design_summary(current_design())
    })

    # The sheet itself. It is redrawn whenever current_design() changes, which
    # also throws away the user's edits (see the next section).
    output$design_sheet <- excelR::renderExcel({
      make_design_sheet(current_design())
    })

    # ---- 4. Edits made in the sheet ----------------------------------------
    # The sheet only tells Shiny about itself when the user changes something,
    # so the server keeps the latest edited copy of the table (`edited`) and the
    # column titles (`titles`). NULL means "no edits yet".
    edited <- shiny::reactiveVal(NULL)
    titles <- shiny::reactiveVal(NULL)

    # A new design means a fresh sheet, so forget the old edits.
    shiny::observeEvent(current_design(), {
      edited(NULL)
      titles(NULL)
    })

    # input$design_sheet changes each time the user edits, sorts, or renames.
    # excel_to_R() turns the reported sheet into a data frame. The titles are
    # tracked separately because the widget reports the original titles with
    # only the renamed column changed, which would forget earlier renames;
    # merge_sheet_titles() keeps them.
    shiny::observeEvent(input$design_sheet, {
      edited(excelR::excel_to_R(input$design_sheet))
      titles(merge_sheet_titles(
        titles(),
        input$design_sheet$colHeaders,
        names(current_design()$table)
      ))
    })

    # ---- 5. Download -------------------------------------------------------
    # The button in make_design_section() is filled by this handler.
    #   filename - the design's name, such as "two_level_factorial.csv"
    #   content  - writes the file when the button is clicked: the design as the
    #              user left it (edits, renames, and sorting), or the design as
    #              generated if nothing was edited
    output$design_download <- shiny::downloadHandler(
      filename = function() {
        paste0(gsub("[^a-z0-9]+", "_", tolower(selected())), ".csv")
      },
      content = function(file) {
        table <- make_download_table(edited(), current_design(), titles())
        utils::write.csv(table, file, row.names = FALSE)
      }
    )
  }
}

# 6. App -----------------------------------------------------------------------
#
# shinyApp() ties the UI and the server together. When this file is run with
# shiny::runApp("design_picker.R"), Shiny evaluates the file and uses the app
# object returned by its last expression, which is this one.
#   make_app_ui()      builds the page once, when the app starts
#   make_app_server()  returns the function Shiny runs for each visitor

shiny::shinyApp(make_app_ui(), make_app_server())
