# Mixture designs: simplex-lattice

## Overview

Add a "Mixture Designs" family after the screening designs, holding one design for now: "Simplex-Lattice Designs", built with `mixexp::SLD()`. Follows `inst/adding-designs.md`: a pure generator in `R/mixture-design.R`, a module in `R/mixture-module.R`, and one registry entry. The generator file is named for the family, as `spacefilling-design.R` is, so later mixture designs have a home.

## Checklist

- [x] Establish from the package what is supported, how long it takes, and what it returns
- [x] Write `R/mixture-design.R`
- [x] Write `R/mixture-module.R`
- [x] Register `simplex_lattice` under a new "Mixture Designs" family in `R/registry.R`
- [x] Add `tests/testthat/test-mixture-design.R`, with snapshots for the output and the error messages
- [x] Pin the return shapes in `tests/testthat/test-contract.R`
- [x] Add module and dispatch tests in `tests/testthat/test-modules.R`
- [x] Update the picker tests that count families, from two to three
- [x] Add the two files to the table in `README.md`
- [x] Run `Rscript tests/run.R`
- [x] Boot the app, select the design, switch away and back
- [x] Cap the factor count at 10, which removes the dependent levels dropdown
- [x] Add a replications option

## Details

### The design and its options

A {q, m} simplex-lattice has every blend whose q proportions are each one of 0, 1/m, ..., 1 and sum to one. `SLD(fac, lev)` takes q as `fac` and m as `lev`. The request was 2 to 12 factors, later capped at 10, and "the number of unique mixtures" from 2 to 5, which is read as `lev`, the number of levels, offered as "Number of levels". If a different quantity was meant, this is the place to change it.

mixexp's own ceilings are 12 factors and 5 levels. The levels ceiling is the package's; the factors ceiling is ours, for the timing reasons below. The lower ends are ours too: one level gives only the pure components, and one factor is not a mixture.

### The range, and why factors stop at 10

The request was 2 to 12 factors, and the factor count is now capped at 10. `SLD()` builds the full `(levels + 1)^factors` grid with `expand.grid()` and then keeps the rows that sum to one, so its cost follows the grid and not the number of blends returned. Timed:

| factors, levels | grid | time |
| --- | --- | --- |
| up to 10 factors, any levels | up to 6^10 | under 4 s |
| 11, 4 | 5^11 | 2.6 s |
| 12, 4 | 5^12 | 18 s |
| 11, 5 | 6^11 | 33 s |
| 12, 5 | 6^12 | fails at the 64 GB memory limit |

Ten factors keeps every number of levels within a few seconds, with 10 factors and 5 levels the slowest at 3.6 s and 2002 blends. The ceiling lives in `mixture_sld_get_limits()`, labelled as ours: mixexp itself allows 12.

An earlier version kept 12 factors and made the levels dropdown depend on the factor count, with a grid budget of 6^10. Capping the factors made that unnecessary, so it was removed: every whole number of levels from 2 to 5 is valid at every factor count, and there is no `_get_num_levels_choices()` helper because there is no list of values to restrict. Both counts are plain numeric inputs. Every size in range was built and checked: the row count equals `choose(q + m - 1, m)`, every row sums to one, and no blend repeats.

### Replications

`SLD()` has no replication argument, so the replicates are made outside it. The lattice is stacked as complete copies in standard order, with nothing added to mark the copy, matching the factorial and Taguchi designs. The title reports the lattice's own run count and then ", n replications".

### Not a flat-factor design

The factors are components of a blend, constrained to sum to one. The table is in proportions, not coded -1/+1, so the design declares no coded scale. When `new_design()` gains its `coded` argument (see `2026-10-17-1425-factor-ranges-and-units.md`) this design passes `NULL`, which opts it out of the factor-range panel as that plan intends.

### Decisions

- No type and no `get_notes()`. A lattice has no variants, and `SLD()` returns a bare data frame with no metadata, so the notes are built in `create()` from its arguments.
- Proportions are left as mixexp computed them, unrounded; the table display rounds to three figures and the download keeps full precision.
- Factor names are the app's own, applied to the table: mixexp names its columns `x1`, `x2`, and the app's defaults are letters.

### Not done

- Other mixture designs, such as simplex-centroid and extreme-vertices, which would join this family.
- Component bounds (lower and upper limits on each proportion), which `mixexp` handles in other functions.
