# The design object every generator returns, and the helpers shared across
# designs. Nothing here depends on Shiny.

# The two order columns the app adds to the front of every design table.
ORDER_COLUMNS <- c("Standard order", "Run order")

# A design: the run table in standard order, a one-line title, and any notes to
# show beneath it, such as the defining relation.
#
# There was a `coded` flag here, but its only job was choosing between signed
# text and rounding in the display, and the table is no longer reformatted at
# all. Add it back if something actually needs to distinguish coded levels from
# real quantities.
new_design <- function(table, title, notes = character()) {
  rownames(table) <- NULL
  structure(
    list(table = table, title = title, notes = notes),
    class = "doe_design"
  )
}

print.doe_design <- function(x, ...) {
  cat(x$title, "\n", sep = "")
  for (note in x$notes) {
    cat("  ", note, "\n", sep = "")
  }
  print(x$table)
  invisible(x)
}

# Stop with a message written for the person using the app, not for a
# developer: the module shows it in place of the table.
stop_unless <- function(condition, message) {
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
  invisible(TRUE)
}

# A readable list of what is on offer, shortened when there is a lot of it.
format_choices <- function(x, max_shown = 12) {
  shown <- paste(utils::head(x, max_shown), collapse = ", ")
  if (length(x) > max_shown) {
    sprintf("%s, ... (%d in all)", shown, length(x))
  } else {
    shown
  }
}

# Report a value the underlying package cannot supply, and say what it can.
#
# Catalogued designs have irregular gaps rather than clean ranges — FrF2 has a
# 2048-run design for 34 factors but no 1024-run one, and around half of its
# factor counts have a hole like that. "Choose from this list" is the only
# honest message in that situation, and every package-backed design will need
# to give it, so this lives here rather than with any one design.
#
#   value     what was asked for
#   available what the package offers, possibly nothing
#   quantity  what is being chosen, such as "run count"
#   context   what it is being chosen for, such as "6 factors"
stop_unavailable <- function(value, available, quantity, context = NULL) {
  where <- if (is.null(context)) "" else paste0(" for ", context)
  if (length(available) == 0) {
    stop(sprintf("No %s is available%s.", quantity, where), call. = FALSE)
  }
  stop(
    sprintf(
      "%s is not an available %s%s. Choose one of: %s.",
      value,
      quantity,
      where,
      format_choices(available)
    ),
    call. = FALSE
  )
}

# The same idea where the valid values really are a contiguous range, so
# listing them would be noise.
stop_out_of_range <- function(value, range, quantity) {
  stop(
    sprintf(
      "%s must be between %s and %s. Got %s.",
      quantity,
      range[1],
      range[2],
      value
    ),
    call. = FALSE
  )
}

# Numbered labels: x1, x2, ... zero-padded once there are ten or more, so that
# x01 ... x10 stay in factor order. Used by factor_labels() below once the
# letters run out.
names0 <- function(num, prefix = "x") {
  ind <- format(seq_len(num))
  ind <- gsub(" ", "0", ind)
  paste0(prefix, ind)
}

# Default factor names: single letters while they last, then names0().
#
# Used both for default column names and for the alias notation — generators
# like "E = ABC" and defining relations like "I = ABCE". Those read well while
# the labels are one character each. Past 26 factors they cannot: the words
# concatenate, so "x001x002x003" is ambiguous. Nothing avoids that, since the
# letters have genuinely run out, and FrF2 has no longer letter vector of its
# own to borrow.
#
# What this is *not* used for is a user's own factor names. Those reach the
# columns only; the alias notation stays canonical, so renaming a factor to
# "Temp" never turns the defining relation into prose.
default_factor_names <- function(num_factors) {
  if (num_factors <= length(LETTERS)) {
    LETTERS[seq_len(num_factors)]
  } else {
    names0(num_factors)
  }
}

# Merge the user's comma-separated factor names over the defaults, giving
# exactly num_factors of them. Anything left out falls back to
# default_factor_names(); extra names are dropped; duplicates are made unique
# so two columns cannot share a header.
#
# The result feeds {design}_create(), which hands it to the underlying package.
# It must not be applied to a finished design instead: FrF2 needs the names at
# construction for its alias legend to read "A=Temp" rather than "A=A", and
# renaming afterwards would leave the notes describing factors by the wrong
# label.
rename_factors <- function(text, num_factors) {
  given <- trimws(strsplit(text %||% "", ",", fixed = TRUE)[[1]])
  given <- given[nzchar(given)]
  names <- default_factor_names(num_factors)
  supplied <- seq_len(min(length(given), num_factors))
  names[supplied] <- given[supplied]
  make.unique(names, sep = "_")
}

# Add the order columns. Generators are deterministic and return rows in
# standard order; randomizing permutes the order the runs are performed in and
# never the rows themselves, which is what keeps generator output snapshottable.
with_run_order <- function(design, randomize) {
  num_runs <- nrow(design$table)
  design$table <- cbind(
    `Standard order` = seq_len(num_runs),
    `Run order` = if (randomize) sample(num_runs) else seq_len(num_runs),
    design$table
  )
  design
}

# The center-point clause of a design title, or "" when there are none.
center_point_text <- function(num_center, num_runs) {
  if (num_center < 1) {
    return("")
  }
  sprintf(
    " + %d center point%s (%d total)",
    num_center,
    if (num_center == 1) "" else "s",
    num_runs
  )
}

# Significant figures shown in the table.
DISPLAY_DIGITS <- 3L

# The table as the app displays it. Values are rounded for display and stay
# numeric — nothing is turned into text — and the CSV download writes the
# untouched table, so the file keeps full precision.
#
# signif() rather than reactable's colFormat(digits = ), which counts decimal
# places and would render a coded -1 as -1.000.
display_table <- function(design, digits = DISPLAY_DIGITS) {
  table <- design$table
  for (column in setdiff(names(table), ORDER_COLUMNS)) {
    if (is.numeric(table[[column]])) {
      table[[column]] <- signif(table[[column]], digits)
    }
  }
  table
}
