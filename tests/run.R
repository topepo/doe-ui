# Run the test suite:  Rscript tests/run.R
#
# Snapshot tests skip themselves unless NOT_CRAN is set, which is how a package
# avoids failing a CRAN check on cosmetic output changes. This app is never
# submitted to CRAN, so the snapshots should always run.
Sys.setenv(NOT_CRAN = "true")

testthat::test_dir("tests/testthat")
