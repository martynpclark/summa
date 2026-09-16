# test_calibration

Tests and worked examples for SUMMA's parameter calibration (`summa[_sundials]_opt.exe`).

## Requirements

Calibration needs an executable built with **both** `-DUSE_MPI=ON` and `-DUSE_MIZUROUTE=ON`.

MPI is what builds the calibration driver in the first place, and it is how trials are run
concurrently: one rank coordinates, the others evaluate parameter sets.

mizuRoute is needed because the objective function compares *routed streamflow* against gauge
observations, and routed streamflow is produced by mizuRoute. In a build without it the
simulated flow series is never filled, so there is nothing to score. This is a real constraint
of the current design, not a property of these tests.

## `test_calibration_bow.sh`

A short, self-contained calibration on the Bow River at Banff (CAN_05BB001). Everything it needs
is already in the repository, under `utils/test/test_mizuroute/bow_real_data/`: lumped SUMMA
inputs and ten years of forcing, the mizuRoute topology and lumped-to-HRU remapping, and daily
streamflow observations.

```bash
./test_calibration_bow.sh [n_samples] [n_ranks]     # defaults: 4 samples, 2 ranks
```

It writes a TOML configuration pointing at that data, runs a DDS search over five parameters for
one simulated year after a year of spinup, and checks that finite, plausible objective values were
recorded for the trials.

The period and the sample count are deliberately tiny so the test finishes in minutes. It
exercises the machinery; it does **not** produce a calibrated parameter set. A real calibration
uses thousands of samples over several years — see `n_samples` in the generated config.

## Multi-case calibration

`--manifest <file>` calibrates many basins in one job, from a manifest listing the cases and a
per-case configuration template. There is no test for it here: it needs several basins, and this
repository bundles one. Run `summa[_sundials]_opt.exe --help` for the option, and see
`test_calibration_bow.sh` for the shape of a single-case configuration.
