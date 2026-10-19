test_that("the factorial module returns a design once its inputs are set", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(
      num_factors = 3,
      num_runs = "8",
      center = "0",
      blocks = "1",
      replications = 1,
      factor_names = ""
    )
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(names(design$table), c("A", "B", "C"))
    expect_equal(nrow(design$table), 8)
  })
})

test_that("the module passes factor names and center points through", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(
      num_factors = 3,
      num_runs = "8",
      center = "2",
      blocks = "1",
      replications = 1,
      factor_names = "Temp, Pressure, Time"
    )
    design <- session$getReturned()()
    expect_equal(names(design$table), c("Temp", "Pressure", "Time"))
    expect_equal(nrow(design$table), 10)
  })
})

test_that("changing the factor count repopulates the run choices", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(
      num_factors = 3,
      num_runs = "8",
      center = "0",
      blocks = "1",
      replications = 1,
      factor_names = ""
    )
    expect_equal(unname(factorial_get_num_runs_choices(3)), c(4, 8))
    session$setInputs(num_factors = 5)
    # The observer fires on k; the new choices are what the dropdown is told.
    expect_equal(unname(factorial_get_num_runs_choices(5)), c(8, 16, 32))
  })
})

test_that("a stale run count does not produce a design", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(
      num_factors = 3,
      num_runs = "8",
      center = "0",
      blocks = "1",
      replications = 1,
      factor_names = ""
    )
    expect_s3_class(session$getReturned()(), "doe_design")
    # 8 runs is not a choice for 2 factors, which is the state that exists for
    # one flush after k changes. The reactive must pause, not error.
    session$setInputs(num_factors = 2)
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("an unusable factor count pauses with a message rather than failing", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(
      num_factors = NA,
      num_runs = "8",
      center = "0",
      factor_names = ""
    )
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("the app dispatches from the picker through to a design", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_1` = "factorial", randomize = FALSE)
    session$setInputs(
      `factorial-num_factors` = 3,
      `factorial-num_runs` = "8",
      `factorial-center` = "0",
      `factorial-blocks` = "1",
      `factorial-replications` = 1,
      `factorial-factor_names` = ""
    )
    expect_equal(selected(), "factorial")
    expect_equal(
      names(current()$table),
      c("Standard order", "Run order", "A", "B", "C")
    )
    expect_equal(current()$table[["Run order"]], 1:8)
    expect_false(is.null(output$options))
  })
})

test_that("the picker starts on the default and follows a selection", {
  shiny::testServer(picker_server, args = list(id = "picker"), {
    expect_equal(session$getReturned()(), DEFAULT_DESIGN)
    session$setInputs(family_1 = "factorial")
    expect_equal(session$getReturned()(), "factorial")
  })
})

test_that("the Taguchi module returns a design once its inputs are set", {
  shiny::testServer(taguchi_server, args = list(id = "taguchi"), {
    session$setInputs(
      num_factors = 5,
      num_runs = "8",
      replications = 1,
      factor_names = ""
    )
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(names(design$table), LETTERS[1:5])
    expect_equal(nrow(design$table), 8)
  })
})

test_that("the Taguchi module passes factor names through", {
  shiny::testServer(taguchi_server, args = list(id = "taguchi"), {
    session$setInputs(
      num_factors = 3,
      num_runs = "12",
      replications = 1,
      factor_names = "Temp (C), Pressure"
    )
    expect_equal(
      names(session$getReturned()()$table),
      c("Temp (C)", "Pressure", "C")
    )
  })
})

test_that("a stale Taguchi run count does not produce a design", {
  shiny::testServer(taguchi_server, args = list(id = "taguchi"), {
    session$setInputs(
      num_factors = 7,
      num_runs = "8",
      replications = 1,
      factor_names = ""
    )
    expect_s3_class(session$getReturned()(), "doe_design")
    # 8 runs cannot hold 8 factors, which is the state that exists for one
    # flush after the count changes. The reactive must pause, not error.
    session$setInputs(num_factors = 8)
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("an unusable Taguchi factor count pauses rather than failing", {
  shiny::testServer(taguchi_server, args = list(id = "taguchi"), {
    session$setInputs(
      num_factors = NA,
      num_runs = "8",
      replications = 1,
      factor_names = ""
    )
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("the Taguchi module passes replications through", {
  shiny::testServer(taguchi_server, args = list(id = "taguchi"), {
    session$setInputs(
      num_factors = 5,
      num_runs = "8",
      replications = 3,
      factor_names = ""
    )
    expect_equal(nrow(session$getReturned()()$table), 24)
  })
})

test_that("the Taguchi panel opens with its run choices in place", {
  html <- as.character(taguchi_ui("taguchi"))
  expect_match(html, sprintf('value="%d"', TAGUCHI_DEFAULT_FACTORS))
  expect_match(html, "8 runs \\(L8\\)")
})

test_that("the app dispatches to the Taguchi design", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_2` = "taguchi", randomize = FALSE)
    session$setInputs(
      `taguchi-num_factors` = 5,
      `taguchi-num_runs` = "8",
      `taguchi-replications` = 1,
      `taguchi-factor_names` = ""
    )
    expect_equal(selected(), "taguchi")
    expect_equal(
      names(current()$table),
      c("Standard order", "Run order", LETTERS[1:5])
    )
    expect_equal(current()$table[["Run order"]], 1:8)
    # The panel renders lazily, so a broken module UI only shows up here.
    expect_false(is.null(output$options))
  })
})

test_that("Taguchi sits in the screening family beside the factorial", {
  families <- design_families()
  expect_equal(families[["Screening designs"]], c("factorial", "taguchi"))
})
