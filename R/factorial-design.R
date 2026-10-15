# Two-level factorial designs, full and fractional, from FrF2's catalog.
# Pure computation: no Shiny here, so every function below is testable on its
# own.

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
  nfac <- vapply(FrF2::catlg, function(e) e$nfac, numeric(1))
  nruns <- vapply(FrF2::catlg, function(e) e$nruns, numeric(1))
  within <- nruns <= FACTORIAL_MAX_RUNS
  lapply(split(nruns[within], nfac[within]), function(x) sort(unique(x)))
})

# The factor counts with at least one available design, as c(min, max).
factorial_factor_range <- local({
  catalogued <- as.integer(names(factorial_support))
  # Small factor counts have no catalogued fraction but do have a full
  # factorial. Two is where a factorial starts being one at all, which is
  # definitional rather than a limit of the package or a choice of ours.
  full_only <- Filter(
    function(k) 2^k <= FACTORIAL_MAX_RUNS,
    seq(2, max(catalogued))
  )
  range(c(catalogued, unlist(full_only)))
})

# Run counts available for k factors: the catalogued fractions, plus the full
# factorial when it is no larger than the biggest design the catalog holds.
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
run_choices <- function(k) {
  fractions <- factorial_support[[as.character(k)]] %||% numeric(0)
  full <- if (2^k <= FACTORIAL_MAX_RUNS) 2^k else numeric(0)
  runs <- sort(unique(c(fractions, full)))
  labels <- ifelse(
    runs == 2^k,
    sprintf("%d runs (full factorial)", runs),
    sprintf("%d runs (2^(%d-%d) fraction)", runs, k, k - log2(runs))
  )
  stats::setNames(runs, labels)
}

# The catalog designs of this size, best first: highest resolution, then the
# fewest words of that shortest length. A full factorial is not in the catalog,
# so this is empty for one.
catalog_entries <- function(k, runs) {
  entries <- Filter(function(e) e$nfac == k && e$nruns == runs, FrF2::catlg)
  if (length(entries) == 0) {
    return(entries)
  }
  resolution <- vapply(entries, function(e) e$res, numeric(1))
  shortest <- vapply(entries, function(e) e$WLP[e$res], numeric(1))
  utils::head(entries[order(-resolution, shortest)], 6)
}

# One line describing a catalog design, for the "Choose a design" radio.
# Generators come from DoE.base, already written as "E=ABC", rather than being
# decoded from the catalog's Yates column codes here.
describe_entry <- function(name, entry, max_generators = 6) {
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
alias_notes <- function(design) {
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

# A two-level factorial design.
#
#   k            number of factors, within factorial_factor_range
#   runs         number of runs, one of run_choices(k)
#   alternative  which catalog design to use when several are equivalent, 1
#                being the best. Ignored for a full factorial; out-of-range
#                values are moved to the nearest valid one.
#   center       center points to append
#   factor_names column names, one per factor
factorial_design <- function(k,
                             runs,
                             alternative = 1,
                             center = 0,
                             factor_names = factor_labels(k)) {
  # Checked before the range comparison below, which would otherwise be NA and
  # fail with "missing value where TRUE/FALSE needed" rather than a message.
  stop_unless(
    length(k) == 1 && !is.na(k) && k == round(k),
    "Number of factors must be a whole number."
  )
  if (k < factorial_factor_range[1] || k > factorial_factor_range[2]) {
    stop_out_of_range(k, factorial_factor_range, "Number of factors")
  }
  available <- run_choices(k)
  if (!runs %in% available) {
    stop_unavailable(runs, available, "run count", sprintf("%d factors", k))
  }
  stop_unless(center >= 0, "Center points cannot be negative.")
  stop_unless(
    length(factor_names) == k,
    sprintf("Give %d factor names, not %d.", k, length(factor_names))
  )

  # factor.names is passed to FrF2 rather than applied to the table
  # afterwards, so that the alias structure it attaches is expressed in the
  # names actually in use — its legend reads "A=Temp" instead of "A=A".
  # ncenter is FrF2's own, rather than appending zero rows here. With
  # randomize = FALSE it puts them at the end, which is what we were doing by
  # hand; it also records them in design.info, and its center.distribute
  # argument can spread them through the run order if that is ever wanted.
  entries <- catalog_entries(k, runs)
  if (length(entries) == 0) {
    design <- suppressMessages(FrF2::FrF2(
      nruns = runs,
      nfactors = k,
      randomize = FALSE,
      factor.names = factor_names,
      ncenter = center
    ))
    description <- sprintf("2^%d full factorial", k)
  } else {
    alternative <- min(max(1, alternative), length(entries))
    entry <- entries[[alternative]]
    design <- suppressMessages(FrF2::FrF2(
      design = names(entries)[alternative],
      randomize = FALSE,
      factor.names = factor_names,
      ncenter = center
    ))
    description <- sprintf(
      "2^(%d-%d) fractional factorial, resolution %s",
      k,
      k - log2(runs),
      as.character(utils::as.roman(entry$res))
    )
  }

  table <- as.data.frame(DoE.base::desnum(design))
  table[] <- lapply(table, as.numeric)
  names(table) <- factor_names
  notes <- alias_notes(design)

  new_design(
    table,
    sprintf(
      "%s – %d factors, %d runs%s",
      description,
      k,
      runs,
      center_point_text(center, nrow(table))
    ),
    notes
  )
}
