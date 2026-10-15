# doe-ui

A Shiny interface to R's experimental design generators. Pick a design, set its options, and download the run table as CSV.

## Running

```r
shiny::runApp()
```

Needs R 4.4 or later and the packages `bslib`, `DoE.base`, `FrF2`, `reactable`, and `shiny`. The app checks for them on startup and tells you what to install.

## Tests

```sh
Rscript tests/run.R
```

Output is checked with testthat snapshots, so review a diff before accepting it — a changed snapshot usually means a changed design, not a cosmetic difference.

## Layout

Shiny sources everything in `R/` automatically, so there is nothing to `source()` by hand.

| File | What it holds |
| --- | --- |
| `app.R` | Package check, then `shinyApp()` |
| `R/design.R` | The `doe_design` object and the helpers every design shares |
| `R/factorial-design.R` | The two-level factorial generator — pure R, no Shiny |
| `R/factorial-module.R` | Its Shiny module |
| `R/registry.R` | The design registry and the sidebar picker |
| `R/ui.R`, `R/server.R` | The page, and how its pieces update each other |

## Adding a design

One design is one Shiny module whose server returns a reactive yielding a `doe_design`. To add one:

1. Write `R/<name>-design.R` with a generator that takes its options as arguments, validates them, and returns `new_design()`. Keep it free of Shiny so it can be tested directly. The design must come from an R package — nothing is constructed here.
2. Write `R/<name>-module.R` with `<name>_ui(id)` and `<name>_server(id)`.
3. Add one entry to `design_registry()` in `R/registry.R`.

### Limits and error messages

Which parameter values a design accepts is read from its package, not written down in app code. `R/factorial-design.R` derives its factor and run choices from `FrF2::catlg`, so the app follows whichever FrF2 version is installed. This matters because catalogued designs have gaps rather than clean ranges: FrF2 has a 2048-run design for 34 factors but no 1024-run one, and asking it for a size it lacks errors rather than returning nothing.

A *practical* ceiling is fine and belongs with the design that owns it — `FACTORIAL_MAX_RUNS` caps the table at 256 runs, well below the catalog's 4096. Put that sort of limit in the design's own file, never in `R/design.R`.

Three shared helpers in `R/design.R` turn a rejected value into a message worth reading:

- `stop_unavailable(value, available, quantity, context)` — for discrete sets with gaps. Gives `1024 is not an available run count for 34 factors. Choose one of: 64, 128, 256.`
- `stop_out_of_range(value, range, quantity)` — where the valid values really are contiguous and listing them would be noise.
- `stop_unless(condition, message)` — everything else.

Messages are shown to the user in place of the table, so write them for the person running the experiment.

Generators return rows in standard order and stay deterministic; `with_run_order()` adds the run-order column afterwards. That separation is what keeps the generator snapshots stable without seeding.

Only the two-level factorial is implemented. Nine further designs — Plackett-Burman, definitive screening, central composite, Box-Behnken, simplex lattice, Latin hypercube, crossed array, randomized block, and Latin square — were removed pending a decision on how to compute them, and are recoverable from git history at `cc3901c`.
