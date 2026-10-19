# Where R looks for packages when it starts in this directory, including every
# Rscript step of the GitHub Actions deploy.
#
# mixexp is not on CRAN, so it comes from its R-universe. That is also what makes
# the shinylive deployment work: shinylive::export() reads the Repository field
# of each installed package's DESCRIPTION, and only a package installed from an
# r-universe.dev repository is fetched as a wasm build from that universe's
# bin/emscripten/contrib/ directory. Installed from CRAN or GitHub, it is looked
# up elsewhere and not found.
#
# The deploy workflow installs packages with pak::pak(), which reads this option.
# CRAN is listed too, so everything else still installs as before.
options(
  repos = c(
    sjvrensburg = "https://sjvrensburg.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
