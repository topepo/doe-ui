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
