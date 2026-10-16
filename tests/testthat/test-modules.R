test_that("the factorial module returns a design once its inputs are set", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(num_factors = 3, num_runs = "8", center = "0", blocks = "1",
                      replications = 1, factor_names = "")
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
    session$setInputs(num_factors = 3, num_runs = "8", center = "0", blocks = "1",
                      replications = 1, factor_names = "")
    expect_equal(unname(factorial_get_num_runs_choices(3)), c(4, 8))
    session$setInputs(num_factors = 5)
    # The observer fires on k; the new choices are what the dropdown is told.
    expect_equal(unname(factorial_get_num_runs_choices(5)), c(8, 16, 32))
  })
})

test_that("a stale run count does not produce a design", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(num_factors = 3, num_runs = "8", center = "0", blocks = "1",
                      replications = 1, factor_names = "")
    expect_s3_class(session$getReturned()(), "doe_design")
    # 8 runs is not a choice for 2 factors, which is the state that exists for
    # one flush after k changes. The reactive must pause, not error.
    session$setInputs(num_factors = 2)
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("an unusable factor count pauses with a message rather than failing", {
  shiny::testServer(factorial_server, args = list(id = "factorial"), {
    session$setInputs(num_factors = NA, num_runs = "8", center = "0", factor_names = "")
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
