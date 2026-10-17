# parse_factor_names fills, trims, truncates, and deduplicates

    Code
      rename_factors(NULL, 3)
    Output
      [1] "A" "B" "C"
    Code
      rename_factors("", 3)
    Output
      [1] "A" "B" "C"
    Code
      rename_factors("Temp, Pressure, Time", 3)
    Output
      [1] "Temp"     "Pressure" "Time"    
    Code
      rename_factors("  Temp ,   Pressure  ", 3)
    Output
      [1] "Temp"     "Pressure" "C"       
    Code
      rename_factors("Temp, Pressure, Time, Catalyst, Speed", 3)
    Output
      [1] "Temp"     "Pressure" "Time"    
    Code
      rename_factors("Temp, Temp, Temp", 3)
    Output
      [1] "Temp"   "Temp_1" "Temp_2"
    Code
      rename_factors(", ,Temp", 3)
    Output
      [1] "Temp" "B"    "C"   

# with_run_order adds the order columns without moving rows

    Code
      with_run_order(design, randomize = FALSE)$table
    Output
      # A tibble: 2 x 4
        `Standard order` `Run order`     A     B
                   <int>       <int> <dbl> <dbl>
      1                1           1    -1    -1
      2                2           2     1    -1

# center_point_text pluralises and counts the total

    Code
      center_point_text(0, 2)
    Output
      [1] ""
    Code
      center_point_text(1, 3)
    Output
      [1] " + 1 center point (3 total)"
    Code
      center_point_text(3, 5)
    Output
      [1] " + 3 center points (5 total)"

# display_table leaves coded levels and the order columns alone

    Code
      shown
    Output
      # A tibble: 3 x 4
        `Standard order` `Run order`     A     B
                   <int>       <int> <dbl> <dbl>
      1                1           1    -1     1
      2                2           2     0     0
      3                3           3     1    -1

# display_table rounds to three significant figures, not decimals

    Code
      shown
    Output
      # A tibble: 2 x 2
              x1      x2
           <dbl>   <dbl>
      1 0.333    1230   
      2 0.000123    1.68

# a design prints its title, notes, and table

    Code
      design
    Output
      A tiny design
        Defining relation: I = AB
      # A tibble: 2 x 1
            A
        <dbl>
      1    -1
      2     1

# stop_unless reports the message it was given

    Code
      stop_unless(FALSE, "Choose between 2 and 8 factors.")
    Condition
      Error:
      ! Choose between 2 and 8 factors.

