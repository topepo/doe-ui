# Factor names, ranges, and designs in actual units

## Context

Every design this app builds is in coded units. The factorial emits -1 and +1, the space-filling designs emit 0 to 1. The experimenter's factors are quantitative and have real ranges — 160 to 180 °C, 20 to 40 bar — and nothing in the app currently knows them.

Factor *names* are already handled, but badly: each design module carries its own `Factor names` text area, four of them now, so the same information is entered separately per design and lost when you switch. Ranges are not handled at all.

The goal is one place, ahead of choosing a design, where the experimenter describes their factors: name, low, high. Supplying it is optional — the app must stay fully usable without it. When it is supplied, the factor count prepopulates the design's own count, and the design table can be shown in the experimenter's units instead of coded ones.

This is planned for after more designs are added, so it is written to survive designs that do not fit the flat-quantitative-factor model.

## Decisions

Settled before planning:

- **Entry** — an editable grid, plus spreadsheet upload for bulk entry, plus a downloadable template in the format we specify.
- **Count coupling** — the spec *prepopulates* each design's `num_factors` and leaves it editable. If the user overrides it so the counts disagree, actual units are unavailable and the app says why.
- **Other designs** — a design opts in by declaring its coded scale. Designs that declare none (mixture proportions, randomized blocks) ignore the panel entirely.
- **Placement** — an accordion panel in the sidebar, above the design picker.

## One consequence of the placement choice

The sidebar is 300px. A three-column editable grid plus an upload control will not sit comfortably in that. Widen `bslib::sidebar(width = )` to about 380px as part of this work, and use a compact DT with no search box, no pagination and no row names.

If 380px still proves cramped once it is real, the fallback is to keep a summary in the sidebar — "4 factors: Temp, Pressure, Time, Catalyst" with an **Edit factors…** button — and open the grid in a modal, which has room for a wide table and the upload controls together. The entry point stays where it was chosen to be either way. Decide this by looking at it, not in advance.

## The factor spec

One object, a tibble with one row per factor:

| column | type | meaning |
| --- | --- | --- |
| `name` | character | column heading for that factor |
| `low` | double | value at the design's coded minimum |
| `high` | double | value at the design's coded maximum |

`NA` in `low`/`high` means that factor has no range yet. A spec is **complete** when every row has both, and `low != high` in each. Only a complete spec enables actual units; a spec with names alone is still useful, and still drives the names and the count.

Pure functions, no Shiny, in a new `R/factors.R` so they can be tested directly:

- `new_factor_spec(name, low, high)` — construct and validate.
- `empty_factor_spec(num_factors)` — `default_factor_names()` with `NA` ranges, for the grid's initial state.
- `factor_spec_is_complete(spec)` — the gate on actual units.
- `factor_spec_names(spec, num_factors)` — exactly `num_factors` names, padding from `default_factor_names()` and truncating. This is `rename_factors()` generalised; fold the two together rather than keeping both.
- `read_factor_spec(path)` — file to spec.
- `factor_spec_template()` — the file handed out by the template button.

### Upload format

**CSV, three columns, one row per factor.** This is the format the template button hands out and the one the panel documents:

```
name,low,high
Temp,160,180
Pressure,20,40
Time,30,60
Catalyst,1,2
```

Read with `utils::read.csv()`. Match the three column names case-insensitively, and ignore any further columns rather than rejecting the file — an experimenter will often be uploading a sheet that also carries their own notes, and refusing it would be unhelpful. Blank `low`/`high` cells are allowed and become `NA`, so a names-only file is a valid upload.

Also accepting `.xlsx` through `readxl::read_excel()` is a small addition on top — same three columns, same validation — and engineers will more often have a workbook than a CSV. It costs one dependency (`readxl`, already installed). Drop it if that is not worth it; nothing else in the plan depends on it.

Reject with a message naming what was expected, through the existing `stop_unavailable()` / `stop_unless()` helpers in `R/design.R`, for: a missing `name` column, non-numeric `low`/`high`, or zero rows.

## Coded scale belongs to the design

`new_design()` in `R/design.R` gains a `coded` argument: the two-element range the generator emits, or `NULL` when the table is already in real units.

| design | `coded` |
| --- | --- |
| `factorial_create()` | `c(-1, 1)` |
| `spacefilling_opt_create()` | `c(0, 1)` |
| `spacefilling_unif_create()` | `c(0, 1)` |
| `spacefilling_rand_create()` | `c(0, 1)` |

This is the `coded` flag removed earlier in the rewrite, coming back now that something consumes it — the comment in `new_design()` says as much.

**It must be declared, not measured.** A random Latin hypercube in 3 factors and 7 runs spans 0.0131 to 0.9706; it does not reach its own bounds and is not supposed to. Inferring the scale from the observed column range would stretch every such design to hit `low` and `high` exactly and destroy the sampling property. Verified against the current code while planning.

While adding the field, move the coded scale out of the prose notes. `spacefilling_rand_create()` currently says "Coded from 0 to 1. Seed 3." and the sfd ones say "…rescaled to 0-1". Those sentences become false the moment the table is shown in actual units. Derive that clause from `coded` at render time instead of writing it into each generator.

## Uncoding

```r
uncode_table(table, spec, coded)
```

For each column whose name appears in `spec$name`, map linearly from `coded` to that factor's `[low, high]`:

```
real <- low + (value - coded[1]) / (coded[2] - coded[1]) * (high - low)
```

Matching **by name** rather than position is what keeps the factorial's `Blocks` column and the two order columns out of it — they are not in the spec. It works because the design's factor columns are named from the spec in the first place.

Apply it in `current()` in `R/server.R`, between building the design and `with_run_order()`, so the order columns are added afterwards and never touched. It affects the rendered table, the CSV download and the title/notes alike — one transformation, one place.

## Wiring

**New module** `R/factors-module.R`: `factors_ui(id)` and `factors_server(id)`, returning a reactive list of `spec` and `uncode` (the checkbox). The grid is `DT::datatable(editable = "cell")` with edits folded back into a `reactiveVal` holding the spec; upload and template buttons sit under it.

**Contract change**: design module servers take the spec. `{design}_server(id, factor_spec)`, called from `app_server()` as `registry[[id]]$server(id, factors$spec)`. Each design module then:

1. Drops its `Factor names` text area — four of them go, and the spec becomes the single source of names.
2. Observes the spec and calls `updateNumericInput(session, "num_factors", value = nrow(spec))`, prepopulating without locking.
3. Passes `factor_names = factor_spec_names(spec, num_factors)` into its `_create()`.

The `{design}_create()` signatures do not change. They already take `factor_names`, and they should not learn about the spec or about units — uncoding happens above them, in the app layer.

**Documentation**: the contract table in `README.md` gains the `coded` field on `new_design()`, and the "Adding a design" steps gain "declare your coded scale, or `NULL`".

## Edge cases to handle explicitly

Each of these should produce a stated reason next to the disabled checkbox, not silence:

- Spec incomplete (any `NA` range) → names and count still apply, units unavailable.
- `low == high` → reject at validation; a zero-width range gives a constant column.
- `low > high` → allow it. A deliberately reversed range is meaningful and the linear map handles it.
- Counts disagree after the user overrides `num_factors` → names pad or truncate as today, units unavailable.
- Design declares `coded = NULL` → units unavailable, and the checkbox says the design is not in coded units.
- Duplicate names → `make.unique()`, as `rename_factors()` already does.
- No spec at all → everything behaves exactly as it does today. This is the case to keep working.

## Files

| file | change |
| --- | --- |
| `R/factors.R` | **new** — spec type, validation, file reading, template, `uncode_table()` |
| `R/factors-module.R` | **new** — sidebar panel: DT grid, upload, template, units checkbox |
| `R/design.R` | `new_design()` gains `coded`; `rename_factors()` folds into `factor_spec_names()` |
| `R/factorial-design.R`, `R/spacefilling-design.R` | declare `coded`; drop the coded scale from prose notes |
| `R/factorial-module.R`, `R/spacefilling-module.R` | drop four `Factor names` text areas; accept the spec; prepopulate `num_factors` |
| `R/registry.R` | pass the spec through to each design's server |
| `R/server.R` | start `factors_server()`; apply `uncode_table()` in `current()` |
| `R/ui.R` | factors accordion above the picker; sidebar to ~380px |
| `app.R` | `APP_PACKAGES` gains `DT`, and `readxl` only if xlsx upload is kept |
| `README.md` | contract table and "Adding a design" steps |

## Verification

- `Rscript tests/run.R`. New tests: snapshot the pure functions (`read_factor_spec()` on a good file and on each rejected one, `uncode_table()` against a hand-checked case, `factor_spec_names()` padding and truncating); `testServer()` on `factors_server()` for a grid edit and an upload; a contract test that every registered design declares `coded` or `NULL` deliberately.
- Hand-check the arithmetic once: a 2-factor factorial with Temp 160–180 and Pressure 20–40 must give exactly `160, 20` / `180, 20` / `160, 40` / `180, 40`. A `0`-level centre point must land on 170 and 30.
- Check a random Latin hypercube **does not** reach its endpoints after uncoding — values strictly inside 160–180. That is the test that the declared scale is being used rather than the observed one.
- Run the app and confirm the no-spec path is untouched: every design still builds, names still default to `A, B, C`, and the units checkbox is disabled with a reason.
- Upload a CSV with extra columns and odd capitalisation, one with a missing `name` column, and one with names but blank ranges. The first two exercise the lenient match and the error message; the third must load and leave units unavailable.

## Deliberately not in this plan

- **Per-factor units** (°C, bar) as a fourth column. Easy to add later; it only affects headings.
- **Non-quantitative factors.** A crossed array has separate control and noise counts, and a mixture design's components are proportions constrained to sum to 1. Both are excluded by the `coded = NULL` opt-out rather than modelled. Revisit when one is actually added — the spec would need a per-factor type, which is a bigger change than it looks.
- **Discrete or categorical levels.** The linear map assumes a continuous range.
