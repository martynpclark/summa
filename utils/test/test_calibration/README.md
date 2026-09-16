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

## `multi_case_example/`

The files here calibrate many basins in one job, driven by a manifest. They are kept as a worked
example rather than a runnable test, because they refer to a dataset that is not in this
repository and to paths on the machine they were written for. Read them as a recipe and adapt
the paths:

| File | What it is |
| --- | --- |
| `manifest_century.toml` | the run manifest: which cases to calibrate, and the configuration template to use |
| `summa_config_template.toml` | the per-case configuration template the manifest expands |
| `summa_config_CAN_05BB001.toml` | a single filled-in case, useful for seeing what the template produces |
| `century_cases.txt` | the basin list |
| `setup_summa_cases.bash` | builds the per-case SUMMA and mizuRoute input directories from an existing dataset |
| `check_time.bash` | reports each case's forcing time range, to check a calibration period is covered |

`setup_summa_cases.bash` and `check_time.bash` both hard-code a personal data root
(`$HOME/data/century/...`) and an experiment-specific directory layout, so neither runs anywhere
else without editing. That is why they sit here beside the calibration they belong to rather than
in `utils/pre-processing/`, which holds tools that are usable as they stand.
