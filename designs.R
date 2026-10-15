# Design information ----------------------------------------------------------
#
# Everything the app knows about each experimental design: how to generate it,
# which options it has, and how it is registered. Nothing in this file depends
# on the app (design_picker.R). The app depends on this file only through the
# objects listed below, so a design can be added or changed here without
# touching the app.
#
# Contents (search for the section banners):
#   1. Packages and constants
#   2. Shared helpers         used by the generators
#   3. Design generators      make_{family}_{design}_design(), one per design
#   4. Option panels          {design}_list(), the option inputs of each design
#   5. Option servers         {design}_server(), for linked options
#   6. Design registry        design_registry: where a design is registered
#
# What the app uses from this file:
#   design_catalog     the designs as a table (name, family, input-id prefix)
#   design_generators  each design's generator function, by design name
#   setup_panels       each design's option-inputs function, by design name
#   setup_servers      each design's option server, by design name, if any
#   check_packages()   which the app also uses, for its own packages
#
# A generator returns a design object (see new_design()): the table, a title,
# notes, and whether the factor columns are coded.
#
# Conventions:
#   - Every function and object has a roxygen-style comment (#') above it that
#     says what it is, what its arguments mean, and what it returns.
#   - Calls to non-base packages are always written package::function().
#   - Functions use braces, even when short.
#
# To add a design, see the header of section 6.

# 1. Packages and constants ----------------------------------------------------

#' Packages the designs need.
#'
#' Checked when this file loads, by `check_packages()`. Calls to these packages
#' are always written as `package::function()`, so none of them is attached with
#' `library()`. (The Shiny packages used by the option panels are checked by the
#' app file.)
DESIGN_PACKAGES <- c("agricolae", "AlgDesign", "DoE.base", "FrF2", "lhs", "rsm")

#' Stop with an install hint if a package is missing.
#'
#' Used by both files: it is defined here because this file loads first, and the
#' app file calls it for its own packages.
#'
#' @param packages Character vector of package names to check.
#' @return `TRUE`, invisibly. It is called for its side effect: an error that
#'   lists the missing packages and the `install.packages()` call to fix it.
check_packages <- function(packages) {
  missing <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0) {
    stop(
      "Install the missing packages first: install.packages(c(",
      paste0("\"", missing, "\"", collapse = ", "),
      "))",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# Fail early, before anything below needs one of the packages.
check_packages(DESIGN_PACKAGES)

#' The largest number of factors the two-level factorial accepts.
#'
#' Used by the option input, the generator's check, and the server's check.
TLF_MAX_FACTORS <- 8L

# 2. Shared helpers ------------------------------------------------------------

#' Build a design object.
#'
#' Every generator returns one of these.
#'
#' @param table Data frame with one row per run, in standard order. It holds
#'   only the design's own columns; the app adds the order columns later
#'   (`with_run_order()` in design_picker.R).
#' @param title One line describing the design, shown above the sheet.
#' @param notes Character vector of extra lines shown under the title, such as
#'   the defining relation. May be empty.
#' @param coded `TRUE` if the factor columns are coded levels (-1, 0, +1, ...),
#'   which the sheet shows with signs. `FALSE` for real quantities such as blend
#'   proportions, or for labels.
#' @return A list with elements `table`, `title`, `notes`, and `coded`.
new_design <- function(table, title, notes = character(), coded = TRUE) {
  rownames(table) <- NULL
  list(table = table, title = title, notes = notes, coded = coded)
}

#' Names for `n` factors: A, B, C, ... then X1, X2, ... past 26.
#'
#' @param n Number of factors.
#' @return A character vector of length `n`.
factor_labels <- function(n) {
  if (n <= length(LETTERS)) {
    LETTERS[seq_len(n)]
  } else {
    paste0("X", seq_len(n))
  }
}

#' Turn numbers into a design table with named, numeric columns.
#'
#' @param values A matrix or data frame of numbers, one column per factor.
#' @param labels Column names, one per column of `values`.
#' @return A data frame of numeric columns named by `labels`.
as_factor_table <- function(values, labels) {
  table <- as.data.frame(values)
  table[] <- lapply(table, as.numeric)
  names(table) <- labels
  table
}

#' Add center points to the end of a coded design table.
#'
#' A center point sets every factor to 0, the middle of its range.
#'
#' @param table A coded design table.
#' @param n Number of center points. Zero or fewer leaves `table` unchanged.
#' @return `table` with `n` extra rows of zeros.
append_center_points <- function(table, n) {
  if (n < 1) {
    return(table)
  }
  centers <- table[rep(1, n), , drop = FALSE]
  centers[] <- 0
  rbind(table, centers)
}

#' Wording about center points for a design title.
#'
#' @param n Number of center points.
#' @param total Total number of rows, center points included.
#' @return `""` when there are no center points, otherwise text such as
#'   `" + 3 center points (19 total)"`.
center_point_text <- function(n, total) {
  if (n < 1) {
    return("")
  }
  sprintf(
    " + %d center point%s (%d total)",
    n,
    if (n == 1) "" else "s",
    total
  )
}

#' Stop with a message for the user unless a condition holds.
#'
#' Generators use this to check their options. `build_design()` shows the
#' message in place of the table, so write it for the person using the app. The
#' function name is left out of the message (`call. = FALSE`).
#'
#' @param condition A single `TRUE` or `FALSE`. Anything else counts as failing.
#' @param message The text to show when the condition fails.
#' @return `TRUE`, invisibly, when the condition holds.
stop_unless <- function(condition, message) {
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
  invisible(TRUE)
}

#' Run code with a fixed random seed, then restore the caller's random state.
#'
#' Makes a design that depends on random numbers (the Latin hypercube)
#' reproducible without disturbing the randomization of run order.
#'
#' @param seed Whole number used as the seed.
#' @param code An expression. It is evaluated after the seed is set (R evaluates
#'   arguments lazily), so pass the random call itself as the argument.
#' @return The value of `code`.
with_seed <- function(seed, code) {
  has_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_seed <- if (has_seed) {
    get(".Random.seed", envir = globalenv())
  }
  on.exit({
    if (has_seed) {
      assign(".Random.seed", old_seed, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  })
  set.seed(seed)
  code
}

# 3. Design generators ---------------------------------------------------------
#
# One function per design, each a thin wrapper around an R package. They are
# named make_{family}_{design}_design():
#
#   family   scr  screening          rsm  response surface
#            mix  mixture            sfd  space-filling
#            rpd  robust parameter   cmp  comparison
#
#   design   tlf   two-level factorial        pb   Plackett-Burman
#            dsd   definitive screening       ccd  central composite
#            bbd   Box-Behnken                sl   simplex lattice
#            lhs   Latin hypercube            ca   crossed array
#            rcbd  randomized complete block  lsq  Latin square
#
# Every generator follows the same contract:
#   - Its arguments are the design's options, named after the option inputs (an
#     input id without its prefix: input `ccd_k` is argument `k`).
#   - It checks them with stop_unless(), with messages written for the user. The
#     app shows a message in place of the table.
#   - It returns new_design(). The table is in standard order, one row per run;
#     the order columns are added later, by the app (design_picker.R).

# ---- Screening: two-level factorial (FrF2) ----

#' Run counts available for a two-level factorial.
#'
#' From the smallest power of 2 that can estimate `k` main effects
#' (2^n >= k + 1) up to the full factorial (2^k).
#'
#' @param k Number of factors.
#' @return A named numeric vector. The values are run counts and the names are
#'   the labels for the dropdown, such as `"16 runs (1/4 fraction)"`.
tlf_run_choices <- function(k) {
  exponents <- seq(ceiling(log2(k + 1)), k)
  runs <- 2^exponents
  labels <- ifelse(
    exponents == k,
    sprintf("%d runs (full factorial)", runs),
    sprintf("%d runs (1/%d fraction)", runs, 2^(k - exponents))
  )
  stats::setNames(runs, labels)
}

#' The letters for a Yates column code.
#'
#' A column code has one bit per factor (A = 1, B = 2, C = 4, D = 8, ...), so 7
#' means A, B and C and reads "ABC".
#'
#' @param code A whole number.
#' @param labels Factor labels, in order (see `factor_labels()`).
#' @return A string such as `"ABC"`.
code_to_word <- function(code, labels) {
  bits <- bitwAnd(as.integer(code), bitwShiftL(1L, seq_along(labels) - 1L)) > 0
  paste(labels[bits], collapse = "")
}

#' FrF2 catalog designs for `k` factors in `runs` runs, best first.
#'
#' Best means the highest resolution, then the fewest shortest words in the
#' defining relation. At most six are returned.
#'
#' @param k Number of factors.
#' @param runs Number of runs, a power of 2.
#' @return A list of FrF2 catalog entries named by catalog id (such as
#'   `"6-2.1"`). Empty for a full factorial, which is not in the catalog.
find_tlf_catalog_entries <- function(k, runs) {
  entries <- Filter(
    function(entry) {
      entry$nfac == k && entry$nruns == runs
    },
    FrF2::catlg
  )
  if (length(entries) == 0) {
    return(entries)
  }
  resolution <- vapply(
    entries,
    function(entry) {
      entry$res
    },
    numeric(1)
  )
  shortest_words <- vapply(
    entries,
    function(entry) {
      entry$WLP[entry$res]
    },
    numeric(1)
  )
  utils::head(entries[order(-resolution, shortest_words)], 6)
}

#' Text for a catalog design in the "Choose a design" list.
#'
#' @param entry An entry from `find_tlf_catalog_entries()`.
#' @param k Number of factors.
#' @param runs Number of runs.
#' @return A string such as
#'   `"Resolution IV: E = ABC, F = ABD (3 words of length 4)"`.
describe_tlf_entry <- function(entry, k, runs) {
  labels <- factor_labels(k)
  base_factors <- log2(runs)
  words <- vapply(entry$gen, code_to_word, character(1), labels = labels)
  generators <- sprintf(
    "%s = %s",
    labels[base_factors + seq_along(words)],
    words
  )
  shortest <- entry$WLP[entry$res]
  sprintf(
    "Resolution %s: %s (%d word%s of length %d)",
    as.character(utils::as.roman(entry$res)),
    paste(generators, collapse = ", "),
    shortest,
    if (shortest == 1) "" else "s",
    entry$res
  )
}

#' The words of a catalog design's defining relation, shortest first.
#'
#' Built from the design's generators by multiplying every combination of them.
#'
#' @param entry An entry from `find_tlf_catalog_entries()`.
#' @param k Number of factors.
#' @param runs Number of runs.
#' @return A character vector such as `c("ABCE", "ABDF", "CDEF")`.
tlf_defining_relation <- function(entry, k, runs) {
  labels <- factor_labels(k)
  added <- bitwShiftL(1L, log2(runs) + seq_along(entry$gen) - 1L)
  words <- bitwOr(as.integer(entry$gen), added)
  products <- vapply(
    seq_len(2^length(words) - 1),
    function(i) {
      chosen <- as.logical(intToBits(i))[seq_along(words)]
      Reduce(bitwXor, words[chosen])
    },
    integer(1)
  )
  text <- vapply(products, code_to_word, character(1), labels = labels)
  text[order(nchar(text), text)]
}

#' Two-level factorial design, full or fractional (package: FrF2).
#'
#' With `runs` equal to 2^k this is the full factorial. With fewer runs it is a
#' fraction taken from FrF2's catalog.
#'
#' @param k Number of factors, 2 to `TLF_MAX_FACTORS`.
#' @param runs Number of runs. One of `tlf_run_choices(k)`.
#' @param sub Which catalog design to use when there are several for this size,
#'   1 being the best. Ignored for a full factorial. Out-of-range values are
#'   moved to the nearest valid one.
#' @param center Number of center points to add at the end.
#' @return A design object.
make_scr_tlf_design <- function(k, runs, sub = 1, center = 0) {
  stop_unless(
    k >= 2 && k <= TLF_MAX_FACTORS,
    sprintf("Choose between 2 and %d factors.", TLF_MAX_FACTORS)
  )
  stop_unless(
    runs %in% tlf_run_choices(k),
    "Choose a number of runs from the list."
  )
  labels <- factor_labels(k)
  entries <- find_tlf_catalog_entries(k, runs)

  if (length(entries) == 0) {
    design <- suppressMessages(
      FrF2::FrF2(nruns = runs, nfactors = k, randomize = FALSE)
    )
    description <- sprintf("2^%d full factorial", k)
    notes <- character()
  } else {
    sub <- min(max(1, sub), length(entries))
    entry <- entries[[sub]]
    design <- suppressMessages(
      FrF2::FrF2(design = names(entries)[sub], randomize = FALSE)
    )
    description <- sprintf(
      "2^(%d-%d) fractional factorial, resolution %s",
      k,
      k - log2(runs),
      as.character(utils::as.roman(entry$res))
    )
    relation <- tlf_defining_relation(entry, k, runs)
    notes <- paste0(
      "Defining relation: I = ",
      paste(utils::head(relation, 15), collapse = " = "),
      if (length(relation) > 15) " = ..." else ""
    )
  }

  table <- as_factor_table(DoE.base::desnum(design), labels)
  table <- append_center_points(table, center)
  title <- sprintf(
    "%s \u2013 %d factors, %d runs%s",
    description,
    k,
    runs,
    center_point_text(center, nrow(table))
  )
  new_design(table, title, notes)
}

# ---- Screening: Plackett-Burman (FrF2) ----

#' Plackett-Burman screening design (package: FrF2).
#'
#' The number of runs is the next multiple of 4 above `k + 1`, and at least 8.
#'
#' @param k Number of factors, 4 to 47.
#' @return A design object.
make_scr_pb_design <- function(k) {
  stop_unless(k >= 4 && k <= 47, "Choose between 4 and 47 factors.")
  runs <- 4 * ceiling((k + 1) / 4)
  design <- suppressWarnings(suppressMessages(
    FrF2::pb(nruns = runs, nfactors = k, randomize = FALSE)
  ))
  table <- as_factor_table(DoE.base::desnum(design), factor_labels(k))
  title <- sprintf("Plackett-Burman \u2013 %d factors, %d runs", k, runs)
  notes <- if (runs == 8) {
    "Eight-run designs are regular fractions of a factorial; use 12 runs for more than four factors."
  } else {
    character()
  }
  new_design(table, title, notes)
}

# ---- Screening: definitive screening (built here, no package) ----

#' Is a number prime?
#'
#' @param n A whole number.
#' @return `TRUE` or `FALSE`.
is_prime <- function(n) {
  n >= 2 && all(n %% seq_len(floor(sqrt(n)))[-1] != 0)
}

#' A conference matrix built by the Paley construction.
#'
#' A conference matrix `C` is square, has 0 on the diagonal and +1 or -1
#' elsewhere, and has orthogonal columns (`C'C` is `(order - 1)` times the
#' identity). The construction works when `order - 1` is prime.
#'
#' @param order Number of rows and columns. Must be even and at least 4.
#' @return A square numeric matrix.
make_paley_conference_matrix <- function(order) {
  q <- order - 1
  stop_unless(
    order >= 4 && order %% 2 == 0 && is_prime(q),
    sprintf("No conference matrix of order %d is available.", order)
  )
  residues <- unique((seq_len(q - 1)^2) %% q)
  character_value <- function(x) {
    x <- x %% q
    ifelse(x == 0, 0, ifelse(x %in% residues, 1, -1))
  }
  indices <- 0:(q - 1)
  jacobsthal <- outer(indices, indices, function(i, j) {
    character_value(i - j)
  })
  border <- if (q %% 4 == 1) 1 else -1
  rbind(c(0, rep(1, q)), cbind(rep(border, q), jacobsthal))
}

#' Definitive screening design (built here; no package generates it).
#'
#' Stacks a conference matrix, its negative, and a center row. For an odd number
#' of factors a matrix for one more factor is built and one column dropped. Only
#' sizes where the matrix exists (see `make_paley_conference_matrix()`) are
#' available; for the others a message says so.
#'
#' @param k Number of factors, 4 to 30.
#' @return A design object.
make_scr_dsd_design <- function(k) {
  stop_unless(k >= 4 && k <= 30, "Choose between 4 and 30 factors.")
  order <- k + k %% 2
  stop_unless(
    is_prime(order - 1),
    sprintf(
      "No definitive screening design is available for %d factors in this prototype.",
      k
    )
  )
  conference <- make_paley_conference_matrix(order)[, seq_len(k), drop = FALSE]
  values <- rbind(conference, -conference, 0)
  table <- as_factor_table(values, factor_labels(k))
  title <- sprintf(
    "Definitive screening \u2013 %d factors, %d runs",
    k,
    nrow(table)
  )
  notes <- "Built from a Paley conference matrix. Every factor has three levels."
  new_design(table, title, notes)
}

# ---- Response surface: central composite (rsm) ----

#' The coded factor columns of a design made by the rsm package.
#'
#' rsm names its factor columns x1, x2, ... and keeps other columns beside them;
#' this keeps only the factors, renamed A, B, ...
#'
#' @param design A design from `rsm::ccd()` or `rsm::bbd()`.
#' @param k Number of factors.
#' @return A data frame with `k` numeric columns.
rsm_factor_table <- function(design, k) {
  values <- lapply(paste0("x", seq_len(k)), function(name) {
    as.numeric(design[[name]])
  })
  as_factor_table(as.data.frame(values), factor_labels(k))
}

#' Central composite response surface design (package: rsm).
#'
#' A single block: the factorial points, the axial points, and the center
#' points.
#'
#' @param k Number of factors, 2 to 6.
#' @param alpha Axial distance: `"rotatable"`, `"faces"`, or `"spherical"`.
#' @param center Number of center points, at least 1.
#' @return A design object.
make_rsm_ccd_design <- function(k, alpha, center) {
  stop_unless(k >= 2 && k <= 6, "Choose between 2 and 6 factors.")
  stop_unless(center >= 1, "Use at least one center point.")
  design <- rsm::ccd(
    basis = k,
    n0 = c(center, 0),
    alpha = alpha,
    oneblock = TRUE,
    randomize = FALSE
  )
  table <- rsm_factor_table(design, k)
  title <- sprintf(
    "Central composite (%s) \u2013 %d factors, %d runs",
    alpha,
    k,
    nrow(table)
  )
  new_design(table, title)
}

# ---- Response surface: Box-Behnken (rsm) ----

#' Box-Behnken response surface design (package: rsm).
#'
#' Three levels per factor and no corner runs. A single block.
#'
#' @param k Number of factors, 3 to 7.
#' @param center Number of center points, at least 1.
#' @return A design object.
make_rsm_bbd_design <- function(k, center) {
  stop_unless(k >= 3 && k <= 7, "Choose between 3 and 7 factors.")
  stop_unless(center >= 1, "Use at least one center point.")
  design <- rsm::bbd(k = k, n0 = center, block = FALSE, randomize = FALSE)
  table <- rsm_factor_table(design, k)
  title <- sprintf("Box-Behnken \u2013 %d factors, %d runs", k, nrow(table))
  new_design(table, title)
}

# ---- Mixture: simplex lattice (AlgDesign) ----

#' Simplex-lattice mixture design (package: AlgDesign).
#'
#' Blends of `components` ingredients whose proportions add up to 1, with
#' proportions in steps of 1 / `degree`.
#'
#' @param components Number of mixture components, 3 to 8.
#' @param degree Degree of the lattice, 1 to 4.
#' @return A design object. Its table holds proportions, so `coded` is `FALSE`.
make_mix_sl_design <- function(components, degree) {
  stop_unless(
    components >= 3 && components <= 8,
    "Choose between 3 and 8 components."
  )
  stop_unless(degree >= 1 && degree <= 4, "Choose a degree from 1 to 4.")
  blends <- AlgDesign::gen.mixture(levels = degree + 1, vars = components)
  table <- as_factor_table(blends, paste0("C", seq_len(components)))
  title <- sprintf(
    "Simplex lattice {%d, %d} \u2013 %d blends",
    components,
    degree,
    nrow(table)
  )
  notes <- "Each row is a blend; the proportions add up to 1."
  new_design(table, title, notes, coded = FALSE)
}

# ---- Space-filling: Latin hypercube (lhs) ----

#' Latin hypercube space-filling design (package: lhs).
#'
#' Points spread across the whole region, in coded units from -1 to 1.
#'
#' @param k Number of factors, 2 to 30.
#' @param n Number of runs, 2 to 500.
#' @param method `"maximin"`, `"improved"`, or `"random"`.
#' @param seed Whole number. The same seed gives the same design.
#' @return A design object.
make_sfd_lhs_design <- function(k, n, method, seed) {
  stop_unless(k >= 2 && k <= 30, "Choose between 2 and 30 factors.")
  stop_unless(n >= 2 && n <= 500, "Choose between 2 and 500 runs.")
  sampler <- switch(
    method,
    maximin = lhs::maximinLHS,
    improved = lhs::improvedLHS,
    random = lhs::randomLHS
  )
  points <- with_seed(seed, sampler(n, k))
  table <- as_factor_table(2 * points - 1, factor_labels(k))
  title <- sprintf(
    "Latin hypercube (%s) \u2013 %d factors, %d runs",
    method,
    k,
    n
  )
  notes <- sprintf("Coded units from -1 to 1. Seed %d.", seed)
  new_design(table, title, notes)
}

# ---- Robust parameter: crossed array (DoE.base) ----

#' Crossed array for robust parameter design (package: DoE.base).
#'
#' An inner array of control factors crossed with an outer array of noise
#' factors: every control setting is run under every noise setting.
#'
#' @param control Number of control factors, 3 to 7. The smallest suitable
#'   orthogonal array is used for them.
#' @param noise Number of noise factors, at least 1 and at most `outer - 1`.
#' @param outer Number of runs in the outer array (4, 8, or 16).
#' @return A design object.
make_rpd_ca_design <- function(control, noise, outer) {
  stop_unless(
    control >= 3 && control <= 7,
    "Choose between 3 and 7 control factors."
  )
  stop_unless(
    noise >= 1 && noise <= outer - 1,
    sprintf(
      "A %d-run outer array holds at most %d noise factors.",
      outer,
      outer - 1
    )
  )
  inner_labels <- paste0("C", seq_len(control))
  outer_labels <- paste0("N", seq_len(noise))
  inner <- suppressMessages(DoE.base::oa.design(
    nfactors = control,
    nlevels = 2,
    factor.names = inner_labels,
    randomize = FALSE
  ))
  outer_array <- suppressMessages(DoE.base::oa.design(
    nruns = outer,
    nfactors = noise,
    nlevels = 2,
    factor.names = outer_labels,
    randomize = FALSE
  ))
  crossed <- suppressMessages(
    DoE.base::cross.design(inner, outer_array, randomize = FALSE)
  )
  table <- as_factor_table(
    DoE.base::desnum(crossed),
    c(inner_labels, outer_labels)
  )
  title <- sprintf(
    "Crossed array \u2013 %d inner runs \u00d7 %d outer runs = %d runs",
    nrow(inner),
    nrow(outer_array),
    nrow(table)
  )
  new_design(table, title)
}

# ---- Comparison: randomized complete block (agricolae) ----

#' Randomized complete block design (package: agricolae).
#'
#' Every treatment appears once in every block. Rows are laid out block by
#' block; use the run order to randomize.
#'
#' @param treatments Number of treatments, 2 to 26. They are named A, B, ...
#' @param blocks Number of blocks, at least 2.
#' @return A design object with `Block` and `Treatment` columns. `coded` is
#'   `FALSE`.
make_cmp_rcbd_design <- function(treatments, blocks) {
  stop_unless(
    treatments >= 2 && treatments <= 26,
    "Choose between 2 and 26 treatments."
  )
  stop_unless(blocks >= 2, "Use at least two blocks.")
  trt <- LETTERS[seq_len(treatments)]
  book <- agricolae::design.rcbd(
    trt = trt,
    r = blocks,
    serie = 0,
    randomization = FALSE
  )$book
  table <- data.frame(
    Block = as.integer(as.character(book$block)),
    Treatment = as.character(book[[3]])
  )
  title <- sprintf(
    "Randomized complete block \u2013 %d treatments, %d blocks, %d runs",
    treatments,
    blocks,
    nrow(table)
  )
  new_design(table, title, coded = FALSE)
}

# ---- Comparison: Latin square (agricolae) ----

#' Latin square design (package: agricolae).
#'
#' Every treatment appears once in every row and once in every column.
#'
#' @param size Number of treatments, rows and columns, 3 to 10.
#' @return A design object with `Row`, `Column` and `Treatment` columns. `coded`
#'   is `FALSE`.
make_cmp_lsq_design <- function(size) {
  stop_unless(size >= 3 && size <= 10, "Choose a size from 3 to 10.")
  trt <- LETTERS[seq_len(size)]
  book <- agricolae::design.lsd(
    trt = trt,
    serie = 0,
    randomization = FALSE
  )$book
  table <- data.frame(
    Row = as.integer(as.character(book$row)),
    Column = as.integer(as.character(book$col)),
    Treatment = as.character(book[[4]])
  )
  title <- sprintf(
    "Latin square \u2013 %d \u00d7 %d, %d runs",
    size,
    size,
    nrow(table)
  )
  new_design(table, title, coded = FALSE)
}

# 4. Option panels -------------------------------------------------------------
#
# Each {design}_list() function returns the option inputs for one design, as a
# list of Shiny inputs. make_options_panel() lays them out as rows, and the
# server calls the right one when the design is selected (see output$options_ui
# in make_app_server()).
#
# The naming rule that connects an input to its generator:
#
#   input id  =  the design's prefix (from `design_registry`)  +  argument name
#   "tlf_k"   =  "tlf_"                                        +  "k"
#
# so the value of input$tlf_k is passed to make_scr_tlf_design(k = ...). A
# generator argument without an input falls back to its default; an input
# without a matching argument is ignored.

#' Option inputs for the two-level factorial.
#'
#' Ids: `tlf_k` (number of factors), `tlf_runs` (number of runs), `tlf_center`
#' (center points) and `tlf_sub` (which catalog design). Two of the rows are
#' placeholders: `uiOutput()` reserves a spot that the server fills in, because
#' the run counts depend on the number of factors and the list of designs
#' depends on the run count. See `two_level_factorial_server()` (section 5).
#'
#' @return A list of Shiny inputs.
two_level_factorial_list <- function() {
  list(
    shiny::numericInput(
      "tlf_k",
      "Number of factors",
      value = 6,
      min = 2,
      max = TLF_MAX_FACTORS
    ),
    shiny::uiOutput("tlf_runs_ui"),
    shiny::selectInput(
      "tlf_center",
      "Center points",
      choices = 0:5,
      selected = 0
    ),
    shiny::uiOutput("tlf_sub_ui")
  )
}

#' Option inputs for the Plackett-Burman design.
#'
#' Id: `pb_k` (number of factors).
#'
#' @return A list of Shiny inputs.
plackett_burman_list <- function() {
  list(shiny::numericInput(
    "pb_k",
    "Number of factors",
    value = 11,
    min = 4,
    max = 47
  ))
}

#' Option inputs for the definitive screening design.
#'
#' Id: `dsd_k` (number of factors).
#'
#' @return A list of Shiny inputs.
definitive_screening_list <- function() {
  list(shiny::numericInput(
    "dsd_k",
    "Number of factors",
    value = 6,
    min = 4,
    max = 30
  ))
}

#' Option inputs for the central composite design.
#'
#' Ids: `ccd_k` (number of factors), `ccd_alpha` (axial distance), and
#' `ccd_center` (center points).
#'
#' @return A list of Shiny inputs.
central_composite_list <- function() {
  list(
    shiny::numericInput(
      "ccd_k",
      "Number of factors",
      value = 3,
      min = 2,
      max = 6
    ),
    shiny::selectInput(
      "ccd_alpha",
      "Axial distance",
      choices = c("rotatable", "faces", "spherical")
    ),
    shiny::numericInput(
      "ccd_center",
      "Center points",
      value = 5,
      min = 1,
      max = 10
    )
  )
}

#' Option inputs for the Box-Behnken design.
#'
#' Ids: `bbd_k` (number of factors) and `bbd_center` (center points).
#'
#' @return A list of Shiny inputs.
box_behnken_list <- function() {
  list(
    shiny::numericInput(
      "bbd_k",
      "Number of factors",
      value = 4,
      min = 3,
      max = 7
    ),
    shiny::numericInput(
      "bbd_center",
      "Center points",
      value = 3,
      min = 1,
      max = 10
    )
  )
}

#' Option inputs for the simplex-lattice mixture design.
#'
#' Ids: `mix_components` (number of components) and `mix_degree` (degree of the
#' lattice).
#'
#' @return A list of Shiny inputs.
mixture_simplex_lattice_list <- function() {
  list(
    shiny::numericInput(
      "mix_components",
      "Number of components",
      value = 3,
      min = 3,
      max = 8
    ),
    shiny::selectInput(
      "mix_degree",
      "Lattice degree",
      choices = 1:4,
      selected = 2
    )
  )
}

#' Option inputs for the Latin hypercube design.
#'
#' Ids: `lhs_k` (number of factors), `lhs_n` (number of runs), `lhs_method`, and
#' `lhs_seed` (random seed).
#'
#' @return A list of Shiny inputs.
latin_hypercube_list <- function() {
  list(
    shiny::numericInput(
      "lhs_k",
      "Number of factors",
      value = 6,
      min = 2,
      max = 30
    ),
    shiny::numericInput(
      "lhs_n",
      "Number of runs",
      value = 60,
      min = 2,
      max = 500
    ),
    shiny::selectInput(
      "lhs_method",
      "Method",
      choices = c("maximin", "improved", "random")
    ),
    shiny::numericInput("lhs_seed", "Random seed", value = 1, min = 1)
  )
}

#' Option inputs for the crossed array.
#'
#' Ids: `ca_control` (control factors), `ca_noise` (noise factors), and
#' `ca_outer` (runs in the outer array).
#'
#' @return A list of Shiny inputs.
crossed_array_list <- function() {
  list(
    shiny::numericInput(
      "ca_control",
      "Control factors",
      value = 4,
      min = 3,
      max = 7
    ),
    shiny::numericInput(
      "ca_noise",
      "Noise factors",
      value = 2,
      min = 1,
      max = 7
    ),
    shiny::selectInput("ca_outer", "Outer array runs", choices = c(4, 8, 16))
  )
}

#' Option inputs for the randomized complete block design.
#'
#' Ids: `rcbd_treatments` and `rcbd_blocks`.
#'
#' @return A list of Shiny inputs.
randomized_block_list <- function() {
  list(
    shiny::numericInput(
      "rcbd_treatments",
      "Treatments",
      value = 4,
      min = 2,
      max = 26
    ),
    shiny::numericInput("rcbd_blocks", "Blocks", value = 4, min = 2, max = 20)
  )
}

#' Option inputs for the Latin square design.
#'
#' Id: `lsq_size` (number of treatments, rows and columns).
#'
#' @return A list of Shiny inputs.
latin_square_list <- function() {
  list(shiny::sliderInput(
    "lsq_size",
    "Square size",
    min = 3,
    max = 10,
    value = 5,
    step = 1
  ))
}

# 5. Option servers ------------------------------------------------------------
#
# Most designs only need their plain inputs from section 4. A design whose
# options depend on each other also gets a {design}_server() function. It takes
# the same `input`, `output`, and `session` as the main server, and it is called
# once, at startup, by make_app_server(), so it can register the outputs that
# fill the `uiOutput()` spots left in the design's {design}_list().
#
# A design's server is optional: it only appears in `design_registry` (section
# 6) if the design has one.

#' Server logic for the two-level factorial's dependent options.
#'
#' Registers the outputs that fill the placeholders left by
#' `two_level_factorial_list()`. Called once at startup by `make_app_server()`.
#'
#' ```
#' tlf_k (input)  -->  factors()  -->  tlf_runs_ui  (dropdown of run counts)
#'                                \
#' tlf_runs (input) ----------------->  entries()  -->  tlf_sub_ui
#'                                                  (list of catalog designs)
#' ```
#'
#' @param input,output,session The session objects Shiny passes to a server
#'   function.
#' @return Nothing. It is called for the outputs it registers.
two_level_factorial_server <- function(input, output, session) {
  # The number of factors, checked. validate() stops the outputs below and shows
  # the message in their place when the number is not usable (empty, out of
  # range, or not a whole number). need() is the condition; the text is what
  # the user sees.
  factors <- shiny::reactive({
    k <- input$tlf_k
    shiny::validate(shiny::need(
      !is.null(k) &&
        !is.na(k) &&
        k >= 2 &&
        k <= TLF_MAX_FACTORS &&
        k == round(k),
      sprintf("Enter a whole number of factors from 2 to %d.", TLF_MAX_FACTORS)
    ))
    as.integer(k)
  })

  # The "Number of runs" dropdown fills the spot left by
  # uiOutput("tlf_runs_ui"). Its choices depend on the number of factors, which
  # is why it is drawn by the server and not written out in the _list function.
  output$tlf_runs_ui <- shiny::renderUI({
    shiny::selectInput(
      "tlf_runs",
      "Number of runs",
      choices = tlf_run_choices(factors())
    )
  })

  # The catalog designs (from FrF2) that fit the chosen factors and runs, best
  # first. A full factorial has none, so this is empty for it.
  # req() waits quietly until the run count has been chosen, and until it is one
  # that is valid for the current number of factors (right after the number of
  # factors changes, the old run count can be stale for a moment).
  entries <- shiny::reactive({
    k <- factors()
    shiny::req(input$tlf_runs)
    runs <- as.integer(input$tlf_runs)
    shiny::req(runs %in% tlf_run_choices(k))
    find_tlf_catalog_entries(k, runs)
  })

  # The "Choose a design" list fills the spot left by uiOutput("tlf_sub_ui").
  # With zero or one possible design there is nothing to choose, so nothing is
  # drawn. Otherwise each choice is described by its resolution and generators.
  # The chosen position is read back as input$tlf_sub, which is the `sub`
  # argument of make_scr_tlf_design().
  output$tlf_sub_ui <- shiny::renderUI({
    entries <- entries()
    if (length(entries) < 2) {
      return(NULL)
    }
    k <- factors()
    runs <- as.integer(input$tlf_runs)
    labels <- vapply(
      entries,
      describe_tlf_entry,
      character(1),
      k = k,
      runs = runs
    )
    shiny::radioButtons(
      "tlf_sub",
      "Choose a design",
      choiceNames = unname(labels),
      choiceValues = seq_along(entries),
      width = "100%"
    )
  })
}

# 6. Design registry -----------------------------------------------------------
#
# The one place designs are registered. Everything the app needs to know about a
# design (its family, input-id prefix, generator, option inputs, and optional
# option server) is one entry in `design_registry`. The rest of the app reads it
# through the small derived objects below.
#
#   design_registry    one entry per design (this is the one you edit)
#     |
#     +--> design_catalog     name, family and prefix, as a table
#     |                       (the side list; finding a design's prefix)
#     +--> design_generators  generator by name   (build_design)
#     +--> setup_panels       option inputs by name   (output$options_ui)
#     +--> setup_servers      option servers by name  (make_app_server)
#
# To add a design:
#   1. Write make_{family}_{design}_design() in section 3.
#   2. Write {design}_list() in section 4 (and {design}_server() in section 5
#      if its options depend on each other).
#   3. Add one entry to `design_registry`.

#' Describe one design for the registry.
#'
#' @param family Name of the family the design is listed under in the side list,
#'   such as `"Screening designs"`.
#' @param prefix Prefix of the design's input ids, such as `"tlf_"`. Must be
#'   unique across designs. An input id is the prefix plus the name of the
#'   generator argument it feeds (`tlf_k` feeds `k`).
#' @param generator The `make_{family}_{design}_design()` function.
#' @param panel The `{design}_list()` function that returns the option inputs.
#' @param server The `{design}_server()` function, or `NULL` (the default) if
#'   the design's options do not depend on each other.
#' @return A list with those five parts.
new_registry_entry <- function(
  family,
  prefix,
  generator,
  panel,
  server = NULL
) {
  stopifnot(
    is.character(family),
    length(family) == 1,
    is.character(prefix),
    length(prefix) == 1,
    is.function(generator),
    is.function(panel),
    is.null(server) || is.function(server)
  )
  list(
    family = family,
    prefix = prefix,
    generator = generator,
    panel = panel,
    server = server
  )
}

#' Every design the app offers: the one place a design is registered.
#'
#' A named list with one entry per design, made by `new_registry_entry()`. The
#' names are the designs' display names. Order matters: it is the order of the
#' side list, and the families appear in the order they are first used.
#'
#' To add a design, write its generator, its `{design}_list()` (and, if needed,
#' its `{design}_server()`), then add one entry here.
design_registry <- list(
  "Two-level factorial" = new_registry_entry(
    family = "Screening designs",
    prefix = "tlf_",
    generator = make_scr_tlf_design,
    panel = two_level_factorial_list,
    server = two_level_factorial_server
  ),
  "Plackett-Burman" = new_registry_entry(
    family = "Screening designs",
    prefix = "pb_",
    generator = make_scr_pb_design,
    panel = plackett_burman_list
  ),
  "Definitive screening" = new_registry_entry(
    family = "Screening designs",
    prefix = "dsd_",
    generator = make_scr_dsd_design,
    panel = definitive_screening_list
  ),
  "Central composite" = new_registry_entry(
    family = "Response surface designs",
    prefix = "ccd_",
    generator = make_rsm_ccd_design,
    panel = central_composite_list
  ),
  "Box-Behnken" = new_registry_entry(
    family = "Response surface designs",
    prefix = "bbd_",
    generator = make_rsm_bbd_design,
    panel = box_behnken_list
  ),
  "Mixture (simplex lattice)" = new_registry_entry(
    family = "Mixture designs",
    prefix = "mix_",
    generator = make_mix_sl_design,
    panel = mixture_simplex_lattice_list
  ),
  "Latin hypercube" = new_registry_entry(
    family = "Space-filling designs",
    prefix = "lhs_",
    generator = make_sfd_lhs_design,
    panel = latin_hypercube_list
  ),
  "Crossed array (Taguchi)" = new_registry_entry(
    family = "Robust parameter designs",
    prefix = "ca_",
    generator = make_rpd_ca_design,
    panel = crossed_array_list
  ),
  "Randomized block" = new_registry_entry(
    family = "Comparison designs",
    prefix = "rcbd_",
    generator = make_cmp_rcbd_design,
    panel = randomized_block_list
  ),
  "Latin square" = new_registry_entry(
    family = "Comparison designs",
    prefix = "lsq_",
    generator = make_cmp_lsq_design,
    panel = latin_square_list
  )
)

#' One field from every registry entry.
#'
#' @param field Name of the field: `"family"`, `"prefix"`, `"generator"`,
#'   `"panel"`, or `"server"`.
#' @return A named list with that field of every design, in registry order.
registry_field <- function(field) {
  lapply(design_registry, function(entry) {
    entry[[field]]
  })
}

#' The designs as a table, for building the side list and finding prefixes.
#'
#' Derived from `design_registry`.
#'
#' @format A data frame with one row per design and columns `name`, `family`,
#'   and `prefix`.
design_catalog <- data.frame(
  name = names(design_registry),
  family = unlist(registry_field("family"), use.names = FALSE),
  prefix = unlist(registry_field("prefix"), use.names = FALSE),
  stringsAsFactors = FALSE
)

#' The generator function of each design, by design name.
#'
#' Derived from `design_registry`. `build_design()` looks the generator up here,
#' and `collect_design_options()` reads its arguments to know which inputs to
#' collect.
design_generators <- registry_field("generator")

#' The option-inputs function of each design, by design name.
#'
#' Derived from `design_registry`. The server calls the one for the selected
#' design to draw the option rows.
setup_panels <- registry_field("panel")

#' The option-server function of each design that has one, by design name.
#'
#' Derived from `design_registry`; designs without a server are left out.
#' `make_app_server()` calls each one once at startup.
setup_servers <- Filter(Negate(is.null), registry_field("server"))

# A check that can only fail if the registry is edited wrongly. Two designs with
# the same prefix would share input ids and read each other's options.
stopifnot(
  "Each design needs its own input-id prefix." = !anyDuplicated(
    design_catalog$prefix
  )
)
