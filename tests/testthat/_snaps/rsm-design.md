# a design is a plain table, named as asked

    Code
      rsm_ccd_create(num_factors = 2, center = 1)
    Output
      Central composite design – 2 factors, 10 runs
        Axial distance 1.414 (orthogonal blocking).
        Cube points are in block 1 and axial points in block 2.
        Each block has 1 center point.
      # A tibble: 10 x 3
         Block     A     B
         <chr> <dbl> <dbl>
       1 1     -1    -1   
       2 1      1    -1   
       3 1     -1     1   
       4 1      1     1   
       5 1      0     0   
       6 2     -1.41  0   
       7 2      1.41  0   
       8 2      0    -1.41
       9 2      0     1.41
      10 2      0     0   

# replications add whole cube and axial blocks

    Code
      stacked$notes
    Output
      [1] "Axial distance 1.414 (orthogonal blocking)."                    
      [2] "Cube points are in blocks 1, 2 and axial points in blocks 3, 4."
      [3] "Each block has 1 center point."                                 

---

    Code
      stacked$title
    Output
      [1] "Central composite design – 2 factors, 20 runs, 2 replications"

# create explains what it cannot build

    Code
      rsm_ccd_create(num_factors = 1)
    Condition
      Error:
      ! Number of factors must be between 2 and 8. Got 1.
    Code
      rsm_ccd_create(num_factors = 9)
    Condition
      Error:
      ! Number of factors must be between 2 and 8. Got 9.
    Code
      rsm_ccd_create(num_factors = 2.5)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      rsm_ccd_create(num_factors = NA)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      rsm_ccd_create(num_factors = 3, center = -1)
    Condition
      Error:
      ! Center points per block must be between 0 and 20. Got -1.
    Code
      rsm_ccd_create(num_factors = 3, center = 21)
    Condition
      Error:
      ! Center points per block must be between 0 and 20. Got 21.
    Code
      rsm_ccd_create(num_factors = 3, center = 1.5)
    Condition
      Error:
      ! Center points must be a whole number.
    Code
      rsm_ccd_create(num_factors = 3, alpha = "bogus")
    Condition
      Error:
      ! bogus is not an available axial distance. Choose one of: orthogonal, rotatable, spherical, faces.
    Code
      rsm_ccd_create(num_factors = 3, alpha = "rot")
    Condition
      Error:
      ! rot is not an available axial distance. Choose one of: orthogonal, rotatable, spherical, faces.
    Code
      rsm_ccd_create(num_factors = 3, alpha = -1)
    Condition
      Error:
      ! Axial distance must be one of the named choices or a positive number.
    Code
      rsm_ccd_create(num_factors = 3, alpha = 0)
    Condition
      Error:
      ! Axial distance must be one of the named choices or a positive number.
    Code
      rsm_ccd_create(num_factors = 3, alpha = NA_real_)
    Condition
      Error:
      ! Axial distance must be one of the named choices or a positive number.
    Code
      rsm_ccd_create(num_factors = 3, replications = 0)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      rsm_ccd_create(num_factors = 3, replications = 1.5)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      rsm_ccd_create(num_factors = 3, factor_names = "a")
    Condition
      Error:
      ! Give 3 factor names, not 1.
    Code
      rsm_ccd_create(num_factors = 2, factor_names = c("Block", "B"))
    Condition
      Error:
      ! "Block" is reserved for the block column; rename that factor.

