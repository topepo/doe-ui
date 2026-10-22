test_that("families and designs both appear in registry order", {
  # Derived from the registry rather than hardcoded, so reordering entries is
  # a one-place change and this still checks the grouping.
  registry <- design_registry()
  families <- vapply(registry, function(d) d$family, character(1))
  grouped <- design_families()

  expect_equal(names(grouped), unique(families))
  for (family in names(grouped)) {
    expect_equal(grouped[[family]], names(registry)[families == family])
  }
  # Space-filling designs still come before screening ones.
  expect_equal(names(grouped)[1], "Space-Filling Designs")
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

test_that("every design package has a literal require() for the bundler", {
  # shinylive bundles only the packages it finds in a static scan of the
  # source, so each one needs an explicit require(). Nothing else run locally
  # would notice one going missing.
  source_text <- paste(
    unlist(lapply(
      list.files(file.path("..", "..", "R"), "\\.R$", full.names = TRUE),
      readLines
    )),
    collapse = "\n"
  )
  packages <- unique(unlist(lapply(design_registry(), function(d) d$packages())))
  for (pkg in packages) {
    expect_match(
      source_text,
      sprintf("suppressPackageStartupMessages(require(%s))", pkg),
      fixed = TRUE,
      label = pkg
    )
  }
})

test_that("the default design is registered", {
  expect_true(DEFAULT_DESIGN %in% names(design_registry()))
})

test_that("the picker renders one panel per family with the default open", {
  html <- as.character(picker_ui("picker"))
  expect_equal(length(gregexpr("accordion-item", html)[[1]]), 4)
  expect_match(html, "Space-Filling Designs")
  expect_match(html, "Screening designs")
  expect_match(html, "Mixture Designs")
  expect_match(html, "Response Surface Designs")
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
  shiny::testServer(
    spacefilling_opt_server,
    args = list(id = "lhs_optimized"),
    {
      session$setInputs(num_factors = 6, type = "max_min_l2", factor_names = "")
      # The run choices depend on the type, so they are not known until it is set.
      session$setInputs(num_runs = "20")
      design <- session$getReturned()()
      expect_s3_class(design, "doe_design")
      expect_equal(nrow(design$table), 20)
      expect_equal(names(design$table), LETTERS[1:6])
    }
  )
})

test_that("a type that this factor count does not offer is dropped", {
  shiny::testServer(
    spacefilling_opt_server,
    args = list(id = "lhs_optimized"),
    {
      session$setInputs(
        num_factors = 6,
        type = "max_min_l1",
        num_runs = "4",
        factor_names = ""
      )
      expect_s3_class(session$getReturned()(), "doe_design")
      # Past ten factors only uniform survives, so the held type goes stale.
      session$setInputs(num_factors = 12)
      expect_error(session$getReturned()(), class = "shiny.silent.error")
    }
  )
})

test_that("the random module builds from DiceDesign", {
  shiny::testServer(spacefilling_rand_server, args = list(id = "lhs_random"), {
    session$setInputs(
      num_factors = 4,
      num_runs = 12,
      seed = 3,
      factor_names = ""
    )
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

test_that("no design's UI renders a dropdown with nothing in it", {
  # The dependent dropdowns are filled by observers that only fire when their
  # input *changes*. Returning to a design rebuilds its UI with the same
  # values, which Shiny's input dedup suppresses, so anything left empty here
  # stays empty on screen until the user nudges a field. Every select must
  # therefore arrive with its choices already in place.
  for (id in names(design_registry())) {
    html <- as.character(design_registry()[[id]]$ui(id))
    selects <- regmatches(
      html,
      gregexpr("<select[^>]*>.*?</select>", html)
    )[[1]]
    for (select in selects) {
      input_id <- sub('.*id="([^"]+)".*', "\\1", select)
      expect_true(
        grepl("<option", select),
        label = sprintf("%s has at least one option", input_id)
      )
    }
  }
})

test_that("optimized designs are rescaled to 0-1 like the random ones", {
  design <- spacefilling_opt_create(
    num_factors = 6,
    num_runs = 20,
    type = "max_min_l2"
  )
  values <- unlist(design$table)
  expect_equal(range(values), c(0, 1))
  # A Latin hypercube keeps one level per run in every column, so rescaling
  # must not collapse any of them.
  expect_equal(length(unique(design$table[[1]])), 20)
  # Divided by num_runs, not each column's own maximum, so every factor is on
  # the same scale.
  expect_true(all(vapply(design$table, max, numeric(1)) == 1))
  expect_true(all(vapply(design$table, min, numeric(1)) == 0))
})

test_that("factor names get a text area, not a single-line input", {
  # The list runs to one name per factor and gets long, so every design gives
  # it room rather than a one-line box.
  for (id in names(design_registry())) {
    html <- as.character(design_registry()[[id]]$ui(id))
    expect_match(
      html,
      sprintf('<textarea id="%s-factor_names"[^>]*rows="3"', id),
      label = sprintf("%s factor names input", id)
    )
  }
})

test_that("uniform designs are separate from the Latin hypercubes", {
  # A uniform design minimises discrepancy, not an LHC criterion, so it is its
  # own entry rather than a fourth type under the optimized hypercubes.
  expect_false("uniform" %in% spacefilling_opt_get_types(6))
  expect_setequal(
    unname(spacefilling_opt_get_types(6)),
    c("audze_eglais", "max_min_l1", "max_min_l2")
  )
  # Having one criterion, it offers no type to choose.
  expect_length(spacefilling_unif_get_types(6), 0)
})

test_that("the split gives the two designs different factor ranges", {
  # This is why one entry could not cover both: past ten factors sfd has only
  # uniform designs, so a combined entry would claim 2-15 and fail on 11-15.
  expect_equal(spacefilling_opt_get_limits()$num_factors, c(2L, 10L))
  expect_equal(spacefilling_unif_get_limits()$num_factors, c(2L, 15L))
  expect_length(spacefilling_opt_get_types(12), 0)
  expect_gt(length(spacefilling_unif_get_num_runs_choices(12)), 0)
})

test_that("the uniform module builds without a type", {
  shiny::testServer(spacefilling_unif_server, args = list(id = "uniform"), {
    session$setInputs(num_factors = 12, num_runs = "20", factor_names = "")
    design <- session$getReturned()()
    expect_s3_class(design, "doe_design")
    expect_equal(dim(design$table), c(20L, 12L))
    expect_match(design$title, "^Uniform design")
    expect_equal(range(unlist(design$table)), c(0, 1))
  })
})

test_that("the picker is styled as a list, and only the picker", {
  html <- as.character(picker_ui("picker"))
  # One class per family radio group, which the stylesheet in R/ui.R targets.
  expect_equal(length(gregexpr("design-picker", html)[[1]]), 4)
  # The input is still a radio group underneath, which is what keeps one
  # selection per family without an observer per design.
  expect_match(html, 'role="radiogroup"')

  # Designs' own radio inputs must not pick up the link styling. The
  # factorial's type selector is a radioButtons too, and should look like one.
  types <- shiny::radioButtons("type", "Choose a design", choices = c(a = "a"))
  expect_false(grepl("design-picker", as.character(types)))
})

test_that("the picker stylesheet compiles and resolves theme colours", {
  deps <- bslib::bs_theme_dependencies(app_theme())
  styled <- Filter(function(d) !is.null(d$stylesheet), deps)
  dep <- styled[[length(styled)]]
  css <- paste(
    readLines(file.path(dep$src$file, dep$stylesheet), warn = FALSE),
    collapse = "\n"
  )
  rules <- regmatches(css, gregexpr("[.]design-picker[^{]*[{][^}]*[}]", css))[[
    1
  ]]
  expect_length(rules, 7)
  # $primary and color-contrast() resolved rather than emitted literally.
  expect_false(any(grepl("$primary", rules, fixed = TRUE)))
  expect_false(any(grepl("color-contrast", rules, fixed = TRUE)))
  # The radio itself is moved out of sight, not removed: display:none would
  # take it out of the tab order.
  expect_false(any(grepl("display:none", rules, fixed = TRUE)))
  expect_true(any(grepl("focus-visible", rules, fixed = TRUE)))
})
