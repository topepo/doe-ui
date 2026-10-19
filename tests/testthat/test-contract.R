# The shapes the README documents for the design helper contract. These are
# here so the documentation cannot quietly drift from the code: a design that
# returns the wrong shape fails here rather than producing a dropdown that
# looks right and submits nonsense.

test_that("get_packages returns an unnamed character vector", {
  packages <- factorial_get_packages()
  expect_type(packages, "character")
  expect_null(names(packages))
  expect_gt(length(packages), 0)
  expect_true(all(nzchar(packages)))
})

test_that("get_limits returns a named list of integer min/max pairs", {
  limits <- factorial_get_limits()
  expect_type(limits, "list")
  expect_true(!is.null(names(limits)) && all(nzchar(names(limits))))
  for (range in limits) {
    expect_true(is.integer(range))
    expect_length(range, 2)
    expect_lt(range[1], range[2])
  }
})

test_that("choices hold values and are named by label, not the reverse", {
  choices <- factorial_get_num_runs_choices(6)
  # Values are the data: what comes back as num_runs.
  expect_type(choices, "double")
  expect_equal(unname(choices), c(8, 16, 32, 64))
  expect_false(is.unsorted(unname(choices)))
  # Names are display only.
  expect_true(all(nzchar(names(choices))))
  expect_match(names(choices)[1], "runs")
  # Every offered value builds, which is the point of the convention.
  for (value in unname(choices)) {
    expect_s3_class(
      factorial_create(num_factors = 6, num_runs = value),
      "doe_design"
    )
  }
})

test_that("choices may be unnamed where the value is its own label", {
  blocks <- factorial_get_blocks_choices(16)
  expect_type(blocks, "double")
  expect_null(names(blocks))
  expect_equal(blocks, c(1, 2, 4, 8))
  expect_false(is.unsorted(blocks))
})

test_that("choices may be empty", {
  # Past the largest factor count the catalog covers. One factor is *not* an
  # empty case: 2^1 is within the run ceiling, so a two-run design is offered
  # even though get_limits() puts one factor out of range.
  expect_length(factorial_get_num_runs_choices(200), 0)
  expect_type(factorial_get_num_runs_choices(200), "double")
})

test_that("get_types holds ids and is named by label", {
  types <- factorial_get_types(6, 16)
  expect_type(types, "character")
  # Values are the package's own ids.
  expect_true(all(unname(types) %in% names(FrF2::catlg)))
  # Names are display only.
  expect_true(all(nzchar(names(types))))
  expect_match(names(types)[1], "^Resolution ")
  # Best first: resolution never increases down the list.
  resolutions <- vapply(types, function(id) FrF2::catlg[[id]]$res, numeric(1))
  expect_false(is.unsorted(rev(resolutions)))
})

test_that("get_types is empty when there is nothing to choose", {
  empty <- factorial_get_types(3, 8)
  expect_type(empty, "character")
  expect_length(empty, 0)
  # A zero-length result is how create() tells a full factorial from a
  # fraction, so it must not be an error or a NULL.
  expect_false(is.null(empty))
})

test_that("get_notes returns unnamed character lines", {
  design <- suppressMessages(
    FrF2::FrF2(design = "6-2.1", randomize = FALSE)
  )
  notes <- factorial_get_notes(design)
  expect_type(notes, "character")
  expect_null(names(notes))
})

test_that("get_notes reads the package's object, not a doe_design", {
  # Handing it a doe_design is a silent no-op rather than an error, because
  # the attribute it looks for is simply absent. Worth knowing: it means the
  # notes quietly vanish if this is ever called at the wrong point in
  # construction, rather than failing loudly.
  expect_length(factorial_get_notes(factorial_create(6, 16)), 0)
  expect_gt(
    length(factorial_get_notes(suppressMessages(
      FrF2::FrF2(design = "6-2.1", randomize = FALSE)
    ))),
    0
  )
})

test_that("get_notes may be empty", {
  full <- suppressMessages(
    FrF2::FrF2(nruns = 8, nfactors = 3, randomize = FALSE)
  )
  expect_length(factorial_get_notes(full), 0)
})

test_that("create returns a doe_design carrying a plain data frame", {
  design <- factorial_create(num_factors = 6, num_runs = 16)
  expect_s3_class(design, "doe_design")
  expect_named(design, c("table", "title", "notes"))
  expect_s3_class(design$table, "tbl_df")
  expect_type(design$title, "character")
  expect_length(design$title, 1)
  expect_type(design$notes, "character")
  # One row per run, in standard order, with the order columns not yet added.
  expect_equal(nrow(design$table), 16)
  expect_false(any(ORDER_COLUMNS %in% names(design$table)))
})

test_that("the Taguchi design returns the documented shapes", {
  packages <- taguchi_get_packages()
  expect_type(packages, "character")
  expect_null(names(packages))

  limits <- taguchi_get_limits()
  expect_named(limits, "num_factors")
  expect_true(is.integer(limits$num_factors))
  expect_length(limits$num_factors, 2)
  expect_lt(limits$num_factors[1], limits$num_factors[2])

  # Values are the data, names are the labels, and every value builds.
  choices <- taguchi_get_num_runs_choices(5)
  expect_type(choices, "double")
  expect_false(is.unsorted(unname(choices)))
  expect_true(all(nzchar(names(choices))))
  expect_match(names(choices)[1], "runs")
  for (value in unname(choices)) {
    expect_s3_class(
      taguchi_create(num_factors = 5, num_runs = value),
      "doe_design"
    )
  }
  # Empty past the widest array, as an empty double rather than NULL.
  expect_length(taguchi_get_num_runs_choices(limits$num_factors[2] + 1), 0)
  expect_type(taguchi_get_num_runs_choices(limits$num_factors[2] + 1), "double")

  design <- taguchi_create(num_factors = 5, num_runs = 8)
  expect_named(design, c("table", "title", "notes"))
  expect_s3_class(design$table, "tbl_df")
  expect_length(design$title, 1)
  expect_type(design$notes, "character")
  expect_false(any(ORDER_COLUMNS %in% names(design$table)))
})

test_that("the space-filling designs return the documented shapes", {
  for (get_packages in list(
    spacefilling_opt_get_packages,
    spacefilling_unif_get_packages,
    spacefilling_rand_get_packages
  )) {
    packages <- get_packages()
    expect_type(packages, "character")
    expect_null(names(packages))
    expect_gt(length(packages), 0)
  }

  for (limits in list(
    spacefilling_opt_get_limits(),
    spacefilling_unif_get_limits(),
    spacefilling_rand_get_limits()
  )) {
    expect_type(limits, "list")
    expect_true(all(nzchar(names(limits))))
    for (range in limits) {
      expect_true(is.integer(range))
      expect_length(range, 2)
      expect_lt(range[1], range[2])
    }
  }

  # Types: sfd's own ids as values, labels as names.
  types <- spacefilling_opt_get_types(6)
  expect_type(types, "character")
  expect_true(all(unname(types) %in% names(SFD_TYPE_LABELS)))
  expect_equal(names(types), unname(SFD_TYPE_LABELS[types]))
  # The other two have nothing to choose, as an empty character, not NULL.
  for (empty in list(
    spacefilling_unif_get_types(6),
    spacefilling_rand_get_types()
  )) {
    expect_type(empty, "character")
    expect_length(empty, 0)
  }

  # Run choices: unnamed doubles, ascending, and every value builds.
  for (choices in list(
    spacefilling_opt_get_num_runs_choices(6, "max_min_l1"),
    spacefilling_unif_get_num_runs_choices(12)
  )) {
    expect_type(choices, "double")
    expect_null(names(choices))
    expect_false(is.unsorted(choices))
  }
  for (value in spacefilling_opt_get_num_runs_choices(6, "max_min_l1")) {
    expect_s3_class(
      spacefilling_opt_create(6, value, "max_min_l1"),
      "doe_design"
    )
  }
  # The random design takes any run count in range, so it has no choices helper.
  expect_false(exists("spacefilling_rand_get_num_runs_choices"))

  for (design in list(
    spacefilling_opt_create(6, 20, "max_min_l2"),
    spacefilling_unif_create(6, 20),
    spacefilling_rand_create(6, 20)
  )) {
    expect_named(design, c("table", "title", "notes"))
    expect_s3_class(design$table, "tbl_df")
    expect_length(design$title, 1)
    expect_type(design$notes, "character")
    expect_false(any(ORDER_COLUMNS %in% names(design$table)))
    expect_equal(nrow(design$table), 20)
  }
})

test_that("the Taguchi design has no types, so it defines no get_types", {
  # One array exists per run count, so there is nothing to choose between. The
  # contract allows a design to omit a helper whose options it does not have.
  expect_false(exists("taguchi_get_types"))
})

test_that("the simplex-lattice design returns the documented shapes", {
  packages <- mixture_sld_get_packages()
  expect_type(packages, "character")
  expect_null(names(packages))

  limits <- mixture_sld_get_limits()
  expect_named(limits, c("num_factors", "num_levels"))
  for (range in limits) {
    expect_true(is.integer(range))
    expect_length(range, 2)
    expect_lt(range[1], range[2])
  }

  # Every size in range builds, which is why there is no choices helper: no
  # value in range needs to be filtered out.
  for (num_levels in seq(limits$num_levels[1], limits$num_levels[2])) {
    expect_s3_class(
      mixture_sld_create(num_factors = 4, num_levels = num_levels),
      "doe_design"
    )
  }
  expect_false(exists("mixture_sld_get_num_levels_choices"))

  design <- mixture_sld_create(num_factors = 4, num_levels = 2)
  expect_named(design, c("table", "title", "notes"))
  expect_s3_class(design$table, "tbl_df")
  expect_length(design$title, 1)
  expect_type(design$notes, "character")
  expect_false(any(ORDER_COLUMNS %in% names(design$table)))
})

test_that("the simplex-centroid design returns the documented shapes", {
  packages <- mixture_scd_get_packages()
  expect_type(packages, "character")
  expect_null(names(packages))

  limits <- mixture_scd_get_limits()
  expect_named(limits, "num_factors")
  expect_true(is.integer(limits$num_factors))
  expect_length(limits$num_factors, 2)
  expect_lt(limits$num_factors[1], limits$num_factors[2])

  # Every factor count in range builds, so there is no choices helper.
  for (num_factors in seq(limits$num_factors[1], limits$num_factors[2])) {
    expect_s3_class(mixture_scd_create(num_factors), "doe_design")
  }
  expect_false(exists("mixture_scd_get_num_factors_choices"))

  design <- mixture_scd_create(num_factors = 4)
  expect_named(design, c("table", "title", "notes"))
  expect_s3_class(design$table, "tbl_df")
  expect_length(design$title, 1)
  expect_type(design$notes, "character")
  expect_false(any(ORDER_COLUMNS %in% names(design$table)))
})
