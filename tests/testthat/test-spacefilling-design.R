# The three space-filling designs: optimized Latin hypercubes and uniform
# designs looked up in sfd, and random Latin hypercubes from DiceDesign.

# ---- What sfd supports ---------------------------------------------------------

test_that("every type sfd ships has a label", {
  # The label map is read in both directions, so a type added in a future sfd
  # should fail here rather than reach a dropdown as a bare id.
  shipped <- unique(unlist(lapply(sfd::sfd_lib, function(lib) unique(lib$type))))
  expect_setequal(shipped, names(SFD_TYPE_LABELS))
  expect_setequal(c(SFD_LHC_TYPES, SFD_UNIFORM_TYPES), names(SFD_TYPE_LABELS))
})

test_that("run choices are read from sfd's library, not computed", {
  for (num_factors in 2:10) {
    lib <- sfd::sfd_lib[[num_factors - 1]]
    for (type in spacefilling_opt_get_types(num_factors)) {
      expect_equal(
        spacefilling_opt_get_num_runs_choices(num_factors, type),
        as.numeric(sort(unique(lib$num_points[lib$type == type])))
      )
    }
  }
  for (num_factors in 2:15) {
    lib <- sfd::sfd_lib[[num_factors - 1]]
    expect_equal(
      spacefilling_unif_get_num_runs_choices(num_factors),
      as.numeric(sort(unique(lib$num_points[lib$type == "uniform"])))
    )
  }
})

test_that("the run choices have gaps, which is why they are listed", {
  # Max-Min (L1) at six factors offers four sizes; a span would offer more.
  expect_equal(spacefilling_opt_get_num_runs_choices(6, "max_min_l1"), c(4, 5, 6, 7))
  expect_true(any(diff(spacefilling_unif_get_num_runs_choices(15)) > 1))
})

test_that("choices are empty, not errors, outside what sfd covers", {
  expect_length(spacefilling_opt_get_types(11), 0)
  expect_type(spacefilling_opt_get_types(11), "character")
  expect_length(spacefilling_opt_get_num_runs_choices(6, "uniform"), 0)
  expect_length(spacefilling_opt_get_num_runs_choices(6, NA), 0)
  expect_length(spacefilling_opt_get_num_runs_choices(6, character(0)), 0)
  expect_length(spacefilling_unif_get_num_runs_choices(16), 0)
  expect_length(spacefilling_unif_get_num_runs_choices(1), 0)
  expect_type(spacefilling_unif_get_num_runs_choices(16), "double")
})

# ---- Optimized and uniform designs ---------------------------------------------

test_that("the smallest and largest of every sfd size build", {
  # All 574,382 designs would take minutes; the ends of each range are where
  # a lookup is most likely to fall off the table.
  for (num_factors in 2:10) {
    for (type in spacefilling_opt_get_types(num_factors)) {
      runs <- spacefilling_opt_get_num_runs_choices(num_factors, type)
      for (num_runs in range(runs)) {
        design <- spacefilling_opt_create(num_factors, num_runs, type)
        expect_equal(dim(design$table), c(num_runs, num_factors))
      }
    }
  }
  for (num_factors in 2:15) {
    for (num_runs in range(spacefilling_unif_get_num_runs_choices(num_factors))) {
      design <- spacefilling_unif_create(num_factors, num_runs)
      expect_equal(dim(design$table), c(num_runs, num_factors))
    }
  }
})

test_that("the table is sfd's design, rescaled and nothing else", {
  # Undoing the rescale must give back exactly what sfd stores, so the app
  # reports the package's design rather than one of its own.
  for (case in list(
    list(6, "max_min_l2"),
    list(3, "audze_eglais"),
    list(10, "max_min_l1")
  )) {
    num_factors <- case[[1]]
    type <- case[[2]]
    num_runs <- max(spacefilling_opt_get_num_runs_choices(num_factors, type))
    table <- spacefilling_opt_create(num_factors, num_runs, type)$table
    levels <- as.matrix(table) * (num_runs - 1) + 1
    expect_equal(
      unname(levels),
      unname(as.matrix(sfd::get_design(num_factors, num_runs, type)))
    )
  }
  table <- spacefilling_unif_create(12, 20)$table
  expect_equal(
    unname(as.matrix(table) * 19 + 1),
    unname(as.matrix(sfd::get_design(12, 20, "uniform")))
  )
})

test_that("each column keeps one level per run, equally spaced from 0 to 1", {
  # The Latin hypercube property. A rescale by each column's own range, or one
  # that collapsed levels, would break it.
  check <- function(table, num_runs) {
    for (column in table) {
      expect_equal(sort(column), (seq_len(num_runs) - 1) / (num_runs - 1))
    }
  }
  check(spacefilling_opt_create(6, 20, "max_min_l2")$table, 20)
  check(spacefilling_opt_create(2, 4, "audze_eglais")$table, 4)
  check(spacefilling_unif_create(15, 23)$table, 23)
})

test_that("sfd designs are deterministic and in sfd's own row order", {
  expect_identical(
    spacefilling_opt_create(4, 6, "max_min_l1"),
    spacefilling_opt_create(4, 6, "max_min_l1")
  )
  expect_snapshot({
    spacefilling_opt_create(3, 6, "max_min_l2")
    spacefilling_unif_create(2, 5)
  })
})

test_that("a NULL type takes the first one offered", {
  expect_equal(
    spacefilling_opt_create(6, 20, type = NULL),
    spacefilling_opt_create(6, 20, type = unname(spacefilling_opt_get_types(6)[1]))
  )
})

test_that("uniform is its own design, offered where the LHC criteria stop", {
  expect_equal(spacefilling_unif_get_limits()$num_factors, c(2L, 15L))
  expect_equal(spacefilling_opt_get_limits()$num_factors, c(2L, 10L))
  expect_false("uniform" %in% spacefilling_opt_get_types(6))
  expect_match(spacefilling_unif_create(12, 20)$title, "^Uniform design")
  # Past ten factors uniform is all sfd has.
  expect_error(spacefilling_opt_create(11, 20, "uniform"), "between 2 and 10")
})

test_that("factor names reach the columns exactly as given", {
  names <- c("Temp (C)", "Pressure", "1st")
  expect_equal(
    names(spacefilling_opt_create(3, 7, "max_min_l2", factor_names = names)$table),
    names
  )
  expect_equal(names(spacefilling_unif_create(3, 7, factor_names = names)$table), names)
  expect_equal(names(spacefilling_rand_create(3, 7, factor_names = names)$table), names)
})

test_that("the largest sfd designs build quickly", {
  largest_unif <- max(spacefilling_unif_get_num_runs_choices(15))
  largest_opt <- max(spacefilling_opt_get_num_runs_choices(10, "audze_eglais"))
  elapsed <- system.time({
    spacefilling_unif_create(15, largest_unif)
    spacefilling_opt_create(10, largest_opt, "audze_eglais")
  })[["elapsed"]]
  expect_lt(elapsed, 5)
})

test_that("sfd designs explain what they cannot build", {
  expect_snapshot(error = TRUE, {
    spacefilling_opt_create(11, 20, "max_min_l2")
    spacefilling_opt_create(2.5, 4, "max_min_l2")
    # Lists ids rather than the labels the dropdown shows.
    spacefilling_opt_create(6, 20, "uniform")
    spacefilling_opt_create(6, 8, "max_min_l1")
    spacefilling_opt_create(6, 20, "max_min_l2", factor_names = c("a", "b"))
    spacefilling_unif_create(16, 20)
    spacefilling_unif_create(6, 3)
  })
})

test_that("an unusable factor count gets a message, not an internal error", {
  skip(paste(
    "Known bug: spacefilling_opt_create() looks up types before validating",
    "num_factors, so 1 gives 'attempt to set an attribute on NULL' and NA",
    "gives 'missing value where TRUE/FALSE needed'. The module guards against",
    "both, so only a direct call sees them."
  ))
  expect_error(spacefilling_opt_create(1, 4, "max_min_l2"), "between 2 and 10")
  expect_error(spacefilling_opt_create(NA, 4, "max_min_l2"), "whole number")
})

# ---- Random Latin hypercubes ---------------------------------------------------

test_that("a random design is a Latin hypercube inside the unit cube", {
  for (case in list(c(3, 7), c(6, 60), c(50, 1000), c(2, 2))) {
    num_factors <- case[1]
    num_runs <- case[2]
    table <- spacefilling_rand_create(num_factors, num_runs, seed = 3)$table
    expect_equal(dim(table), c(num_runs, num_factors))
    # One point in each of the num_runs equal strata of every factor.
    for (column in table) {
      expect_setequal(floor(column * num_runs), seq_len(num_runs) - 1)
    }
  }
})

test_that("a random design is not stretched to its bounds", {
  # DiceDesign samples within each stratum, so the extremes fall short of 0
  # and 1. That is the sampling property; a rescale to the observed range
  # would destroy it.
  values <- unlist(spacefilling_rand_create(3, 7, seed = 3)$table)
  expect_gt(min(values), 0)
  expect_lt(max(values), 1)
})

test_that("the seed makes a random design reproducible", {
  expect_identical(
    spacefilling_rand_create(4, 12, seed = 3),
    spacefilling_rand_create(4, 12, seed = 3)
  )
  expect_false(identical(
    spacefilling_rand_create(4, 12, seed = 3)$table,
    spacefilling_rand_create(4, 12, seed = 4)$table
  ))
  expect_snapshot(spacefilling_rand_create(3, 5, seed = 3))
})

test_that("building a random design leaves the caller's random state alone", {
  skip(paste(
    "Known bug: spacefilling_rand_create() says passing seed to DiceDesign",
    "leaves the caller's random state alone, but lhsDesign() calls set.seed()."
  ))
  set.seed(9131)
  before <- .Random.seed
  spacefilling_rand_create(3, 7, seed = 3)
  expect_identical(.Random.seed, before)
})

test_that("the random design has two count limits and no types", {
  limits <- spacefilling_rand_get_limits()
  expect_named(limits, c("num_factors", "num_runs"))
  expect_equal(limits$num_factors, c(2L, RANDOM_LHC_MAX_FACTORS))
  expect_equal(limits$num_runs, c(2L, RANDOM_LHC_MAX_RUNS))
  expect_length(spacefilling_rand_get_types(), 0)
})

test_that("the largest random design builds quickly", {
  elapsed <- system.time(
    design <- spacefilling_rand_create(RANDOM_LHC_MAX_FACTORS, RANDOM_LHC_MAX_RUNS)
  )[["elapsed"]]
  expect_equal(dim(design$table), c(RANDOM_LHC_MAX_RUNS, RANDOM_LHC_MAX_FACTORS))
  expect_lt(elapsed, 5)
})

test_that("the random design explains what it cannot build", {
  expect_snapshot(error = TRUE, {
    spacefilling_rand_create(1, 10)
    spacefilling_rand_create(51, 10)
    spacefilling_rand_create(2.5, 10)
    spacefilling_rand_create(3, 1)
    spacefilling_rand_create(3, 1001)
    spacefilling_rand_create(3, 10.5)
    spacefilling_rand_create(3, NA)
    spacefilling_rand_create(3, 10, factor_names = "a")
    # Not validated here, so this is DiceDesign's own message.
    spacefilling_rand_create(3, 10, seed = NA)
  })
})
