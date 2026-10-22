# the app's ceilings sit inside mixexp's own

    Code
      mixexp::SLD(13, 2)
    Condition
      Error in `loadNamespace()`:
      ! there is no package called 'mixexp'
    Code
      mixexp::SLD(3, 6)
    Condition
      Error in `loadNamespace()`:
      ! there is no package called 'mixexp'

# create explains what it cannot build

    Code
      mixture_sld_create(num_factors = 1, num_levels = 2)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be between 2 and 10. Got 1.
    Code
      mixture_sld_create(num_factors = 11, num_levels = 2)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be between 2 and 10. Got 11.
    Code
      mixture_sld_create(num_factors = 2.5, num_levels = 2)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be a whole number.
    Code
      mixture_sld_create(num_factors = NA, num_levels = 2)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 6)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of levels must be between 2 and 5. Got 6.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 1)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of levels must be between 2 and 5. Got 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2.5)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of levels must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = NA)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of levels must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = c(2, 3))
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of levels must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, replications = 0)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, replications = 1.5)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, replications = NA)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, factor_names = "a")
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Give 3 factor names, not 1.

# centroid create explains what it cannot build

    Code
      mixture_scd_create(num_factors = 1)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be between 2 and 10. Got 1.
    Code
      mixture_scd_create(num_factors = 11)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be between 2 and 10. Got 11.
    Code
      mixture_scd_create(num_factors = 2.5)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be a whole number.
    Code
      mixture_scd_create(num_factors = NA)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Number of factors must be a whole number.
    Code
      mixture_scd_create(num_factors = 3, replications = 0)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_scd_create(num_factors = 3, replications = 1.5)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_scd_create(num_factors = 3, replications = NA)
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_scd_create(num_factors = 3, factor_names = "a")
    Message
      Loading required package: mixexp
    Condition
      Warning in `library()`:
      there is no package called 'mixexp'
      Error:
      ! Give 3 factor names, not 1.

