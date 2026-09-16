# pre-processing folder
Helpful scripts for a variety of pre-processing purposes:
- `convert_summa_config_v2_v3.py`: convert SUMMA v2.x configuration to SUMMA v3.0.0
- `gen_coldstate.py`: create a vector cold state file for SUMMA from constant values
- `subsetGRU.sh`: subset out a NA HRU forcing, parameter, and attribute files where GRU matches HRU
- `SUMMA_merge_restarts_into_warmState.py`: combine split domain state files (with 2 dimensions, hru and gru)
- `create_lumped_to_hru_mapping.sh`: build the lumped-to-HRU mapping used to pass SUMMA runoff to mizuRoute
- `setup_summa_cases.bash`: build the per-case SUMMA and mizuRoute input directories used by multi-case
  calibration, from an existing dataset, and create the SUMMA-HRU to mizuRoute-HRU mapping
- `check_time.bash`: report the forcing time range of each case, to check a calibration period is covered
- `century_cases.txt`: the basin list `setup_summa_cases.bash` reads
