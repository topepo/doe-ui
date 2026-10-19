# Two-level Taguchi orthogonal arrays, from DoE.base's catalog. Pure
# computation: no Shiny here, so every function below is testable on its own.
#
# This file implements the design contract described in the README:
#
#   taguchi_get_packages()            packages this design needs
#   taguchi_get_limits()              integer range of the factor count
#   taguchi_get_num_runs_choices()    valid run counts, given the factors
#   taguchi_create()                  builds the doe_design
#   taguchi_get_notes()               what the package says about the result
#
# There is no taguchi_get_types(): one array exists per run count, so there is
# nothing to choose between.

# Returns: an unnamed character vector of package names.
taguchi_get_packages <- function() {
  "DoE.base"
}

# The arrays this design offers, read off DoE.base's catalog: one row each, in
# ascending run order, with the catalog's own name, its run count and its
# number of columns.
#
# "Two-level Taguchi" is the saturated arrays L_N(2^(N-1)): every column is
# two-level, and there is one column for each degree of freedom the runs
# provide. The saturation test is what separates them from L256.2.19 and
# L2048.2.63, which also hold only two-level columns but are fractions of a
# much larger array. It is the definition of the family rather than a ceiling
# of ours, so none is declared; the largest array comes out at 140 runs.
#
# Computed once, when Shiny sources this file. The catalog has no gaps in its
# run counts today, but they are read rather than computed as a span so that
# the app follows whichever DoE.base version is installed.
taguchi_support <- local({
  catalog <- DoE.base::oacat
  level_columns <- grep("^n[0-9]+$", names(catalog), value = TRUE)
  other_levels <- setdiff(level_columns, "n2")
  saturated <- catalog$n2 > 0 &
    rowSums(catalog[other_levels]) == 0 &
    catalog$n2 == catalog$nruns - 1
  support <- data.frame(
    name = catalog$name[saturated],
    num_runs = as.integer(catalog$nruns[saturated]),
    num_columns = as.integer(catalog$n2[saturated]),
    stringsAsFactors = FALSE
  )
  support[order(support$num_runs), ]
})

# Returns: a named list of integer vectors of length 2, each c(min, max)
# inclusive, so this design gives list(num_factors = c(2L, 139L)).
#
# Two is where an array starts being a design at all. The top is the widest
# array in the catalog.
taguchi_get_limits <- function() {
  list(num_factors = c(2L, max(taguchi_support$num_columns)))
}

# Returns: a numeric vector of run counts, ascending, named by the label to
# show. Values are what gets passed back as num_runs; names are display only:
#
#   8 runs (L8)   12 runs (L12)
#               8             12
#
# An array is offered when it has a column for every factor, so the smallest
# is first. Empty past the widest array. Feeds updateSelectInput(choices = )
# directly.
taguchi_get_num_runs_choices <- function(num_factors) {
  wide_enough <- taguchi_support[taguchi_support$num_columns >= num_factors, ]
  stats::setNames(
    as.numeric(wide_enough$num_runs),
    sprintf("%d runs (L%d)", wide_enough$num_runs, wide_enough$num_runs)
  )
}

# The one place oa.design() is called, so its quirks are explained once.
#
# The array is pinned by its catalog id. The alternative, handing oa.design()
# only nruns, nfactors and nlevels = 2, lets it choose an array by its own
# criteria, and it does not choose these ones: it returns a replicated full
# factorial for small factor counts and a mixed-level array such as L32.2.9 or
# L96.2.20.4.2 for others.
#
# oa.design() reads ID as an unevaluated name, and rejects a character string.
# A name it cannot find as an object it looks up in the catalog and builds from
# its lineage, which works for most arrays. The base arrays (L4.2.3, L12.2.11
# and every fourth one after) have no lineage, so for those the object is bound
# to its own name first. Without that they fail with "No lineage information
# found".
#
# replications stacks complete copies of the array, in standard order, with
# nothing added to mark which copy a row belongs to. repeat.only is left at its
# default, FALSE: a true replication, rather than the same run measured twice.
#
# columns is left at the package default, "order": the first num_factors
# columns, which oa.design() announces with a message that is not for the
# experimenter.
#
# factor.names is deliberately not passed. oa.design() runs the names through
# make.names(), so "Temp (C)" becomes "Temp..C." and "1st" becomes "X1st", which
# is not what the experimenter typed. taguchi_create() applies the names to the
# table instead. The usual objection to renaming afterwards, that the package's
# notes would describe the factors by the wrong label, does not arise: nothing
# in this design's notes mentions a factor by name.
taguchi_oa_design <- function(id, num_factors, replications = 1) {
  env <- new.env()
  base_array <- tryCatch(
    getExportedValue("DoE.base", id),
    error = function(e) NULL
  )
  if (!is.null(base_array)) {
    assign(id, base_array, envir = env)
  }
  suppressMessages(eval(
    bquote(DoE.base::oa.design(
      ID = .(as.name(id)),
      nfactors = .(num_factors),
      replications = .(replications),
      randomize = FALSE
    )),
    envir = env
  ))
}

# Returns: an unnamed character vector, one note per line to show under the
# title. Takes the object the package returned, not a doe_design.
#
# All of it is read from design.info, which oa.design() attaches: the columns
# of the array that were used, and the residual degrees of freedom it works
# out. Reported, not derived. The levels line is ours to state, since the
# package hands back a factor labelled "1" and "2" and create() recodes it.
# The package labels the two levels "1" and "2". They are recoded to -1 and +1
# so this design reads on the same scale as the two-level factorial. Declared
# here, by label, rather than inferred from the values in a table.
TAGUCHI_CODED <- c("1" = -1, "2" = 1)

taguchi_get_notes <- function(design) {
  info <- attr(design, "design.info")
  array_columns <- taguchi_support$num_columns[
    taguchi_support$num_runs == info$nruns
  ]
  columns_used <- info$selected.columns
  c(
    if (length(columns_used) == array_columns) {
      sprintf("Uses all %d columns of the array.", array_columns)
    } else {
      sprintf(
        "Uses columns %s of the array's %d.",
        format_choices(columns_used),
        array_columns
      )
    },
    "Levels are coded -1 and +1.",
    sprintf(
      "Residual degrees of freedom%s: %d.",
      # oa.design() works this out from the array alone and does not count
      # replication, so with replicates the figure understates what the table
      # has. Said so rather than corrected here, since the package is the
      # source of truth for the number.
      if (info$replications > 1) ", not counting replication" else "",
      info$residual.df
    )
  )
}

# Returns: a doe_design — see new_design(). The table holds one row per run in
# standard order; the order columns are added later, by the app.
#
# A two-level Taguchi orthogonal array.
#
#   num_factors  within taguchi_get_limits()$num_factors
#   num_runs     one of taguchi_get_num_runs_choices(num_factors)
#   replications times each run is carried out; the array is stacked that many
#                times, so the table has num_runs * replications rows
#   factor_names column names, one per factor
taguchi_create <- function(
  num_factors,
  num_runs,
  replications = 1,
  factor_names = default_factor_names(num_factors)
) {
  limits <- taguchi_get_limits()$num_factors
  # Checked before the range comparison below, which would otherwise be NA and
  # fail with "missing value where TRUE/FALSE needed" rather than a message.
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (num_factors < limits[1] || num_factors > limits[2]) {
    stop_out_of_range(num_factors, limits, "Number of factors")
  }
  stop_unless(
    length(num_runs) == 1 && !is.na(num_runs),
    "Number of runs must be a single number."
  )
  available <- taguchi_get_num_runs_choices(num_factors)
  if (!num_runs %in% available) {
    stop_unavailable(
      num_runs,
      available,
      "run count",
      sprintf("%d factors", num_factors)
    )
  }
  stop_unless(
    length(replications) == 1 &&
      !is.na(replications) &&
      replications >= 1 &&
      replications == round(replications),
    "Replications must be a whole number of at least 1."
  )
  stop_unless(
    length(factor_names) == num_factors,
    sprintf("Give %d factor names, not %d.", num_factors, length(factor_names))
  )

  id <- taguchi_support$name[taguchi_support$num_runs == num_runs]
  design <- taguchi_oa_design(id, num_factors, as.numeric(replications))

  # Rebuilt column by column as plain numbers. oa.design() returns each factor
  # as an R factor with levels "1" and "2" and carries design.info on the
  # object; neither should ride along on the table we hand out. Recoded by
  # label through TAGUCHI_CODED, never by the factor's integer codes, which
  # would only agree with the label by coincidence.
  raw <- as.data.frame(design)
  columns <- lapply(raw, function(values) {
    coded <- unname(TAGUCHI_CODED[as.character(values)])
    stop_unless(
      !anyNA(coded),
      "DoE.base returned a level this design does not recognise."
    )
    coded
  })
  names(columns) <- factor_names
  table <- tibble::as_tibble(columns)

  new_design(
    table,
    sprintf(
      "L%d orthogonal array (2^%d) – %d factors, %d runs%s",
      num_runs,
      num_runs - 1,
      num_factors,
      num_runs,
      if (replications > 1) sprintf(", %d replications", replications) else ""
    ),
    taguchi_get_notes(design)
  )
}
