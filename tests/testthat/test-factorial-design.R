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

test_that("generators come from DoE.base rather than decoded Yates codes", {
  expect_equal(
    DoE.base::generators("6-2.1", select.catlg = FrF2::catlg)[[1]],
    c("E=ABC", "F=ABD")
  )
})

test_that("a full factorial has every combination and aliases nothing", {
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

test_that("renaming factors adds a legend but keeps the alias letters", {
  plain <- factorial_design(k = 6, runs = 16)
  renamed <- factorial_design(
    k = 6,
    runs = 16,
    factor_names = parse_factor_names("Temp, Pressure", 6)
  )
  expect_equal(names(renamed$table)[1:2], c("Temp", "Pressure"))
  # The confounding itself stays written in FrF2's letters, unchanged ...
  confounding <- function(x) grep("^Two-factor", x, value = TRUE)
  expect_equal(confounding(renamed$notes), confounding(plain$notes))
  # ... with a legend added that maps those letters onto the new names. The
  # legend is absent when nothing has been renamed, since it would be identity.
  expect_match(renamed$notes[[1]], "^Factors: A=Temp, B=Pressure$")
  expect_length(grep("^Factors:", plain$notes), 0)
})

test_that("a large design reports aliasing without enumerating words", {
  # This design has 53 generators. Deriving its defining relation here would
  # mean 2^53 words and would hang; FrF2's alias classes are bounded by the
  # run count instead, so the note is both cheap and complete.
  elapsed <- system.time(design <- factorial_design(k = 60, runs = 128))[["elapsed"]]
  expect_lt(elapsed, 10)
  expect_length(grep("^Two-factor interactions aliased:", design$notes), 1)
})

test_that("alias notes are read from FrF2, at every design size", {
  expect_snapshot({
    factorial_design(k = 6, runs = 16)$notes
    # Resolution III aliases main effects, not just two-factor interactions.
    factorial_design(k = 7, runs = 8)$notes
    # A full factorial aliases nothing.
    factorial_design(k = 3, runs = 8)$notes
  })
})

test_that("a renamed factor appears in the alias legend", {
  renamed <- factorial_design(
    k = 6,
    runs = 16,
    factor_names = parse_factor_names("Temp, Pressure", 6)
  )
  expect_snapshot(renamed$notes)
})

test_that("describe_entry shortens a long generator list", {
  large <- catalog_entries(30, 64)
  expect_match(describe_entry(names(large)[1], large[[1]]), "\\(24 generators\\)")
  small <- catalog_entries(6, 16)
  expect_no_match(describe_entry(names(small)[1], small[[1]]), "generators\\)")
  expect_snapshot(describe_entry(names(small)[1], small[[1]]))
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

test_that("center points come from FrF2 and are recorded on the design", {
  plain <- factorial_design(k = 3, runs = 8)
  with_centers <- factorial_design(k = 3, runs = 8, center = 2)
  expect_equal(nrow(with_centers$table), nrow(plain$table) + 2)
  # Appended at the end, every factor at zero, with randomize = FALSE.
  expect_true(all(with_centers$table[9:10, ] == 0))
  expect_equal(with_centers$table[1:8, ], plain$table)
  expect_snapshot(cat(with_centers$title))
})

test_that("a fraction takes center points too", {
  design <- factorial_design(k = 6, runs = 16, center = 5)
  expect_equal(nrow(design$table), 21)
  expect_equal(sum(apply(design$table, 1, function(r) all(r == 0))), 5)
})

test_that("our best-first ordering agrees with FrF2's own choice", {
  # catalog_entries() sorts by resolution then word count so the app can offer
  # alternatives, which FrF2 has no exported helper for. This checks the
  # ordering is the package's policy and not one of our own: the entry we put
  # first is the one FrF2 picks when asked for a design without naming it.
  for (spec in list(c(5, 16), c(6, 16), c(8, 32), c(12, 64), c(20, 256))) {
    ours <- names(catalog_entries(spec[1], spec[2]))[1]
    chosen <- suppressMessages(FrF2::FrF2(
      nruns = spec[2],
      nfactors = spec[1],
      randomize = FALSE
    ))
    expect_equal(ours, names(attr(chosen, "design.info")$catlg.entry))
  }
})

test_that("blocks add a labelled block column", {
  plain <- factorial_design(k = 3, runs = 8)
  blocked <- factorial_design(k = 3, runs = 8, blocks = 2)
  expect_false("Blocks" %in% names(plain$table))
  expect_equal(names(blocked$table), c("Blocks", "A", "B", "C"))
  expect_setequal(blocked$table$Blocks, c("1", "2"))
  expect_match(blocked$title, "2 blocks")
})

test_that("block labels stay labels and are never coerced to numbers", {
  # With replications FrF2 labels blocks "1.1", "2.1" -- block and replicate,
  # not a decimal. Coercing would turn "1.1" into 1.1 and invent a number.
  design <- factorial_design(k = 3, runs = 8, blocks = 2, replications = 2)
  expect_type(design$table$Blocks, "character")
  expect_setequal(design$table$Blocks, c("1.1", "1.2", "2.1", "2.2"))
})

test_that("blocks = 1 means unblocked, including as an integer", {
  # FrF2's `blocks` also takes Yates column numbers, and an integer 1L lands in
  # that branch and errors rather than meaning "one block".
  expect_equal(factorial_design(k = 3, runs = 8, blocks = 1L)$table,
               factorial_design(k = 3, runs = 8)$table)
  expect_equal(factorial_design(k = 3, runs = 8, blocks = 1)$table,
               factorial_design(k = 3, runs = 8)$table)
})

test_that("replications repeat every run", {
  design <- factorial_design(k = 3, runs = 8, replications = 3)
  expect_equal(nrow(design$table), 24)
  expect_match(design$title, "3 replications")
})

test_that("center points are per block, as FrF2 counts them", {
  design <- factorial_design(k = 3, runs = 8, blocks = 2, center = 2)
  # Two per block, two blocks, on top of the eight design runs.
  expect_equal(nrow(design$table), 12)
  expect_match(design$title, "4 center points")
})

test_that("the design table carries no FrF2 attributes", {
  design <- factorial_design(k = 3, runs = 8, blocks = 2)
  expect_null(attr(design$table, "design.info"))
  expect_null(attr(design$table, "desnum"))
  expect_null(attr(design$table, "run.order"))
  expect_identical(class(design$table), "data.frame")
})

test_that("block counts follow FrF2's rules and report what is available", {
  expect_equal(block_choices(8), c(1, 2, 4))
  expect_equal(block_choices(16), c(1, 2, 4, 8))
  expect_snapshot(error = TRUE, {
    factorial_design(k = 3, runs = 8, blocks = 3)
    factorial_design(k = 3, runs = 8, blocks = 16)
    factorial_design(k = 3, runs = 8, replications = 0)
    factorial_design(k = 3, runs = 8, blocks = 2, factor_names = c("Blocks", "B", "C"))
  })
})

test_that("a blocking FrF2 will not build reports its own reason", {
  # Validity is design-specific: 4 blocks is structurally allowed at 16 runs
  # but confounds a two-factor interaction in this design. FrF2 says so.
  expect_snapshot(error = TRUE, factorial_design(k = 6, runs = 16, blocks = 4))
})
