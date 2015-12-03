# summa_tools
Private repo for summa tool development


# Fortran ASCII to netCDF
Huan Wu developed some initial fortran routines to convert SUMMA ASCII input to netCDF.
The _ascii2netcdf/_  directory contains a Makefile to compile _setup_summa_forcings.f90_  


The SUMMA ASCII input files that are converted by _setup_summa_forcings.f90_  can be found in the
summaTestCases tarball on the summa website: https://www.ral.ucar.edu/projects/summa

The _ascii2netcdf/cdl/_ directory has example .cdl files for creating the SUMMA netCDF file structure.
For example: _ascii2netcdf/cdl/meta_forcing_in_riparianAspenPP.cdl_

# PLUMBER
The _plumber/_ directory contains scripts to run SUMMA for all sites in the SUMMA experiment and to perform analysis.
