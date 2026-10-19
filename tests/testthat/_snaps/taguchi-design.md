# choices are the arrays wide enough for the factors

    Code
      taguchi_get_num_runs_choices(7)[1:4]
    Output
        8 runs (L8) 12 runs (L12) 16 runs (L16) 20 runs (L20) 
                  8            12            16            20 
    Code
      taguchi_get_num_runs_choices(8)[1:3]
    Output
      12 runs (L12) 16 runs (L16) 20 runs (L20) 
                 12            16            20 
    Code
      taguchi_get_num_runs_choices(139)
    Output
      140 runs (L140) 
                  140 

# a design is plain numbers on the -1/+1 scale, in standard order

    Code
      design
    Output
      L8 orthogonal array (2^7) – 5 factors, 8 runs
        Uses columns 1, 2, 3, 4, 5 of the array's 7.
        Levels are coded -1 and +1.
        Residual degrees of freedom: 2.
      # A tibble: 8 x 5
            A     B     C     D     E
        <dbl> <dbl> <dbl> <dbl> <dbl>
      1    -1    -1    -1    -1    -1
      2    -1    -1     1     1     1
      3    -1     1    -1     1    -1
      4    -1     1     1    -1     1
      5     1    -1    -1     1     1
      6     1    -1     1    -1    -1
      7     1     1    -1    -1     1
      8     1     1     1     1    -1

# a saturated array has no residual degrees of freedom

    Code
      taguchi_create(num_factors = 7, num_runs = 8)$notes
    Output
      [1] "Uses all 7 columns of the array." "Levels are coded -1 and +1."     
      [3] "Residual degrees of freedom: 0." 
    Code
      taguchi_create(num_factors = 3, num_runs = 12)$notes
    Output
      [1] "Uses columns 1, 2, 3 of the array's 11."
      [2] "Levels are coded -1 and +1."            
      [3] "Residual degrees of freedom: 8."        
    Code
      taguchi_create(num_factors = 139, num_runs = 140)$notes
    Output
      [1] "Uses all 139 columns of the array." "Levels are coded -1 and +1."       
      [3] "Residual degrees of freedom: 0."   

# replications stack complete copies of the array

    Code
      stacked$title
    Output
      [1] "L8 orthogonal array (2^7) – 3 factors, 8 runs, 3 replications"
    Code
      stacked$notes
    Output
      [1] "Uses columns 1, 2, 3 of the array's 7."                   
      [2] "Levels are coded -1 and +1."                              
      [3] "Residual degrees of freedom, not counting replication: 4."
    Code
      single$notes
    Output
      [1] "Uses columns 1, 2, 3 of the array's 7."
      [2] "Levels are coded -1 and +1."           
      [3] "Residual degrees of freedom: 4."       

# create explains what it cannot build

    Code
      taguchi_create(num_factors = 1, num_runs = 8)
    Condition
      Error:
      ! Number of factors must be between 2 and 139. Got 1.
    Code
      taguchi_create(num_factors = 140, num_runs = 140)
    Condition
      Error:
      ! Number of factors must be between 2 and 139. Got 140.
    Code
      taguchi_create(num_factors = 2.5, num_runs = 8)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      taguchi_create(num_factors = NA, num_runs = 8)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      taguchi_create(num_factors = 5, num_runs = 6)
    Condition
      Error:
      ! 6 is not an available run count for 5 factors. Choose one of: 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, ... (34 in all).
    Code
      taguchi_create(num_factors = 20, num_runs = 16)
    Condition
      Error:
      ! 16 is not an available run count for 20 factors. Choose one of: 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, ... (30 in all).
    Code
      taguchi_create(num_factors = 5, num_runs = c(8, 12))
    Condition
      Error:
      ! Number of runs must be a single number.
    Code
      taguchi_create(num_factors = 5, num_runs = 8, replications = 0)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      taguchi_create(num_factors = 5, num_runs = 8, replications = 1.5)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      taguchi_create(num_factors = 5, num_runs = 8, replications = NA)
    Condition
      Error:
      ! Replications must be a whole number of at least 1.
    Code
      taguchi_create(num_factors = 5, num_runs = 8, factor_names = c("a", "b"))
    Condition
      Error:
      ! Give 5 factor names, not 2.

