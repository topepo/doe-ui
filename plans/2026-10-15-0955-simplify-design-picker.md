# Simplify the design picker app

## Context

`design_picker.R` (734 lines) and `designs.R` (1262 lines) work, but the structure costs more than the problem does. The idea — pick a design, set options, get a table — is sound; the machinery around it is not.

Three things carry most of the weight:

**Reflection-based option plumbing.** `collect_design_options()` reads `formals(generator)`, concatenates a per-design `prefix` onto each argument name to guess an input id, and filters out the ones that do not exist yet. `coerce_option()` then guesses whether `"16"` is a number or a word, because `selectInput` reports everything as text. `required_arguments()` inspects `quote(expr = )` to find arguments without defaults. The registry carries a `prefix` field and a `stopifnot` guarding against two designs colliding on it. All of this exists to connect an input to a function argument — which is what Shiny modules do natively, with namespacing instead of string concatenation.

**Hand-rolled navigation.** `design_link_id()` builds ids from display names, ten `actionLink`s get ten `observeEvent`s in a `for` loop wrapped in `local()` to avoid the loop-variable capture bug, and `output$design_nav_ui` redraws the entire accordion on every click purely to move an `.active` class. Roughly a third of `APP_CSS` exists to style those links.

**The excelR round-trip.** `merge_sheet_titles()` exists only because excelR reports the original column headers with one changed, so reading them directly forgets earlier renames. That workaround forces the `edited()` and `titles()` reactiveVals, the observer that resets them, and `make_download_table()`, which has to guess which character columns were numbers.

Smaller items: `%||%` is defined for R < 4.4 (we are on 4.6.1), `with_seed()` reimplements `withr::with_seed()`, and roughly a third of both files is prose, much of it explaining Shiny itself rather than this app.

The goal is the same app, with the structure a reader can hold in their head. The design *computations* are deliberately out of scope for now — the two-level factorial is the test case that proves the structure, and it is a fair test because it is the most demanding of the ten: its run-count choices depend on the factor count, and its catalog-fraction choices depend on the run count.

## Decisions

Settled before planning:

- **Scope** — delete the nine non-factorial generators. They stay recoverable from git history at `cc3901c`. Only the two-level factorial is implemented against the new structure.
- **Table** — read-only, rendered with `reactable` (already installed). excelR is dropped entirely. Factor naming moves into the options panel, which is what the column-rename feature was really for.
- **Factor names** — one comma-separated `textInput` ("Temp, Pressure, Time"), falling back to `A, B, C` when blank and padding or truncating when the count does not match. One input regardless of `k`, so nothing has to be rebuilt when `k` changes.
- **Layout** — `app.R` at the root with helpers in `R/`, which Shiny auto-sources. Tests under `tests/testthat/`.
- **Navigation** — keep the browse-by-family accordion sidebar, driven by one `radioButtons` per family rather than ten `actionLink`s and ten observers.

## Target layout

Shiny's `loadSupport()` sources **top-level** `.R` files in `R/` only — subdirectories are not sourced, so `R/` stays flat.

```
app.R                      # shinyApp(app_ui(), app_server) — thin
R/
  design.R                 # new_design(), with_run_order(), factor names, formatting
  factorial-design.R       # pure generator: no Shiny, fully testable
  factorial-module.R       # factorial_ui() / factorial_server()
  registry.R               # design_registry + the picker module
  ui.R                     # page_sidebar skeleton
tests/testthat/
  setup.R                  # shiny::loadSupport() so tests see R/
  test-design.R
  test-factorial-design.R
  _snaps/
```

Splitting the pure generator from its module is what makes "defer the computations" real: `factorial-design.R` has no Shiny dependency and can be exercised directly from tests, and adding a design back later means adding one `*-design.R` plus one `*-module.R` plus one registry line.

## Work items

### Phase 1 — Structure

- [x] Create `plans/`, `R/`, and `tests/testthat/`
- [x] Write `R/design.R`: `new_design()` (S3 class `doe_design` with a `print` method), `with_run_order()`, `factor_labels()`, `parse_factor_names()`, `format_coded()`
- [x] Write `R/registry.R`: the registry (one entry: id, display name, family, ui, server) and the picker module, clearing with `character(0)` and registering observers via `lapply()`
- [x] Write `R/ui.R`: `page_sidebar()` skeleton, no custom CSS unless something demonstrably needs it
- [x] Write `app.R`: package check, then `shinyApp(app_ui(), app_server)`

### Phase 2 — The factorial design

- [x] Write `R/factorial-design.R`: port `make_scr_tlf_design()` and its helpers (`tlf_run_choices()`, `find_tlf_catalog_entries()`, `describe_tlf_entry()`, `tlf_defining_relation()`, `code_to_word()`), dropping the `tlf_`/`scr_` prefixes
- [x] Write `R/factorial-module.R`: `factorial_ui()` / `factorial_server()`, returning `reactive(<doe_design>)`
- [x] Replace the `tlf_runs_ui` placeholder with `updateSelectInput()` driven by `k`, with `req(input$k)` so the startup flush is safe
- [x] Guard the top-level dispatch with `req(selected())` before indexing the server list
- [x] Keep one `uiOutput()` for the catalog-fraction radio, whose *existence* is conditional (see Details)

### Phase 3 — Output

- [x] Render the design table with `reactable`, read-only, coded levels shown as `+1` / `0` / `-1`
- [x] Wire the CSV download to the numeric table with factor names applied
- [x] Carry over the randomize checkbox and the `Standard order` / `Run order` columns

### Phase 4 — Tests and cleanup

- [x] `tests/testthat/setup.R` calling `shiny::loadSupport()`
- [x] Snapshot tests for `factorial_design()` across a full factorial, a fraction with one catalog entry, and a fraction with several
- [x] Snapshot tests for `parse_factor_names()` edge cases: blank, too few, too many, duplicates, whitespace
- [x] Snapshot tests for the generator's user-facing error messages
- [x] Delete `design_picker.R` and `designs.R`
- [x] Update `README.md` with how to run the app and the tests

## Details

### Module contract

One design is one module. The server returns a reactive yielding a `doe_design`:

```r
factorial_ui <- function(id) {
  ns <- NS(id)
  tagList(
    numericInput(ns("k"), "Number of factors", 6, min = 2, max = MAX_FACTORS),
    selectInput(ns("runs"), "Number of runs", choices = NULL),
    selectInput(ns("center"), "Center points", choices = 0:5),
    textInput(ns("names"), "Factor names", placeholder = "blank for A, B, C"),
    uiOutput(ns("alternatives"))
  )
}

factorial_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$k, {
      updateSelectInput(session, "runs", choices = run_choices(input$k))
    })
    reactive({
      factorial_design(
        k = input$k,
        runs = as.integer(input$runs),
        sub = as.integer(input$alternative %||% 1),
        center = as.integer(input$center),
        names = parse_factor_names(input$names, input$k)
      )
    })
  })
}
```

This replaces `collect_design_options()`, `coerce_option()`, `required_arguments()`, `is_blank()`, the `prefix` registry field, the prefix-uniqueness `stopifnot`, and the `setup_panels` / `setup_servers` split. Argument types are explicit at the call site (`as.integer(input$runs)`), so nothing has to guess whether `"16"` is a number.

### Why one `uiOutput` survives

`updateSelectInput()` handles the run-count dropdown because only its *choices* vary. The catalog-fraction radio is different: when there are fewer than two equivalent fractions there is nothing to choose and the input should not exist at all. A single namespaced `uiOutput()` is the honest way to express that, and it is clearer than a `conditionalPanel` with `outputOptions(suspendWhenHidden = FALSE)`. One `renderUI` for one genuinely conditional element is a fair trade for removing the rest.

### The picker module

Verified against the installed shiny 1.14.0 / bslib 0.12.0 sources while planning. One `radioButtons()` per family inside `accordion_panel()`, with the default family pre-selected and the rest cleared. Three details are load-bearing:

**Clear with `character(0)`, never `NULL`.** `radioButtons()` contains `selected <- if (is.null(selected)) args$choiceValues[[1]] else as.character(selected)`, so `selected = NULL` silently selects the *first* choice. `character(0)` survives that branch, and `generateOptions()` then marks nothing as checked. The same applies to `updateRadioButtons()`, where `character(0)` serialises to JSON `[]` and the client's `RadioInputBinding.setValue()` unchecks everything; `getValue()` then returns `null`, so `input[[id]]` becomes `NULL`.

**The mutual-clearing observers do not feed back,** for two independent reasons. Clearing a family that is already clear produces an identical JSON value, and shiny.js's `InputNoResendDecorator` suppresses the message before it reaches the server. Clearing a family that *did* have a selection does re-invalidate its observer, but the value is `NULL` and `observeEvent`'s default `ignoreNULL = TRUE` returns before the handler body runs. Keep the default explicitly rather than relying on it silently.

**Register the observers with `lapply()`, not `for` + `local()`.** R's `for` does not rebind the loop variable per iteration, which is why the current code needs `local()`. `lapply()` gets a fresh frame per element for free and removes the idiom entirely.

Note that `accordion(id = ...)` tracks only which panels are *open*, not which design is chosen, so it cannot replace the radios. It is still worth wiring up later so the family containing the current selection auto-expands.

With one design and one family today, the clearing path is dead code that only activates when a second family returns. Write it generically, but treat it as unexercised until then — these findings are traced from source, not observed in a running app.

### Guard the dispatch against `NULL`

The top-level server picks the selected module's reactive at runtime. The obvious spelling has a latent crash in it:

```r
current_design <- reactive({
  req(selected())             # without this, the next line errors
  design_servers[[selected()]]()
})
```

`req()` is not decoration here. `list[[NULL]]` raises `attempt to select less than one element in get1index`, and `selected()` is genuinely `NULL` in two reachable states: before any family has a selection, and transiently while one family is being cleared and another set. Without the guard that surfaces as a red error box rather than a quiet pause.

Relatedly, module *reactives* are lazy — an unselected design's reactive never executes — but `moduleServer()` runs the module body eagerly at startup, so any `observeEvent()` inside a module is live from the first flush whether or not that design is selected or its UI is in the DOM. The `observeEvent(input$k, ...)` that repopulates the run-count dropdown therefore needs a `req()` on `input$k`, since the input is `NULL` until the UI is rendered and bound.

### Two component details worth getting right first time

`bslib::accordion()` only renders flush against the sidebar when it is an *immediate* child of `sidebar()`. The picker module's UI function must therefore return the `accordion()` itself, not an `accordion()` wrapped in a `tagList()` or `div()`, or it picks up stray padding.

`reactable()` defaults to `pagination = TRUE` with `defaultPageSize = 10`, which would silently chop a 16-run design across two pages. Use `pagination = FALSE` with a fixed `height` to reproduce the current scroll-inside-the-table behaviour, plus `defaultColDef = colDef(align = "center")` instead of the per-column `align` entries that `make_sheet_columns()` builds today.

### `new_design()` keeps `coded`

With only the factorial left, `coded` is always `TRUE` and could be dropped. Keep it anyway, as an explicit field. Inferring "is this coded?" from whether the values land in `{-1, 0, 1}` is exactly the kind of cleverness this rewrite is removing, and the mixture and comparison designs will need the field when they return.

### Factor names

`parse_factor_names(text, k)` splits on commas, trims whitespace, drops empties, pads short vectors from `factor_labels(k)`, truncates long ones, and runs `make.unique()` so two factors cannot share a column name. It is a pure function with no Shiny dependency, which makes the edge cases cheap to snapshot.

### Randomization stays out of the generator

`with_run_order()` keeps the current separation: generators are deterministic and return rows in standard order, and the run-order column is added afterwards. That is what lets the generator snapshots be stable without seeding.

### What is deleted outright

From `designs.R`: nine generators and their `*_list()` functions, `with_seed()` (only the Latin hypercube used it), `is_prime()` and `make_paley_conference_matrix()` (definitive screening), `rsm_factor_table()`, `new_registry_entry()`, `registry_field()`, and the derived `design_catalog` / `design_generators` / `setup_panels` / `setup_servers` objects. From `design_picker.R`: `%||%` (base R since 4.4), `coerce_option()`, `collect_design_options()`, `is_blank()`, `required_arguments()`, `design_link_id()`, `make_design_nav()`, `merge_sheet_titles()`, `make_download_table()`, `make_sheet_data()`, `make_sheet_columns()`, `make_design_sheet()`, and most of `APP_CSS`.

Package dependencies drop from `agricolae`, `AlgDesign`, `DoE.base`, `FrF2`, `lhs`, `rsm`, `bslib`, `excelR`, `htmltools`, `shiny` to `bslib`, `DoE.base`, `FrF2`, `reactable`, `shiny`.

## Verification

- `shiny::runApp()` from the repo root, then check by hand: the accordion shows Screening with the factorial selected; changing the factor count repopulates the run-count dropdown; factor names reach the column headers; the randomize checkbox changes `Run order` only; the CSV downloads with the right headers and numeric levels.
- Both branches of the conditional alternatives input are reachable from the defaults, so check both: `k = 6` with 16 runs has **4** equivalent catalog fractions and must show the radio, while `k = 3` with 8 runs is a full factorial, has none, and must not. Verified against the installed FrF2 2.3.5 while planning.
- `testthat::test_dir("tests/testthat")` passes, with snapshots reviewed rather than accepted blind.
- Confirm no `source()` call remains anywhere — `R/` auto-loading replaces it.
- Watch the browser console and the R console for errors on first load. The dispatch and dropdown guards exist for states that only occur during the startup flush, so a clean first paint is the thing that actually exercises them.
- Line count as a sanity check, not a target: roughly 2000 lines today, expected to land near 500.

## What changed during implementation

Five things differ from the plan above, all verified against the installed packages rather than assumed.

**Default factor names: `names0()` was tried and reverted.** Columns briefly defaulted to `x1, x2, x3` (zero-padded to `x01 … x10` past nine), which required splitting the alias notation into a separate `yates_labels()` so defining relations stayed readable as `I = ABCE` rather than `x1x2x3x5`. Reverted at the user's request; `factor_labels()` is restored as the single function behind both column defaults and alias notation, exactly as before.

Worth keeping from that detour: `factor_labels()` handles more than 26 factors by switching *every* label to `X1, X2, …` rather than continuing from `Z`, and it does not pad, so `X10` sorts before `X2`. Neither matters while `MAX_FACTORS` caps the factorial at 8, but Plackett-Burman takes up to 47 factors and the Latin hypercube up to 30, so this needs revisiting when either returns.

**`design_registry` is a function, not a list.** `loadSupport()` sorts `R/` with `sort_c()` and sources it alphabetically, so a registry holding function *objects* at top level breaks as soon as a design file sorts after `registry.R` — `R/rsm-module.R` would. Resolving the functions when the registry is called makes source order irrelevant. Call it as `design_registry()`.

**Tests need `tests/run.R`.** `expect_snapshot()` requires testthat's 3rd edition, which a package declares in DESCRIPTION; this is not a package, so `setup.R` calls `local_edition(3)`. Snapshots also skip themselves unless `NOT_CRAN` is set, so the runner sets it — this app is never submitted to CRAN, so the snapshots should always run.

**Added `tests/testthat/test-modules.R`.** Not in the plan. `shiny::testServer()` exercises the module servers without a browser, covering the reactive wiring the pure-function snapshots cannot reach: the dependent run-count dropdown, the stale-run-count pause, the validate path for an unusable factor count, and the full picker → dispatch → design path through `app_server`.

**`append_center_points()` resets row names.** `rbind()` derives them from the originals, so copying row 1 produced duplicates like `11` and `1.1`. `new_design()` masked it downstream, but the helper should not emit it.

### Result

51 tests pass, no skips. App code went from 1996 lines across two files to roughly 580 across seven, with around 250 lines of tests where there were none. Dependencies dropped from ten to five: `agricolae`, `AlgDesign`, `lhs`, `rsm`, `excelR`, and `htmltools` are gone.

The one unexercised path is the picker's cross-family clearing, which cannot run until a second family is registered. The mechanism is traced from the shiny and bslib sources but not observed live — worth a smoke test when the second design lands.

## Follow-up: limits read from the package, not declared in app code

The first pass carried `TLF_MAX_FACTORS <- 8L` forward from the old `designs.R` and kept `run_choices()` computing run counts arithmetically as `seq(ceiling(log2(k + 1)), k)`. Both were wrong in the same way: they restate in app code something the package already knows.

**What FrF2 actually supports.** The installed catalog (FrF2 2.3.5) holds 3099 entries spanning 3 to 160 factors and 4 to 4096 runs. The cap of 8 was discarding most of it.

**The catalog has gaps.** It is not a clean span of powers of two. 34 factors has designs at 64, 128, 256, 512, 2048 and 4096 runs — but not 1024. Asking `FrF2::FrF2(nruns = 1024, nfactors = 34)` errors with `subscript out of bounds` rather than returning nothing. 79 of the 158 catalogued factor counts have a hole like that, so the arithmetic version would have offered an unbuildable run count for half of them.

All of those holes sit above the 256-run ceiling now in place, so the arithmetic version would get away with it at today's settings. That is a coincidence, not a justification — reading the catalog keeps the app right if the ceiling is raised or a future FrF2 ships a different catalog.

**What changed.** `factorial_support` and `factorial_factor_range` in `R/factorial-design.R` are computed from `FrF2::catlg` when Shiny sources the file, and `run_choices()` reads off them. `MAX_FACTORS` is gone from `R/design.R` entirely: limits are design-specific, so they live with the design that owns them. `FACTORIAL_MAX_RUNS <- 256L` is the one declared value, and it is explicitly a practical ceiling of ours rather than a limit of FrF2. The usable factor range is then derived as 2 to 127.

**Shared error helpers.** Unpredictable parameter values are not specific to this design, so `R/design.R` gained `stop_unavailable()` and `stop_out_of_range()` alongside `stop_unless()`, plus `format_choices()` to shorten a long list. The first produces `1024 is not an available run count for 34 factors. Choose one of: 64, 128, 256.` and handles the empty case as `No run count is available for 99 factors.` It is already general enough for the designs still to come — `stop_unavailable("rotatable", c("faces", "spherical"), "axial distance")` is the central composite's `alpha` argument.

**A bug this surfaced.** `factorial_design(k = NA, ...)` reached `if (k < range[1] || ...)`, which is `NA`, and died with `missing value where TRUE/FALSE needed` instead of a message. The generator now checks that `k` is a whole number first.

### Still open

`factor_labels()` switches every label to `X1, X2, ...` past 26 factors rather than continuing from `Z`, and does not pad, so `X10` sorts before `X2`. That was unreachable while the cap was 8 factors; with the range now reaching 127 it is not. Left as is, since the zero-padded `names0()` alternative was tried and reverted.

The table renders every row at once (`pagination = FALSE`). Bounded at 256 runs that is fine; raising `FACTORIAL_MAX_RUNS` would want pagination turned back on.

70 tests pass, no skips.

## Follow-up: names0 restored, table formatting removed

**Default column names are `names0()` again**, so a design comes out as `x1, x2, x3`, padded to `x01 … x10` past nine. The alias notation keeps single letters via `yates_labels()` — generators read `E = ABC` and the note still reads `Defining relation: I = ABCE = ABDF = CDEF`, which `x1x2x3x5` would not. FrF2 has no letter vector of its own to borrow, so `yates_labels()` falls back to `F1, F2, ...` past 26 factors; with the range now reaching 127 that is reachable, though the notation is not much use at that size anyway.

**The table data is no longer reformatted.** `format_coded()` is gone, and with it the `"+1"` / `"0"` character conversion and the `round(values, 4)` branch. `display_table()` now only applies `signif()`, so values stay numeric and the CSV download continues to write the untouched table at full precision.

Three significant figures is `signif()` rather than reactable's `colFormat(digits = )`, which counts *decimal* places — it would render a coded `-1` as `-1.000` and could not shorten `1234.567` to `1230`. Factor columns are right-justified through a per-column `colDef(align = "right")`; the two order columns keep the centred default so they still read as row labels.

**`coded` was removed from `new_design()`.** Its only consumer was the formatting branch above. It is noted in the file as something to add back if anything genuinely needs to tell coded levels from real quantities — the mixture designs might, when they return.

79 tests pass, no skips.

## Follow-up: letters first, names0 past the alphabet

Default column names are now `factor_labels()`: `A, B, C` while the letters last, then `names0()` from 27 factors on, so a 30-factor design is `x01 … x30` rather than running out of alphabet. The switch is wholesale — a design never mixes the two schemes.

`yates_labels()` is gone. It was identical to `factor_labels()` for 26 factors or fewer, and only diverged past that, where no concatenated notation is readable anyway: `F1F2F3` is no clearer than `x001x002x003`. One function now serves both column names and alias notation. The separation that actually matters is preserved — a user's own factor names reach the columns only, so renaming a factor to `Temp` never leaks into the defining relation. There is a test for that.

### A hang this exposed

Lifting the factor cap made `defining_relation()` dangerous. It multiplies every combination of the design's generators, so a design with p generators has 2^p − 1 words:

| design | generators | words |
| --- | --- | --- |
| 6 factors, 16 runs | 2 | 3 |
| 20 factors, 256 runs | 12 | 4,095 |
| 30 factors, 64 runs | 24 | 16.7 million |
| 60 factors, 128 runs | 53 | 9.0e15 |

Only the first two are feasible. At the old cap of 8 factors this was unreachable; with the range now derived from the catalog it is easy to hit, and it froze the app — the 30-factor case had to be killed after two minutes.

`relation_note()` now derives the relation only at or below `MAX_RELATION_GENERATORS` (12, so at most 4,095 words) and otherwise reports what the catalog already holds: `24 generators. Defining relation not shown; it has 1.68e+07 words. Shortest words: 945 of length 4.` Every size above now builds in under a fifth of a second, and there is a timing test guarding it.

`describe_entry()` got the same treatment, showing at most six generators before `, ... (24 generators)`, since a fifty-generator radio label is unreadable.

95 tests pass, no skips.

## Follow-up: aliasing read from FrF2 (closes #1)

The defining relation was being computed in app code — `defining_relation()` XORed every subset of the design's generators to build the group. That was the same "built locally" problem as the Paley matrix, carried over intact from the old `designs.R` and not recognised as one while porting.

FrF2 attaches the alias structure to every design it builds, under `attr(design, "design.info")$aliased`, with `$legend`, `$main` and `$fi2`. No internal function, no model fit, no catalog decoding. It is cheap at every size because it reports alias classes of two-factor interactions — bounded by the run count — rather than enumerating words: 0.11s for the 60-factor design whose defining relation would be 9e15 words.

So `MAX_RELATION_GENERATORS` is gone. There is no cutoff now, and every design the app offers shows its aliasing. It is also the more useful report — `AB=CE=DF` says directly what is confounded with what. Resolution III designs report `$main` instead, e.g. `A=BD=CE=FG, ...`.

Removed along with it: `relation_note()`, and `code_to_word()`, which decoded Yates column codes into letters. `DoE.base::generators(name, select.catlg = FrF2::catlg)` returns `"E=ABC" "F=ABD"` ready-made. Note the explicit `select.catlg`: it defaults to a bare `catlg`, which is only on the search path when FrF2 has been attached, and this app only uses qualified calls.

`factor_names` is now passed into `FrF2::FrF2()` rather than applied to the table afterwards, so the alias legend is expressed in the names in use. Renaming two factors gives `Factors: A=Temp, B=Pressure` beside the unchanged confounding; the legend is suppressed when it would be identity.

### Still open

Past 26 factors FrF2 labels with lowercase (`Aa=BZ=Cc=De=...`) and past 52 with `F1:F17=...`, while our columns go `A ... Z` then `x01, x02, ...`. The legend note covers the mismatch but truncates at 12 entries, so a 30-factor design reads `Factors: A=x01, B=x02, ... (30 in all)`. Adopting FrF2's own factor names as the defaults would remove the mismatch, at the cost of the letters-then-names0 rule.

93 tests pass, no skips.

## Follow-up: center points, blocks and replications from FrF2

Three more computations moved into the package, following the rule that the package is the source of truth.

**Center points.** `append_center_points()` built the rows by hand — copy row one, zero it, `rbind`. FrF2 has `ncenter`. Output is identical in every case checked, because with `randomize = FALSE` FrF2 also appends them at the end, and it records the count in `design.info`. Its `center.distribute` argument can spread center points through the run order instead of clumping them at the end, which is better for detecting drift; not used yet, but now one argument away. Note `ncenter` is **per block**, so the title counts `center * blocks`.

**`blocks` and `replications` exposed,** both defaulting to FrF2's own defaults of 1. `replications` repeats every run; `blocks` adds a block column. Two traps found while wiring them up:

- FrF2's `blocks` is overloaded — a number means how many blocks, but a vector of Yates column numbers is also accepted. An integer `1L` takes the latter branch and fails with `'names' attribute [2] must be the same length as the vector [0]` rather than meaning "unblocked". A double `1` is correct, so `factorial_design()` coerces. There is a test pinning it.
- Block labels are **not numbers**. With replications FrF2 labels them `1.1`, `2.1` — block and replicate — and with replications alone, `.1`, `.2`. The first version of this coerced the column to numeric and turned `"1.1"` into 1.1, inventing a number that looked like data. The block column now stays character, found by elimination against `factor_names` because `design.info$block.name` is `NULL` when replications alone produced the column.

**Table construction switched from `desnum()` to `as.data.frame(design)`,** which carries FrF2's factor names and a readable block column where `desnum()` contrast-codes it into `Blocks1`. The table is rebuilt as a plain data frame rather than edited in place, so FrF2's `design.info`, `desnum` and `run.order` attributes do not ride along on what the app hands out. A test asserts they are absent.

### Block choices are only structurally derivable

`block_choices(runs)` offers powers of two up to half the run size, which are FrF2's own two stated rules. Whether a *particular* count works is design-specific — FrF2 refuses a blocking that confounds a two-factor interaction, so 4 blocks is fine for some 16-run designs and not for `6-2.1`. That cannot be known without building the design, and probing every candidate was measured at 16s for a 256-run design, far too slow for a dropdown:

| design | runs | candidates | probe time |
| --- | --- | --- | --- |
| 6-2.1 | 16 | 3 | 0.06s |
| 12-6.1 | 64 | 5 | 0.56s |
| 20-12.1 | 256 | 7 | 15.92s |

So the dropdown offers what is structurally valid and FrF2's own message covers the rest — `no adequate blocked design found with 2fis unconfounded with blocks in design 6-2.1` — which the module already shows in place of the table. `FrF2::block.catlg` was checked as an alternative source and does not help: it is a 30-row table of block generators for full factorials only, not catalogued fractions.

### Audit of what remains computed locally

- `catalog_entries()` filters and sorts `FrF2::catlg`; there is no exported catalog-selection helper, so the filtering is unavoidable. The *ordering* is now pinned by a test showing the entry we put first is the one FrF2 itself picks when asked for a design without naming one, agreeing across all sizes tested.
- `with_run_order()` generates the run-order permutation with `sample()`. This is deliberate and not a reimplementation: FrF2's `randomize` permutes the design rows, where this keeps rows in standard order and adds a run-order column, which is what keeps generators deterministic and snapshot-testable.

123 tests pass, no skips.

## Follow-up: num_runs and num_factors throughout

The two quantities every design shares are now named consistently: `num_runs` for the number of runs and `num_factors` for the number of experimental factors. This replaces the terse `k`, `n` and `runs` the code had inherited from the original `designs.R`. It covers function arguments, local variables and Shiny input ids alike, so `input$num_factors` feeds `factorial_design(num_factors = )`.

Renamed: `factorial_design()`, `run_choices()`, `catalog_entries()`, `block_choices()`, `factor_labels()`, `parse_factor_names()`, `usable_factor_count()`, the locals in `factorial_support` and `with_run_order()`, and the `num_factors` / `num_runs` inputs in the factorial module. `center_point_text(n, total)` became `center_point_text(num_center, num_runs)` while its arguments were being touched.

Three things deliberately left alone:

- **Arguments of the underlying packages.** `FrF2::FrF2(nruns = , nfactors = )` is still called as FrF2 names it. Renaming at that boundary would hide which name belongs to whom.
- **`names0(num, prefix)`**, which keeps the signature it was supplied with.
- **`FACTORIAL_MAX_RUNS`**, a constant that already reads as a maximum number of runs; `FACTORIAL_MAX_NUM_RUNS` would be worse.

Historical sections of this plan still refer to `k` and `runs` where they describe work done at the time. That is the record of what happened, so it stays as written.

All 149 tests pass. The 19 snapshot lines that changed are the expressions `expect_snapshot()` records, not results — every error message and printed output is byte-identical, checked by diffing them against the previous commit.

## Follow-up: a prescriptive helper contract

The README said a design needs "a generator that takes its options as arguments, validates them, and returns `new_design()`", which is too vague to follow. There is now a named contract, with `R/factorial-design.R` as the reference implementation:

| function | returns |
| --- | --- |
| `{design}_get_packages()` | packages this design needs |
| `{design}_get_limits()` | named list of integer ranges, one per count option |
| `{design}_get_{option}_choices(...)` | valid values for an option that depends on other options |
| `{design}_get_types(...)` | the variants to choose between, ids named by label |
| `{design}_create(...)` | the `doe_design` |
| `{design}_get_notes(design)` | what the package says about the result |

Three shapes in that table exist because the deferred designs disagree with each other, and auditing their old signatures is what settled them:

- **`_get_limits()` returns a named list** rather than one range. Four of the eleven original generators count something other than factors — components, treatments, a square size — and the crossed array has two independent counts.
- **`_create()` takes named options with no positional run count.** The run count is chosen for only two of eleven designs; everywhere else it is derived from the other options, so a fixed `num_runs` argument would be dead weight those designs must ignore.
- **`_get_types()` may return nothing.** Six of eleven have no variant at all, and a full factorial has none either — which is now exactly how `factorial_create()` distinguishes a full factorial from a fraction.

**Types are identified by the package's own id.** `factorial_get_types()` returns FrF2 catalog ids like `6-2.1`, named by their label. This replaced an `alternative` index, and removed a real defect with it: the index was clamped with `min(max(1, alternative), length(entries))`, so a selection left over from a different size silently became whatever had moved into that slot. An unknown id is now rejected by name through `stop_unavailable()`, and the module falls back to the best type rather than the generator guessing.

**Package checks are per design.** `app.R` keeps only `APP_PACKAGES` for what the app itself needs; everything else comes from each entry's `packages` field in the registry. Adding a design that wraps a new package no longer means editing a central list, and the error names the package actually missing.

Renamed along the way: `factor_labels()` to `default_factor_names()`, `parse_factor_names()` to `rename_factors()`, `run_choices()` to `factorial_get_num_runs_choices()`, `block_choices()` to `factorial_get_blocks_choices()`, `catalog_entries()` to `factorial_catalog_entries()`, `describe_entry()` to `factorial_type_label()`, `alias_notes()` to `factorial_get_notes()`, and `factorial_design()` to `factorial_create()`.

168 tests pass, no skips.

## Follow-up: output formats documented and pinned

Reading `factorial_get_num_runs_choices()` did not say what it had to return, which is a problem for anyone implementing the next design. Every contract function now states its shape directly above it, the README gives the same table with types, and `tests/testthat/test-contract.R` pins all of it so the documentation cannot drift from the code.

The one worth stating twice, and the reason the tests exist: **the vector holds the values and its names are the labels.** Getting that backwards produces a dropdown that looks correct and submits nonsense, because Shiny takes names as labels and values as values. Both `_get_{option}_choices()` and `_get_types()` follow it.

Documenting the shapes turned up an inconsistency worth keeping rather than fixing: `factorial_get_num_runs_choices()` is named and `factorial_get_blocks_choices()` is not. Both work, since Shiny shows the value when there is no name. The contract now says names are *optional* on `_choices()` — supply them only when the value alone does not read well. A run count earns `16 runs (2^(6-2) fraction)`; a block count does not.

Two things the tests documented rather than changed:

- `factorial_get_num_runs_choices(1)` is **not** empty. One factor is outside `get_limits()`, but 2^1 is within the run ceiling, so a two-run design is offered. The empty case is a factor count past what the catalog covers.
- `factorial_get_notes()` handed a `doe_design` instead of the package's object returns `character(0)` rather than erroring, because the attribute it reads is simply absent. That makes the README's "takes the object the package returned" load-bearing: calling it at the wrong point in construction loses the notes silently instead of failing.

213 tests pass, no skips.

## Follow-up: two space-filling designs, and three bugs in the sfd lookup

The space-filling scaffold became two registry entries in one family, `Latin hypercubes (Optimized)` (sfd) and `Latin hypercubes (Random)` (DiceDesign). Two entries rather than one design with a type, because switching between them changes which inputs are on screen: the optimized one picks a type and then a run count that depends on it, while the random one takes any run count in range and has no type at all. Their limits differ too — 2 to 15 factors against 2 to 50 — which a single entry could not express.

Multiple designs per family needed no change to the registry: `design_families()` already groups by the `family` string and the picker builds one radio group per family.

### Three defects in the draft sfd lookup

**`sfd_list()` returned indices where it meant run counts.** `which(x != 0)` yields positions named by the dimnames, so `Max-Min (L1)` at six factors came back as `c("4" = 3, "5" = 4, "6" = 5, "7" = 6)` — the names were the run counts and the values were column positions. Fed to a dropdown that is precisely the failure the contract warns about: it displays correctly and submits nonsense. Values are now the run counts.

**`apply()` collapsed to a matrix from 11 factors up.** `apply()` over the rows of a table simplifies when there is a single row, and from eleven factors only the `uniform` type survives, so `sfd_list(11)[["Uniform"]]` failed with `subscript out of bounds` — exactly at the top of the supported range. Now `lapply()` over the types.

**The factor range was understated.** `length(sfd::sfd_lib) - 1` gives 13, but the library is indexed from two factors up, so its fourteen elements reach **15** factors. `spacefilling_opt_get_limits()` now reads `length(sfd_lib) + 1L`.

The type availability is worth knowing: all four types exist from 2 to 10 factors, and only `uniform` from 11 to 15. So a type genuinely does go stale when the factor count crosses ten, which the module handles by pausing rather than silently substituting, and which has a test.

227 tests pass, no skips.

## Follow-up: dropdowns arrived empty

Four dependent dropdowns rendered with no options at all — the factorial's run count and blocks, and the optimized design's type and run count — and stayed empty until the factor count was nudged.

The cause is that each was declared `choices = NULL` and filled by an `observeEvent()` on the factor count. That observer fires only when its input *changes*. The module UI is rebuilt by `output$options` every time a design is selected, and the rebuilt inputs re-send the same values, which Shiny's client-side dedup suppresses — so nothing changed, the observer never ran, and the selects stayed as rendered.

They are now built with their choices already in place, from a named default factor count per design (`FACTORIAL_DEFAULT_FACTORS`, `SPACEFILLING_OPT_DEFAULT_FACTORS`) so the value and the dependent choices cannot drift apart. The observers stay, for when the user does change the factor count.

A test now renders every registered design's UI and asserts no `<select>` comes back without options, which covers designs not yet written.

### Two fixes to the sfd rescaling

The `[0, 1]` standardization added to `spacefilling_opt_create()` had a stray `sprintf()` argument — the format string had lost its `%d` but kept `num_runs`, which R warns about. The note now reads `Precomputed by the sfd package, 20 levels rescaled to 0-1.`

The rescaling itself divides by `num_runs` rather than each column's own maximum. Every column of a Latin hypercube is a permutation of 1 to n, so the two agree today — checked across three types and sizes — but the per-column form would silently put each factor on a different scale if that ever stopped holding. It is also base R now rather than `purrr::map_dfc()`, which is superseded and would have added an undeclared dependency: `spacefilling_opt_get_packages()` lists only `sfd`.

236 tests pass, no skips.

## Follow-up: tibbles

`doe_design$table` is a tibble. `new_design()` coerces whatever a generator hands it, so no generator has to remember, and `as_tibble()` drops the row names that `rbind()` and friends leave behind.

Two things that needed care:

- **`as_tibble()` does not strip other attributes.** The guarantee that FrF2's `design.info`, `desnum` and `run.order` stay off the table still comes from rebuilding it column by column in `factorial_create()`, not from the coercion. The README says so, and the test that asserts those attributes are absent still passes.
- **`cbind()` would have silently undone it.** `with_run_order()` used `cbind()`, which dispatches to the base method and returns a plain data frame. It now uses `tibble::add_column(.before = 1)`.

`print.doe_design()` prints with `n = Inf` rather than the tibble default of ten rows: a design is meant to be read whole, and run counts are bounded by each design's own ceiling. Without it the snapshots would cover only the first ten runs of a sixteen-run design.

Snapshots changed but no values did. The numeric content of the old and new snapshot files differs only by the `# A tibble: 16 x 6` header lines and by tibble not padding to a common decimal width — `0.333000` became `0.333` and `1230.00` became `1230`. The value assertions over the same data were untouched and still pass.

Verified that the CSV download round-trips and reactable renders from a tibble.

236 tests pass, no skips.

## Follow-up: room to type factor names

The `Factor names` box is a three-row `textAreaInput` instead of a one-line `textInput`, in all three designs. The input holds one name per factor and the factorial goes to 127 of them, so a single line was never going to be enough. `resize = "vertical"` so dragging it taller cannot break the panel width.

The inputs carry no explicit width and already stretch to the card, so height was the dimension with anything to gain.

`rename_factors()` now splits on newlines as well as commas. A text area invites one name per line, and without this the whole block would have arrived as a single factor name. Verified end to end: `"Temp\nPressure\nTime\nCatalyst"` reaches the table as four columns.

242 tests pass, no skips.

## Follow-up: uniform designs split out of the Latin hypercubes

A uniform design minimises discrepancy from a uniform distribution over the region. That is a different criterion from the three the sfd package optimises a Latin hypercube against, and the result is not an LHC, so it is now its own registry entry — `Uniform designs` — rather than a fourth type under `Latin hypercubes (Optimized)`.

The split is not only a matter of naming. The two reach different distances:

| | factor counts | types to choose |
| --- | --- | --- |
| Latin hypercubes (Optimized) | 2 to 10 | Audze-Eglais, Max-Min (L1), Max-Min (L2) |
| Uniform designs | 2 to 15 | none |

Past ten factors sfd holds **only** uniform designs. The combined entry therefore claimed 2 to 15 factors and would have failed across 11 to 15 for every criterion a user could actually select — the stale-type handling papered over it by falling back to uniform. Both ranges are derived from the installed library by `sfd_factor_range()`, not written down, so they follow whichever sfd is present.

Having a single criterion, the uniform design returns no types at all and `spacefilling_unif_create()` takes no `type` argument — the contract already allows an empty `_get_types()`, and this is a cleaner instance of it than the factorial's full-factorial case.

The shared work moved into `sfd_create()` and `sfd_table()`: the two sfd designs differ in which types they offer, not in how a design is built. `SFD_SUPPORT` now summarises all fourteen library tables once when the file is sourced, about a tenth of a second, rather than rescanning on every keystroke.

262 tests pass, no skips.

## Follow-up: the picker reads as a list again, not radio buttons

The original app picked a design by clicking its name; the rewrite replaced that with visible radio buttons. That was my decision, carried inside the "Accordion family list" option chosen during planning — the question being answered there was accordion versus dropdown, and the control type rode along in the option's description rather than being asked about.

The radio group is worth keeping underneath. It gives one selection per family for free, where the original needed a `reactiveVal`, an `observeEvent` per design, `design_link_id()` to mangle names into input ids, and a `renderUI` that redrew the whole accordion on every click purely to move an `.active` class. It also lets the accordion sit as an immediate child of `sidebar()`, which is what makes it render flush — the original's `uiOutput()` wrapper broke that.

So the control stays and only the appearance changes. `PICKER_RULES` in `R/ui.R` styles the labels as the old links and moves the radio itself out of sight. Seven rules, scoped to a `design-picker` class that `picker_ui()` puts on each family's radio group, so a design's own radio inputs — the factorial's type selector — still look like radio buttons.

Two details worth keeping:

- The input is positioned out of view at 1px rather than hidden with `display: none`, which would take it out of the tab order and out of the accessibility tree. `:focus-visible` puts the focus ring back on the label.
- The rules are Sass, not plain CSS, so `$primary` and `color-contrast($primary)` follow the theme. Compiled against the yeti preset they resolve to `#008cba` on `#fff`; changing the preset moves the highlight with it. There is a test that reads the compiled stylesheet and asserts neither token is emitted literally.

Also made the family-order test derive its expectation from the registry rather than hardcoding ids, since the registry order is yours to change and the test should check the grouping, not the choice.

271 tests pass, no skips.

One practical note, which cost a round-trip to diagnose: bslib serves the compiled theme at `bootstrap-<version>/bootstrap.min.css`, named for the Bootstrap version rather than content-hashed. The URL therefore does not change when the Sass does, and a browser that cached the file keeps serving the old copy — editing `PICKER_RULES` looks like it has done nothing until a hard reload. There is a comment to that effect above the rules.
