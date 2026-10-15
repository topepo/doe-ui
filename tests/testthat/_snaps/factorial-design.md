# run_choices reports what the catalog actually holds

    Code
      run_choices(2)
    Output
      4 runs (full factorial) 
                            4 
    Code
      run_choices(3)
    Output
      4 runs (2^(3-1) fraction)   8 runs (full factorial) 
                              4                         8 
    Code
      run_choices(6)
    Output
       8 runs (2^(6-3) fraction) 16 runs (2^(6-2) fraction) 
                               8                         16 
      32 runs (2^(6-1) fraction)   64 runs (full factorial) 
                              32                         64 

# a full factorial has every combination and no defining relation

    Code
      design
    Output
      2^3 full factorial – 3 factors, 8 runs
         A  B  C
      1 -1 -1 -1
      2  1 -1 -1
      3 -1  1 -1
      4  1  1 -1
      5 -1 -1  1
      6  1 -1  1
      7 -1  1  1
      8  1  1  1

# a fractional factorial reports its resolution and generators

    Code
      factorial_design(k = 6, runs = 16)
    Output
      2^(6-2) fractional factorial, resolution IV – 6 factors, 16 runs
        Defining relation: I = ABCE = ABDF = CDEF
          A  B  C  D  E  F
      1  -1 -1 -1 -1 -1 -1
      2   1 -1 -1 -1  1  1
      3  -1  1 -1 -1  1  1
      4   1  1 -1 -1 -1 -1
      5  -1 -1  1 -1  1 -1
      6   1 -1  1 -1 -1  1
      7  -1  1  1 -1 -1  1
      8   1  1  1 -1  1 -1
      9  -1 -1 -1  1 -1  1
      10  1 -1 -1  1  1 -1
      11 -1  1 -1  1  1 -1
      12  1  1 -1  1 -1  1
      13 -1 -1  1  1  1  1
      14  1 -1  1  1 -1 -1
      15 -1  1  1  1 -1 -1
      16  1  1  1  1  1  1

# relation_note derives the relation only below the generator limit

    Code
      relation_note(small, 6, 16)
    Output
      [1] "Defining relation: I = ABCE = ABDF = CDEF"
    Code
      relation_note(large, 30, 64)
    Output
      [1] "24 generators. Defining relation not shown; it has 1.68e+07 words. Shortest words: 945 of length 4."

# center points are appended as zero rows and counted in the title

    Code
      cat(design$title)
    Output
      2^3 full factorial – 3 factors, 8 runs + 2 center points (10 total)

# invalid options fail with a message written for the user

    Code
      factorial_design(k = 1, runs = 2)
    Condition
      Error:
      ! Number of factors must be between 2 and 127. Got 1.
    Code
      factorial_design(k = 500, runs = 8)
    Condition
      Error:
      ! Number of factors must be between 2 and 127. Got 500.
    Code
      factorial_design(k = NA, runs = 8)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      factorial_design(k = 3.5, runs = 8)
    Condition
      Error:
      ! Number of factors must be a whole number.
    Code
      factorial_design(k = 3, runs = 6)
    Condition
      Error:
      ! 6 is not an available run count for 3 factors. Choose one of: 4, 8.
    Code
      factorial_design(k = 34, runs = 1024)
    Condition
      Error:
      ! 1024 is not an available run count for 34 factors. Choose one of: 64, 128, 256.
    Code
      factorial_design(k = 3, runs = 8, center = -1)
    Condition
      Error:
      ! Center points cannot be negative.
    Code
      factorial_design(k = 3, runs = 8, factor_names = c("Temp", "Pressure"))
    Condition
      Error:
      ! Give 3 factor names, not 2.

# an unavailable value is reported with what is available instead

    Code
      stop_unavailable(1024, c(64, 128, 256), "run count", "34 factors")
    Condition
      Error:
      ! 1024 is not an available run count for 34 factors. Choose one of: 64, 128, 256.
    Code
      stop_unavailable(7, numeric(0), "run count", "99 factors")
    Condition
      Error:
      ! No run count is available for 99 factors.
    Code
      stop_unavailable("rotatable", c("faces", "spherical"), "axial distance")
    Condition
      Error:
      ! rotatable is not an available axial distance. Choose one of: faces, spherical.
    Code
      stop_out_of_range(500, c(2, 127), "Number of factors")
    Condition
      Error:
      ! Number of factors must be between 2 and 127. Got 500.

# a long list of choices is shortened

    Code
      format_choices(1:5)
    Output
      [1] "1, 2, 3, 4, 5"
    Code
      format_choices(1:30)
    Output
      [1] "1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, ... (30 in all)"

