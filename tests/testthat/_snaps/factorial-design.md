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

# a full factorial has every combination and aliases nothing

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
        Two-factor interactions aliased: AB=CE=DF, AC=BE, AD=BF, AE=BC, AF=BD, CD=EF, CF=DE
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

# alias notes are read from FrF2, at every design size

    Code
      factorial_design(k = 6, runs = 16)$notes
    Output
      [1] "Two-factor interactions aliased: AB=CE=DF, AC=BE, AD=BF, AE=BC, AF=BD, CD=EF, CF=DE"
    Code
      factorial_design(k = 7, runs = 8)$notes
    Output
      [1] "Main effects aliased: A=BD=CE=FG, B=AD=CF=EG, C=AE=BF=DG, D=AB=CG=EF, E=AC=BG=DF, F=AG=BC=DE, G=AF=BE=CD"
    Code
      factorial_design(k = 3, runs = 8)$notes
    Output
      character(0)

# a renamed factor appears in the alias legend

    Code
      renamed$notes
    Output
      [1] "Factors: A=Temp, B=Pressure"                                                        
      [2] "Two-factor interactions aliased: AB=CE=DF, AC=BE, AD=BF, AE=BC, AF=BD, CD=EF, CF=DE"

# describe_entry shortens a long generator list

    Code
      describe_entry(names(small)[1], small[[1]])
    Output
      [1] "Resolution IV: E=ABC, F=ABD (3 words of length 4)"

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

# center points come from FrF2 and are recorded on the design

    Code
      cat(with_centers$title)
    Output
      2^3 full factorial – 3 factors, 8 runs + 2 center points (10 total)

