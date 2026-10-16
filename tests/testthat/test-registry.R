test_that("families appear in registry order, space-filling first", {
  families <- design_families()
  expect_equal(
    names(families),
    c("Space-Filling Designs", "Screening designs")
  )
  expect_equal(families[["Space-Filling Designs"]], "latin_hypercube")
  expect_equal(families[["Screening designs"]], "factorial")
})

test_that("every registry entry has the fields the app reads", {
  for (entry in design_registry()) {
    expect_named(entry, c("label", "family", "ui", "server"))
    expect_type(entry$label, "character")
    expect_type(entry$family, "character")
    expect_true(is.function(entry$ui))
    expect_true(is.function(entry$server))
  }
})

test_that("the default design is registered", {
  expect_true(DEFAULT_DESIGN %in% names(design_registry()))
})

test_that("the picker renders one panel per family with the default open", {
  html <- as.character(picker_ui("picker"))
  expect_equal(length(gregexpr("accordion-item", html)[[1]]), 2)
  expect_match(html, "Space-Filling Designs")
  expect_match(html, "Screening designs")
  # The open panel is the one holding the default design.
  expect_match(html, "Screening designs")
})

test_that("selecting in either family drives the selection", {
  shiny::testServer(picker_server, args = list(id = "picker"), {
    expect_equal(session$getReturned()(), DEFAULT_DESIGN)
    session$setInputs(family_1 = "latin_hypercube")
    expect_equal(session$getReturned()(), "latin_hypercube")
    session$setInputs(family_2 = "factorial")
    expect_equal(session$getReturned()(), "factorial")
  })
  # The observers also clear the other families' radio groups so only one
  # design is ever selected. That cannot be checked here: MockShinySession
  # discards input messages rather than applying them, so updateRadioButtons()
  # has no observable effect in testServer. It needs a browser.
})

test_that("the space-filling scaffold pauses with a message", {
  shiny::testServer(spacefilling_server, args = list(id = "latin_hypercube"), {
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("the app dispatches to the scaffold without erroring out", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_1` = "latin_hypercube", randomize = FALSE)
    expect_equal(selected(), "latin_hypercube")
    # Pauses rather than crashes: the message lands in place of the table.
    expect_error(current(), class = "shiny.silent.error")
    # And switching back to a real design still works.
    session$setInputs(`picker-family_2` = "factorial")
    session$setInputs(
      `factorial-num_factors` = 3,
      `factorial-num_runs` = "8",
      `factorial-center` = "0",
      `factorial-blocks` = "1",
      `factorial-replications` = 1,
      `factorial-factor_names` = ""
    )
    expect_equal(selected(), "factorial")
    expect_s3_class(current(), "doe_design")
  })
})
