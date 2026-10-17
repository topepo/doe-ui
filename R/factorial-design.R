# Two-level factorial designs, full and fractional, from FrF2's catalog.
# Pure computation: no Shiny here, so every function below is testable on its
# own.
#
# This file implements the design contract described in the README:
#
#   factorial_get_packages()            packages this design needs
#   factorial_get_limits()              integer range of each count option
#   factorial_get_num_runs_choices()    valid run counts, given the factors
#   factorial_get_blocks_choices()      valid block counts, given the runs
#   factorial_get_types()               the variants to choose between
#   factorial_create()                  builds the doe_design
#   factorial_get_notes()               what the package says about the result
#
# Each states the shape it returns above it. The one worth reading twice is the
# *_choices() pair: the vector holds the values, and its names are the labels.
# Getting that backwards produces a dropdown that looks right and submits
# nonsense, because Shiny takes names as labels and values as values.

# Returns: an unnamed character vector of package names.
#
# Per design rather than one global list, because each design wraps a different
# package and the app should be able to name the one actually missing.
factorial_get_packages <- function() {
  c("DoE.base", "FrF2")
}

# The largest design this app offers. A practical limit of ours, not one of
# FrF2 — the installed catalog reaches 4096 runs and 160 factors, well past
# what anyone runs and past what the browser renders comfortably. It is
# declared here rather than in shared code because it belongs to this design;
# another design will have its own ceiling from its own package.
FACTORIAL_MAX_RUNS <- 256L

# Everything else about what this design supports is read off the installed
# catalog, so the app follows whichever FrF2 version is present rather than a
# second copy of its contents written out here. Computed once, when Shiny
# sources this file.
factorial_support <- local({
  num_factors <- vapply(FrF2::catlg, function(e) e$nfac, numeric(1))
  num_runs <- vapply(FrF2::catlg, function(e) e$nruns, numeric(1))
  keep <- num_runs <= FACTORIAL_MAX_RUNS
  lapply(split(num_runs[keep], num_factors[keep]), function(x) sort(unique(x)))
})

# The factor counts with at least one available design, as c(min, max).
factorial_factor_range <- local({
  catalogued <- as.integer(names(factorial_support))
  # Small factor counts have no catalogued fraction but do have a full
  # factorial. Two is where a factorial starts being one at all, which is
  # definitional rather than a limit of the package or a choice of ours.
  full_only <- Filter(
    function(num_factors) 2^num_factors <= FACTORIAL_MAX_RUNS,
    seq(2, max(catalogued))
  )
  range(c(catalogued, unlist(full_only)))
})

# Returns: a named list of integer vectors of length 2, each c(min, max)
# inclusive. Names are option names, so this design gives
# list(num_factors = c(2L, 127L)).
#
# A named list rather than a single range because not every design has one
# axis: a crossed array has separate control and noise factor counts, and a
# mixture design counts components rather than factors.
factorial_get_limits <- function() {
  list(num_factors = factorial_factor_range)
}

# Returns: a numeric vector of run counts, ascending, named by the label to
# show. Values are what gets passed back as num_runs; names are display only:
#
#   8 runs (2^(6-3) fraction)   16 runs (2^(6-2) fraction)
#                           8                           16
#
# Empty when this design supports no run count at that many factors. Feeds
# updateSelectInput(choices = ) directly.
#
# The run counts are the catalogued fractions plus the full factorial, when it
# is no larger than the biggest design the catalog holds.
#
# These are read off the catalog rather than computed as a span of powers of
# two. The catalog is irregular: 34 factors has a 2048-run design but no
# 1024-run one, and asking FrF2 for a size it lacks errors rather than
# returning nothing. Around half of its factor counts have a hole like that.
#
# All of those holes happen to sit above the current 256-run ceiling, so the
# arithmetic version would get away with it today. Reading the catalog means
# the app stays right if the ceiling is raised or a future FrF2 ships a
# different catalog, instead of depending on that coincidence.
factorial_get_num_runs_choices <- function(num_factors) {
  fractions <- factorial_support[[as.character(num_factors)]] %||% numeric(0)
  full <- if (2^num_factors <= FACTORIAL_MAX_RUNS) 2^num_factors else numeric(0)
  num_runs <- sort(unique(c(fractions, full)))
  labels <- ifelse(
    num_runs == 2^num_factors,
    sprintf("%d runs (full factorial)", num_runs),
    sprintf(
      "%d runs (2^(%d-%d) fraction)",
      num_runs,
      num_factors,
      num_factors - log2(num_runs)
    )
  )
  stats::setNames(num_runs, labels)
}

# The catalog designs of this size, best first: highest resolution, then the
# fewest words of that shortest length. A full factorial is not in the catalog,
# so this is empty for one.
factorial_catalog_entries <- function(num_factors, num_runs) {
  entries <- Filter(
    function(e) e$nfac == num_factors && e$nruns == num_runs,
    FrF2::catlg
  )
  if (length(entries) == 0) {
    return(entries)
  }
  resolution <- vapply(entries, function(e) e$res, numeric(1))
  shortest <- vapply(entries, function(e) e$WLP[e$res], numeric(1))
  utils::head(entries[order(-resolution, shortest)], 6)
}

# The label shown for one catalog design in the "Choose a design" radio.
# Generators come from DoE.base, already written as "E=ABC", rather than being
# decoded from the catalog's Yates column codes here.
factorial_type_label <- function(name, entry, max_generators = 6) {
  # select.catlg is passed explicitly: generators() defaults it to a bare
  # `catlg`, which is only on the search path if FrF2 has been attached, and
  # this app only ever uses FrF2:: qualified calls.
  generators <- DoE.base::generators(name, select.catlg = FrF2::catlg)[[1]]
  # A large design can have fifty-odd generators, which makes an unreadable
  # radio label. The resolution and word count are what tell the choices apart.
  shown <- paste(utils::head(generators, max_generators), collapse = ", ")
  if (length(generators) > max_generators) {
    shown <- sprintf("%s, ... (%d generators)", shown, length(generators))
  }
  shortest <- entry$WLP[entry$res]
  sprintf(
    "Resolution %s: %s (%d word%s of length %d)",
    as.character(utils::as.roman(entry$res)),
    shown,
    shortest,
    if (shortest == 1) "" else "s",
    entry$res
  )
}

# Returns: a character vector of catalog ids, best first, named by the label to
# show. Same values-and-names convention as the *_choices() helpers:
#
#   Resolution IV: E=ABC, F=ABD (3 words of length 4)
#                                            "6-2.1"
#
# Zero-length when there is nothing to choose — a full factorial has no catalog
# entry, and most other designs have no type at all — so callers must handle an
# empty result rather than assuming at least one.
factorial_get_types <- function(num_factors, num_runs) {
  entries <- factorial_catalog_entries(num_factors, num_runs)
  if (length(entries) == 0) {
    return(stats::setNames(character(0), character(0)))
  }
  stats::setNames(
    names(entries),
    vapply(
      names(entries),
      function(id) factorial_type_label(id, entries[[id]]),
      character(1)
    )
  )
}

# Returns: an unnamed character vector, one note per line to show under the
# title, or character(0) when there is nothing to say. Takes the object the
# package returned, not a doe_design.
#
# The alias structure FrF2 attaches to every design it builds, under
# attr(design, "design.info")$aliased. Reported, not derived.
#
# This used to be computed here, by multiplying every combination of the
# design's generators to get the defining relation. That is 2^p - 1 words for
# p generators: fine for the two a small design has, hopeless for the 24 in a
# 30-factor design (16.7 million) or the 53 in a 60-factor one (9e15). FrF2
# instead reports alias classes of two-factor interactions, which is bounded
# by the run count — 0.11s for that 60-factor design — and is what an
# experimenter wants to know anyway.
factorial_get_notes <- function(design) {
  aliased <- attr(design, "design.info")$aliased
  # A full factorial has no catalog entry and nothing aliased.
  if (is.null(aliased)) {
    return(character())
  }
  notes <- character()

  # The legend maps FrF2's own letters onto the factor names in use. It is
  # identity until a factor has been renamed, and noise until then.
  letters_used <- sub("=.*$", "", aliased$legend)
  names_used <- sub("^[^=]*=", "", aliased$legend)
  renamed <- aliased$legend[letters_used != names_used]
  if (length(renamed) > 0) {
    notes <- c(notes, paste0("Factors: ", format_choices(renamed)))
  }

  if (length(aliased$main) > 0) {
    notes <- c(
      notes,
      paste0("Main effects aliased: ", format_choices(aliased$main))
    )
  }
  if (length(aliased$fi2) > 0) {
    notes <- c(
      notes,
      paste0("Two-factor interactions aliased: ", format_choices(aliased$fi2))
    )
  }
  notes
}

# Returns: a numeric vector of block counts, ascending, unnamed — the number
# is its own label, so there is nothing to add. Names are optional across the
# *_choices() helpers; supply them only when the value alone does not read
# well, as the run counts do.
#
# Block counts are those FrF2 will consider, by its own two rules: a power of
# two, and no more blocks than half the run size.
#
# Whether a *particular* count works also depends on the design — FrF2 refuses
# a blocking that would confound a two-factor interaction with blocks, so 4
# blocks is fine for some 16-run designs and not for 6-2.1. That cannot be
# known without building the design, and probing every candidate takes 16s for
# a 256-run design, which is far too slow for a dropdown. So offer what is
# structurally valid and let FrF2's own message cover the rest; the module
# shows it in place of the table.
factorial_get_blocks_choices <- function(num_runs) {
  2^(0:floor(log2(num_runs / 2)))
}

# Returns: a doe_design — see new_design(). The table holds one row per run in
# standard order, with FrF2's block column first when there is one; the order
# columns are added later, by the app.
#
# A two-level factorial design.
#
#   num_factors  within factorial_get_limits()$num_factors
#   num_runs     one of factorial_get_num_runs_choices(num_factors)
#   type         which catalog design to use when several are equivalent, as an
#                id from factorial_get_types(). NULL takes the best one, and is
#                the only valid value for a full factorial, which has no types.
#   center       center points per block
#   blocks       one of factorial_get_blocks_choices(num_runs)
#   replications times each run is carried out
#   factor_names column names, one per factor
#
# center, blocks and replications default to FrF2's own defaults.
factorial_create <- function(num_factors,
                             num_runs,
                             type = NULL,
                             center = 0,
                             blocks = 1,
                             replications = 1,
                             factor_names = default_factor_names(num_factors)) {
  # Checked before the range comparison below, which would otherwise be NA and
  # fail with "missing value where TRUE/FALSE needed" rather than a message.
  stop_unless(
    length(num_factors) == 1 &&
      !is.na(num_factors) &&
      num_factors == round(num_factors),
    "Number of factors must be a whole number."
  )
  if (
    num_factors < factorial_factor_range[1] ||
      num_factors > factorial_factor_range[2]
  ) {
    stop_out_of_range(num_factors, factorial_factor_range, "Number of factors")
  }
  available <- factorial_get_num_runs_choices(num_factors)
  if (!num_runs %in% available) {
    stop_unavailable(
      num_runs,
      available,
      "run count",
      sprintf("%d factors", num_factors)
    )
  }
  stop_unless(center >= 0, "Center points cannot be negative.")
  stop_unless(
    replications >= 1 && replications == round(replications),
    "Replications must be a whole number of at least 1."
  )
  available_blocks <- factorial_get_blocks_choices(num_runs)
  if (!blocks %in% available_blocks) {
    stop_unavailable(
      blocks,
      available_blocks,
      "block count",
      sprintf("%d runs", num_runs)
    )
  }
  # as.numeric deliberately. FrF2's `blocks` is overloaded: a number means how
  # many blocks, but a vector of Yates column numbers is also accepted. An
  # integer 1L takes the latter branch and fails with "'names' attribute [2]
  # must be the same length as the vector [0]" instead of meaning "unblocked".
  # A double 1 means what we want.
  blocks <- as.numeric(blocks)
  stop_unless(
    length(factor_names) == num_factors,
    sprintf("Give %d factor names, not %d.", num_factors, length(factor_names))
  )
  # FrF2 adds its block column under this name, so a factor cannot take it.
  stop_unless(
    blocks == 1 || !"Blocks" %in% factor_names,
    "\"Blocks\" is reserved for the block column; rename that factor."
  )

  # factor.names is passed to FrF2 rather than applied to the table
  # afterwards, so that the alias structure it attaches is expressed in the
  # names actually in use — its legend reads "A=Temp" instead of "A=A".
  # ncenter is FrF2's own, rather than appending zero rows here. With
  # randomize = FALSE it puts them at the end, which is what we were doing by
  # hand; it also records them in design.info, and its center.distribute
  # argument can spread them through the run order if that is ever wanted.
  types <- factorial_get_types(num_factors, num_runs)
  if (length(types) == 0) {
    # A full factorial, which the catalog does not hold and which has no
    # variants to choose between.
    design <- suppressMessages(FrF2::FrF2(
      nruns = num_runs,
      nfactors = num_factors,
      randomize = FALSE,
      factor.names = factor_names,
      ncenter = center,
      blocks = blocks,
      replications = replications
    ))
    description <- sprintf("2^%d full factorial", num_factors)
  } else {
    # Identified by catalog id rather than by position, so a type left over
    # from a different size is rejected by name instead of silently selecting
    # whatever now sits at that index.
    if (is.null(type)) {
      type <- unname(types[1])
    }
    if (!type %in% types) {
      stop_unavailable(
        type,
        types,
        "design",
        sprintf("%d factors in %d runs", num_factors, num_runs)
      )
    }
    entry <- FrF2::catlg[[type]]
    design <- suppressMessages(FrF2::FrF2(
      design = type,
      randomize = FALSE,
      factor.names = factor_names,
      ncenter = center,
      blocks = blocks,
      replications = replications
    ))
    description <- sprintf(
      "2^(%d-%d) fractional factorial, resolution %s",
      num_factors,
      num_factors - log2(num_runs),
      as.character(utils::as.roman(entry$res))
    )
  }

  # The design itself rather than desnum(): it carries FrF2's factor names and
  # a readable Blocks column, where desnum() contrast-codes that column into
  # Blocks1.
  #
  # The block column keeps its labels rather than being made numeric. With
  # replications FrF2 labels blocks "1.1", "2.1" — block and replicate, not a
  # decimal — so coercing would turn "1.1" into 1.1 and quietly invent a
  # number. It is found by elimination because design.info$block.name is NULL
  # when replications alone produced the column.
  # Rebuilt as a plain data frame rather than modified in place: FrF2 carries
  # design.info, desnum and run.order as attributes on the design, and those
  # should not ride along on the table we hand out.
  raw <- as.data.frame(design)
  factor_columns <- intersect(names(raw), factor_names)
  columns <- lapply(names(raw), function(column) {
    values <- raw[[column]]
    if (!column %in% factor_columns) {
      as.character(values)
    } else if (is.factor(values)) {
      as.numeric(as.character(values))
    } else {
      as.numeric(values)
    }
  })
  names(columns) <- names(raw)
  table <- tibble::as_tibble(columns)

  new_design(
    table,
    sprintf(
      "%s – %d factors, %d runs%s%s%s",
      description,
      num_factors,
      num_runs,
      if (blocks > 1) sprintf(", %d blocks", blocks) else "",
      if (replications > 1) {
        sprintf(", %d replications", replications)
      } else {
        ""
      },
      # ncenter is per block, so this many in total.
      center_point_text(center * blocks, nrow(table))
    ),
    factorial_get_notes(design)
  )
}
