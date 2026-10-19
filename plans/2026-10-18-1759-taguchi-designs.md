# Two-level Taguchi designs

## Overview

Add two-level Taguchi orthogonal arrays to the "Screening designs" family, built with `DoE.base::oa.design()`. Follows `inst/adding-designs.md`: a pure generator in `R/taguchi-design.R`, a module in `R/taguchi-module.R`, and one registry entry. Nothing is constructed in this app; the arrays come from the package.

## Checklist

- [x] Establish from the package what is supported, how long it takes, and what scale it emits
- [x] Write `R/taguchi-design.R`
- [x] Write `R/taguchi-module.R`
- [x] Register `taguchi` in `R/registry.R`
- [x] Add `tests/testthat/test-taguchi-design.R`, with snapshots for the output and the error messages
- [x] Pin the return shapes in `tests/testthat/test-contract.R`
- [x] Add module and dispatch tests in `tests/testthat/test-modules.R`
- [x] Add the two files to the table in `README.md`
- [x] Run `Rscript tests/run.R`
- [x] Boot the app, select the design, switch away and back

## Details

### What the package supports

"Two-level Taguchi" means the saturated arrays L_N(2^(N-1)), which are the rows of `DoE.base::oacat` whose only columns are two-level and whose column count is one less than the run count. That filter is read from the catalog, not written out here. It gives 36 arrays, L4 through L140, which today is every multiple of four. There are no gaps now, but run counts are still read from the catalog and never computed as a span, so the app follows whichever DoE.base version is installed.

The catalog also holds `L256.2.19` and `L2048.2.63`, which have only two-level columns but are not saturated. The saturation test excludes them, and it is the Taguchi definition rather than a ceiling of ours, so no run ceiling is declared. The largest array is 140 runs by 139 columns.

### Choosing the array must be done by ID

`oa.design(nruns = , nfactors = , nlevels = 2)` is not safe. It picks its own array by its own criteria: it returns a replicated full factorial for small factor counts, and a mixed-level array such as `L32.2.9` or `L96.2.20.4.2` for others. Only `ID =` pins the array. Verified across all 36 arrays: pinning by ID returned the right array and the right dimensions every time.

Passing the ID has a quirk. `oa.design()` treats an *unevaluated name* as a catalog lookup, and a character string is rejected. The base arrays (`L4.2.3`, `L12.2.11`, `L20.2.19` and every other fourth one) are objects in the package and must be bound to their own name; the rest are built from their lineage when only named. The generator binds the object when the package exports it, then passes the name. Without that, the base arrays fail with "No lineage information found".

### Options

- `num_factors`, from 2 to the widest array's column count. The array is saturated, so fewer factors than columns uses the first columns in order, which is the package default (`columns = "order"`).
- `num_runs`, one of the arrays with at least `num_factors` columns.
- `replications`, passed straight to `oa.design(replications = )`, which stacks complete copies of the array in standard order. Nothing is added to the table to mark the copy, matching the factorial. `repeat.only` is left at its default.
- Factor names.

There is no type. One array exists per run count, so `taguchi_get_types()` is not written, rather than inventing a helper that lists one thing. The package's other column-selection rules (`min3`, `min34`, ...) are a possible later addition and would be a type, since they change one argument and not the panel.

### Replication and residual degrees of freedom

`oa.design()` works out `residual.df` from the array alone, so a replicated design still reports the unreplicated figure. The app does not re-derive the correct number, since the package is the source of truth for it. Instead the note reads "Residual degrees of freedom, not counting replication" whenever there are replicates.

### Scale

The package emits levels "1" and "2" as a factor. They are recoded by label to -1 and +1, so this design reads on the same scale as the two-level factorial, and the notes say so. The scale is declared, not measured. This design should declare `coded = c(-1, 1)` when `new_design()` gains that argument (see `2026-10-17-1425-factor-ranges-and-units.md`).

### Not done

- Repeat-only runs (`repeat.only = TRUE`), which `oa.design()` supports.
- Mixed-level and three-level arrays, which belong with this family later but change the panel.
