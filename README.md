# summa_tools
Private repo for summa tool development


#Fortran ASCII to netCDF
Huan Wu developed some initial fortran routines to convert SUMMA ASCII input to netCDF.
The _fortran/_  directory contains a Makefile to compile _setup_summa_forcings.f90_  only

Other code: _convert_meta_2_cdl.f90_, _pres_temp_4D_rd.f90_, _pres_temp_4D_wr.f90_  has not been tested
and may be slated for deletion in the future.

The SUMMA ASCII input files that are converted by _setup_summa_forcings.f90_  can be found in the 
summaTestCases tarball on the summa website: https://www.ral.ucar.edu/projects/summa

The _cdl/_ directory has example .cdl files for creating the SUMMA netCDF file structure.
For example: _cdl/meta_forcing_in_riparianAspenPP.cdl_

It also has example cdl files for converting SUMMA HRU meta data to netCDF with and without
the GRU structure.  This capability will be changed to remove netCDF groups or deleted in future releases.
For example: _cdl/meta_hru_attri.cdl_


The _scripts/_ directory has a shell script that uses NCO to convert classic netCDF into netCDF files
that use groups.

The group structure Huan is using currently is tagged for deletion.

