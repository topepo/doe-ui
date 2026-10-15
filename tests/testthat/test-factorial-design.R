test_that("run_choices reports what the catalog actually holds", {
  expect_snapshot({
    run_choices(2)
    run_choices(3)
    run_choices(6)
  })
})

test_that("the supported range is derived from FrF2, not declared", {
  catalogued <- as.integer(names(factorial_support))
  expect_equal(factorial_factor_range[2], max(catalogued))
  # Every offered run count is one FrF2 can actually build.
  for (k in c(3, 6, 12, 34)) {
    offered <- unname(run_choices(k))
    expect_true(all(offered <= FACTORIAL_MAX_RUNS))
    expect_true(all(offered %in% c(factorial_support[[as.character(k)]], 2^k)))
  }
})

test_that("run_choices never offers a run count FrF2 lacks", {
  # The catalog is irregular: 34 factors has 2048 runs but not 1024. Deriving
  # the choices rather than computing a span of powers of two is what keeps a
  # missing size out of the dropdown.
  expect_false(1024 %in% run_choices(34))
  expect_false(1024 %in% factorial_support[["34"]])
  expect_true(2048 %in% vapply(
    Filter(function(e) e$nfac == 34, FrF2::catlg),
    function(e) e$nruns,
    numeric(1)
  ))
})

test_that("nothing beyond the run ceiling is offered", {
  for (k in c(2, 8, 20, 60, factorial_factor_range[2])) {
    expect_true(all(unname(run_choices(k)) <= FACTORIAL_MAX_RUNS))
  }
})

test_that("catalog_entries finds fractions and skips full factorials", {
  # A full factorial is not in FrF2's catalog.
  expect_length(catalog_entries(3, 8), 0)
  # Several equivalent fractions exist at this size; the app offers a choice.
  expect_gt(length(catalog_entries(6, 16)), 1)
  # Best first: resolution never increases down the list.
  resolutions <- vapply(catalog_entries(6, 16), function(e) e$res, numeric(1))
  expect_false(is.unsorted(rev(resolutions)))
})

test_that("code_to_word reads a Yates column code", {
  expect_equal(code_to_word(7, LETTERS[1:4]), "ABC")
  expect_equal(code_to_word(1, LETTERS[1:4]), "A")
  expect_equal(code_to_word(8, LETTERS[1:4]), "D")
})

test_that("a full factorial has every combination and no defining relation", {
  design <- factorial_design(k = 3, runs = 8)
  expect_equal(nrow(design$table), 8)
  expect_equal(design$notes, character())
  expect_snapshot(design)
})

test_that("a fractional factorial reports its resolution and generators", {
  expect_snapshot(factorial_design(k = 6, runs = 16))
})

test_that("alternative picks a different catalog design", {
  first <- factorial_design(k = 6, runs = 16, alternative = 1)
  second <- factorial_design(k = 6, runs = 16, alternative = 2)
  expect_false(identical(first$notes, second$notes))
})

test_that("an out-of-range alternative is clamped rather than failing", {
  available <- length(catalog_entries(6, 16))
  expect_equal(
    factorial_design(k = 6, runs = 16, alternative = 99)$notes,
    factorial_design(k = 6, runs = 16, alternative = available)$notes
  )
  expect_equal(
    factorial_design(k = 6, runs = 16, alternative = 0)$notes,
    factorial_design(k = 6, runs = 16, alternative = 1)$notes
  )
})

test_that("default names cross from letters to names0 past the alphabet", {
  expect_equal(names(factorial_design(k = 20, runs = 256)$table)[c(1, 20)], c("A", "T"))
  big <- names(factorial_design(k = 30, runs = 64)$table)
  expect_equal(big[c(1, 30)], c("x01", "x30"))
  expect_false(any(big %in% LETTERS))
})

test_that("the alias notation stays canonical when factors are renamed", {
  renamed <- factorial_design(
    k = 6,
    runs = 16,
    factor_names = parse_factor_names("Temp, Pressure", 6)
  )
  expect_equal(names(renamed$table)[1:2], c("Temp", "Pressure"))
  # Renaming a factor must not leak into the defining relation.
  expect_equal(renamed$notes, factorial_design(k = 6, runs = 16)$notes)
  expect_match(renamed$notes, "^Defining relation: I = [A-Z= ]+$")
})

test_that("a large design does not enumerate its defining relation", {
  # 2^p - 1 words for p generators: 30 factors in 64 runs has 24 generators and
  # 16.7 million words, which hangs the app if it is actually derived.
  elapsed <- system.time(design <- factorial_design(k = 60, runs = 128))[["elapsed"]]
  expect_lt(elapsed, 10)
  expect_match(design$notes, "Defining relation not shown")
  expect_match(design$notes, "53 generators")
})

test_that("relation_note derives the relation only below the generator limit", {
  small <- Filter(function(e) e$nfac == 6 && e$nruns == 16, FrF2::catlg)[[1]]
  large <- Filter(function(e) e$nfac == 30 && e$nruns == 64, FrF2::catlg)[[1]]
  expect_lte(length(small$gen), MAX_RELATION_GENERATORS)
  expect_gt(length(large$gen), MAX_RELATION_GENERATORS)
  expect_snapshot({
    relation_note(small, 6, 16)
    relation_note(large, 30, 64)
  })
})

test_that("describe_entry shortens a long generator list", {
  large <- Filter(function(e) e$nfac == 30 && e$nruns == 64, FrF2::catlg)[[1]]
  expect_match(describe_entry(large, 30, 64), "\\(24 generators\\)")
  small <- Filter(function(e) e$nfac == 6 && e$nruns == 16, FrF2::catlg)[[1]]
  expect_no_match(describe_entry(small, 6, 16), "generators\\)")
})

test_that("center points are appended as zero rows and counted in the title", {
  design <- factorial_design(k = 3, runs = 8, center = 2)
  expect_equal(nrow(design$table), 10)
  expect_true(all(design$table[9:10, ] == 0))
  expect_snapshot(cat(design$title))
})

test_that("factor names reach the column headers", {
  design <- factorial_design(
    k = 3,
    runs = 8,
    factor_names = parse_factor_names("Temp, Pressure, Time", 3)
  )
  expect_equal(names(design$table), c("Temp", "Pressure", "Time"))
})

test_that("invalid options fail with a message written for the user", {
  expect_snapshot(error = TRUE, {
    factorial_design(k = 1, runs = 2)
    factorial_design(k = 500, runs = 8)
    factorial_design(k = NA, runs = 8)
    factorial_design(k = 3.5, runs = 8)
    factorial_design(k = 3, runs = 6)
    factorial_design(k = 34, runs = 1024)
    factorial_design(k = 3, runs = 8, center = -1)
    factorial_design(k = 3, runs = 8, factor_names = c("Temp", "Pressure"))
  })
})

test_that("an unavailable value is reported with what is available instead", {
  expect_snapshot(error = TRUE, {
    stop_unavailable(1024, c(64, 128, 256), "run count", "34 factors")
    stop_unavailable(7, numeric(0), "run count", "99 factors")
    stop_unavailable("rotatable", c("faces", "spherical"), "axial distance")
    stop_out_of_range(500, c(2, 127), "Number of factors")
  })
})

test_that("a long list of choices is shortened", {
  expect_snapshot({
    format_choices(1:5)
    format_choices(1:30)
  })
})
