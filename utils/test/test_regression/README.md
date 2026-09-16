# SUMMA code regression tests

These scripts check that a SUMMA code change has not altered model output --
"regression" in the sense of comparing runs, not a bundled pass/fail test
suite. All of them read paths under `$HOME/data/...` and `$HOME/models/...`
that are **not part of this repository** (private reference domains and
side-by-side builds); edit the "User settings" block at the top of each
script before running it.

## What each script does

- `parallel_sims.sh` / `parallel_sims_original.sh` -- run the same domain with
  a stable build, a development build (serial), and a development build under
  MPI at several process counts (`parallel_sims_original.sh` is the same
  comparison against the pre-refactor MPI implementation). Writes one output
  file per run/decomposition plus a log per run.
- `regression_test.sh` -- compares the output files those runs produced:
  mizuRoute on vs. off, stable serial vs. development serial, development
  serial vs. MPI np=1, and development serial vs. each decomposed MPI run
  (reassembling the per-process HRU/GRU ranges to diff against the matching
  slice of the serial run). Reports the maximum absolute difference per HRU-
  and GRU-level variable and an overall PASS/FAIL per comparison; PASS means
  bit-identical.
- `test_mizuroute_coupling.sh` -- compares SUMMA's coupled mizuRoute output
  (`q_reach`) against a standalone mizuRoute run (`KWroutedRunoff`) on the
  same real river network, reach by reach. The standalone run needs the
  `route_runoff` executable, built separately from SUMMA by
  [`../test_mizuroute/make_mizuRoute.sh`](../test_mizuroute/README.md). For a
  version of this comparison that runs entirely from the repository
  (synthetic network, no external data or standalone mizuRoute build), see
  [`../test_mizuroute/test_mizuroute_bundled.sh`](../test_mizuroute/test_mizuroute_bundled.sh).
- `parallel_time.sh` -- summarizes wall-clock time, speedup and parallel
  efficiency across the MPI process counts `parallel_sims.sh` ran, comparing
  the current MPI implementation against a saved "original" run.
- `plotvars.R` -- plots a handful of state variables at one HRU from two of
  the output files above, for visually inspecting where two runs diverge.

R scripts doing the same kind of comparison as `regression_test.sh` /
`plotvars.R`, against different private domains (edit the hardcoded paths at
the top of each before running):

- `compare_summa_versions.R` -- plots state variables and fluxes (SWE,
  surface/root-zone temperature, soil water, cumulative snow drainage and
  transpiration) and their difference, between two executables run on the
  same Reynolds Mountain East test case.
- `compare_summa_runoff.R` -- compares `averageRoutedRunoff` between a
  reference and a new run (KGE, NSE, mean/max difference), identifying each
  by the `gitHash`/`gitBranch` global attributes SUMMA writes to its output.
- `compare_summa_simulations.R` -- per-GRU KGE/NSE and a 12-panel plot of
  `averageRoutedRunoff`, reference vs. new, for the GSL/Athabasca domain.
- `compare_parameters.R` -- diffs every scalar (non-time/segment-dimensioned)
  variable between two output files -- i.e. parameters and other
  time-invariant fields, not fluxes or states.
- `plot_utils.R` -- shared `nc_time()` helper (NetCDF CF time units ->
  `POSIXct`) sourced by several scripts here and in `../test_mizuroute/`.

## Requirements

`ncdiff`, `ncap2`, `ncks`, `ncwa`, `ncrename` (NCO), `bc`, and for
`parallel_sims.sh`, `mpirun` and MPI-enabled SUMMA builds. The R scripts need
`ncdf4`, and `hydroGOF` for the ones computing KGE/NSE.
