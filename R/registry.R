# Where designs are registered, and the sidebar that picks between them.
#
# To add a design: write R/<name>-design.R and R/<name>-module.R, then add one
# entry below. Nothing else in the app needs to change.

DEFAULT_DESIGN <- "factorial"

# A function rather than a plain list, deliberately. Shiny sources R/ in
# alphabetical order, so a design file sorting after this one (R/rsm-module.R
# would) is not yet loaded when this file runs. Resolving the functions when
# the registry is called instead of when it is defined makes the order
# irrelevant.
# Order matters: families appear in the sidebar in the order they are first
# used here, and designs in the order they are listed within a family.
design_registry <- function() {
  list(
    lhs_random = list(
      label = "Latin hypercubes (Random)",
      family = "Space-Filling Designs",
      ui = spacefilling_rand_ui,
      server = spacefilling_rand_server,
      packages = spacefilling_rand_get_packages
    ),
    lhs_optimized = list(
      label = "Latin hypercubes (Optimized)",
      family = "Space-Filling Designs",
      ui = spacefilling_opt_ui,
      server = spacefilling_opt_server,
      packages = spacefilling_opt_get_packages
    ),
    uniform = list(
      label = "Uniform designs",
      family = "Space-Filling Designs",
      ui = spacefilling_unif_ui,
      server = spacefilling_unif_server,
      packages = spacefilling_unif_get_packages
    ),
    factorial = list(
      label = "Two-level factorial",
      family = "Screening designs",
      ui = factorial_ui,
      server = factorial_server,
      packages = factorial_get_packages
    ),
    taguchi = list(
      label = "Two-level Taguchi",
      family = "Screening designs",
      ui = taguchi_ui,
      server = taguchi_server,
      packages = taguchi_get_packages
    ),
    simplex_lattice = list(
      label = "Simplex-Lattice Designs",
      family = "Mixture Designs",
      ui = mixture_sld_ui,
      server = mixture_sld_server,
      packages = mixture_sld_get_packages
    ),
    simplex_centroid = list(
      label = "Simplex-Centroid Designs",
      family = "Mixture Designs",
      ui = mixture_scd_ui,
      server = mixture_scd_server,
      packages = mixture_scd_get_packages
    )
  )
}

# Design ids grouped by family, families in the order they first appear.
design_families <- function(registry = design_registry()) {
  families <- vapply(registry, function(d) d$family, character(1))
  split(names(registry), factor(families, levels = unique(families)))
}

# The picker is one accordion panel per family with a radio group inside each.
# Exactly one design is selected across the whole app, so choosing in one
# family clears every other.
picker_ui <- function(
  id,
  registry = design_registry(),
  selected = DEFAULT_DESIGN
) {
  ns <- shiny::NS(id)
  families <- design_families(registry)

  panels <- lapply(seq_along(families), function(i) {
    ids <- families[[i]]
    bslib::accordion_panel(
      title = names(families)[i],
      value = names(families)[i],
      # The design-picker class is what the stylesheet in R/ui.R hangs the
      # link styling on. The control stays a radio group; it just does not
      # look like one.
      shiny::tagAppendAttributes(
        class = "design-picker",
        shiny::radioButtons(
          ns(paste0("family_", i)),
          label = NULL,
          choiceNames = unname(vapply(
            ids,
            function(x) registry[[x]]$label,
            character(1)
          )),
          choiceValues = ids,
          # character(0) leaves the group unchecked. NULL would silently
          # select the first choice, which would mean several families
          # claiming a selection at once.
          selected = if (selected %in% ids) selected else character(0)
        )
      )
    )
  })

  open <- names(families)[
    vapply(families, function(ids) selected %in% ids, logical(1))
  ]

  # Returned bare, not wrapped in a tagList or div: bslib only renders an
  # accordion flush against the sidebar when it is an immediate child of it.
  do.call(
    bslib::accordion,
    c(list(id = ns("family"), multiple = FALSE, open = open), panels)
  )
}

# Returns a reactive holding the id of the selected design.
picker_server <- function(
  id,
  registry = design_registry(),
  default = DEFAULT_DESIGN
) {
  shiny::moduleServer(id, function(input, output, session) {
    families <- design_families(registry)
    inputs <- paste0("family_", seq_along(families))
    selected <- shiny::reactiveVal(default)

    # lapply(), not a for loop: R does not rebind a loop variable per
    # iteration, so a for loop here would leave every observer pointing at the
    # last family.
    lapply(seq_along(inputs), function(i) {
      shiny::observeEvent(
        input[[inputs[i]]],
        {
          selected(input[[inputs[i]]])
          for (other in inputs[-i]) {
            # This cannot feed back. Clearing a family that is already clear
            # sends an identical value, which Shiny's client drops before it
            # reaches the server; the one family that did hold a selection sends
            # NULL, which ignoreNULL stops before the handler body runs.
            shiny::updateRadioButtons(session, other, selected = character(0))
          }
        },
        ignoreNULL = TRUE
      )
    })

    selected
  })
}
