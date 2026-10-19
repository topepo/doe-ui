test_that("the arrays offered are the saturated two-level ones in the catalog", {
  catalog <- DoE.base::oacat
  # Every array offered exists in DoE.base's own catalog, under its own name.
  expect_true(all(taguchi_support$name %in% catalog$name))
  expect_false(is.unsorted(taguchi_support$num_runs))
  # Saturated: one column for each degree of freedom the runs provide.
  expect_equal(taguchi_support$num_columns, taguchi_support$num_runs - 1L)
  # The near-miss arrays hold only two-level columns but are not Taguchi
  # arrays, and must not be offered.
  expect_true(all(c("L256.2.19", "L2048.2.63") %in% catalog$name))
  expect_false(any(c("L256.2.19", "L2048.2.63") %in% taguchi_support$name))
})

test_that("choices are the arrays wide enough for the factors", {
  expect_snapshot({
    taguchi_get_num_runs_choices(7)[1:4]
    taguchi_get_num_runs_choices(8)[1:3]
    taguchi_get_num_runs_choices(139)
  })
  expect_length(taguchi_get_num_runs_choices(140), 0)
})

test_that("every offered run count builds", {
  # The point of reading the choices from the catalog: nothing in the dropdown
  # fails when it is picked. Both ends of every array's range, since the base
  # arrays and the arrays built from a lineage take different routes through
  # oa.design().
  for (i in seq_len(nrow(taguchi_support))) {
    num_runs <- taguchi_support$num_runs[i]
    num_columns <- taguchi_support$num_columns[i]
    for (num_factors in unique(c(2L, num_columns))) {
      design <- taguchi_create(num_factors, num_runs)
      expect_equal(dim(design$table), c(num_runs, num_factors))
    }
  }
})

test_that("the array asked for is the array built", {
  # Handing oa.design() only a run count lets it choose for itself, and it
  # builds a replicated full factorial or a mixed-level array. Pinning the
  # catalog id is what prevents that, so check the package agrees on every
  # array.
  for (i in seq_len(nrow(taguchi_support))) {
    built <- taguchi_oa_design(taguchi_support$name[i], 2L)
    expect_equal(
      attr(built, "design.info")$generating.oa,
      taguchi_support$name[i]
    )
  }
})

test_that("a design is plain numbers on the -1/+1 scale, in standard order", {
  design <- taguchi_create(num_factors = 5, num_runs = 8)
  expect_snapshot(design)
  expect_true(all(vapply(design$table, is.numeric, logical(1))))
  expect_equal(sort(unique(unlist(design$table))), c(-1, 1))
  # Standard order: the first column changes slowest.
  expect_equal(design$table$A, rep(c(-1, 1), each = 4))
  # Nothing of the package's travels with the table.
  expect_null(attr(design$table, "design.info"))
})

test_that("a saturated array has no residual degrees of freedom", {
  expect_snapshot({
    taguchi_create(num_factors = 7, num_runs = 8)$notes
    taguchi_create(num_factors = 3, num_runs = 12)$notes
    taguchi_create(num_factors = 139, num_runs = 140)$notes
  })
})

test_that("factor names reach the columns exactly as given", {
  # oa.design() would turn these into "Temp..C." and "X1st".
  design <- taguchi_create(
    num_factors = 3,
    num_runs = 8,
    factor_names = c("Temp (C)", "Pressure", "1st")
  )
  expect_equal(names(design$table), c("Temp (C)", "Pressure", "1st"))
})

test_that("replications stack complete copies of the array", {
  single <- taguchi_create(num_factors = 3, num_runs = 8)
  stacked <- taguchi_create(num_factors = 3, num_runs = 8, replications = 3)
  expect_equal(nrow(stacked$table), 24)
  # Each copy is the whole array in standard order, so the table is the
  # single design repeated, with no column added to mark the copy.
  expect_equal(stacked$table, rbind(single$table, single$table, single$table))
  expect_equal(names(stacked$table), names(single$table))
  expect_snapshot({
    stacked$title
    stacked$notes
    single$notes
  })
})

test_that("every array builds replicated", {
  for (num_runs in taguchi_support$num_runs) {
    design <- taguchi_create(num_factors = 2, num_runs = num_runs, replications = 2)
    expect_equal(nrow(design$table), 2 * num_runs)
  }
})

test_that("the widest array builds quickly", {
  elapsed <- system.time(
    design <- taguchi_create(num_factors = 139, num_runs = 140)
  )[["elapsed"]]
  expect_equal(dim(design$table), c(140L, 139L))
  expect_lt(elapsed, 10)
})

test_that("create explains what it cannot build", {
  expect_snapshot(error = TRUE, {
    taguchi_create(num_factors = 1, num_runs = 8)
    taguchi_create(num_factors = 140, num_runs = 140)
    taguchi_create(num_factors = 2.5, num_runs = 8)
    taguchi_create(num_factors = NA, num_runs = 8)
    taguchi_create(num_factors = 5, num_runs = 6)
    taguchi_create(num_factors = 20, num_runs = 16)
    taguchi_create(num_factors = 5, num_runs = c(8, 12))
    taguchi_create(num_factors = 5, num_runs = 8, replications = 0)
    taguchi_create(num_factors = 5, num_runs = 8, replications = 1.5)
    taguchi_create(num_factors = 5, num_runs = 8, replications = NA)
    taguchi_create(num_factors = 5, num_runs = 8, factor_names = c("a", "b"))
  })
})
