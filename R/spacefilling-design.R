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

# The sfd library is a list of tables, one per factor count, indexed from two
# factors up. Each table holds one row per design point, tagged with its type
# and the number of points in that design.
sfd_table <- function(num_factors) {
  sfd::sfd_lib[[num_factors - 1]]
}

# The package's type ids, and the labels we show for them. One map, read in
# both directions, so a new type in a future sfd version shows up as a missing
# label rather than silently as an id.
SFD_TYPE_LABELS <- c(
  audze_eglais = "Audze-Eglais",
  max_min_l1 = "Max-Min (L1)",
  max_min_l2 = "Max-Min (L2)",
  uniform = "Uniform"
)

sfd_labels <- function(ids) {
  unname(SFD_TYPE_LABELS[ids])
}

# Returns: a named list, one element per type available at this many factors,
# each a sorted integer vector of the run counts that type offers. Names are
# the package's type ids.
#
#   $max_min_l1
#   [1] 4 5 6 7
#
# lapply() rather than apply(): apply() over the rows of a table simplifies to
# a matrix when there is only one row, and from 11 factors up only the uniform
# type survives. Lookup by name then fails with "subscript out of bounds",
# precisely at the top of the supported range.
sfd_list <- function(num_factors) {
  designs <- sfd_table(num_factors)
  types <- sort(unique(designs$type))
  stats::setNames(
    lapply(types, function(type) {
      sort(unique(designs$num_points[designs$type == type]))
    }),
    types
  )
}

# ---- Optimized (sfd) ---------------------------------------------------------

# Returns: an unnamed character vector of package names.
spacefilling_opt_get_packages <- function() {
  "sfd"
}

# Returns: a named list of integer c(min, max) pairs.
#
# Read off the library rather than written down: it is indexed from two factors
# up, so the largest it covers is one past its length.
spacefilling_opt_get_limits <- function() {
  list(num_factors = c(2L, length(sfd::sfd_lib) + 1L))
}

# Returns: a character vector of sfd type ids named by display label, empty
# when this factor count has none.
spacefilling_opt_get_types <- function(num_factors) {
  ids <- names(sfd_list(num_factors))
  ids <- ids[ids %in% names(SFD_TYPE_LABELS)]
  stats::setNames(ids, sfd_labels(ids))
}

# Returns: a numeric vector of run counts, ascending, unnamed — the number is
# its own label.
#
# Depends on the type as well as the factor count, because the four types do
# not cover the same sizes: at six factors Max-Min (L1) offers four run counts
# and Audze-Eglais offers ninety-nine.
spacefilling_opt_get_num_runs_choices <- function(num_factors, type) {
  available <- sfd_list(num_factors)
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
  limits <- spacefilling_opt_get_limits()$num_factors
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (num_factors < limits[1] || num_factors > limits[2]) {
    stop_out_of_range(num_factors, limits, "Number of factors")
  }

  types <- spacefilling_opt_get_types(num_factors)
  if (is.null(type)) {
    type <- unname(types[1])
  }
  if (!type %in% types) {
    stop_unavailable(
      type,
      types,
      "design",
      sprintf("%d factors", num_factors)
    )
  }

  available <- spacefilling_opt_get_num_runs_choices(num_factors, type)
  if (!num_runs %in% available) {
    stop_unavailable(
      num_runs,
      available,
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

  points <- sfd::get_design(num_factors, num_runs, type)
  # standardize to be on [0, 1]
  points <- points |> purrr::map_dfc(~ (.x - 1) / (max(.x) - 1))
  table <- as.data.frame(points, stringsAsFactors = FALSE)
  names(table) <- factor_names

  new_design(
    table,
    sprintf(
      "%s Latin hypercube – %d factors, %d runs",
      sfd_labels(type),
      num_factors,
      num_runs
    ),
    sprintf(
      "Precomputed by the sfd package. Levels run from 1 to %d.",
      num_runs
    )
  )
}

# Returns: an unnamed character vector of notes, or character(0).
#
# The notes are built in _create() from the type and size, since sfd returns a
# bare table with no metadata attached.
spacefilling_opt_get_notes <- function(design) {
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
  table <- as.data.frame(built$design, stringsAsFactors = FALSE)
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
