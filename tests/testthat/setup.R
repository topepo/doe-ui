# A package would declare this in DESCRIPTION as Config/testthat/edition: 3.
# This is not a package, so the 3rd edition — and with it expect_snapshot() —
# has to be asked for here.
testthat::local_edition(3, .env = globalenv())

# Shiny sources R/ automatically when it runs the app, but testthat does not.
# loadSupport() is the same function Shiny itself calls, so the tests see
# exactly what the app sees.
shiny::loadSupport(
  file.path("..", ".."),
  renv = globalenv(),
  globalrenv = NULL
)
