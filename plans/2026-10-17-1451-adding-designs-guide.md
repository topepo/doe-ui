# A guide for adding designs with an LLM

## Context

Adding a design to this app is a repeatable job: find the package that builds it, read what it supports off that package, write a pure generator, write a Shiny module, add one registry line. The shape is settled and `README.md` documents the contract.

What the README does not carry is the *procedure*, or the traps. Every one of the following cost real debugging time while the first four designs were built, and an LLM coming to this repo cold will hit them again:

- A defining relation derived in app code instead of read from FrF2 — `2^p` words for `p` generators, which hung the app at 53 generators.
- Run counts computed as a span of powers of two, when the FrF2 catalog has holes in it.
- A coded scale measured from the data rather than declared, which would silently stretch a random Latin hypercube to hit its endpoints.
- Dropdowns declared `choices = NULL` and filled by an observer, which arrive empty whenever a design is reselected.
- A lookup returning column indices as values and run counts as names, backwards from the convention, which produces a dropdown that looks right and submits nonsense.

The deliverable is one markdown file at **`inst/adding-designs.md`** written as instructions to a model, so it can be handed to an LLM — or read by a person — before extending the app.

## Decisions

- **Location and format** — `inst/adding-designs.md`. Written SKILL.md-style: YAML frontmatter (`name`, `description`) and an imperative body, so it works as a prompt today and can be moved to `.claude/skills/add-doe-design/SKILL.md` unchanged if it should become invocable.
- **The contract is not duplicated.** `README.md` holds the contract table and stays the source of truth; the guide tells the model to read it first and then references the pieces by name. Two copies of the contract would diverge the first time it changes.

## Content

### Frontmatter

`name: add-doe-design`, and a description naming the triggers: adding a design, adding a design family, wiring a new DOE package, extending the registry.

### Section 1 — Read this first

Point at `README.md` "Adding a design" for the contract, and at `R/factorial-design.R` as the reference implementation. State the one rule everything else follows from: **the package is the source of truth**, the app calls it and reports what it returns.

### Section 2 — Decide family or type

The test, stated once: *does switching between them change which inputs are on screen?*

- Different options panel → a new registry entry, possibly in a new `family`.
- Same panel, different argument to the same generator → a `type` within one design.

Worked from the real case: the optimized and random Latin hypercubes are separate entries because one picks a run count from a list and the other takes any number; the three optimized criteria are types because they share a panel. Uniform designs are separate again because they are not hypercubes and reach 15 factors where the others stop at 10.

### Section 3 — Establish what the package supports

Before writing anything, find out *from the package*, in a console:

- Which parameter combinations exist. Read the package's own catalog or index if it has one — `FrF2::catlg`, `sfd::sfd_lib` — rather than inferring a range.
- Whether availability has **gaps**. 34-factor designs exist at 2048 runs but not 1024; asking FrF2 for a missing size errors rather than returning nothing.
- Whether the package already computes the design's properties. Check attributes on whatever it returns, not just its exported functions — FrF2 attaches the whole alias structure under `attr(design, "design.info")$aliased`.
- How long it takes at the largest size the app will offer. Anything iterative gets timed before it is exposed.

### Section 4 — Write the generator

`R/<name>-design.R`, pure R, no Shiny. Implement the contract functions. Specifics worth stating:

- `_get_limits()` returns a **named list** of integer pairs, because not every design counts factors.
- `_get_{option}_choices()` only exists for options whose valid values are constrained. Three of the four current designs have a run-count helper; the random hypercube takes any number in range and has none.
- `_get_types()` may return nothing, and an empty result is meaningful — it is how `factorial_create()` tells a full factorial from a fraction.
- Identify a type by the package's own id, never by position.
- A practical ceiling of ours is fine, declared in the design's own file and labelled as ours, never in `R/design.R`.
- Validate with `stop_unless()`, `stop_unavailable()`, `stop_out_of_range()` from `R/design.R`; messages are read by the experimenter.

### Section 5 — Write the module

`R/<name>-module.R`, `_ui(id)` and `_server(id)` returning a reactive yielding the `doe_design`. The two that bite:

- **Build dependent dropdowns with their choices already in place**, from a named default factor count. Observers fire only on *change*, and reselecting a design rebuilds its UI with the same values, which Shiny's input dedup suppresses — so anything left `NULL` stays empty on screen.
- Values are the data, names are the labels. Backwards gives a dropdown that displays correctly and submits nonsense.

### Section 6 — Register it

One entry: `label`, `family`, `ui`, `server`, `packages`. Note that registry order sets sidebar order, and that `design_registry()` is a function so source order does not matter.

### Section 7 — Verify

An ordered checklist: `Rscript tests/run.R`; add cases to `tests/testthat/test-contract.R` so the new design's shapes are pinned; snapshot the generator; time the largest size; boot the app and select the design, since `renderUI` means a broken module panel does not show up at startup; check the dropdowns are populated on first open *and* after switching away and back.

### Section 8 — Traps, with the evidence

Short entries, each with the concrete case that produced it, drawn from the list in Context above. These are the part a model cannot infer from the contract.

## Files

| file | change |
| --- | --- |
| `inst/adding-designs.md` | **new** — the guide |
| `README.md` | one line under "Adding a design" pointing at it |

`inst/` does not exist yet and will be created. The repo is not an R package, so nothing installs from `inst/`; it is being used as the conventional place for supplementary material.

## Verification

- Read it end to end against the current code and confirm every function name, file path and claim is real — `_get_num_runs_choices()` exists for three designs and not the fourth, `design_registry()` has exactly the five fields listed, the test files named exist.
- Hand the guide to a fresh model with a concrete task, such as adding Plackett-Burman from `FrF2::pb()`, and see whether it produces the right file layout and asks about the right things. That is the real test of the guide, and it is cheap.
- Confirm nothing in it restates the contract table, so there is only one copy to maintain.
