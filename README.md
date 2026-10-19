# doe-ui

A Shiny interface to R's experimental design generators. There are families of designs (e.g., two-level factorials, mixtures, etc) and specific designs within each. You can access the interface at [`https://topepo.github.io/doe-ui/`](https://topepo.github.io/doe-ui/) or run it locally. 

If you would like to contribute, we have a skill file in `inst,` and you can give an LLM instructions on the R package/function to use, options and their limits, and any other specifications. 

## Running Locally

```r
shiny::runApp()
```

Needs R 4.4 or later and the packages `bslib`, `DiceDesign`, `DoE.base`, `FrF2`, `reactable`, `sfd`, `shiny` and `tibble`. The app checks for them on startup and names any that are missing — the per-design ones come from each `{design}_get_packages()`, so this list is derived rather than maintained by hand.

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
| `R/taguchi-design.R` | The two-level Taguchi orthogonal arrays (DoE.base) — pure R, no Shiny |
| `R/taguchi-module.R` | Its Shiny module |
| `R/mixture-design.R` | The mixture-design generators — simplex-lattice and simplex-centroid (mixexp), pure R, no Shiny |
| `R/mixture-module.R` | Their Shiny modules |
| `R/spacefilling-design.R` | The three space-filling generators: optimized hypercubes and uniform designs (sfd), and random hypercubes (DiceDesign) |
| `R/spacefilling-module.R` | Their Shiny modules |
| `R/registry.R` | The design registry and the sidebar picker |
| `R/ui.R`, `R/server.R` | The page, and how its pieces update each other |

## Adding a design

One design is one Shiny module whose server returns a reactive yielding a `doe_design`. To add one:

1. Write `R/<name>-design.R` implementing the helper contract below. Keep it free of Shiny so every piece is testable on its own. The design must come from an R package — nothing is constructed here.
2. Write `R/<name>-module.R` with `<name>_ui(id)` and `<name>_server(id)`. The UI builds the inputs from the design's own limits and choices; the server returns a reactive yielding the `doe_design`.
3. Add one entry to `design_registry()` in `R/registry.R`.

`R/factorial-design.R` is the reference implementation, and `inst/adding-designs.md` is a step-by-step guide to the whole job — written as instructions to an LLM, but worth reading first either way. It carries the procedure and the traps; the contract below stays the source of truth for the shapes.

### The helper contract

| function | returns | may be empty |
| --- | --- | --- |
| `{design}_get_packages()` | unnamed `character` of package names | no |
| `{design}_get_limits()` | named `list` of `integer` vectors of length 2, each `c(min, max)` inclusive | no |
| `{design}_get_{option}_choices(...)` | `numeric` of valid values, ascending, optionally named by display label | yes |
| `{design}_get_types(...)` | `character` of ids, best first, named by display label | yes |
| `{design}_create(...)` | a `doe_design` — see `new_design()` | n/a |
| `{design}_get_notes(design)` | unnamed `character`, one note per line | yes |

**The vector holds the values; its names are the labels.** This is the one that bites, because getting it backwards produces a dropdown that looks correct and submits nonsense — Shiny takes names as labels and values as values. Both `_choices()` and `_get_types()` follow it:

```
> factorial_get_num_runs_choices(6)
 8 runs (2^(6-3) fraction) 16 runs (2^(6-2) fraction) 32 runs (2^(6-1) fraction)
                         8                         16                         32

> factorial_get_types(6, 16)
Resolution IV: E=ABC, F=ABD (3 words of length 4)   Resolution III: E=AB, F=ACD ...
                                          "6-2.1"                       "6-2.2"
```

Names are optional on `_choices()`. Supply them only when the value alone does not read well: run counts earn a label, block counts do not, and `factorial_get_blocks_choices()` returns a bare `c(1, 2, 4, 8)`.

Three of the functions can legitimately return nothing, and callers must cope rather than assume at least one element — `_get_types()` especially, since a zero-length result is exactly how `factorial_create()` tells a full factorial from a fraction.

`{design}_get_notes()` takes **the object the package returned**, not a `doe_design`. It runs during construction, since that is where the package's own metadata is still attached.

A `doe_design` from `new_design(table, title, notes)` holds:

- `table` — a `tibble`, one row per run in standard order, carrying none of the package's attributes. `new_design()` coerces whatever you hand it, so a generator need not. Note that coercion does **not** strip other attributes, so still build a clean table rather than passing the package's own object straight through. The order columns are added later by the app, not here.
- `title` — one line, shown above the table.
- `notes` — `character`, zero or more lines shown underneath.

Three of these have shapes that exist because the designs disagree with each other, so do not simplify them away:

**`_get_limits()` returns a named list, not one range.** Only some designs have a single factor-count axis. A crossed array has separate control and noise counts; a mixture design counts components; a Latin square has one size that fixes everything. The factorial returns `list(num_factors = c(2, 127))`, and a crossed array would return `list(control = c(3, 7), noise = c(1, 15))`.

**`_create()` takes named options, with no fixed positional run count.** The number of runs is something the user *chooses* for only a couple of designs — the two-level factorial and the Latin hypercube. For a Box-Behnken, a central composite, a Plackett-Burman or a randomized block it is *derived* from the other options, so those designs must not be made to carry a `num_runs` argument they would have to ignore. Designs that take one accept `num_runs`; the rest do not.

**`_get_types()` may legitimately return nothing.** Of the designs this app is meant to cover, most have no variant to choose between. A full factorial has none either, which is exactly how `factorial_create()` tells a full factorial from a fraction. Callers must handle a zero-length result rather than assuming at least one.

Identify a type by the package's own id, not by position. `factorial_get_types()` returns FrF2 catalog ids like `6-2.1`, so a type left over from a different size is rejected by name. An index would silently select whatever had moved into that slot.

### Naming

Name the two quantities every design shares consistently: `num_runs` for the number of runs and `num_factors` for the number of experimental factors. That applies to function arguments, local variables and Shiny input ids alike, so `input$num_factors` feeds `factorial_create(num_factors = )`. Arguments of the underlying package keep that package's own spelling — `FrF2::FrF2(nruns = , nfactors = )` is called as FrF2 names it, not renamed at the boundary.

Factor names come from two shared helpers in `R/design.R`. `default_factor_names(num_factors)` generates the defaults — single letters while they last, then `names0()`. `rename_factors(text, num_factors)` merges a user's comma-separated names over those defaults. The result feeds `{design}_create()`, which hands it to the package; it must **not** be applied to a finished design instead. FrF2 needs the names at construction for its alias legend to read `A=Temp` rather than `A=A`, and renaming afterwards would leave the notes describing factors by the wrong label.

Each design also names the factor count its panel opens on — `FACTORIAL_DEFAULT_FACTORS`, `SPACEFILLING_OPT_DEFAULT_FACTORS` — because the dependent dropdowns are built from it and the two must not drift apart.

### The packages are the source of truth

Almost all computation happens in the R package implementing the method. This app calls the package, reports what it returns, and formats the result. It does not reimplement, re-derive, or second-guess it — not the designs, not their properties, and not the parameter values they accept.

This is not a style preference. Three things in earlier versions of this code looked perfectly reasonable and were all wrong:

- A definitive screening design built by hand from a Paley conference matrix instead of calling a package.
- The alias structure derived by multiplying every subset of a design's generators — `2^p` words for `p` generators, which hung the app at 53 generators. FrF2 attaches the whole thing to the design under `attr(design, "design.info")$aliased`, bounded by the run count, in 0.11s.
- Available run counts computed as a span of powers of two, when `FrF2::catlg` has irregular gaps — 34 factors has a 2048-run design but no 1024-run one, and asking FrF2 for the missing size errors rather than returning nothing.

Before writing any statistical computation, check whether the package already exposes it. It is easy to miss, because it may arrive as an attribute on an object the package already returned rather than as a function you have to call.

### Limits and error messages

Which parameter values a design accepts is read from its package, not written down in app code. `R/factorial-design.R` derives its factor and run choices from `FrF2::catlg`, so the app follows whichever FrF2 version is installed. This matters because catalogued designs have gaps rather than clean ranges: FrF2 has a 2048-run design for 34 factors but no 1024-run one, and asking it for a size it lacks errors rather than returning nothing.

A *practical* ceiling is fine and belongs with the design that owns it — `FACTORIAL_MAX_RUNS` caps the table at 256 runs, well below the catalog's 4096. Put that sort of limit in the design's own file, never in `R/design.R`.

Three shared helpers in `R/design.R` turn a rejected value into a message worth reading:

- `stop_unavailable(value, available, quantity, context)` — for discrete sets with gaps. Gives `1024 is not an available run count for 34 factors. Choose one of: 64, 128, 256.`
- `stop_out_of_range(value, range, quantity)` — where the valid values really are contiguous and listing them would be noise.
- `stop_unless(condition, message)` — everything else.

Messages are shown to the user in place of the table, so write them for the person running the experiment.

Factor names come from two shared helpers in `R/design.R`. `default_factor_names(num_factors)` generates the defaults — single letters while they last, then `names0()`. `rename_factors(text, num_factors)` merges a user's comma-separated names over those defaults. The result feeds `{design}_create()`, which hands it to the package; it must **not** be applied to a finished design instead. FrF2 needs the names at construction for its alias legend to read `A=Temp` rather than `A=A`, and renaming afterwards would leave the notes describing factors by the wrong label.

Name the two quantities every design shares consistently: `num_runs` for the number of runs and `num_factors` for the number of experimental factors. That applies to function arguments, local variables and Shiny input ids alike, so `input$num_factors` feeds `factorial_design(num_factors = )`. Arguments of the underlying package keep that package's own spelling — `FrF2::FrF2(nruns = , nfactors = )` is called as FrF2 names it, not renamed at the boundary.

Generators return rows in standard order and stay deterministic; `with_run_order()` adds the run-order column afterwards. That separation is what keeps the generator snapshots stable without seeding.

Only the two-level factorial is implemented. Nine further designs — Plackett-Burman, definitive screening, central composite, Box-Behnken, simplex lattice, Latin hypercube, crossed array, randomized block, and Latin square — were removed pending a decision on how to compute them, and are recoverable from git history at `cc3901c`.
