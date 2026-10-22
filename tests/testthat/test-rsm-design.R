test_that("the CCD limits are the ones declared", {
  expect_equal(
    rsm_ccd_get_limits(),
    list(num_factors = c(2L, 8L), center = c(0L, 20L))
  )
})

test_that("the factor ceiling is ours, not rsm's", {
  # rsm builds past it without complaint; the ceiling is the full-factorial
  # cube reaching 256 points, matching the factorial's own run ceiling.
  expect_no_error(rsm::ccd(10, randomize = FALSE))
  expect_equal(2^rsm_ccd_get_limits()$num_factors[2], FACTORIAL_MAX_RUNS)
})

test_that("the types are rsm's own alpha ids", {
  types <- rsm_ccd_get_types()
  expect_equal(
    unname(types),
    c("orthogonal", "rotatable", "spherical", "faces")
  )
  # Each one builds, and rsm places the axial points where it says it does.
  for (type in types) {
    expect_s3_class(rsm_ccd_create(3, alpha = type), "doe_design")
  }
})

test_that("every size in range builds a cube, axial points and centers", {
  limits <- rsm_ccd_get_limits()
  for (num_factors in seq(limits$num_factors[1], limits$num_factors[2])) {
    design <- rsm_ccd_create(num_factors, center = 2)
    factors <- default_factor_names(num_factors)
    values <- as.matrix(design$table[factors])
    nonzero <- rowSums(values != 0)
    label <- sprintf("%d factors", num_factors)
    expect_equal(sum(nonzero == num_factors), 2^num_factors, label = label)
    expect_equal(sum(nonzero == 1), 2 * num_factors, label = label)
    # Two blocks, each with its own center points.
    expect_equal(sum(nonzero == 0), 4, label = label)
    expect_equal(
      nrow(design$table),
      2^num_factors + 2 * num_factors + 4,
      label = label
    )
  }
})

test_that("the axial distance reported is the one rsm used", {
  # Rotatable is (2^k)^(1/4) and spherical sqrt(k), for a full-factorial cube.
  expect_match(
    rsm_ccd_create(3, alpha = "rotatable")$notes[1],
    "Axial distance 1.682 (rotatable)",
    fixed = TRUE
  )
  expect_match(
    rsm_ccd_create(4, alpha = "spherical")$notes[1],
    "Axial distance 2 (spherical)",
    fixed = TRUE
  )
  expect_match(
    rsm_ccd_create(3, alpha = "faces")$notes[1],
    "Axial distance 1 (face-centered)",
    fixed = TRUE
  )
  custom <- rsm_ccd_create(3, alpha = 1.25)
  expect_match(custom$notes[1], "Axial distance 1.25 (custom)", fixed = TRUE)
  expect_equal(max(abs(as.matrix(custom$table[LETTERS[1:3]]))), 1.25)
})

test_that("a design is a plain table, named as asked", {
  expect_snapshot(rsm_ccd_create(num_factors = 2, center = 1))
  design <- rsm_ccd_create(
    num_factors = 3,
    factor_names = c("Temp (C)", "Pressure", "Time")
  )
  # Non-syntactic names work, because they are applied after rsm.
  expect_equal(names(design$table), c("Block", "Temp (C)", "Pressure", "Time"))
  # Block labels stay labels.
  expect_type(design$table$Block, "character")
  # Nothing of rsm's travels with the table: not its attributes, nor its own
  # order columns.
  expect_null(attr(design$table, "codings"))
  expect_null(attr(design$table, "rsdes"))
  expect_false(any(c("run.order", "std.order") %in% names(design$table)))
})

test_that("replications repeat cube and axial points, not center points", {
  single <- rsm_ccd_create(num_factors = 2, center = 1)
  replicated <- rsm_ccd_create(num_factors = 2, center = 1, replications = 3)
  count <- function(design) {
    nonzero <- rowSums(as.matrix(design$table[c("A", "B")]) != 0)
    table(design$table$Block, nonzero)
  }
  # Cube (2 nonzero) and axial (1 nonzero) points triple; centers (0) do not.
  expect_equal(count(replicated)[, "2"], 3 * count(single)[, "2"])
  expect_equal(count(replicated)[, "1"], 3 * count(single)[, "1"])
  expect_equal(count(replicated)[, "0"], count(single)[, "0"])
  # Still one cube block and one axial block.
  expect_equal(sort(unique(replicated$table$Block)), c("1", "2"))
  expect_snapshot(replicated$notes)
  expect_snapshot(replicated$title)
})

test_that("only orthogonal blocking is blocked", {
  blocked <- rsm_ccd_create(num_factors = 3, center = 2, alpha = "orthogonal")
  expect_equal(sort(unique(blocked$table$Block)), c("1", "2"))
  # Center points per block, so four in all.
  expect_equal(nrow(blocked$table), 8 + 6 + 2 * 2)

  for (alpha in list("rotatable", "spherical", "faces", 1.3)) {
    design <- rsm_ccd_create(num_factors = 3, center = 2, alpha = alpha)
    label <- format(alpha)
    # Same columns either way, with every run in block 1.
    expect_equal(names(design$table), names(blocked$table), label = label)
    expect_equal(unique(design$table$Block), "1", label = label)
    # The center count is the total in the one block.
    centers <- rowSums(as.matrix(design$table[LETTERS[1:3]]) != 0) == 0
    expect_equal(sum(centers), 2, label = label)
    expect_equal(nrow(design$table), 8 + 6 + 2, label = label)
    expect_match(design$notes[2], "single block", label = label)
  }
  expect_snapshot(rsm_ccd_create(num_factors = 2, center = 2, alpha = "rotatable"))
})

test_that("zero center points is allowed", {
  design <- rsm_ccd_create(num_factors = 2, center = 0, alpha = "rotatable")
  expect_equal(nrow(design$table), 8)
  expect_match(design$notes[3], "0 center points")
})

test_that("the largest design builds quickly", {
  limits <- rsm_ccd_get_limits()
  elapsed <- system.time(
    design <- rsm_ccd_create(
      num_factors = limits$num_factors[2],
      center = limits$center[2],
      replications = 3
    )
  )[["elapsed"]]
  expect_equal(nrow(design$table), 3 * (256 + 16) + 2 * 20)
  expect_lt(elapsed, 5)
})

test_that("create explains what it cannot build", {
  expect_snapshot(error = TRUE, {
    rsm_ccd_create(num_factors = 1)
    rsm_ccd_create(num_factors = 9)
    rsm_ccd_create(num_factors = 2.5)
    rsm_ccd_create(num_factors = NA)
    rsm_ccd_create(num_factors = 3, center = -1)
    rsm_ccd_create(num_factors = 3, center = 21)
    rsm_ccd_create(num_factors = 3, center = 1.5)
    rsm_ccd_create(num_factors = 3, alpha = "bogus")
    rsm_ccd_create(num_factors = 3, alpha = "rot")
    rsm_ccd_create(num_factors = 3, alpha = -1)
    rsm_ccd_create(num_factors = 3, alpha = 0)
    rsm_ccd_create(num_factors = 3, alpha = NA_real_)
    rsm_ccd_create(num_factors = 3, replications = 0)
    rsm_ccd_create(num_factors = 3, replications = 1.5)
    rsm_ccd_create(num_factors = 3, factor_names = "a")
    rsm_ccd_create(num_factors = 2, factor_names = c("Block", "B"))
  })
})
