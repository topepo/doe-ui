test_that("the limits are the ones asked for", {
  expect_equal(
    mixture_sld_get_limits(),
    list(num_factors = c(2L, 10L), num_levels = c(2L, 5L))
  )
})

test_that("the app's ceilings sit inside mixexp's own", {
  # The levels ceiling is mixexp's. The factors ceiling is ours, below the
  # package's 12 because of how long SLD() takes to build its grid.
  limits <- mixture_sld_get_limits()
  expect_snapshot(error = TRUE, {
    mixexp::SLD(13, 2)
    mixexp::SLD(3, 6)
  })
  expect_no_error(mixexp::SLD(12, 2))
  expect_lt(limits$num_factors[2], 12)
  expect_equal(limits$num_levels[2], 5)
})

test_that("every size in range builds the whole lattice", {
  # A {q, m} lattice has choose(q + m - 1, m) blends, each a set of proportions
  # summing to one, and none repeated.
  limits <- mixture_sld_get_limits()
  for (num_factors in seq(limits$num_factors[1], limits$num_factors[2])) {
    for (num_levels in seq(limits$num_levels[1], limits$num_levels[2])) {
      design <- mixture_sld_create(num_factors, num_levels)
      expect_equal(
        nrow(design$table),
        choose(num_factors + num_levels - 1, num_levels),
        label = sprintf("%d factors, %d levels", num_factors, num_levels)
      )
      expect_true(all(abs(rowSums(design$table) - 1) < 1e-9))
      expect_equal(
        nrow(unique(round(design$table * num_levels))),
        nrow(design$table)
      )
    }
  }
})

test_that("the largest design builds in reasonable time", {
  # SLD() builds a (levels + 1)^factors grid, so this is where it is slowest.
  limits <- mixture_sld_get_limits()
  elapsed <- system.time(
    design <- mixture_sld_create(
      num_factors = limits$num_factors[2],
      num_levels = limits$num_levels[2]
    )
  )[["elapsed"]]
  expect_equal(nrow(design$table), 2002)
  expect_lt(elapsed, 15)
})

test_that("a design is plain proportions, named as asked", {
  expect_snapshot(mixture_sld_create(num_factors = 3, num_levels = 2))
  design <- mixture_sld_create(
    num_factors = 3,
    num_levels = 3,
    factor_names = c("Oil", "Water", "Soap")
  )
  expect_equal(names(design$table), c("Oil", "Water", "Soap"))
  expect_true(all(vapply(design$table, is.numeric, logical(1))))
  expect_gte(min(unlist(design$table)), 0)
  expect_lte(max(unlist(design$table)), 1)
  # Nothing of the package's travels with the table.
  expect_null(attr(design$table, "out.attrs"))
  # Left as mixexp computed them: a third is not rounded.
  expect_equal(max(design$table$Oil[design$table$Oil < 0.5]), 1 / 3)
})

test_that("replications stack complete copies of the lattice", {
  single <- mixture_sld_create(num_factors = 3, num_levels = 2)
  stacked <- mixture_sld_create(
    num_factors = 3,
    num_levels = 2,
    replications = 3
  )
  expect_equal(nrow(stacked$table), 18)
  # Each copy is the whole lattice in order, with no column added to mark it.
  expect_equal(stacked$table, rbind(single$table, single$table, single$table))
  expect_equal(names(stacked$table), names(single$table))
  expect_false(any(duplicated(single$table)))
  # The title reports the lattice's own run count, then the replication, as the
  # other designs do.
  expect_snapshot(stacked$title)
  # Nothing else about the design changes.
  expect_equal(stacked$notes, single$notes)
})

test_that("every size builds replicated", {
  design <- mixture_sld_create(
    num_factors = 10,
    num_levels = 5,
    replications = 2
  )
  expect_equal(nrow(design$table), 2 * 2002)
})

test_that("a lattice has every pure blend and every equal split", {
  design <- mixture_sld_create(num_factors = 4, num_levels = 2)
  expect_equal(nrow(design$table), 10)
  # The four pure components, and the six halves of two of them.
  expect_equal(sum(rowSums(design$table == 1) == 1), 4)
  expect_equal(sum(rowSums(design$table == 0.5) == 2), 6)
})

test_that("create explains what it cannot build", {
  expect_snapshot(error = TRUE, {
    mixture_sld_create(num_factors = 1, num_levels = 2)
    mixture_sld_create(num_factors = 11, num_levels = 2)
    mixture_sld_create(num_factors = 2.5, num_levels = 2)
    mixture_sld_create(num_factors = NA, num_levels = 2)
    mixture_sld_create(num_factors = 3, num_levels = 6)
    mixture_sld_create(num_factors = 3, num_levels = 1)
    mixture_sld_create(num_factors = 3, num_levels = 2.5)
    mixture_sld_create(num_factors = 3, num_levels = NA)
    mixture_sld_create(num_factors = 3, num_levels = c(2, 3))
    mixture_sld_create(num_factors = 3, num_levels = 2, replications = 0)
    mixture_sld_create(num_factors = 3, num_levels = 2, replications = 1.5)
    mixture_sld_create(num_factors = 3, num_levels = 2, replications = NA)
    mixture_sld_create(num_factors = 3, num_levels = 2, factor_names = "a")
  })
})

# ---- Simplex-centroid ---------------------------------------------------------

test_that("the centroid limits are the ones asked for", {
  expect_equal(mixture_scd_get_limits(), list(num_factors = c(2L, 10L)))
})

test_that("the centroid ceiling is ours, and the floor is the package's", {
  # SCD() has no ceiling: it builds 13 factors, 8191 blends, without complaint.
  expect_equal(nrow(mixexp::SCD(13)), 2^13 - 1)
  expect_lt(mixture_scd_get_limits()$num_factors[2], 13)
  # A single factor fails inside the package with an unhelpful message, so the
  # floor keeps it from ever being called.
  expect_snapshot(error = TRUE, mixexp::SCD(1))
})

test_that("every centroid size in range builds every subset once", {
  # One blend for each non-empty subset of the factors, in equal parts, so
  # 2^q - 1 in all, each summing to one and none repeated.
  limits <- mixture_scd_get_limits()
  for (num_factors in seq(limits$num_factors[1], limits$num_factors[2])) {
    design <- mixture_scd_create(num_factors)
    expect_equal(nrow(design$table), 2^num_factors - 1)
    expect_true(all(abs(rowSums(design$table) - 1) < 1e-9))
    expect_false(any(duplicated(design$table)))
    # Equal parts: every blend's nonzero proportions are the same.
    equal_parts <- apply(design$table, 1, function(x) {
      length(unique(round(x[x > 0], 9))) == 1
    })
    expect_true(all(equal_parts))
  }
})

test_that("a centroid design is plain proportions, named as asked", {
  expect_snapshot(mixture_scd_create(num_factors = 3))
  design <- mixture_scd_create(
    num_factors = 3,
    factor_names = c("Oil", "Water", "Soap")
  )
  expect_equal(names(design$table), c("Oil", "Water", "Soap"))
  expect_true(all(vapply(design$table, is.numeric, logical(1))))
  # The overall centroid is in there, as a third each, unrounded.
  expect_true(any(design$table$Oil == 1 / 3))
  expect_null(attr(design$table, "out.attrs"))
})

test_that("centroid replications stack complete copies of the design", {
  single <- mixture_scd_create(num_factors = 4)
  stacked <- mixture_scd_create(num_factors = 4, replications = 3)
  expect_equal(nrow(stacked$table), 3 * 15)
  expect_equal(stacked$table, rbind(single$table, single$table, single$table))
  expect_snapshot(stacked$title)
  expect_equal(stacked$notes, single$notes)
})

test_that("the largest centroid design builds in reasonable time", {
  limits <- mixture_scd_get_limits()
  elapsed <- system.time(
    design <- mixture_scd_create(
      num_factors = limits$num_factors[2],
      replications = 2
    )
  )[["elapsed"]]
  expect_equal(nrow(design$table), 2 * 1023)
  expect_lt(elapsed, 15)
})

test_that("centroid create explains what it cannot build", {
  expect_snapshot(error = TRUE, {
    mixture_scd_create(num_factors = 1)
    mixture_scd_create(num_factors = 11)
    mixture_scd_create(num_factors = 2.5)
    mixture_scd_create(num_factors = NA)
    mixture_scd_create(num_factors = 3, replications = 0)
    mixture_scd_create(num_factors = 3, replications = 1.5)
    mixture_scd_create(num_factors = 3, replications = NA)
    mixture_scd_create(num_factors = 3, factor_names = "a")
  })
})

test_that("the two mixture designs agree where they overlap", {
  # A {q, 1} lattice is the q pure components, which are also the first q
  # blends of the centroid design. Different functions, one answer. Compared
  # after the same sort, so the order each package happens to use is not tested.
  canonical <- function(x) {
    x <- unname(as.matrix(x))
    x[do.call(order, as.data.frame(x)), ]
  }
  pure_lattice <- canonical(mixexp::SLD(4, 1))
  pure_centroid <- canonical(mixture_scd_create(num_factors = 4)$table[1:4, ])
  expect_equal(pure_centroid, pure_lattice)
})
