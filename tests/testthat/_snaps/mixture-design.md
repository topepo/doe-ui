# the app's ceilings sit inside mixexp's own

    Code
      mixexp::SLD(13, 2)
    Condition
      Error in `mixexp::SLD()`:
      ! This function only handles 12 or less factors.
    Code
      mixexp::SLD(3, 6)
    Condition
      Error in `mixexp::SLD()`:
      ! This function only works for 5 levels or less

# a design is plain proportions, named as asked

    Code
      mixture_sld_create(num_factors = 3, num_levels = 2)
    Output
      {3, 2} simplex-lattice – 3 factors, 6 runs
        Each run is a blend: its proportions sum to 1.
        Proportions go up in steps of 1/2.
      # A tibble: 6 x 3
            A     B     C
        <dbl> <dbl> <dbl>
      1   1     0     0  
      2   0.5   0.5   0  
      3   0     1     0  
      4   0.5   0     0.5
      5   0     0.5   0.5
      6   0     0     1  

# replications stack complete copies of the lattice

    Code
      stacked$title
    Output
      [1] "{3, 2} simplex-lattice – 3 factors, 6 runs, 3 replications"

# create explains what it cannot build

    Code
      mixture_sld_create(num_factors = 1, num_levels = 2)
    Condition
      Error:
      ! Number of factors must be between 2 and 10. Got 1.
    Code
      mixture_sld_create(num_factors = 11, num_levels = 2)
    Condition
      Error:
      ! Number of factors must be between 2 and 10. Got 11.
    Code
      mixture_sld_create(num_factors = 2.5, num_levels = 2)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      mixture_sld_create(num_factors = NA, num_levels = 2)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 6)
    Condition
      Error:
      ! Number of levels must be between 2 and 5. Got 6.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 1)
    Condition
      Error:
      ! Number of levels must be between 2 and 5. Got 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2.5)
    Condition
      Error:
      ! Number of levels must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = NA)
    Condition
      Error:
      ! Number of levels must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = c(2, 3))
    Condition
      Error:
      ! Number of levels must be a whole number.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, replications = 0)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, replications = 1.5)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, replications = NA)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      mixture_sld_create(num_factors = 3, num_levels = 2, factor_names = "a")
    Condition
      Error:
      ! Give 3 factor names, not 1.

