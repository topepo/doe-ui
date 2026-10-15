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

# A Yates column code carries one bit per factor (A = 1, B = 2, C = 4, ...), so
# 7 has the first three bits set and reads "ABC".
code_to_word <- function(code, labels) {
  bits <- bitwAnd(as.integer(code), bitwShiftL(1L, seq_along(labels) - 1L)) > 0
  paste(labels[bits], collapse = "")
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
describe_entry <- function(entry, k, runs, max_generators = 6) {
  labels <- factor_labels(k)
  base <- log2(runs)
  words <- vapply(entry$gen, code_to_word, character(1), labels = labels)
  generators <- sprintf("%s = %s", labels[base + seq_along(words)], words)
  # A large design can have fifty-odd generators, which makes an unreadable
  # radio label. The resolution and word count are what distinguishes the
  # choices anyway.
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

# Deriving the defining relation means multiplying every combination of the
# design's generators, so a design with p generators has 2^p - 1 words. That is
# nothing for the two or three generators a small design has, and hopeless for
# a large one: 30 factors in 64 runs has 24 generators and 16.7 million words,
# and 60 factors in 128 runs has 53 and 9e15. Both would hang the app.
#
# This was unreachable while the factor count was capped at 8. It is reachable
# now that the range comes from the catalog, so past this many generators the
# note reports what the catalog already knows instead of deriving anything.
MAX_RELATION_GENERATORS <- 12L

# The note shown under a fractional design's title.
relation_note <- function(entry, k, runs) {
  generators <- length(entry$gen)
  if (generators > MAX_RELATION_GENERATORS) {
    return(sprintf(
      "%d generators. Defining relation not shown; it has %.3g words. Shortest words: %d of length %d.",
      generators,
      2^generators - 1,
      entry$WLP[entry$res],
      entry$res
    ))
  }
  relation <- defining_relation(entry, k, runs)
  paste0(
    "Defining relation: I = ",
    paste(utils::head(relation, 15), collapse = " = "),
    if (length(relation) > 15) " = ..." else ""
  )
}

# The words of a catalog design's defining relation, shortest first, built by
# multiplying every combination of its generators. Guard with
# MAX_RELATION_GENERATORS before calling: the cost is exponential.
defining_relation <- function(entry, k, runs) {
  labels <- factor_labels(k)
  added <- bitwShiftL(1L, log2(runs) + seq_along(entry$gen) - 1L)
  words <- bitwOr(as.integer(entry$gen), added)
  products <- vapply(
    seq_len(2^length(words) - 1),
    function(i) Reduce(bitwXor, words[as.logical(intToBits(i))[seq_along(words)]]),
    integer(1)
  )
  text <- vapply(products, code_to_word, character(1), labels = labels)
  text[order(nchar(text), text)]
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

  entries <- catalog_entries(k, runs)
  if (length(entries) == 0) {
    design <- suppressMessages(
      FrF2::FrF2(nruns = runs, nfactors = k, randomize = FALSE)
    )
    description <- sprintf("2^%d full factorial", k)
    notes <- character()
  } else {
    alternative <- min(max(1, alternative), length(entries))
    entry <- entries[[alternative]]
    design <- suppressMessages(
      FrF2::FrF2(design = names(entries)[alternative], randomize = FALSE)
    )
    description <- sprintf(
      "2^(%d-%d) fractional factorial, resolution %s",
      k,
      k - log2(runs),
      as.character(utils::as.roman(entry$res))
    )
    notes <- relation_note(entry, k, runs)
  }

  table <- as.data.frame(DoE.base::desnum(design))
  table[] <- lapply(table, as.numeric)
  names(table) <- factor_names
  table <- append_center_points(table, center)

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
