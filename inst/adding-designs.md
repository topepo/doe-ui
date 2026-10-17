---
name: add-doe-design
description: Add a new experimental design, or a new design family, to the doe-ui Shiny app. Use when asked to add a design, wire up a new DOE package, extend the design registry, or add a variant of a design that already exists.
---

# Adding a design to doe-ui

## Read these first

- `README.md`, section "Adding a design" — the helper contract, the return shapes, and the naming rules. That is the source of truth; this file does not repeat it.
- `R/factorial-design.R` — the reference implementation of the contract.

One rule everything below follows from: **the package is the source of truth.** This app calls an R package, reports what it returns, and formats the result. It does not reimplement, re-derive, or second-guess the statistics. If you are about to write a loop that computes a design property, stop and look for it in the package first.

## 1. Is it a new design, or a type within one?

The test: **does switching between them change which inputs are on screen?**

- Different options panel → a separate registry entry. It may join an existing `family` or start a new one.
- Same panel, different argument to the same generator → a `type` within one design, returned by `{design}_get_types()`.

How the current four landed:

| | why |
| --- | --- |
| Latin hypercubes (Optimized) vs (Random) | separate entries — one picks a run count from a list, the other takes any number, so the panels differ |
| Audze-Eglais / Max-Min L1 / Max-Min L2 | types within the optimized entry — same panel, one argument changes |
| Uniform designs | separate entry — not a hypercube, and reaches 15 factors where the hypercube criteria stop at 10 |

Differing *limits* are a strong signal for separate entries. A single entry has to claim the widest range and then fail across the part it cannot serve.

## 2. Establish what the package supports, from the package

Before writing any file, open a console and find out:

**Which combinations exist.** Read the package's own catalog or index — `FrF2::catlg`, `sfd::sfd_lib` — rather than inferring a range from the documentation.

**Whether availability has gaps.** It usually does. FrF2 has a 2048-run design for 34 factors but no 1024-run one, and around half its factor counts have a hole like that. Asking for a missing size errors rather than returning nothing. Never compute the valid values as a span.

**Whether the package already computes the design's properties.** Check attributes on whatever it returns, not only its exported functions. FrF2 attaches the entire alias structure under `attr(design, "design.info")$aliased`; deriving it here instead took `2^p` words for `p` generators and hung the app at 53 generators.

**How long it takes at the largest size you will offer.** Time it. Anything iterative or combinatorial gets timed before it is exposed, not after a user finds it.

**What scale the values come out on.** You will need to declare it, so read it off a built design.

## 3. Write the generator — `R/<name>-design.R`

Pure R, no Shiny, so every piece is testable on its own. Implement the contract from the README. Points that are easy to get wrong:

- `_get_limits()` returns a **named list** of integer pairs. Not every design counts factors — a crossed array has control and noise counts, a mixture design counts components.
- `_get_{option}_choices()` exists only for options whose valid values are constrained. Three of the four current designs have a run-count helper; `spacefilling_rand_*` takes any number in range and has none. Do not invent a helper to list values that are not actually restricted.
- `_get_types()` may return nothing, and empty is meaningful — it is how `factorial_create()` distinguishes a full factorial from a fraction. Callers must cope with zero length.
- Identify a type by **the package's own id**, never by position in a list. An index silently selects whatever moved into that slot when the size changes.
- A practical ceiling of your own is fine. Declare it in the design's own file, label it as ours rather than the package's, and never put it in `R/design.R`.
- Validate with `stop_unless()`, `stop_unavailable()` and `stop_out_of_range()` from `R/design.R`. `stop_unavailable()` lists what *is* available, which is the only honest message when the package has gaps. These messages are shown to the experimenter in place of the table, so write them for that reader.
- Return `new_design(table, title, notes)`. Build the table column by column rather than handing over the package's object: coercion to a tibble does not strip the package's attributes.

## 4. Write the module — `R/<name>-module.R`

`<name>_ui(id)` and `<name>_server(id)`, the server returning a reactive that yields the `doe_design`. Two things bite here:

**Build dependent dropdowns with their choices already in place.** Declare a named default factor count — see `FACTORIAL_DEFAULT_FACTORS` — and compute the dependent choices from it in the UI function. Filling them from an observer alone is not enough: observers fire only when their input *changes*, and reselecting a design rebuilds its UI with the same values, which Shiny's client-side dedup suppresses. The dropdown then arrives empty and stays empty until the user nudges something. Keep the observer too, for when the count really does change.

**Values are the data; names are the labels.** `c("16 runs (2^(6-2) fraction)" = 16)`. Backwards produces a dropdown that displays correctly and submits nonsense.

Guard every reactive on the factor count being usable. `moduleServer()` runs eagerly at startup, so your inputs are `NULL` until the UI is rendered and bound.

## 5. Register it — `R/registry.R`

One entry: `label`, `family`, `ui`, `server`, `packages`. Registry order sets sidebar order, and families appear in the order they are first used. `design_registry()` is a function rather than a list so that source order does not matter — do not turn it back into a list.

## 6. Verify

In this order:

1. `Rscript tests/run.R`.
2. Add the new design to `tests/testthat/test-contract.R` so its return shapes are pinned — that file exists to stop the documented shapes drifting from the code.
3. Snapshot the generator's output and its user-facing error messages. Review the diff; a changed snapshot usually means a changed design.
4. Time the largest size you offer, and assert it in a test if anything about it is iterative.
5. Boot the app and select the design. A broken module panel does **not** show up at startup, because `output$options` renders it lazily — only selecting it will reveal the error.
6. Open the design, switch to another, and switch back. This is what catches empty dropdowns.

## Traps, with the case that produced each

Each of these was a real defect in this repo, not a hypothetical.

**Deriving what the package already knows.** A definitive screening design was built by hand from a Paley conference matrix. The alias structure was derived by multiplying every subset of a design's generators: 16.7 million words at 24 generators, 9e15 at 53, and a frozen app. FrF2 had it attached to the design all along.

**Computing valid values instead of reading them.** Run counts were generated as a span of powers of two. Around half of FrF2's factor counts have a missing size in that span, and asking for one errors.

**Measuring the coded scale instead of declaring it.** A random Latin hypercube in 3 factors and 7 runs spans 0.0131 to 0.9706 — it does not reach its own bounds, and is not supposed to. Any transformation that infers the scale from the observed column range will stretch it to the endpoints and destroy the sampling property.

**Returning indices where you meant values.** A lookup used `which(x != 0)`, which returns positions named by the dimnames — so the run counts ended up as *names* and column positions as *values*. The dropdown looked perfect and submitted nonsense.

**`apply()` over a table that has one row.** It simplifies to a matrix, and lookup by name then fails with `subscript out of bounds`. This happened only at the top of the supported range, where a single design type survived. Use `lapply()`.

**Overloaded package arguments.** `FrF2::FrF2(blocks = )` means "how many blocks" for a double, but a vector of Yates column numbers for an integer, so `blocks = 1L` fails obscurely where `blocks = 1` means unblocked. Coerce deliberately and pin it with a test.

**Labels that are not numbers.** With replications, FrF2 labels blocks `1.1`, `2.1` — block and replicate, not a decimal. Coercing that column to numeric invents data that looks plausible. Leave such columns as character.

## Things that are not designs

The app assumes quantitative factors on a coded scale. A mixture design's components are proportions constrained to sum to one; a randomized block design has treatments, not factors. If you are adding one of those, say so rather than forcing it into the flat-factor model, and check `plans/` for the current thinking on how those should be handled.
