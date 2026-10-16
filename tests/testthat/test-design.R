test_that("names0 zero-pads only once the width demands it", {
  expect_equal(names0(3), c("x1", "x2", "x3"))
  expect_equal(names0(10)[c(1, 10)], c("x01", "x10"))
  expect_equal(names0(100)[c(1, 100)], c("x001", "x100"))
  expect_equal(names0(2, prefix = "C"), c("C1", "C2"))
})

test_that("factor_labels uses letters until they run out, then names0", {
  expect_equal(default_factor_names(3), c("A", "B", "C"))
  expect_equal(default_factor_names(26)[26], "Z")
  # One past the alphabet every label switches over, rather than mixing the
  # two schemes within one design.
  expect_equal(default_factor_names(27)[1:2], c("x01", "x02"))
  expect_equal(default_factor_names(27)[27], "x27")
  expect_false("A" %in% default_factor_names(27))
  expect_equal(default_factor_names(100)[1], "x001")
})

test_that("parse_factor_names fills, trims, truncates, and deduplicates", {
  expect_snapshot({
    rename_factors(NULL, 3)
    rename_factors("", 3)
    rename_factors("Temp, Pressure, Time", 3)
    rename_factors("  Temp ,   Pressure  ", 3)
    rename_factors("Temp, Pressure, Time, Catalyst, Speed", 3)
    rename_factors("Temp, Temp, Temp", 3)
    rename_factors(", ,Temp", 3)
  })
})

test_that("with_run_order adds the order columns without moving rows", {
  design <- new_design(data.frame(A = c(-1, 1), B = c(-1, -1)), "Two runs")
  expect_snapshot(with_run_order(design, randomize = FALSE)$table)
})

test_that("randomizing permutes the run order and nothing else", {
  design <- new_design(
    data.frame(A = c(-1, 1, -1, 1), B = c(-1, -1, 1, 1)),
    "Four runs"
  )
  withr::with_seed(42, {
    randomized <- with_run_order(design, randomize = TRUE)
  })
  expect_equal(randomized$table[["Standard order"]], 1:4)
  expect_setequal(randomized$table[["Run order"]], 1:4)
  # The design columns are untouched.
  expect_equal(randomized$table[c("A", "B")], design$table)
})

test_that("center_point_text pluralises and counts the total", {
  expect_snapshot({
    center_point_text(0, 2)
    center_point_text(1, 3)
    center_point_text(3, 5)
  })
})

test_that("display_table leaves coded levels and the order columns alone", {
  design <- new_design(data.frame(A = c(-1, 0, 1), B = c(1, 0, -1)), "Coded")
  shown <- display_table(with_run_order(design, randomize = FALSE))
  # Nothing is turned into text, and -1 stays -1 rather than becoming -1.000.
  expect_true(all(vapply(shown, is.numeric, logical(1))))
  expect_snapshot(shown)
})

test_that("display_table rounds to three significant figures, not decimals", {
  design <- new_design(
    data.frame(
      x1 = c(0.333333, 0.000123456),
      x2 = c(1234.567, 1.681793)
    ),
    "Mixed magnitudes"
  )
  shown <- display_table(design)
  # Significant figures, so a small value keeps its precision and a large one
  # is rounded in its leading digits. colFormat(digits = ) could do neither.
  expect_equal(shown$x1, c(0.333, 0.000123))
  expect_equal(shown$x2, c(1230, 1.68))
  expect_snapshot(shown)
})

test_that("the order columns are never rounded", {
  design <- new_design(data.frame(x1 = c(-1, 1)), "Two runs")
  shown <- display_table(with_run_order(design, randomize = FALSE))
  expect_equal(shown[["Standard order"]], 1:2)
  expect_equal(shown[["Run order"]], 1:2)
})

test_that("a design prints its title, notes, and table", {
  design <- new_design(
    data.frame(A = c(-1, 1)),
    "A tiny design",
    notes = "Defining relation: I = AB"
  )
  expect_snapshot(design)
})

test_that("stop_unless reports the message it was given", {
  expect_snapshot(error = TRUE, stop_unless(FALSE, "Choose between 2 and 8 factors."))
  expect_true(stop_unless(TRUE, "unused"))
})
