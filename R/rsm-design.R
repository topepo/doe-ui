# Response surface designs, from rsm. Pure computation: no Shiny here, so every
# function below is testable on its own.
#
# This file implements the design contract described in the README for the
# central composite design:
#
#   rsm_ccd_get_packages()   packages this design needs
#   rsm_ccd_get_limits()     integer range of each count option
#   rsm_ccd_get_types()      the named axial distances rsm offers
#   rsm_ccd_create()         builds the doe_design
#
# There is no *_choices() helper: every factor count and center-point count in
# range builds, so there is no list of values to filter. Nor is there a
# num_runs argument: a CCD's run count is derived from its other options. Nor
# a *_get_notes(): rsm attaches nothing about the axial distance or the block
# layout, so the notes are read off the built table in _create().

# ---- Central composite designs (rsm) -----------------------------------------
#
# A CCD is a two-level factorial "cube" plus axial "star" points at +/- alpha
# on each factor axis, plus center points. rsm builds it as blocked: the cube
# and the axial points are separate blocks, each with its own center points.

# Returns: an unnamed character vector of package names.
rsm_ccd_get_packages <- function() {
  "rsm"
}

# Returns: a named list of integer vectors of length 2, each c(min, max)
# inclusive: list(num_factors = c(2L, 8L), center = c(0L, 20L)).
#
# Both ceilings are practical limits of ours, not rsm's. ccd() builds the cube
# as a full factorial when given only a factor count, so the cube doubles with
# every factor: 8 factors is a 256-point cube, matching FACTORIAL_MAX_RUNS, and
# ccd() builds 10 factors (3162 runs, 3 replicates) in under 0.01 s, so time is
# not the constraint. Past 8 factors a CCD normally uses a fractional cube,
# which rsm supports through generators but this app does not yet offer.
#
# The floor of 2 factors is ours too: ccd(1) builds without complaint, but a
# one-factor "composite" has no cube to speak of.
#
# The center-point ceiling only keeps a typo from building a huge table;
# rsm has none.
rsm_ccd_get_limits <- function() {
  list(num_factors = c(2L, 8L), center = c(0L, 20L))
}

# Returns: a character vector of rsm's own alpha ids, named by the label to
# show. A numeric alpha is also accepted by rsm_ccd_create(); it is not a type,
# because it is not one of the package's named choices.
#
# rsm computes the distance for each of these from the factor count, the
# center points and the blocking. The value it chose is read back off the
# built design and reported in the title, not computed here.
rsm_ccd_get_types <- function() {
  c(
    "Orthogonal blocking" = "orthogonal",
    "Rotatable" = "rotatable",
    "Spherical" = "spherical",
    "Face-centered" = "faces"
  )
}

# The rows of a built table that are axial points: exactly one factor away
# from zero. Cube points have every factor at +/-1 and center points none.
rsm_ccd_axial_rows <- function(table, factor_names) {
  rowSums(as.matrix(table[factor_names]) != 0) == 1
}

# Which blocks hold what, read off the table rather than assumed from how rsm
# happens to number them today.
rsm_ccd_block_note <- function(table, factor_names) {
  axial_blocks <- unique(table$Block[rsm_ccd_axial_rows(table, factor_names)])
  cube_blocks <- setdiff(unique(table$Block), axial_blocks)
  plural <- function(x) if (length(x) == 1) "block" else "blocks"
  sprintf(
    "Cube points are in %s %s and axial points in %s %s.",
    plural(cube_blocks),
    paste(cube_blocks, collapse = ", "),
    plural(axial_blocks),
    paste(axial_blocks, collapse = ", ")
  )
}

# Returns: a doe_design — see new_design(). The table holds rsm's Block column
# then one column per factor, in rsm's standard order within each block; the
# order columns are added later, by the app.
#
# A central composite design.
#
#   num_factors  within rsm_ccd_get_limits()$num_factors
#   center       center points in each block, within
#                rsm_ccd_get_limits()$center
#   alpha        axial distance: an id from rsm_ccd_get_types(), or a single
#                positive number
#   replications times the whole design is carried out; each replicate gets
#                its own cube and axial blocks (rsm's bbreps)
#   factor_names column names, one per factor
#
# center and alpha default to rsm's own defaults.
rsm_ccd_create <- function(
  num_factors,
  center = 4,
  alpha = "orthogonal",
  replications = 1,
  factor_names = default_factor_names(num_factors)
) {
  limits <- rsm_ccd_get_limits()
  # Checked before the range comparison below, which would otherwise be NA and
  # fail with "missing value where TRUE/FALSE needed" rather than a message.
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (num_factors < limits$num_factors[1] || num_factors > limits$num_factors[2]) {
    stop_out_of_range(num_factors, limits$num_factors, "Number of factors")
  }
  stop_unless(
    length(center) == 1 && !is.na(center) && center == round(center),
    "Center points must be a whole number."
  )
  if (center < limits$center[1] || center > limits$center[2]) {
    stop_out_of_range(center, limits$center, "Center points per block")
  }
  stop_unless(
    length(replications) == 1 &&
      !is.na(replications) &&
      replications >= 1 &&
      replications == round(replications),
    "Replications must be a whole number of at least 1."
  )
  # rsm partially matches a string and silently does something else with one
  # it does not recognise, and accepts a negative number, which just swaps the
  # two axial points. Both are stopped here instead.
  types <- rsm_ccd_get_types()
  if (is.character(alpha)) {
    if (length(alpha) != 1 || !alpha %in% types) {
      stop_unavailable(alpha, types, "axial distance")
    }
    alpha_label <- names(types)[types == alpha]
  } else {
    stop_unless(
      length(alpha) == 1 && is.numeric(alpha) && !is.na(alpha) && alpha > 0,
      "Axial distance must be one of the named choices or a positive number."
    )
    alpha_label <- "Custom"
  }
  stop_unless(
    length(factor_names) == num_factors,
    sprintf("Give %d factor names, not %d.", num_factors, length(factor_names))
  )
  stop_unless(
    !"Block" %in% factor_names,
    "\"Block\" is reserved for the block column; rename that factor."
  )

  design <- rsm::ccd(
    basis = num_factors,
    n0 = center,
    alpha = alpha,
    bbreps = replications,
    randomize = FALSE
  )

  # Rebuilt column by column rather than handed over: rsm's coded.data carries
  # codings and rsdes attributes, plus its own run.order and std.order
  # columns, which the app adds for itself.
  #
  # Factor names are applied here rather than passed to rsm. rsm takes them
  # through a formula, so they would have to be syntactic R names, and "Temp
  # (C)" is not. Nothing rsm reports refers to them, so renaming afterwards
  # leaves nothing describing a factor by the wrong label.
  #
  # Block keeps rsm's labels as character, not numbers: they are labels.
  raw <- as.data.frame(design)
  rsm_names <- attr(design, "rsdes")$primary
  columns <- c(
    list(Block = as.character(raw$Block)),
    stats::setNames(lapply(rsm_names, function(x) as.numeric(raw[[x]])), factor_names)
  )
  table <- tibble::as_tibble(columns)

  # The distance rsm chose, read off its axial points.
  axial <- as.matrix(table[factor_names])[
    rsm_ccd_axial_rows(table, factor_names),
    ,
    drop = FALSE
  ]
  alpha_value <- max(abs(axial))

  new_design(
    table,
    sprintf(
      "Central composite design – %d factors, %d runs%s",
      num_factors,
      nrow(table),
      if (replications > 1) sprintf(", %d replications", replications) else ""
    ),
    c(
      sprintf(
        "Axial distance %s (%s).",
        format(signif(alpha_value, 4)),
        tolower(alpha_label)
      ),
      rsm_ccd_block_note(table, factor_names),
      sprintf("Each block has %d center point%s.", center, if (center == 1) "" else "s")
    )
  )
}
