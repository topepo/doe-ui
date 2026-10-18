# Space-filling designs. Two of them, because they disagree about what the
# user gets to choose:
#
# - Optimized designs are precomputed and looked up in the sfd package. Four
#   types up to ten factors, and uniform alone from eleven to fifteen, each
#   available only at particular run counts.
# - Random designs are unconstrained Latin hypercubes from DiceDesign. Almost
#   any number of factors and runs, and no type to choose.
#
# That difference is why they are two registry entries rather than one design
# with a type: switching between them changes which inputs are on screen, not
# just what a generator does with them.
#
# Pure computation: no Shiny here.

# ---- Shared ------------------------------------------------------------------

# What sfd holds, summarised once when Shiny sources this file: a list indexed
# from two factors up, each element naming the run counts every type offers at
# that many factors. Scanning all fourteen tables takes about a tenth of a
# second, which is worth paying once rather than on every keystroke.
SFD_SUPPORT <- lapply(seq_along(sfd::sfd_lib), function(i) {
  designs <- sfd::sfd_lib[[i]]
  lapply(split(designs$num_points, designs$type), function(x) sort(unique(x)))
})

# The package's type ids, and the labels we show for them. One map, read in
# both directions, so a new type in a future sfd version shows up as a missing
# label rather than silently as an id.
SFD_TYPE_LABELS <- c(
  audze_eglais = "Audze-Eglais",
  max_min_l1 = "Max-Min (L1)",
  max_min_l2 = "Max-Min (L2)",
  uniform = "Uniform"
)

# Which types belong to which design. The three criteria below optimise a
# Latin hypercube; a uniform design is built to a different criterion and is
# not an LHC at all, so it is a design of its own rather than a type within
# one.
#
# They differ in reach as well as in kind: the LHC criteria exist for 2 to 10
# factors, uniform for 2 to 15. One entry covering both would have to claim
# the wider range and then fail on most of it.
SFD_LHC_TYPES <- c("audze_eglais", "max_min_l1", "max_min_l2")
SFD_UNIFORM_TYPES <- "uniform"

sfd_labels <- function(ids) {
  unname(SFD_TYPE_LABELS[ids])
}

# Returns: a named list of the run counts each of `types` offers at this many
# factors, keyed by the package's type ids. Types with nothing here are left
# out, so the result can be empty.
sfd_list <- function(num_factors, types = names(SFD_TYPE_LABELS)) {
  index <- num_factors - 1
  if (index < 1 || index > length(SFD_SUPPORT)) {
    return(list())
  }
  available <- SFD_SUPPORT[[index]]
  available[intersect(types, names(available))]
}

# Returns: c(min, max) of the factor counts where any of `types` has a design.
# Derived rather than written down, so it follows the installed sfd.
sfd_factor_range <- function(types) {
  covered <- which(vapply(
    SFD_SUPPORT,
    function(available) any(types %in% names(available)),
    logical(1)
  ))
  range(covered) + 1L
}

# Build the table for one sfd design. Shared, because the optimized and
# uniform designs differ in which types they offer, not in how they are built.
sfd_table <- function(num_factors, num_runs, type, factor_names) {
  points <- sfd::get_design(num_factors, num_runs, type)
  # sfd returns integer levels 1 to num_runs; rescale to [0, 1] so these read
  # on the same scale as the random design.
  #
  # Divided by num_runs rather than each column's own maximum: every column is
  # a permutation of 1 to n so the two agree today, but the per-column version
  # would silently rescale each factor differently if that ever stopped
  # holding.
  table <- tibble::as_tibble(points)
  table[] <- lapply(table, function(level) (level - 1) / (num_runs - 1))
  names(table) <- factor_names
  table
}

# Validate the options shared by both sfd designs, then build. `types` is the
# set this design offers.
sfd_create <- function(num_factors, num_runs, type, factor_names, types) {
  limits <- sfd_factor_range(types)
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (num_factors < limits[1] || num_factors > limits[2]) {
    stop_out_of_range(num_factors, limits, "Number of factors")
  }

  available_types <- sfd_list(num_factors, types)
  if (!type %in% names(available_types)) {
    stop_unavailable(
      type,
      stats::setNames(
        names(available_types),
        sfd_labels(names(available_types))
      ),
      "design",
      sprintf("%d factors", num_factors)
    )
  }

  available_runs <- as.numeric(available_types[[type]])
  if (!num_runs %in% available_runs) {
    stop_unavailable(
      num_runs,
      available_runs,
      "run count",
      sprintf("%s in %d factors", sfd_labels(type), num_factors)
    )
  }
  stop_unless(
    length(factor_names) == num_factors,
    sprintf(
      "Give %d factor names, not %d.",
      num_factors,
      length(factor_names)
    )
  )

  sfd_table(num_factors, num_runs, type, factor_names)
}

# ---- Optimized Latin hypercubes (sfd) ----------------------------------------

# Returns: an unnamed character vector of package names.
spacefilling_opt_get_packages <- function() {
  "sfd"
}

# Returns: a named list of integer c(min, max) pairs.
spacefilling_opt_get_limits <- function() {
  list(num_factors = sfd_factor_range(SFD_LHC_TYPES))
}

# Returns: a character vector of sfd type ids named by display label, empty
# when this factor count has none.
spacefilling_opt_get_types <- function(num_factors) {
  ids <- names(sfd_list(num_factors, SFD_LHC_TYPES))
  stats::setNames(ids, sfd_labels(ids))
}

# Returns: a numeric vector of run counts, ascending, unnamed.
#
# Depends on the type as well as the factor count, because the criteria do not
# cover the same sizes: at six factors Max-Min (L1) offers four run counts and
# Audze-Eglais offers ninety-nine.
spacefilling_opt_get_num_runs_choices <- function(num_factors, type) {
  available <- sfd_list(num_factors, SFD_LHC_TYPES)
  if (length(type) != 1 || is.na(type) || !type %in% names(available)) {
    return(numeric(0))
  }
  as.numeric(available[[type]])
}

# Returns: a doe_design.
spacefilling_opt_create <- function(
  num_factors,
  num_runs,
  type,
  factor_names = default_factor_names(
    num_factors
  )
) {
  types <- spacefilling_opt_get_types(num_factors)
  if (is.null(type)) {
    type <- unname(types[1])
  }
  table <- sfd_create(
    num_factors,
    num_runs,
    type,
    factor_names,
    SFD_LHC_TYPES
  )
  new_design(
    table,
    sprintf(
      "%s Latin hypercube \u2013 %d factors, %d runs",
      sfd_labels(type),
      num_factors,
      num_runs
    ),
    sprintf(
      "Precomputed by the sfd package, %d levels rescaled to 0-1.",
      num_runs
    )
  )
}

# Returns: an unnamed character vector of notes, or character(0).
#
# The notes are built in _create(), since sfd returns a bare table with no
# metadata attached.
spacefilling_opt_get_notes <- function(design) {
  character(0)
}

# ---- Uniform designs (sfd) ---------------------------------------------------
#
# A uniform design minimises discrepancy from a uniform distribution over the
# region. That is a different criterion from the Latin hypercube ones above,
# and the result is not an LHC, so it is a design in its own right rather than
# a type within one. It also reaches further: 2 to 15 factors against 2 to 10.

# Returns: an unnamed character vector of package names.
spacefilling_unif_get_packages <- function() {
  "sfd"
}

# Returns: a named list of integer c(min, max) pairs.
spacefilling_unif_get_limits <- function() {
  list(num_factors = sfd_factor_range(SFD_UNIFORM_TYPES))
}

# Returns: an empty character vector. There is a single criterion here, so
# there is nothing to choose between.
spacefilling_unif_get_types <- function(...) {
  stats::setNames(character(0), character(0))
}

# Returns: a numeric vector of run counts, ascending, unnamed.
spacefilling_unif_get_num_runs_choices <- function(num_factors) {
  available <- sfd_list(num_factors, SFD_UNIFORM_TYPES)
  if (length(available) == 0) {
    return(numeric(0))
  }
  as.numeric(available[[SFD_UNIFORM_TYPES]])
}

# Returns: a doe_design. No type argument: there is only one.
spacefilling_unif_create <- function(
  num_factors,
  num_runs,
  factor_names = default_factor_names(
    num_factors
  )
) {
  table <- sfd_create(
    num_factors,
    num_runs,
    SFD_UNIFORM_TYPES,
    factor_names,
    SFD_UNIFORM_TYPES
  )
  new_design(
    table,
    sprintf(
      "Uniform design \u2013 %d factors, %d runs",
      num_factors,
      num_runs
    ),
    sprintf(
      "Precomputed by the sfd package, %d levels rescaled to 0-1.",
      num_runs
    )
  )
}

# Returns: an unnamed character vector of notes, or character(0).
spacefilling_unif_get_notes <- function(design) {
  character(0)
}

# ---- Random (DiceDesign) -----------------------------------------------------

# A practical ceiling of ours, not one of DiceDesign, which will build almost
# anything. Kept here because it belongs to this design.
RANDOM_LHC_MAX_FACTORS <- 50L
RANDOM_LHC_MAX_RUNS <- 1000L

# Returns: an unnamed character vector of package names.
spacefilling_rand_get_packages <- function() {
  "DiceDesign"
}

# Returns: a named list of integer c(min, max) pairs. Two axes here, because
# the run count is chosen rather than derived.
spacefilling_rand_get_limits <- function() {
  list(
    num_factors = c(2L, RANDOM_LHC_MAX_FACTORS),
    num_runs = c(2L, RANDOM_LHC_MAX_RUNS)
  )
}

# Returns: an empty character vector. There is nothing to choose between.
spacefilling_rand_get_types <- function(...) {
  stats::setNames(character(0), character(0))
}

# Returns: a doe_design. Coded from 0 to 1, as DiceDesign produces it.
spacefilling_rand_create <- function(
  num_factors,
  num_runs,
  seed = 1,
  factor_names = default_factor_names(
    num_factors
  )
) {
  limits <- spacefilling_rand_get_limits()
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (
    num_factors < limits$num_factors[1] || num_factors > limits$num_factors[2]
  ) {
    stop_out_of_range(num_factors, limits$num_factors, "Number of factors")
  }
  stop_unless(
    length(num_runs) == 1 && !is.na(num_runs) && num_runs == round(num_runs),
    "Number of runs must be a whole number."
  )
  if (num_runs < limits$num_runs[1] || num_runs > limits$num_runs[2]) {
    stop_out_of_range(num_runs, limits$num_runs, "Number of runs")
  }
  stop_unless(
    length(factor_names) == num_factors,
    sprintf(
      "Give %d factor names, not %d.",
      num_factors,
      length(factor_names)
    )
  )

  # seed is passed to DiceDesign rather than wrapped in set.seed() here, so the
  # caller's random state is left alone.
  built <- DiceDesign::lhsDesign(
    n = num_runs,
    dimension = num_factors,
    seed = seed
  )
  table <- tibble::as_tibble(built$design, .name_repair = "minimal")
  names(table) <- factor_names

  new_design(
    table,
    sprintf(
      "Random Latin hypercube – %d factors, %d runs",
      num_factors,
      num_runs
    ),
    sprintf("Coded from 0 to 1. Seed %d.", seed)
  )
}

# Returns: an unnamed character vector of notes, or character(0).
spacefilling_rand_get_notes <- function(design) {
  character(0)
}
