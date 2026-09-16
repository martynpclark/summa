# SUMMA-mizuRoute coupled test case: Bow River at Banff (CAN_05BB001)

A real, lumped-catchment SUMMA-mizuRoute coupling case, distinct from the
[toy problem and Provo real-network tests](../README.md) one level up: it
uses a real (single-HRU lumped) river network and remapping, ~9 years of real
distributed forcing, and observed daily streamflow for objective-function
evaluation -- rather than either a synthetic network or a network converted
purely to compare against t-route.

## Layout
- `summa_inputs/` -- forcing, attributes, parameters, decisions for the Bow
  at Banff domain.
- `mizuroute_inputs/` -- the real river network (`topology.nc`), the
  lumped-catchment-to-routing-HRU remapping (`lumped_to_hru.nc`), mizuRoute
  parameters (`mizuroute.param`), and observed daily flow
  (`CAN_05BB001_daily_flow_observations.nc`) for evaluation.
- `settings/summa_fileManager.txt` -- SUMMA file manager for this domain.
- `settings/mizu_control_CAN_05BB001.toml` -- mizuRoute coupling
  configuration: hydrofabric, remapping, observations, and the `[objective]`
  section (KGE against observed flow over 1982-10-01 to 1983-10-01).

## Running

Requires a build configured with `-DUSE_MIZUROUTE=ON` (see
[docs/index.md](../../../../docs/index.md)), run from the repository root
(the file manager and TOML config use paths relative to it):

```
bin/summa_sundials_mizuroute.exe -m utils/test/test_mizuroute/bow_real_data/settings/summa_fileManager.txt \
                                  -c utils/test/test_mizuroute/bow_real_data/settings/mizu_control_CAN_05BB001.toml
```

Output goes to `work/` (created if needed, gitignored). With `write_aligned`
set in the TOML, mizuRoute also writes an aligned evaluation time series and
the objective-function value alongside the routed output.
