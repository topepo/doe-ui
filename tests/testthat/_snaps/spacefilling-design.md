# sfd designs are deterministic and in sfd's own row order

    Code
      spacefilling_opt_create(3, 6, "max_min_l2")
    Output
      Max-Min (L2) Latin hypercube – 3 factors, 6 runs
        Precomputed by the sfd package, 6 levels rescaled to 0-1.
      # A tibble: 6 x 3
            A     B     C
        <dbl> <dbl> <dbl>
      1   0     0.2   0.4
      2   0.2   0.6   1  
      3   0.4   1     0.2
      4   0.6   0     0.8
      5   0.8   0.4   0  
      6   1     0.8   0.6
    Code
      spacefilling_unif_create(2, 5)
    Output
      Uniform design – 2 factors, 5 runs
        Precomputed by the sfd package, 5 levels rescaled to 0-1.
      # A tibble: 5 x 2
            A     B
        <dbl> <dbl>
      1  0     0.25
      2  0.25  0.75
      3  0.5   0   
      4  0.75  0.5 
      5  1     1   

# sfd designs explain what they cannot build

    Code
      spacefilling_opt_create(11, 20, "max_min_l2")
    Condition
      Error:
      ! Number of factors must be between 2 and 10. Got 11.
    Code
      spacefilling_opt_create(2.5, 4, "max_min_l2")
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      spacefilling_opt_create(6, 20, "uniform")
    Condition
      Error:
      ! uniform is not an available design for 6 factors. Choose one of: audze_eglais, max_min_l1, max_min_l2.
    Code
      spacefilling_opt_create(6, 8, "max_min_l1")
    Condition
      Error:
      ! 8 is not an available run count for Max-Min (L1) in 6 factors. Choose one of: 4, 5, 6, 7.
    Code
      spacefilling_opt_create(6, 20, "max_min_l2", factor_names = c("a", "b"))
    Condition
      Error:
      ! Give 6 factor names, not 2.
    Code
      spacefilling_unif_create(16, 20)
    Condition
      Error:
      ! Number of factors must be between 2 and 15. Got 16.
    Code
      spacefilling_unif_create(6, 3)
    Condition
      Error:
      ! 3 is not an available run count for Uniform in 6 factors. Choose one of: 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, ... (144 in all).

# the seed makes a random design reproducible

    Code
      spacefilling_rand_create(3, 5, seed = 3)
    Output
      Random Latin hypercube – 3 factors, 5 runs
        Coded from 0 to 1. Seed 3.
      # A tibble: 5 x 3
            A     B      C
        <dbl> <dbl>  <dbl>
      1 0.966 0.879 0.298 
      2 0.238 0.775 0.699 
      3 0.123 0.141 0.0932
      4 0.734 0.484 0.889 
      5 0.480 0.274 0.426 

# the random design explains what it cannot build

    Code
      spacefilling_rand_create(1, 10)
    Condition
      Error:
      ! Number of factors must be between 2 and 50. Got 1.
    Code
      spacefilling_rand_create(51, 10)
    Condition
      Error:
      ! Number of factors must be between 2 and 50. Got 51.
    Code
      spacefilling_rand_create(2.5, 10)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      spacefilling_rand_create(3, 1)
    Condition
      Error:
      ! Number of runs must be between 2 and 1000. Got 1.
    Code
      spacefilling_rand_create(3, 1001)
    Condition
      Error:
      ! Number of runs must be between 2 and 1000. Got 1001.
    Code
      spacefilling_rand_create(3, 10.5)
    Condition
      Error:
      ! Number of runs must be a whole number.
    Code
      spacefilling_rand_create(3, NA)
    Condition
      Error:
      ! Number of runs must be a whole number.
    Code
      spacefilling_rand_create(3, 10, factor_names = "a")
    Condition
      Error:
      ! Give 3 factor names, not 1.
    Code
      spacefilling_rand_create(3, 10, seed = NA)
    Condition
      Error in `set.seed()`:
      ! supplied seed is not a valid integer

