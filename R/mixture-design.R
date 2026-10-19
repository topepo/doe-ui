# Mixture designs, from mixexp. Pure computation: no Shiny here, so every
# function below is testable on its own.
#
# A mixture design's factors are the components of a blend: proportions that
# are never negative and always sum to one. That is not the flat
# quantitative-factor model the other designs share, so the table is in
# proportions rather than coded -1/+1 units, and nothing here assumes the
# factors can be moved independently.
#
# This file implements the design contract described in the README for two
# designs, each with the same three functions:
#
#   mixture_{sld,scd}_get_packages()   packages this design needs
#   mixture_{sld,scd}_get_limits()     integer range of each count option
#   mixture_{sld,scd}_create()         builds the doe_design
#
# sld is the simplex-lattice and scd the simplex-centroid. Neither has a
# *_get_types(), because neither has variants, nor a *_get_notes(): mixexp
# returns a bare data frame with no metadata attached, so the notes are built in
# _create() from its arguments. Nor is there a *_choices() helper: every number
# of factors and levels in range is valid, so there is no list of values to
# offer.

# ---- Shared by both designs --------------------------------------------------

# Stop unless num_factors is a whole number inside the design's range.
mixture_check_num_factors <- function(num_factors, range) {
  # Checked before the range comparison below, which would otherwise be NA and
  # fail with "missing value where TRUE/FALSE needed" rather than a message.
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (num_factors < range[1] || num_factors > range[2]) {
    stop_out_of_range(num_factors, range, "Number of factors")
  }
}

# Stop unless replications is a whole number of at least 1.
mixture_check_replications <- function(replications) {
  stop_unless(
    length(replications) == 1 &&
      !is.na(replications) &&
      replications >= 1 &&
      replications == round(replications),
    "Replications must be a whole number of at least 1."
  )
}

# The run table for a design mixexp returned: plain numbers, named as asked,
# and stacked once for each replicate.
#
# Rebuilt column by column rather than handed over. SLD() returns the leftover
# out.attrs of the expand.grid() it filtered, which has nothing to say about the
# table and should not ride along. The packages name their columns x1, x2, ...;
# the app's own names replace them, as they do for every design.
#
# Replication is done here, not by mixexp: neither SLD() nor SCD() has an
# argument for it. The design is stacked as complete copies in its own order,
# with nothing added to mark the copy, which is how the factorial and Taguchi
# designs do it.
mixture_table <- function(design, factor_names, replications) {
  columns <- lapply(design, as.numeric)
  names(columns) <- factor_names
  table <- tibble::as_tibble(columns)
  table[rep(seq_len(nrow(table)), times = replications), ]
}

# The replication clause of a design title, or "" when there is none.
mixture_replication_text <- function(replications) {
  if (replications > 1) sprintf(", %d replications", replications) else ""
}

# ---- Simplex-lattice designs (mixexp) ----------------------------------------
#
# A {q, m} simplex-lattice has every blend whose q proportions are each one of
# 0, 1/m, 2/m, ..., 1 and sum to one. Here q is the number of factors and m the
# number of levels.

# Returns: an unnamed character vector of package names.
mixture_sld_get_packages <- function() {
  "mixexp"
}

# Returns: a named list of integer vectors of length 2, each c(min, max)
# inclusive, so this design gives
# list(num_factors = c(2L, 10L), num_levels = c(2L, 5L)).
#
# The top of num_levels is mixexp's own: SLD() stops with "only works for 5
# levels or less". The top of num_factors is a practical limit of ours. SLD()
# stops at 12 factors, but it builds the whole (levels + 1)^factors grid with
# expand.grid() and then keeps the rows that sum to one, so its cost is set by
# that grid and not by the number of blends it returns. Timed, by factors and
# levels:
#
#   10 factors, 5 levels   6^10   3.6 s   the slowest size offered
#   11 factors, 4 levels   5^11   2.6 s
#   12 factors, 4 levels   5^12   18 s
#   11 factors, 5 levels   6^11   33 s
#   12 factors, 5 levels   6^12   fails at the memory limit
#
# Ten factors keeps every number of levels within a few seconds. It is declared
# here rather than in shared code because it belongs to this design.
#
# The lower ends are ours too. One level would give only the pure components,
# which is not a lattice worth offering, and a single component is not a
# mixture.
mixture_sld_get_limits <- function() {
  list(num_factors = c(2L, 10L), num_levels = c(2L, 5L))
}

# Returns: a doe_design — see new_design(). The table holds one row per blend,
# in the order SLD() returns them, each row summing to one; the order columns
# are added later, by the app.
#
# A simplex-lattice mixture design.
#
#   num_factors  within mixture_sld_get_limits()$num_factors
#   num_levels   within mixture_sld_get_limits()$num_levels
#   replications times each blend is carried out; the lattice is stacked that
#                many times, so the table has one block of runs per replicate
#   factor_names column names, one per factor
#
# The proportions are mixexp's own, left as it computed them. They are not
# rounded here, so a third is 0.3333333 in the table and the download.
mixture_sld_create <- function(
  num_factors,
  num_levels,
  replications = 1,
  factor_names = default_factor_names(num_factors)
) {
  require(mixexp)
  limits <- mixture_sld_get_limits()
  mixture_check_num_factors(num_factors, limits$num_factors)
  stop_unless(
    length(num_levels) == 1 &&
      !is.na(num_levels) &&
      num_levels == round(num_levels),
    "Number of levels must be a whole number."
  )
  if (num_levels < limits$num_levels[1] || num_levels > limits$num_levels[2]) {
    stop_out_of_range(num_levels, limits$num_levels, "Number of levels")
  }
  mixture_check_replications(replications)
  stop_unless(
    length(factor_names) == num_factors,
    sprintf("Give %d factor names, not %d.", num_factors, length(factor_names))
  )

  design <- mixexp::SLD(fac = num_factors, lev = num_levels)
  table <- mixture_table(design, factor_names, replications)

  new_design(
    table,
    sprintf(
      "{%d, %d} simplex-lattice – %d factors, %d runs%s",
      num_factors,
      num_levels,
      num_factors,
      nrow(design),
      mixture_replication_text(replications)
    ),
    c(
      "Each run is a blend: its proportions sum to 1.",
      sprintf("Proportions go up in steps of 1/%d.", num_levels)
    )
  )
}

# ---- Simplex-centroid designs (mixexp) ---------------------------------------
#
# A simplex-centroid design has one blend for every non-empty subset of the
# factors: that subset in equal parts and the rest absent. With q factors that
# is 2^q - 1 blends: the q pure components, the equal splits of each pair, of
# each triple, and so on up to the overall centroid. It has no levels to choose.

# Returns: an unnamed character vector of package names.
mixture_scd_get_packages <- function() {
  "mixexp"
}

# Returns: a named list with one integer vector of length 2, c(min, max)
# inclusive, so this design gives list(num_factors = c(2L, 10L)).
#
# The bottom is mixexp's own: SCD(1) fails with "attempt to set 'colnames' on an
# object with less than two dimensions", and a single component is not a mixture
# anyway. The top is a practical limit of ours, not the package's: SCD() has no
# ceiling of its own, and a 13-factor design of 8191 blends builds in 0.4 s. The
# design is 2^q - 1 blends, so the table is what grows; ten factors is 1023 runs
# and matches the simplex-lattice's ceiling.
mixture_scd_get_limits <- function() {
  list(num_factors = c(2L, 10L))
}

# Returns: a doe_design — see new_design(). The table holds one row per blend,
# in the order SCD() returns them, each row summing to one; the order columns
# are added later, by the app.
#
# A simplex-centroid mixture design.
#
#   num_factors  within mixture_scd_get_limits()$num_factors
#   replications times each blend is carried out; the design is stacked that
#                many times, so the table has one block of runs per replicate
#   factor_names column names, one per factor
#
# The proportions are mixexp's own, left as it computed them, so a third is
# 0.3333333 in the table and the download.
mixture_scd_create <- function(
  num_factors,
  replications = 1,
  factor_names = default_factor_names(num_factors)
) {
  require(mixexp)
  mixture_check_num_factors(
    num_factors,
    mixture_scd_get_limits()$num_factors
  )
  mixture_check_replications(replications)
  stop_unless(
    length(factor_names) == num_factors,
    sprintf("Give %d factor names, not %d.", num_factors, length(factor_names))
  )

  design <- mixexp::SCD(fac = num_factors)
  table <- mixture_table(design, factor_names, replications)

  new_design(
    table,
    sprintf(
      "Simplex-centroid – %d factors, %d runs%s",
      num_factors,
      nrow(design),
      mixture_replication_text(replications)
    ),
    c(
      "Each run is a blend: its proportions sum to 1.",
      "One blend for every subset of the factors, in equal parts."
    )
  )
}
