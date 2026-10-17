test_that("families appear in registry order, space-filling first", {
  families <- design_families()
  expect_equal(
    names(families),
    c("Space-Filling Designs", "Screening designs")
  )
  expect_equal(
    families[["Space-Filling Designs"]],
    c("lhs_optimized", "lhs_random")
  )
  expect_equal(families[["Screening designs"]], "factorial")
})

test_that("every registry entry has the fields the app reads", {
  for (entry in design_registry()) {
    expect_named(entry, c("label", "family", "ui", "server", "packages"))
    expect_type(entry$label, "character")
    expect_type(entry$family, "character")
    expect_true(is.function(entry$ui))
    expect_true(is.function(entry$server))
    # Each design names its own packages, so the app can report the one that
    # is actually missing rather than a union of everything.
    expect_true(is.function(entry$packages))
    expect_type(entry$packages(), "character")
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

test_that("the optimized module builds from sfd once its inputs are set", {
  shiny::testServer(spacefilling_opt_server, args = list(id = "lhs_optimized"), {
    session$setInputs(num_factors = 6, type = "max_min_l2", factor_names = "")
    # The run choices depend on the type, so they are not known until it is set.
    session$setInputs(num_runs = "20")
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(nrow(design$table), 20)
    expect_equal(names(design$table), LETTERS[1:6])
  })
})

test_that("a type that this factor count does not offer is dropped", {
  shiny::testServer(spacefilling_opt_server, args = list(id = "lhs_optimized"), {
    session$setInputs(num_factors = 6, type = "max_min_l1", num_runs = "4",
                      factor_names = "")
    expect_s3_class(session$getReturned()(), "doe_design")
    # Past ten factors only uniform survives, so the held type goes stale.
    session$setInputs(num_factors = 12)
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("the random module builds from DiceDesign", {
  shiny::testServer(spacefilling_rand_server, args = list(id = "lhs_random"), {
    session$setInputs(num_factors = 4, num_runs = 12, seed = 3, factor_names = "")
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(dim(design$table), c(12L, 4L))
    # Coded 0 to 1, unlike the optimized designs' integer levels.
    expect_true(all(unlist(design$table) >= 0 & unlist(design$table) <= 1))
  })
})

test_that("the app dispatches across families", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_1` = "lhs_random", randomize = FALSE)
    expect_equal(selected(), "lhs_random")
    session$setInputs(
      `lhs_random-num_factors` = 4,
      `lhs_random-num_runs` = 12,
      `lhs_random-seed` = 1,
      `lhs_random-factor_names` = ""
    )
    expect_s3_class(current(), "doe_design")
    # And switching to another family still works.
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

test_that("every design implements the helper contract it needs", {
  # The factorial is the reference implementation of the contract in the
  # README. The space-filling entry is scaffolding and has only the packages
  # helper so far, which is what the app's startup check calls.
  expect_true(is.function(factorial_get_packages))
  expect_true(is.function(factorial_get_limits))
  expect_true(is.function(factorial_get_num_runs_choices))
  expect_true(is.function(factorial_get_blocks_choices))
  expect_true(is.function(factorial_get_types))
  expect_true(is.function(factorial_create))
  expect_true(is.function(factorial_get_notes))

  limits <- factorial_get_limits()
  expect_type(limits, "list")
  expect_named(limits, "num_factors")
  expect_length(limits$num_factors, 2)
  expect_true(limits$num_factors[1] < limits$num_factors[2])
})
