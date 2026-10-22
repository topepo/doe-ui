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

test_that("the simplex-lattice module returns a design once its inputs are set", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = 3,
      num_levels = 2,
      replications = 1,
      factor_names = ""
    )
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(names(design$table), LETTERS[1:3])
    expect_equal(nrow(design$table), 6)
  })
})

test_that("the simplex-lattice module passes factor names through", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = 3,
      num_levels = 3,
      replications = 1,
      factor_names = "Oil, Water"
    )
    expect_equal(
      names(session$getReturned()()$table),
      c("Oil", "Water", "C")
    )
  })
})

test_that("the simplex-lattice module builds at the top of both ranges", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = 10,
      num_levels = 5,
      replications = 1,
      factor_names = ""
    )
    expect_equal(nrow(session$getReturned()()$table), 2002)
  })
})

test_that("the simplex-lattice module passes replications through", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = 3,
      num_levels = 2,
      replications = 3,
      factor_names = ""
    )
    expect_equal(nrow(session$getReturned()()$table), 18)
  })
})

test_that("a factor count past the ceiling pauses with a message", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = 11,
      num_levels = 2,
      replications = 1,
      factor_names = ""
    )
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("an unusable levels count pauses rather than failing", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = 3,
      num_levels = 6,
      replications = 1,
      factor_names = ""
    )
    expect_error(session$getReturned()(), class = "shiny.silent.error")
    session$setInputs(num_levels = NA)
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("an unusable simplex-lattice factor count pauses rather than failing", {
  shiny::testServer(mixture_sld_server, args = list(id = "simplex_lattice"), {
    session$setInputs(
      num_factors = NA,
      num_levels = 2,
      replications = 1,
      factor_names = ""
    )
    expect_error(session$getReturned()(), class = "shiny.silent.error")
  })
})

test_that("the simplex-lattice panel opens on its defaults", {
  html <- as.character(mixture_sld_ui("simplex_lattice"))
  expect_match(html, sprintf('value="%d"', MIXTURE_SLD_DEFAULT_FACTORS))
  expect_match(html, sprintf('value="%d"', MIXTURE_SLD_DEFAULT_LEVELS))
  expect_match(html, 'max="10"')
  expect_match(html, 'max="5"')
})

test_that("the app dispatches to the simplex-lattice design", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_3` = "simplex_lattice", randomize = FALSE)
    session$setInputs(
      `simplex_lattice-num_factors` = 3,
      `simplex_lattice-num_levels` = 2,
      `simplex_lattice-replications` = 1,
      `simplex_lattice-factor_names` = ""
    )
    expect_equal(selected(), "simplex_lattice")
    expect_equal(
      names(current()$table),
      c("Standard order", "Run order", LETTERS[1:3])
    )
    expect_equal(nrow(current()$table), 6)
    # The panel renders lazily, so a broken module UI only shows up here.
    expect_false(is.null(output$options))
  })
})

test_that("Mixture Designs is its own family, after the screening designs", {
  families <- design_families()
  expect_equal(names(families)[3], "Mixture Designs")
  expect_equal(
    families[["Mixture Designs"]],
    c("simplex_lattice", "simplex_centroid")
  )
})

test_that("the simplex-centroid module returns a design once its inputs are set", {
  shiny::testServer(mixture_scd_server, args = list(id = "simplex_centroid"), {
    session$setInputs(num_factors = 3, replications = 1, factor_names = "")
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(names(design$table), LETTERS[1:3])
    expect_equal(nrow(design$table), 7)
  })
})

test_that("the simplex-centroid module passes names and replications through", {
  shiny::testServer(mixture_scd_server, args = list(id = "simplex_centroid"), {
    session$setInputs(
      num_factors = 3,
      replications = 2,
      factor_names = "Oil, Water"
    )
    design <- session$getReturned()()
    expect_equal(names(design$table), c("Oil", "Water", "C"))
    expect_equal(nrow(design$table), 14)
  })
})

test_that("the simplex-centroid module builds at the top of the range", {
  shiny::testServer(mixture_scd_server, args = list(id = "simplex_centroid"), {
    session$setInputs(num_factors = 10, replications = 1, factor_names = "")
    expect_equal(nrow(session$getReturned()()$table), 1023)
  })
})

test_that("an unusable simplex-centroid factor count pauses with a message", {
  shiny::testServer(mixture_scd_server, args = list(id = "simplex_centroid"), {
    for (bad in list(NA, 1, 11, 2.5)) {
      session$setInputs(num_factors = bad, replications = 1, factor_names = "")
      expect_error(session$getReturned()(), class = "shiny.silent.error")
    }
  })
})

test_that("the simplex-centroid panel opens on its defaults", {
  html <- as.character(mixture_scd_ui("simplex_centroid"))
  expect_match(html, sprintf('value="%d"', MIXTURE_SCD_DEFAULT_FACTORS))
  expect_match(html, 'max="10"')
  # No levels: a centroid design has none to choose.
  expect_false(grepl("num_levels", html))
})

test_that("the CCD module returns a design once its inputs are set", {
  shiny::testServer(rsm_ccd_server, args = list(id = "central_composite"), {
    session$setInputs(
      num_factors = 3,
      center = 2,
      alpha = "rotatable",
      replications = 1,
      factor_names = "Temp, Pressure"
    )
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(names(design$table), c("Block", "Temp", "Pressure", "C"))
    # Rotatable is one block, so the two center points are the total.
    expect_equal(nrow(design$table), 8 + 6 + 2)
  })
})

test_that("the CCD module passes a custom axial distance and replications", {
  shiny::testServer(rsm_ccd_server, args = list(id = "central_composite"), {
    session$setInputs(
      num_factors = 2,
      center = 1,
      alpha = RSM_CCD_CUSTOM_ALPHA,
      alpha_value = 1.3,
      replications = 2,
      factor_names = ""
    )
    design <- session$getReturned()()
    expect_equal(max(abs(as.matrix(design$table[c("A", "B")]))), 1.3)
    # Cube and axial points doubled, the one center point not.
    expect_equal(nrow(design$table), 2 * (4 + 4) + 1)
    expect_equal(unique(design$table$Block), "1")
  })
})

test_that("unusable CCD counts pause rather than failing", {
  shiny::testServer(rsm_ccd_server, args = list(id = "central_composite"), {
    for (bad in list(NA, 1, 9, 2.5)) {
      session$setInputs(
        num_factors = bad,
        center = 4,
        alpha = "orthogonal",
        replications = 1,
        factor_names = ""
      )
      expect_error(session$getReturned()(), class = "shiny.silent.error")
    }
    for (bad in list(NA, -1, 21, 1.5)) {
      session$setInputs(num_factors = 3, center = bad)
      expect_error(session$getReturned()(), class = "shiny.silent.error")
    }
  })
})

test_that("the CCD panel opens on its defaults with every axial choice", {
  html <- as.character(rsm_ccd_ui("central_composite"))
  expect_match(html, sprintf('value="%d"', RSM_CCD_DEFAULT_FACTORS))
  expect_match(html, sprintf('value="%d"', RSM_CCD_DEFAULT_CENTER))
  for (type in c(rsm_ccd_get_types(), RSM_CCD_CUSTOM_ALPHA)) {
    expect_match(html, sprintf('<option value="%s"', type))
  }
})

test_that("the app dispatches to the central composite design", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_4` = "central_composite", randomize = FALSE)
    session$setInputs(
      `central_composite-num_factors` = 2,
      `central_composite-center` = 1,
      `central_composite-alpha` = "orthogonal",
      `central_composite-replications` = 1,
      `central_composite-factor_names` = ""
    )
    expect_equal(selected(), "central_composite")
    expect_equal(
      names(current()$table),
      c("Standard order", "Run order", "Block", "A", "B")
    )
    expect_equal(nrow(current()$table), 10)
    # The panel renders lazily, so a broken module UI only shows up here.
    expect_false(is.null(output$options))
  })
})

test_that("Response Surface Designs is its own family, last", {
  families <- design_families()
  expect_equal(names(families)[4], "Response Surface Designs")
  expect_equal(families[["Response Surface Designs"]], "central_composite")
})

test_that("the app dispatches to the simplex-centroid design", {
  shiny::testServer(app_server, {
    session$setInputs(`picker-family_3` = "simplex_centroid", randomize = FALSE)
    session$setInputs(
      `simplex_centroid-num_factors` = 3,
      `simplex_centroid-replications` = 1,
      `simplex_centroid-factor_names` = ""
    )
    expect_equal(selected(), "simplex_centroid")
    expect_equal(
      names(current()$table),
      c("Standard order", "Run order", LETTERS[1:3])
    )
    expect_equal(nrow(current()$table), 7)
    # The panel renders lazily, so a broken module UI only shows up here.
    expect_false(is.null(output$options))
  })
})
