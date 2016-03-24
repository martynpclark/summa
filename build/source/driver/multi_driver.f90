! SUMMA - Structure for Unifying Multiple Modeling Alternatives
! Copyright (C) 2014-2015 NCAR/RAL
!
! This file is part of SUMMA
!
! For more information see: http://www.ral.ucar.edu/projects/summa
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

program multi_driver
! used to evaluate different methods for simulating snow processes
! *****************************************************************************
! use desired modules
! *****************************************************************************
USE nrtype                                                  ! variable types, etc.
! provide access to subroutines and functions
USE summaFileManager,only:summa_SetDirsUndPhiles            ! sets directories and filenames
USE module_sf_noahmplsm,only:read_mp_veg_parameters         ! module to read NOAH vegetation tables
USE module_sf_noahmplsm,only:redprm                         ! module to assign more Noah-MP parameters
USE nr_utility_module,only:arth                             ! get a sequence of numbers
USE ascii_util_module,only:file_open                        ! open ascii file
USE ascii_util_module,only:get_vlines                       ! read a vector of non-comment lines from an ASCII file
USE ascii_util_module,only:split_line                       ! extract the list of variable names from the character string
USE allocspace_module,only:initStruct                       ! module to allocate space for data structures
USE allocspace_module,only:allocLocal                       ! module to allocate space for data structures
USE mDecisions_module,only:mDecisions                       ! module to read model decisions
USE popMetadat_module,only:popMetadat                       ! module to populate metadata structures
USE checkStruc_module,only:checkStruc                       ! module to check metadata structures
USE def_output_module,only:def_output                       ! module to define model output
USE ffile_info_module,only:ffile_info                       ! module to read information on forcing datafile
USE read_attrb_module,only:read_attrb                       ! module to read local attributes
USE read_pinit_module,only:read_pinit                       ! module to read initial model parameter values
USE paramCheck_module,only:paramCheck                       ! module to check consistency of model parameters
USE read_icond_module,only:read_icond                       ! module to read initial conditions
USE pOverwrite_module,only:pOverwrite                       ! module to overwrite default parameter values with info from the Noah tables
USE read_param_module,only:read_param                       ! module to read model parameter sets
USE ConvE2Temp_module,only:E2T_lookup                       ! module to calculate a look-up table for the temperature-enthalpy conversion
USE var_derive_module,only:calcHeight                       ! module to calculate height at layer interfaces and layer mid-point
USE var_derive_module,only:v_shortcut                       ! module to calculate "short-cut" variables
USE var_derive_module,only:rootDensty                       ! module to calculate the vertical distribution of roots
USE var_derive_module,only:satHydCond                       ! module to calculate the saturated hydraulic conductivity in each soil layer
USE var_derive_module,only:fracFuture                       ! module to calculate the fraction of runoff in future time steps (time delay histogram)
USE read_force_module,only:read_force                       ! module to read model forcing data
USE derivforce_module,only:derivforce                       ! module to compute derived forcing data
USE modelwrite_module,only:writeAttrb,writeParam            ! module to write model attributes and parameters
USE modelwrite_module,only:writeForce                       ! module to write model forcing data
USE modelwrite_module,only:writeModel,writeBasin            ! module to write model output
USE vegPhenlgy_module,only:vegPhenlgy                       ! module to compute vegetation phenology
USE coupled_em_module,only:coupled_em                       ! module to run the coupled energy and mass model
USE groundwatr_module,only:groundwatr                       ! module to simulate regional groundwater balance
USE qTimeDelay_module,only:qOverland                        ! module to route water through an "unresolved" river network
! provide access to file paths
USE summaFileManager,only:SETNGS_PATH                       ! define path to settings files (e.g., Noah vegetation tables)
USE summaFileManager,only:MODEL_INITCOND                    ! name of model initial conditions file
USE summaFileManager,only:LOCAL_ATTRIBUTES                  ! name of file containing information on local attributes
USE summaFileManager,only:OUTPUT_PATH,OUTPUT_PREFIX         ! define output file
USE summaFileManager,only:LOCALPARAM_INFO,BASINPARAM_INFO   ! files defining the default values and constraints for model parameters
! provide access to global data
USE globalData,only:refTime                                 ! reference time
USE globalData,only:startTime                               ! start time
USE globalData,only:finshTime                               ! end time
USE globalData,only:doJacobian                              ! flag to compute the Jacobian
USE globalData,only:localParFallback                        ! local column default parameters
USE globalData,only:basinParFallback                        ! basin-average default parameters
USE globalData,only:time_meta                               ! metadata for time information 
USE globalData,only:mpar_meta,bpar_meta                     ! metadata for local column and basin-average model parameters
USE globalData,only:indx_meta,prog_meta,diag_meta,flux_meta ! metadata for local column variables
USE globalData,only:averageFlux_meta                        ! metadata for time-step average fluxes
USE globalData,only:numtim                                  ! number of time steps
USE globalData,only:model_decisions                         ! model decisions
USE globalData,only:urbanVegCategory                        ! vegetation category for urban areas
USE globalData,only:globalPrintFlag                         ! global print flag
USE globalData,only:forcFileInfo                            ! forcing file info
USE multiconst,only:integerMissing                          ! missing integer value
! provide access to Noah-MP parameters
USE NOAHMP_VEG_PARAMETERS,only:SAIM,LAIM                    ! 2-d tables for stem area index and leaf area index (vegType,month)
USE NOAHMP_VEG_PARAMETERS,only:HVT,HVB                      ! height at the top and bottom of vegetation (vegType)
USE noahmp_globals,only:RSMIN                               ! minimum stomatal resistance (vegType)
! provide access to the derived types to define the data structures
USE data_types,only:&
                    var_i,               & ! x%var(:)            (i4b)
                    var_d,               & ! x%var(:)            (dp)
                    var_ilength,         & ! x%var(:)%dat        (i4b)
                    var_dlength,         & ! x%var(:)%dat        (dp)
                    spatial_int,         & ! x%hru(:)%var(:)     (i4b)
                    spatial_double,      & ! x%hru(:)%var(:)     (dp)
                    spatial_intVec,      & ! x%hru(:)%var(:)%dat (i4b)
                    spatial_doubleVec      ! x%hru(:)%var(:)%dat (dp)
USE data_types,only:extended_info          ! extended metadata structure
! provide access to the named variables that describe elements of parent model structures
USE var_lookup,only:iLookTIME,iLookFORCE                    ! look-up values for time and forcing data structures
USE var_lookup,only:iLookTYPE                               ! look-up values for classification of veg, soils etc.
USE var_lookup,only:iLookATTR                               ! look-up values for local attributes
USE var_lookup,only:iLookPARAM                              ! look-up values for local column model parameters
USE var_lookup,only:iLookINDEX                              ! look-up values for local column index variables
USE var_lookup,only:iLookPROG                               ! look-up values for local column model prognostic (state) variables
USE var_lookup,only:iLookDIAG                               ! look-up values for local column model diagnostic variables 
USE var_lookup,only:iLookFLUX                               ! look-up values for local column model fluxes 
USE var_lookup,only:iLookBVAR                               ! look-up values for basin-average model variables
USE var_lookup,only:iLookBPAR                               ! look-up values for basin-average model parameters
USE var_lookup,only:iLookDECISIONS                          ! look-up values for model decisions
! provide access to the named variables that describe elements of child  model structures
USE var_lookup,only:childFLUX_MEAN                          ! look-up values for timestep-average model fluxes
! provide access to the named variables that describe model decisions
USE mDecisions_module,only:  &                              ! look-up values for method used to compute derivative
 numerical,   & ! numerical solution
 analytical     ! analytical solution
USE mDecisions_module,only:&                                ! look-up values for LAI decisions
 monthlyTable,& ! LAI/SAI taken directly from a monthly table for different vegetation classes
 specified      ! LAI/SAI computed from green vegetation fraction and winterSAI and summerLAI parameters
USE mDecisions_module,only:&                                ! look-up values for the choice of method for the spatial representation of groundwater
 localColumn, & ! separate groundwater representation in each local soil column
 singleBasin    ! single groundwater store over the entire basin
implicit none

! *****************************************************************************
! (0) variable definitions
! *****************************************************************************
! define the primary data structures
type(var_i)               :: timeStruct    ! x%var(:)            -- model time data
type(spatial_double)      :: forcStruct    ! x%hru(:)%var(:)     -- model forcing data
type(spatial_double)      :: attrStruct    ! x%hru(:)%var(:)     -- local attributes for each HRU
type(spatial_int)         :: typeStruct    ! x%hru(:)%var(:)     -- local classification of soil veg etc. for each HRU
type(spatial_double)      :: mparStruct    ! x%hru(:)%var(:)     -- model parameters
type(spatial_intVec)      :: indxStruct    ! x%hru(:)%var(:)%dat -- model indices

type(spatial_doubleVec)   :: progStruct    ! x%hru(:)%var(:)%dat -- model prognostic (state) variables
type(spatial_doubleVec)   :: diagStruct    ! x%hru(:)%var(:)%dat -- model diagnostic variables
type(spatial_doubleVec)   :: fluxStruct    ! x%hru(:)%var(:)%dat -- model fluxes
type(var_dlength)         :: derivStruct   ! x%var(:)%dat        -- model derivatives

type(var_d)               :: bparStruct    ! x%var(:)            -- basin-average parameters
type(var_dlength)         :: bvarStruct    ! x%var(:)%dat        -- basin-average variables
! define the ancillary data structures
type(spatial_double)      :: dparStruct    ! x%hru(:)%var(:)     -- default model parameters
! define counters
integer(i4b)              :: iVar                           ! index of a model variable 
integer(i4b)              :: iHRU,jHRU,kHRU                 ! index of the hydrologic response unit
integer(i4b)              :: nHRU                           ! number of hydrologic response units
integer(i4b)              :: iStep=0                        ! index of model time step
integer(i4b)              :: jStep=0                        ! index of model output
! define the re-start file
logical(lgt)              :: printRestart                   ! flag to print a re-start file
integer(i4b),parameter    :: ixRestart_iy=1000              ! named variable to print a re-start file once per year
integer(i4b),parameter    :: ixRestart_im=1001              ! named variable to print a re-start file once per month
integer(i4b),parameter    :: ixRestart_id=1002              ! named variable to print a re-start file once per day
integer(i4b),parameter    :: ixRestart_never=1003           ! named variable to print a re-start file never
integer(i4b)              :: ixRestart=ixRestart_im         ! define frequency to write restart files
! define output file
character(len=8)          :: cdate1=''                      ! initial date
character(len=10)         :: ctime1=''                      ! initial time
character(len=64)         :: output_fileSuffix=''           ! suffix for the output file
character(len=256)        :: summaFileManagerFile=''        ! path/name of file defining directories and files
character(len=256)        :: fileout=''                     ! output filename
! define model indices
integer(i4b),allocatable  :: nSnow(:)                       ! number of snow layers for each HRU
integer(i4b),allocatable  :: nSoil(:)                       ! number of soil layers for each HRU
integer(i4b)              :: nLayers                        ! total number of layers
real(dp),allocatable      :: dt_init(:)                     ! used to initialize the length of the sub-step for each HRU
logical(lgt),allocatable  :: computeVegFlux(:)              ! flag to indicate if we are computing fluxes over vegetation (.false. means veg is buried with snow) 
real(dp)                  :: totalArea                      ! total basin area (m2)
! exfiltration
real(dp),parameter        :: supersatScale=0.001_dp         ! scaling factor for the logistic function (-)
real(dp),parameter        :: xMatch = 0.99999_dp            ! point where x-value and function value match (-)
real(dp),parameter        :: safety = 0.01_dp               ! safety factor to ensure logistic function is less than 1
real(dp),parameter        :: fSmall = epsilon(xMatch)       ! smallest possible value to test
real(dp),allocatable      :: upArea(:)                      ! area upslope of each HRU
! general local variables
real(dp)                  :: fracHRU                        ! fractional area of a given HRU (-)
integer(i4b)              :: fileUnit                       ! file unit (output from file_open; a unit not currently used)
character(LEN=256),allocatable :: dataLines(:)    ! vector of character strings from non-comment lines
character(LEN=256),allocatable :: chardata(:)     ! vector of character data
integer(i4b)              :: iWord                          ! loop through words in a string
integer(i4b)              :: nScalarFlux                    ! number of scalar flux variables
real(dp),allocatable      :: zSoilReverseSign(:)            ! height at bottom of each soil layer, negative downwards (m)
real(dp),dimension(12)    :: greenVegFrac_monthly           ! fraction of green vegetation in each month (0-1)
real(dp),parameter        :: doubleMissing=-9999._dp        ! missing value
logical(lgt),parameter    :: overwriteRSMIN=.false.         ! flag to overwrite RSMIN
real(dp)                  :: notUsed_canopyDepth            ! NOT USED: canopy depth (m)
real(dp)                  :: notUsed_exposedVAI             ! NOT USED: exposed vegetation area index (m2 m-2)
! error control
integer(i4b)              :: err=0                          ! error code
character(len=1024)       :: message=''                     ! error message

! *****************************************************************************
! (1) inital priming -- get command line arguments, identify files, etc.
! *****************************************************************************
print*, 'start'
! get the initial time
call date_and_time(cdate1,ctime1)
print*,ctime1
! get command-line arguments for the output file suffix
call getarg(1,output_fileSuffix)
if (len_trim(output_fileSuffix) == 0) then
 print*,'1st command-line argument missing, expect text string defining the output file suffix'; stop
endif
! get command-line argument for the muster file
call getarg(2,summaFileManagerFile) ! path/name of file defining directories and files
if (len_trim(summaFileManagerFile) == 0) then
 print*,'2nd command-line argument missing, expect path/name of muster file'; stop
endif
! set directories and files -- summaFileManager used as command-line argument
call summa_SetDirsUndPhiles(summaFileManagerFile,err,message); call handle_err(err,message)
! initialize the Jacobian flag
doJacobian=.false.

! allocate time structures
call allocLocal(time_meta, refTime,   err=err, message=message); call handle_err(err,message)  ! reference time for the model simulation
call allocLocal(time_meta, startTime, err=err, message=message); call handle_err(err,message)  ! start time for the model simulation 
call allocLocal(time_meta, finshTime, err=err, message=message); call handle_err(err,message)  ! end time for the model simulation

! *****************************************************************************
! (2) populate/check metadata structures
! *****************************************************************************
! populate metadata for all model variables
call popMetadat(err,message); call handle_err(err,message)
! check data structures
call checkStruc(err,message); call handle_err(err,message)

! allocate space for the averageFlux metadata structure
nScalarFlux = count(flux_meta(:)%vartype == 'scalarv' .or. flux_meta(:)%vartype == 'ifcSoil')
if(allocated(averageFlux_meta)) deallocate(averageFlux_meta)
allocate(averageFlux_meta(nScalarFlux),stat=err)
if(err/=0) call handle_err(20,'problem allocating space for averageFlux_meta')

! define mapping with the parent data structure
averageFlux_meta(:)%ixParent = pack(arth(1,1,size(flux_meta)), flux_meta(:)%vartype == 'scalarv' .or. flux_meta(:)%vartype == 'ifcSoil')

! copy across the metadata from the parent structure
averageFlux_meta(:)%var_info = flux_meta(averageFlux_meta(:)%ixParent)

! put the child indices in the childFLUX_MEAN vector
childFLUX_MEAN(:) = integerMissing
childFLUX_MEAN(averageFlux_meta(:)%ixParent) = arth(1,1,nScalarFlux)

! *****************************************************************************
! (3) read information for each HRU and allocate space for data structures
! *****************************************************************************

! *** TEMPORARY CODE ***
! code will be replaced once merge with the NetCDF branch

! get the number of HRUs
call file_open(trim(SETNGS_PATH)//trim(LOCAL_ATTRIBUTES),fileUnit,err,message); call handle_err(err,message)
call get_vlines(fileUnit,dataLines,err,message); call handle_err(err,message)
nHRU = size(dataLines)-1  ! -1 because of the header
deallocate(dataLines)
close(fileUnit)

! allocate space for the number of snow and soil layers
allocate(nSnow(nHRU),nSoil(nHRU),stat=err); call handle_err(err,'unable to allocate space for the number of snow and soil layers')

! loop through HRUs
! NOTE: currently the same initial conditions for all HRUs; will change when shift to NetCDF
do iHRU=1,nHRU

 ! get a vector of non-commented lines
 call file_open(trim(SETNGS_PATH)//trim(MODEL_INITCOND),fileUnit,err,message); call handle_err(err,message)
 call get_vlines(fileUnit,dataLines,err,message); call handle_err(err,message)
 close(fileUnit)

 ! get the number of snow and soil layers for each HRU
 nSnow(iHRU)=0           ! initialize the number of snow layers
 nSoil(iHRU)=0           ! initialize the number of soil layers
 do iVar=1,size(dataLines)
  ! split the line into an array of words
  call split_line(dataLines(iVar),chardata,err,message); call handle_err(err,message)
  ! check if the line contains initial conditions data (contains the word "snow" or "soil")
  do iword=1,size(chardata)
   if(chardata(iword)=='snow') nSnow(iHRU) = nSnow(iHRU)+1
   if(chardata(iword)=='soil') nSoil(iHRU) = nSoil(iHRU)+1
   if(chardata(iword)=='snow' .or. chardata(iword)=='soil') exit ! exit once read the layer type
  end do
  deallocate(chardata)
 end do
 deallocate(dataLines)

end do  ! looping through HRUs

! **** END OF TEMPORARY CODE ***

! allocate space for the time step and computeVegFlux flags (recycled for each HRU for subsequent calls to coupled_em)
allocate(dt_init(nHRU),stat=err); call handle_err(err,'problem allocating space for dt_init')
allocate(computeVegFlux(nHRU),stat=err); call handle_err(err,'problem allocating space for computeVegFlux')

! initialize data structures
call initStruct(&
                ! input: model control
                nHRU,       &    ! number of HRUs
                nSnow,      &    ! number of snow layers in each HRU
                nSoil,      &    ! number of soil layers in each HRU
                ! input: data structures
                timeStruct, &    ! model time data
                forcStruct, &    ! model forcing data
                attrStruct, &    ! local attributes for each HRU
                typeStruct, &    ! local classification of soil veg etc. for each HRU
                mparStruct, &    ! model parameters
                indxStruct, &    ! model indices
                progStruct, &    ! model prognostic (state) variables
                diagStruct, &    ! model diagnostic variables
                fluxStruct, &    ! model fluxes
                derivStruct,&    ! model derivatives
                bparStruct, &    ! basin-average parameters
                bvarStruct, &    ! basin-average variables
                ! output: error control
                err,message)   ; call handle_err(err,message)

! get the 

! read local attributes for each HRU
call read_attrb(nHRU,attrStruct,typeStruct,err,message); call handle_err(err,message)

! *****************************************************************************
! (4a) read description of model forcing datafile used in each HRU
! *****************************************************************************
call ffile_info(nHRU,typeStruct,err,message); call handle_err(err,message)

! *****************************************************************************
! (4b) read model decisions
! *****************************************************************************
call mDecisions(err,message); call handle_err(err,message)

! *****************************************************************************
! (5a) read default model parameters
! *****************************************************************************
! read default values and constraints for model parameters (local column, and basin-average)
call read_pinit(LOCALPARAM_INFO,.TRUE., mpar_meta,localParFallback,err,message); call handle_err(err,message)
call read_pinit(BASINPARAM_INFO,.FALSE.,bpar_meta,basinParFallback,err,message); call handle_err(err,message)

! *****************************************************************************
! (5b) read Noah vegetation and soil tables
! *****************************************************************************

! define monthly fraction of green vegetation
!                           J        F        M        A        M        J        J        A        S        O        N        D
greenVegFrac_monthly = (/0.01_dp, 0.02_dp, 0.03_dp, 0.07_dp, 0.50_dp, 0.90_dp, 0.95_dp, 0.96_dp, 0.65_dp, 0.24_dp, 0.11_dp, 0.02_dp/)

! read Noah soil and vegetation tables
call soil_veg_gen_parm(trim(SETNGS_PATH)//'VEGPARM.TBL',                              & ! filename for vegetation table
                       trim(SETNGS_PATH)//'SOILPARM.TBL',                             & ! filename for soils table
                       trim(SETNGS_PATH)//'GENPARM.TBL',                              & ! filename for general table
                       trim(model_decisions(iLookDECISIONS%vegeParTbl)%cDecision),    & ! classification system used for vegetation
                       trim(model_decisions(iLookDECISIONS%soilCatTbl)%cDecision))      ! classification system used for soils

! read Noah-MP vegetation tables
call read_mp_veg_parameters(trim(SETNGS_PATH)//'MPTABLE.TBL',                         & ! filename for Noah-MP table
                            trim(model_decisions(iLookDECISIONS%vegeParTbl)%cDecision)) ! classification system used for vegetation

! define urban vegetation category
select case(trim(model_decisions(iLookDECISIONS%vegeParTbl)%cDecision))
 case('USGS');                     urbanVegCategory =    1
 case('MODIFIED_IGBP_MODIS_NOAH'); urbanVegCategory =   13
 case('plumberCABLE');             urbanVegCategory = -999
 case('plumberCHTESSEL');          urbanVegCategory = -999
 case('plumberSUMMA');             urbanVegCategory = -999
 case default; call handle_err(30,'unable to identify vegetation category')
end select

! allocate space for default model parameters
if(allocated(dparStruct%hru))then
 call handle_err(20,'dparStruct is unexpectedly allocated')
else
 ! allocate the spatial dimension
 allocate(dparStruct%hru(nHRU),stat=err)
 if(err/=0) call handle_err(20,'problem allocating dparStruct')
endif

! set default model parameters
do iHRU=1,nHRU
 ! allocate the variable dimension for a given HRU
 call allocLocal(mpar_meta,dparStruct%hru(iHRU),err=err,message=message)
 call handle_err(err,message)
 ! set parmameters to their default value
 dparStruct%hru(iHRU)%var(:) = localParFallback(:)%default_val         ! x%hru(:)%var(:)
 ! overwrite default model parameters with information from the Noah-MP tables
 call pOverwrite(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex),  &  ! vegetation category
                 typeStruct%hru(iHRU)%var(iLookTYPE%soilTypeIndex), &  ! soil category
                 dparStruct%hru(iHRU)%var,                          &  ! default model parameters
                 err,message); call handle_err(err,message)            ! error control
 ! copy over to the parameter structure
 mparStruct%hru(iHRU)%var(:) = dparStruct%hru(iHRU)%var(:)
end do  ! looping through HRUs

! *****************************************************************************
! (5c) read trial model parameter values for each HRU, and populate initial data structures
! *****************************************************************************
call read_param(nHRU,typeStruct,mparStruct,err,message); call handle_err(err,message)

! *****************************************************************************
! (5d) assign basin parameters to the data structures 
! *****************************************************************************
bparStruct%var(:) = basinParFallback(:)%default_val

! *****************************************************************************
! (5e) compute derived model variables that are pretty much constant for the basin as a whole
! *****************************************************************************

! calculate the fraction of runoff in future time steps
call fracFuture(bparStruct%var,    &  ! vector of basin-average model parameters
                bvarStruct,        &  ! data structure of basin-average variables
                err,message)          ! error control
call handle_err(err,message)

! loop through HRUs
do iHRU=1,nHRU

 ! check that the parameters are consistent
 call paramCheck(mparStruct%hru(iHRU)%var,err,message); call handle_err(err,message)

 ! calculate a look-up table for the temperature-enthalpy conversion 
 call E2T_lookup(mparStruct%hru(iHRU)%var,err,message); call handle_err(err,message)

 ! read description of model initial conditions -- also initializes model structure components
 ! NOTE: at this stage the same initial conditions are used for all HRUs -- need to modify
 call read_icond(nSnow(iHRU),             & ! number of snow layers
                 nSoil(iHRU),             & ! number of soil layers
                 mparStruct%hru(iHRU)%var,& ! vector of model parameters
                 indxStruct%hru(iHRU),    & ! data structure of model indices
                 progStruct%hru(iHRU),    & ! model prognostic (state) variables
                 err,message)               ! error control
 call handle_err(err,message)

 ! re-calculate height of each layer
 call calcHeight(&
                 ! input/output: data structures
                 indxStruct%hru(iHRU),   & ! intent(in): layer type
                 progStruct%hru(iHRU),   & ! intent(inout): model prognostic (state) variables for a local HRU
                 ! output: error control
                 err,message); call handle_err(err,message)

 ! calculate vertical distribution of root density
 call rootDensty(mparStruct%hru(iHRU)%var,& ! vector of model parameters
                 indxStruct%hru(iHRU),    & ! data structure of model indices
                 progStruct%hru(iHRU),    & ! data structure of model prognostic (state) variables
                 diagStruct%hru(iHRU),    & ! data structure of model diagnostic variables
                 err,message)               ! error control
 call handle_err(err,message) 

 ! calculate saturated hydraulic conductivity in each soil layer
 call satHydCond(mparStruct%hru(iHRU)%var,& ! vector of model parameters
                 indxStruct%hru(iHRU),    & ! data structure of model indices
                 progStruct%hru(iHRU),    & ! data structure of model prognostic (state) variables
                 fluxStruct%hru(iHRU),    & ! data structure of model fluxes 
                 err,message)               ! error control
 call handle_err(err,message)

 ! calculate "short-cut" variables such as volumetric heat capacity
 call v_shortcut(mparStruct%hru(iHRU)%var,& ! vector of model parameters
                 diagStruct%hru(iHRU),    & ! data structure of model diagnostic variables
                 err,message)               ! error control
 call handle_err(err,message)

 ! overwrite the vegetation height
 HVT(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex)) = mparStruct%hru(iHRU)%var(iLookPARAM%heightCanopyTop)
 HVB(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex)) = mparStruct%hru(iHRU)%var(iLookPARAM%heightCanopyBottom)

 ! overwrite the tables for LAI and SAI
 if(model_decisions(iLookDECISIONS%LAI_method)%iDecision == specified)then
  SAIM(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex),:) = mparStruct%hru(iHRU)%var(iLookPARAM%winterSAI)
  LAIM(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex),:) = mparStruct%hru(iHRU)%var(iLookPARAM%summerLAI)*greenVegFrac_monthly
 endif

 ! initialize canopy drip
 ! NOTE: canopy drip from the previous time step is used to compute throughfall for the current time step
 fluxStruct%hru(iHRU)%var(iLookFLUX%scalarCanopyLiqDrainage)%dat(1) = 0._dp  ! not used

 ! define the file if the first HRU
 if(iHRU==1) then
  write(fileout,'(a,i0,a,i0,a)') trim(OUTPUT_PATH)//trim(OUTPUT_PREFIX)//'_spinup'//trim(output_fileSuffix)//'.nc'
  call def_output(nHRU,nSoil(iHRU),fileout,err,message); call handle_err(err,message)
 endif

 ! write local model attributes and parameters to the model output file
 call writeAttrb(fileout,iHRU,attrStruct%hru(iHRU)%var,typeStruct%hru(iHRU)%var,err,message); call handle_err(err,message)
 call writeParam(fileout,iHRU,mparStruct%hru(iHRU)%var,bparStruct%var,err,message); call handle_err(err,message)

end do  ! (looping through HRUs)

! allocate space for the upslope area
allocate(upArea(nHRU),stat=err); call handle_err(err,'problem allocating space for upArea')

! identify the total basin area (m2)
totalArea = bvarStruct%var(iLookBVAR%basin__totalArea)%dat(1)
totalArea = 0._dp
do iHRU=1,nHRU
 totalArea = totalArea + attrStruct%hru(iHRU)%var(iLookATTR%HRUarea)
end do

! compute total area of the upstream HRUS that flow into each HRU
do iHRU=1,nHRU
 upArea(iHRU) = 0._dp
 do jHRU=1,nHRU
  ! check if jHRU flows into iHRU
  if(typeStruct%hru(jHRU)%var(iLookTYPE%downHRUindex) ==  typeStruct%hru(iHRU)%var(iLookTYPE%hruIndex))then
   upArea(iHRU) = upArea(iHRU) + attrStruct%hru(jHRU)%var(iLookATTR%HRUarea)
  endif   ! (if jHRU is an upstream HRU)
 end do  ! jHRU
end do  ! iHRU

! initialize aquifer storage
! NOTE: this is ugly: need to add capabilities to initialize basin-wide state variables
select case(model_decisions(iLookDECISIONS%spatial_gw)%iDecision)
 case(localColumn)
  bvarStruct%var(iLookBVAR%basin__AquiferStorage)%dat(1) = 0._dp  ! not used
 case(singleBasin)
  bvarStruct%var(iLookBVAR%basin__AquiferStorage)%dat(1) = 1._dp
  do iHRU=1,nHRU
   progStruct%hru(iHRU)%var(iLookPROG%scalarAquiferStorage)%dat(1) = 0._dp  ! not used
  end do
 case default; call handle_err(20,'unable to identify decision for regional representation of groundwater')
endselect

! initialize time step length for each HRU
do iHRU=1,nHRU
 dt_init(iHRU) = progStruct%hru(iHRU)%var(iLookPROG%dt_init)%dat(1) ! seconds
end do

! initialize time step index
jstep=1

! ****************************************************************************
! (6) loop through time
! ****************************************************************************
do istep=1,numtim

 ! set print flag
 globalPrintFlag=.true.

 ! read a line of forcing data (if not already opened, open file, and get to the correct place)
 do iHRU=1,nHRU  ! loop through HRUs
  if(forcFileInfo(iHRU)%ixFirstHRU > 0)then
   forcStruct%hru(iHRU) = forcStruct%hru(forcFileInfo(iHRU)%ixFirstHRU)  ! copy forcing data from another HRU
  else
   call read_force(istep,iHRU,timeStruct%var,forcStruct%hru(iHRU)%var,err,message); call handle_err(err,message)
  endif
 end do  ! (end looping through HRUs)

 ! print progress
 !if(globalPrintFlag)then
  !if(timeStruct%var(iLookTIME%ih) == 1) write(*,'(i4,1x,5(i2,1x))') timeStruct%var
  write(*,'(i4,1x,5(i2,1x))') timeStruct%var
 !endif

 ! compute the exposed LAI and SAI and whether veg is buried by snow
 if(istep==1)then  ! (call phenology here because we need the time information)
  do iHRU=1,nHRU
   ! get vegetation phenology
   call vegPhenlgy(&
                   ! input/output: data structures
                   model_decisions,             & ! intent(in):    model decisions
                   typeStruct%hru(iHRU),        & ! intent(in):    type of vegetation and soil
                   attrStruct%hru(iHRU),        & ! intent(in):    spatial attributes
                   mparStruct%hru(iHRU),        & ! intent(in):    model parameters
                   progStruct%hru(iHRU),        & ! intent(in):    model prognostic variables for a local HRU
                   diagStruct%hru(iHRU),        & ! intent(inout): model diagnostic variables for a local HRU
                   ! output
                   computeVegFlux(iHRU),        & ! intent(out): flag to indicate if we are computing fluxes over vegetation (.false. means veg is buried with snow)
                   notUsed_canopyDepth,         & ! intent(out): NOT USED: canopy depth (m)
                   notUsed_exposedVAI,          & ! intent(out): NOT USED: exposed vegetation area index (m2 m-2)
                   err,message)                   ! intent(out): error control
   call handle_err(err,message)
   ! define the green vegetation fraction of the grid box (used to compute LAI)
   diagStruct%hru(iHRU)%var(iLookDIAG%scalarGreenVegFraction)%dat(1) = greenVegFrac_monthly(timeStruct%var(iLookTIME%im))
  end do  ! looping through HRUs
 endif  ! if the first time step

 ! *****************************************************************************
 ! (7) create a new NetCDF output file, and write parameters and forcing data
 ! *****************************************************************************
 ! check the start of a new water year
 if(timeStruct%var(iLookTIME%im)  ==10 .and. &   ! month = October
    timeStruct%var(iLookTIME%id)  ==1  .and. &   ! day = 1
    timeStruct%var(iLookTIME%ih)  ==1  .and. &   ! hour = 1
    timeStruct%var(iLookTIME%imin)==0)then       ! minute = 0
  ! define the filename
  write(fileout,'(a,i0,a,i0,a)') trim(OUTPUT_PATH)//trim(OUTPUT_PREFIX)//'_',&
                                 timeStruct%var(iLookTIME%iyyy),'-',timeStruct%var(iLookTIME%iyyy)+1,&
                                 trim(output_fileSuffix)//'.nc'
  ! define the file
  call def_output(nHRU,nSoil(1),fileout,err,message); call handle_err(err,message)
  ! write parameters for each HRU, and re-set indices
  do iHRU=1,nHRU
   ! write model parameters to the model output file
   call writeAttrb(fileout,iHRU,attrStruct%hru(iHRU)%var,typeStruct%hru(iHRU)%var,err,message); call handle_err(err,message)
   call writeParam(fileout,iHRU,mparStruct%hru(iHRU)%var,bparStruct%var,err,message); call handle_err(err,message)
   ! re-initalize the indices for midSnow, midSoil, midToto, and ifcToto
   jStep=1
   indxStruct%hru(iHRU)%var(iLookINDEX%midSnowStartIndex)%dat(1) = 1
   indxStruct%hru(iHRU)%var(iLookINDEX%midSoilStartIndex)%dat(1) = 1
   indxStruct%hru(iHRU)%var(iLookINDEX%midTotoStartIndex)%dat(1) = 1
   indxStruct%hru(iHRU)%var(iLookINDEX%ifcSnowStartIndex)%dat(1) = 1
   indxStruct%hru(iHRU)%var(iLookINDEX%ifcSoilStartIndex)%dat(1) = 1
   indxStruct%hru(iHRU)%var(iLookINDEX%ifcTotoStartIndex)%dat(1) = 1
  end do  ! (looping through HRUs)
 endif  ! if start of a new water year, and defining a new file

 ! initialize runoff variables
 bvarStruct%var(iLookBVAR%basin__SurfaceRunoff)%dat(1)    = 0._dp  ! surface runoff (m s-1)
 bvarStruct%var(iLookBVAR%basin__ColumnOutflow)%dat(1)    = 0._dp  ! outflow from all "outlet" HRUs (those with no downstream HRU)

 ! initialize baseflow variables
 bvarStruct%var(iLookBVAR%basin__AquiferRecharge)%dat(1)  = 0._dp ! recharge to the aquifer (m s-1)
 bvarStruct%var(iLookBVAR%basin__AquiferBaseflow)%dat(1)  = 0._dp ! baseflow from the aquifer (m s-1)
 bvarStruct%var(iLookBVAR%basin__AquiferTranspire)%dat(1) = 0._dp ! transpiration loss from the aquifer (m s-1)

 ! initialize total inflow for each layer in a soil column
 do iHRU=1,nHRU
  fluxStruct%hru(iHRU)%var(iLookFLUX%mLayerColumnInflow)%dat(:) = 0._dp
 end do


 ! ****************************************************************************
 ! (8) loop through HRUs
 ! ****************************************************************************
 do iHRU=1,nHRU

  ! identify the area covered by the current HRU
  fracHRU =  attrStruct%hru(iHRU)%var(iLookATTR%HRUarea) / bvarStruct%var(iLookBVAR%basin__totalArea)%dat(1)

  ! assign model layers
  ! NOTE: layer structure is different for each HRU
  nSnow(iHRU)   = indxStruct%hru(iHRU)%var(iLookINDEX%nSnow)%dat(1)
  nSoil(iHRU)   = indxStruct%hru(iHRU)%var(iLookINDEX%nSoil)%dat(1)
  nLayers       = indxStruct%hru(iHRU)%var(iLookINDEX%nLayers)%dat(1)

  ! get height at bottom of each soil layer, negative downwards (used in Noah MP)
  allocate(zSoilReverseSign(nSoil(iHRU)),stat=err); call handle_err(err,'problem allocating space for zSoilReverseSign')
  zSoilReverseSign(:) = -progStruct%hru(iHRU)%var(iLookPROG%iLayerHeight)%dat(nSnow(iHRU)+1:nLayers)

  ! get NOAH-MP parameters
  call REDPRM(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex),                & ! vegetation type index
              typeStruct%hru(iHRU)%var(iLookTYPE%soilTypeIndex),               & ! soil type
              typeStruct%hru(iHRU)%var(iLookTYPE%slopeTypeIndex),              & ! slope type index
              zSoilReverseSign,                                                & ! * not used: height at bottom of each layer [NOTE: negative] (m)
              nSoil(iHRU),                                                     & ! number of soil layers
              urbanVegCategory)                                                  ! vegetation category for urban areas

  ! overwrite the minimum resistance
  if(overwriteRSMIN) RSMIN = mparStruct%hru(iHRU)%var(iLookPARAM%minStomatalResistance)

  ! overwrite the vegetation height
  HVT(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex)) = mparStruct%hru(iHRU)%var(iLookPARAM%heightCanopyTop)
  HVB(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex)) = mparStruct%hru(iHRU)%var(iLookPARAM%heightCanopyBottom)

  ! overwrite the tables for LAI and SAI
  if(model_decisions(iLookDECISIONS%LAI_method)%iDecision == specified)then
   SAIM(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex),:) = mparStruct%hru(iHRU)%var(iLookPARAM%winterSAI)
   LAIM(typeStruct%hru(iHRU)%var(iLookTYPE%vegTypeIndex),:) = mparStruct%hru(iHRU)%var(iLookPARAM%summerLAI)*greenVegFrac_monthly
  endif

  ! compute derived forcing variables
  call derivforce(timeStruct%var,          & ! vector of time information
                  forcStruct%hru(iHRU)%var,& ! vector of model forcing data
                  attrStruct%hru(iHRU)%var,& ! vector of model attributes
                  mparStruct%hru(iHRU)%var,& ! vector of model parameters
                  diagStruct%hru(iHRU),    & ! data structure of model diagnostic variables
                  fluxStruct%hru(iHRU),    & ! data structure of model fluxes
                  err,message)               ! error control
  call handle_err(err,message)

  ! ****************************************************************************
  ! (9) run the model
  ! ****************************************************************************
  ! define the need to calculate the re-start file
  select case(ixRestart)
   case(ixRestart_iy);    printRestart = (timeStruct%var(iLookTIME%im) == 1 .and. timeStruct%var(iLookTIME%id) == 1 .and. timeStruct%var(iLookTIME%ih) == 0  .and. timeStruct%var(iLookTIME%imin) == 0)
   case(ixRestart_im);    printRestart = (timeStruct%var(iLookTIME%id) == 1 .and. timeStruct%var(iLookTIME%ih) == 0 .and. timeStruct%var(iLookTIME%imin) == 0)
   case(ixRestart_id);    printRestart = (timeStruct%var(iLookTIME%ih) == 0 .and. timeStruct%var(iLookTIME%imin) == 0)
   case(ixRestart_never); printRestart = .false.
   case default; call handle_err(20,'unable to identify option for the restart file')
  end select

  ! run the model for a single parameter set and time step
  call coupled_em(&
                  ! model control
                  istep,                & ! intent(in):    time step index
                  printRestart,         & ! intent(in):    flag to print a re-start file
                  output_fileSuffix,    & ! intent(in):    name of the experiment used in the restart file
                  dt_init(iHRU),        & ! intent(inout): initial time step
                  computeVegFlux(iHRU), & ! intent(inout): flag to indicate if we are computing fluxes over vegetation (.false. means veg is buried with snow)
                  ! data structures (input)
                  timeStruct,           & ! intent(in):    model time data
                  typeStruct%hru(iHRU), & ! intent(in):    local classification of soil veg etc. for each HRU
                  attrStruct%hru(iHRU), & ! intent(in):    local attributes for each HRU
                  forcStruct%hru(iHRU), & ! intent(in):    model forcing data
                  mparStruct%hru(iHRU), & ! intent(in):    model parameters
                  bvarStruct,           & ! intent(in):    basin-average model variables
                  ! data structures (input-output)
                  indxStruct%hru(iHRU), & ! intent(inout): model indices
                  progStruct%hru(iHRU), & ! intent(inout): model prognostic variables for a local HRU
                  diagStruct%hru(iHRU), & ! intent(inout): model diagnostic variables for a local HRU
                  fluxStruct%hru(iHRU), & ! intent(inout): model fluxes for a local HRU
                  ! error control
                  err,message)            ! intent(out): error control
  call handle_err(err,message)

  kHRU = 0
  ! identify the downslope HRU
  do jHRU=1,nHRU
   if(typeStruct%hru(iHRU)%var(iLookTYPE%downHRUindex) == typeStruct%hru(jHRU)%var(iLookTYPE%hruIndex))then
    if(kHRU==0)then  ! check there is a unique match
     kHRU=jHRU
    else
     call handle_err(20,'multi_driver: only expect there to be one downslope HRU')
    endif  ! (check there is a unique match)
   endif  ! (if identified a downslope HRU)
  end do

  !write(*,'(a,1x,i4,1x,10(f20.10,1x))') 'iHRU, averageColumnOutflow = ', iHRU, fluxStruct%hru(iHRU)%var(iLookFLUX%averageColumnOutflow)%dat(:)

  ! add inflow to the downslope HRU
  if(kHRU > 0)then  ! if there is a downslope HRU
   fluxStruct%hru(kHRU)%var(iLookFLUX%mLayerColumnInflow)%dat(:) = fluxStruct%hru(kHRU)%var(iLookFLUX%mLayerColumnInflow)%dat(:)  + fluxStruct%hru(iHRU)%var(iLookFLUX%mLayerColumnOutflow)%dat(:)

  ! increment basin column outflow (m3 s-1)
  else
   bvarStruct%var(iLookBVAR%basin__ColumnOutflow)%dat(1)   = bvarStruct%var(iLookBVAR%basin__ColumnOutflow)%dat(1) + sum(fluxStruct%hru(iHRU)%var(iLookFLUX%mLayerColumnOutflow)%dat(:))
  endif

  ! increment basin surface runoff (m s-1)
  bvarStruct%var(iLookBVAR%basin__SurfaceRunoff)%dat(1)    = bvarStruct%var(iLookBVAR%basin__SurfaceRunoff)%dat(1)     + fluxStruct%hru(iHRU)%var(iLookFLUX%scalarSurfaceRunoff)%dat(1)    * fracHRU

  ! increment basin-average baseflow input variables (m s-1)
  bvarStruct%var(iLookBVAR%basin__AquiferRecharge)%dat(1)  = bvarStruct%var(iLookBVAR%basin__AquiferRecharge)%dat(1)   + fluxStruct%hru(iHRU)%var(iLookFLUX%scalarSoilDrainage)%dat(1)     * fracHRU
  bvarStruct%var(iLookBVAR%basin__AquiferTranspire)%dat(1) = bvarStruct%var(iLookBVAR%basin__AquiferTranspire)%dat(1)  + fluxStruct%hru(iHRU)%var(iLookFLUX%scalarAquiferTranspire)%dat(1) * fracHRU

  ! increment aquifer baseflow -- ONLY if baseflow is computed individually for each HRU
  ! NOTE: groundwater computed later for singleBasin
  if(model_decisions(iLookDECISIONS%spatial_gw)%iDecision == localColumn)then
   bvarStruct%var(iLookBVAR%basin__AquiferBaseflow)%dat(1)  = bvarStruct%var(iLookBVAR%basin__AquiferBaseflow)%dat(1)  + fluxStruct%hru(iHRU)%var(iLookFLUX%scalarAquiferBaseflow)%dat(1) * fracHRU
  endif

  ! write the forcing data to the model output file
  call writeForce(fileout,forcStruct%hru(iHRU),iHRU,jstep,err,message); call handle_err(err,message)

  ! write the model output to the NetCDF file
  call writeModel(fileout,indxStruct%hru(iHRU),indx_meta,indxStruct%hru(iHRU),iHRU,jstep,err,message); call handle_err(err,message)
  call writeModel(fileout,indxStruct%hru(iHRU),prog_meta,progStruct%hru(iHRU),iHRU,jstep,err,message); call handle_err(err,message)
  call writeModel(fileout,indxStruct%hru(iHRU),diag_meta,diagStruct%hru(iHRU),iHRU,jstep,err,message); call handle_err(err,message)
  call writeModel(fileout,indxStruct%hru(iHRU),flux_meta,fluxStruct%hru(iHRU),iHRU,jstep,err,message); call handle_err(err,message)
  !if(istep>6) call handle_err(20,'stopping on a specified step: after call to writeModel')

  ! increment the model indices
  nLayers = nSnow(iHRU) + nSoil(iHRU)
  indxStruct%hru(iHRU)%var(iLookINDEX%midSnowStartIndex)%dat(1) = indxStruct%hru(iHRU)%var(iLookINDEX%midSnowStartIndex)%dat(1) + nSnow(iHRU)
  indxStruct%hru(iHRU)%var(iLookINDEX%midSoilStartIndex)%dat(1) = indxStruct%hru(iHRU)%var(iLookINDEX%midSoilStartIndex)%dat(1) + nSoil(iHRU)
  indxStruct%hru(iHRU)%var(iLookINDEX%midTotoStartIndex)%dat(1) = indxStruct%hru(iHRU)%var(iLookINDEX%midTotoStartIndex)%dat(1) + nLayers
  indxStruct%hru(iHRU)%var(iLookINDEX%ifcSnowStartIndex)%dat(1) = indxStruct%hru(iHRU)%var(iLookINDEX%ifcSnowStartIndex)%dat(1) + nSnow(iHRU)+1
  indxStruct%hru(iHRU)%var(iLookINDEX%ifcSoilStartIndex)%dat(1) = indxStruct%hru(iHRU)%var(iLookINDEX%ifcSoilStartIndex)%dat(1) + nSoil(iHRU)+1
  indxStruct%hru(iHRU)%var(iLookINDEX%ifcTotoStartIndex)%dat(1) = indxStruct%hru(iHRU)%var(iLookINDEX%ifcTotoStartIndex)%dat(1) + nLayers+1

  ! deallocate height at bottom of each soil layer(used in Noah MP)
  deallocate(zSoilReverseSign,stat=err); call handle_err(err,'problem deallocating space for zSoilReverseSign')

 end do  ! (looping through HRUs)

 ! compute water balance for the basin aquifer
 if(model_decisions(iLookDECISIONS%spatial_gw)%iDecision == singleBasin)then
  call handle_err(20,'multi_driver/bigBucket groundwater code not transferred from old code base yet')
 endif

 ! perform the routing
 call qOverland(&
                ! input
                model_decisions(iLookDECISIONS%subRouting)%iDecision,            &  ! intent(in): index for routing method
                bvarStruct%var(iLookBVAR%basin__SurfaceRunoff)%dat(1),           &  ! intent(in): surface runoff (m s-1)
                bvarStruct%var(iLookBVAR%basin__ColumnOutflow)%dat(1)/totalArea, &  ! intent(in): outflow from all "outlet" HRUs (those with no downstream HRU)
                bvarStruct%var(iLookBVAR%basin__AquiferBaseflow)%dat(1),         &  ! intent(in): baseflow from the aquifer (m s-1)
                bvarStruct%var(iLookBVAR%routingFractionFuture)%dat,             &  ! intent(in): fraction of runoff in future time steps (m s-1)
                bvarStruct%var(iLookBVAR%routingRunoffFuture)%dat,               &  ! intent(in): runoff in future time steps (m s-1)
                ! output
                bvarStruct%var(iLookBVAR%averageInstantRunoff)%dat(1),           &  ! intent(out): instantaneous runoff (m s-1)
                bvarStruct%var(iLookBVAR%averageRoutedRunoff)%dat(1),            &  ! intent(out): routed runoff (m s-1)
                err,message)                                                        ! intent(out): error control
 call handle_err(err,message)

 ! write basin-average variables
 call writeBasin(fileout,bvarStruct,jstep,err,message); call handle_err(err,message)

 ! increment the time index
 jstep = jstep+1

 !print*, 'PAUSE: in driver: testing differences'; read(*,*)
 !stop 'end of time step'

end do  ! (looping through time)

! deallocate space for dt_init and upArea
deallocate(dt_init,upArea,stat=err); call handle_err(err,'unable to deallocate space for dt_init and upArea')

call stop_program('finished simulation')

contains

 ! **************************************************************************************************
 ! private subroutine handle_err: error handler
 ! **************************************************************************************************
 subroutine handle_err(err,message)
 ! used to handle error codes
 USE var_lookup,only:iLookPROG,iLookDIAG,iLookFLUX,iLookPARAM,iLookINDEX    ! named variables defining elements in data structure
 implicit none
 ! define dummy variables
 integer(i4b),intent(in)::err             ! error code
 character(*),intent(in)::message         ! error message
 ! return if A-OK
 if(err==0) return
 ! process error messages
 if (err>0) then
  write(*,'(a)') 'FATAL ERROR: '//trim(message)
 else
  write(*,'(a)') 'WARNING: '//trim(message); print*,'(can keep going, but stopping anyway)'
 endif
 ! dump variables
 print*, 'error, variable dump:'
 print*, 'istep              = ', istep
 print*, 'HRU index          = ', typeStruct%hru(iHRU)%var(iLookTYPE%hruIndex)
 print*, 'pptrate            = ', forcStruct%hru(iHRU)%var(iLookFORCE%pptrate)
 print*, 'airtemp            = ', forcStruct%hru(iHRU)%var(iLookFORCE%airtemp)
 print*, 'theta_res          = ', mparStruct%hru(iHRU)%var(iLookPARAM%theta_res)            ! soil residual volumetric water content (-)
 print*, 'theta_sat          = ', mparStruct%hru(iHRU)%var(iLookPARAM%theta_sat)            ! soil porosity (-)
 print*, 'plantWiltPsi       = ', mparStruct%hru(iHRU)%var(iLookPARAM%plantWiltPsi)         ! matric head at wilting point (m)
 print*, 'soilStressParam    = ', mparStruct%hru(iHRU)%var(iLookPARAM%soilStressParam)      ! parameter in the exponential soil stress function (-)
 print*, 'critSoilWilting    = ', mparStruct%hru(iHRU)%var(iLookPARAM%critSoilWilting)      ! critical vol. liq. water content when plants are wilting (-)
 print*, 'critSoilTranspire  = ', mparStruct%hru(iHRU)%var(iLookPARAM%critSoilTranspire)    ! critical vol. liq. water content when transpiration is limited (-)
 print*, 'scalarSWE          = ', progStruct%hru(iHRU)%var(iLookPROG%scalarSWE)%dat(1)
 print*, 'scalarSnowDepth    = ', progStruct%hru(iHRU)%var(iLookPROG%scalarSnowDepth)%dat(1)
 print*, 'scalarCanopyTemp   = ', progStruct%hru(iHRU)%var(iLookPROG%scalarCanopyTemp)%dat(1)
 print*, 'scalarRainPlusMelt = ', fluxStruct%hru(iHRU)%var(iLookFLUX%scalarRainPlusMelt)%dat(1)
 write(*,'(a,100(i4,1x))'   ) 'layerType          = ', indxStruct%hru(iHRU)%var(iLookINDEX%layerType)%dat
 write(*,'(a,100(f11.5,1x))') 'mLayerDepth        = ', progStruct%hru(iHRU)%var(iLookPROG%mLayerDepth)%dat
 write(*,'(a,100(f11.5,1x))') 'mLayerTemp         = ', progStruct%hru(iHRU)%var(iLookPROG%mLayerTemp)%dat
 write(*,'(a,100(f11.5,1x))') 'mLayerVolFracIce   = ', progStruct%hru(iHRU)%var(iLookPROG%mLayerVolFracIce)%dat
 write(*,'(a,100(f11.5,1x))') 'mLayerVolFracLiq   = ', progStruct%hru(iHRU)%var(iLookPROG%mLayerVolFracLiq)%dat
 print*, 'mLayerMatricHead   = ', progStruct%hru(iHRU)%var(iLookPROG%mLayerMatricHead)%dat
 print*, 'column inflow      = ', fluxStruct%hru(iHRU)%var(iLookFLUX%mLayerColumnInflow)%dat
 print*,'error code = ', err
 print*, timeStruct%var
 write(*,'(a)') trim(message)
 stop
 end subroutine handle_err

 ! **************************************************************************************************
 ! private subroutine stop_program: stop program execution
 ! **************************************************************************************************
 subroutine stop_program(message)
 ! used to stop program execution
 implicit none
 ! define dummy variables
 character(*),intent(in)::message
 ! define the local variables
 integer(i4b),parameter :: outunit=6               ! write to screen
 character(len=8)       :: cdate2                  ! final date
 character(len=10)      :: ctime2                  ! final time
 ! get the final date and time
 call date_and_time(cdate2,ctime2)
 ! print initial and final date and time
 write(outunit,*) 'initial date/time = '//'ccyy='//cdate1(1:4)//' - mm='//cdate1(5:6)//' - dd='//cdate1(7:8), &
                                         ' - hh='//ctime1(1:2)//' - mi='//ctime1(3:4)//' - ss='//ctime1(5:10)
 write(outunit,*) 'final date/time   = '//'ccyy='//cdate2(1:4)//' - mm='//cdate2(5:6)//' - dd='//cdate2(7:8), &
                                         ' - hh='//ctime2(1:2)//' - mi='//ctime2(3:4)//' - ss='//ctime2(5:10)
 ! stop with message
 print*,'FORTRAN STOP: '//trim(message)
 stop
 end subroutine

end program multi_driver


 ! **************************************************************************************************
 ! private subroutine SOIL_VEG_GEN_PARM: Read soil, vegetation and other model parameters (from NOAH)
 ! **************************************************************************************************
!-----------------------------------------------------------------
SUBROUTINE SOIL_VEG_GEN_PARM(FILENAME_VEGTABLE, FILENAME_SOILTABLE, FILENAME_GENERAL, MMINLU, MMINSL)
!-----------------------------------------------------------------
  use module_sf_noahlsm, only : shdtbl, nrotbl, rstbl, rgltbl, &
       &                        hstbl, snuptbl, maxalb, laimintbl, &
       &                        bb, drysmc, f11, maxsmc, laimaxtbl, &
       &                        emissmintbl, emissmaxtbl, albedomintbl, &
       &                        albedomaxtbl, wltsmc, qtz, refsmc, &
       &                        z0mintbl, z0maxtbl, &
       &                        satpsi, satdk, satdw, &
       &                        theta_res, theta_sat, vGn_alpha, vGn_n, k_soil, &  ! MPC add van Genutchen parameters
       &                        fxexp_data, lvcoef_data, &
       &                        lutype, maxalb, &
       &                        slope_data, frzk_data, bare, cmcmax_data, &
       &                        cfactr_data, csoil_data, czil_data, &
       &                        refkdt_data, natural, refdk_data, &
       &                        rsmax_data, salp_data, sbeta_data, &
       &                        zbot_data, smhigh_data, smlow_data, &
       &                        lucats, topt_data, slcats, slpcats, sltype

  IMPLICIT NONE

  CHARACTER(LEN=*), INTENT(IN) :: FILENAME_VEGTABLE, FILENAME_SOILTABLE, FILENAME_GENERAL
  CHARACTER(LEN=*), INTENT(IN) :: MMINLU, MMINSL
  integer :: LUMATCH, IINDEX, LC, NUM_SLOPE
  integer :: ierr
  INTEGER , PARAMETER :: OPEN_OK = 0

  character*128 :: mess , message

!-----SPECIFY VEGETATION RELATED CHARACTERISTICS :
!             ALBBCK: SFC albedo (in percentage)
!                 Z0: Roughness length (m)
!             SHDFAC: Green vegetation fraction (in percentage)
!  Note: The ALBEDO, Z0, and SHDFAC values read from the following table
!          ALBEDO, amd Z0 are specified in LAND-USE TABLE; and SHDFAC is
!          the monthly green vegetation data
!             CMXTBL: MAX CNPY Capacity (m)
!             NROTBL: Rooting depth (layer)
!              RSMIN: Mimimum stomatal resistance (s m-1)
!              RSMAX: Max. stomatal resistance (s m-1)
!                RGL: Parameters used in radiation stress function
!                 HS: Parameter used in vapor pressure deficit functio
!               TOPT: Optimum transpiration air temperature. (K)
!             CMCMAX: Maximum canopy water capacity
!             CFACTR: Parameter used in the canopy inteception calculati
!               SNUP: Threshold snow depth (in water equivalent m) that
!                     implies 100% snow cover
!                LAI: Leaf area index (dimensionless)
!             MAXALB: Upper bound on maximum albedo over deep snow
!
!-----READ IN VEGETAION PROPERTIES FROM VEGPARM.TBL
!

  OPEN(19, FILE=trim(FILENAME_VEGTABLE),FORM='FORMATTED',STATUS='OLD',IOSTAT=ierr)
  IF(ierr .NE. OPEN_OK ) THEN
     WRITE(message,FMT='(A)') &
          'module_sf_noahlsm.F: soil_veg_gen_parm: failure opening VEGPARM.TBL'
     CALL wrf_error_fatal ( message )
  END IF


  LUMATCH=0

  FIND_LUTYPE : DO WHILE (LUMATCH == 0)
     READ (19,*,END=2002)
     READ (19,*,END=2002)LUTYPE
     READ (19,*)LUCATS,IINDEX

     IF(LUTYPE.EQ.MMINLU)THEN
        WRITE( mess , * ) 'LANDUSE TYPE = ' // TRIM ( LUTYPE ) // ' FOUND', LUCATS,' CATEGORIES'
        ! CALL wrf_message( mess )
        LUMATCH=1
     ELSE
        call wrf_message ( "Skipping over LUTYPE = " // TRIM ( LUTYPE ) )
        DO LC = 1, LUCATS+12
           read(19,*)
        ENDDO
     ENDIF
  ENDDO FIND_LUTYPE
! prevent possible array overwrite, Bill Bovermann, IBM, May 6, 2008
  IF ( SIZE(SHDTBL)       < LUCATS .OR. &
       SIZE(NROTBL)       < LUCATS .OR. &
       SIZE(RSTBL)        < LUCATS .OR. &
       SIZE(RGLTBL)       < LUCATS .OR. &
       SIZE(HSTBL)        < LUCATS .OR. &
       SIZE(SNUPTBL)      < LUCATS .OR. &
       SIZE(MAXALB)       < LUCATS .OR. &
       SIZE(LAIMINTBL)    < LUCATS .OR. &
       SIZE(LAIMAXTBL)    < LUCATS .OR. &
       SIZE(Z0MINTBL)     < LUCATS .OR. &
       SIZE(Z0MAXTBL)     < LUCATS .OR. &
       SIZE(ALBEDOMINTBL) < LUCATS .OR. &
       SIZE(ALBEDOMAXTBL) < LUCATS .OR. &
       SIZE(EMISSMINTBL ) < LUCATS .OR. &
       SIZE(EMISSMAXTBL ) < LUCATS ) THEN
     CALL wrf_error_fatal('Table sizes too small for value of LUCATS in module_sf_noahdrv.F')
  ENDIF

  IF(LUTYPE.EQ.MMINLU)THEN
     DO LC=1,LUCATS
        READ (19,*)IINDEX,SHDTBL(LC),                        &
             NROTBL(LC),RSTBL(LC),RGLTBL(LC),HSTBL(LC), &
             SNUPTBL(LC),MAXALB(LC), LAIMINTBL(LC),     &
             LAIMAXTBL(LC),EMISSMINTBL(LC),             &
             EMISSMAXTBL(LC), ALBEDOMINTBL(LC),         &
             ALBEDOMAXTBL(LC), Z0MINTBL(LC), Z0MAXTBL(LC)
     ENDDO
!
     READ (19,*)
     READ (19,*)TOPT_DATA
     READ (19,*)
     READ (19,*)CMCMAX_DATA
     READ (19,*)
     READ (19,*)CFACTR_DATA
     READ (19,*)
     READ (19,*)RSMAX_DATA
     READ (19,*)
     READ (19,*)BARE
     READ (19,*)
     READ (19,*)NATURAL
  ENDIF
!
2002 CONTINUE

  CLOSE (19)
  IF (LUMATCH == 0) then
     CALL wrf_error_fatal ("Land Use Dataset '"//MMINLU//"' not found in VEGPARM.TBL.")
  ENDIF

!
!-----READ IN SOIL PROPERTIES FROM SOILPARM.TBL
!
  OPEN(19, FILE=trim(FILENAME_SOILTABLE),FORM='FORMATTED',STATUS='OLD',IOSTAT=ierr)
  IF(ierr .NE. OPEN_OK ) THEN
     WRITE(message,FMT='(A)') &
          'module_sf_noahlsm.F: soil_veg_gen_parm: failure opening SOILPARM.TBL'
     CALL wrf_error_fatal ( message )
  END IF

  WRITE(mess,*) 'INPUT SOIL TEXTURE CLASSIFICATION = ', TRIM ( MMINSL )
  ! CALL wrf_message( mess )

  LUMATCH=0



  ! MPC add a new soil table
  FIND_soilTYPE : DO WHILE (LUMATCH == 0)
   READ (19,*)
   READ (19,*,END=2003)SLTYPE
   READ (19,*)SLCATS,IINDEX
   IF(SLTYPE.EQ.MMINSL)THEN
     WRITE( mess , * ) 'SOIL TEXTURE CLASSIFICATION = ', TRIM ( SLTYPE ) , ' FOUND', &
          SLCATS,' CATEGORIES'
     ! CALL wrf_message ( mess )
     LUMATCH=1
   ELSE
    call wrf_message ( "Skipping over SLTYPE = " // TRIM ( SLTYPE ) )
    DO LC = 1, SLCATS
     read(19,*)
    ENDDO
   ENDIF
  ENDDO FIND_soilTYPE
  ! prevent possible array overwrite, Bill Bovermann, IBM, May 6, 2008
  IF ( SIZE(BB    ) < SLCATS .OR. &
       SIZE(DRYSMC) < SLCATS .OR. &
       SIZE(F11   ) < SLCATS .OR. &
       SIZE(MAXSMC) < SLCATS .OR. &
       SIZE(REFSMC) < SLCATS .OR. &
       SIZE(SATPSI) < SLCATS .OR. &
       SIZE(SATDK ) < SLCATS .OR. &
       SIZE(SATDW ) < SLCATS .OR. &
       SIZE(WLTSMC) < SLCATS .OR. &
       SIZE(QTZ   ) < SLCATS  ) THEN
     CALL wrf_error_fatal('Table sizes too small for value of SLCATS in module_sf_noahdrv.F')
  ENDIF

  ! MPC add new soil table
  select case(trim(SLTYPE))
   case('STAS','STAS-RUC')  ! original soil tables
     DO LC=1,SLCATS
        READ (19,*) IINDEX,BB(LC),DRYSMC(LC),F11(LC),MAXSMC(LC),&
             REFSMC(LC),SATPSI(LC),SATDK(LC), SATDW(LC),   &
             WLTSMC(LC), QTZ(LC)
     ENDDO
   case('ROSETTA')          ! new soil table
     DO LC=1,SLCATS
        READ (19,*) IINDEX,&
             ! new soil parameters (from Rosetta)
             theta_res(LC), theta_sat(LC),        &
             vGn_alpha(LC), vGn_n(LC), k_soil(LC), &
             ! original soil parameters
             BB(LC),DRYSMC(LC),F11(LC),MAXSMC(LC),&
             REFSMC(LC),SATPSI(LC),SATDK(LC), SATDW(LC),   &
             WLTSMC(LC), QTZ(LC)
     ENDDO
   case default
     CALL wrf_message( 'SOIL TEXTURE IN INPUT FILE DOES NOT ' )
     CALL wrf_message( 'MATCH SOILPARM TABLE'                 )
     CALL wrf_error_fatal ( 'INCONSISTENT OR MISSING SOILPARM FILE' )
  end select

2003 CONTINUE

  CLOSE (19)

  IF(LUMATCH.EQ.0)THEN
     CALL wrf_message( 'SOIL TEXTURE IN INPUT FILE DOES NOT ' )
     CALL wrf_message( 'MATCH SOILPARM TABLE'                 )
     CALL wrf_error_fatal ( 'INCONSISTENT OR MISSING SOILPARM FILE' )
  ENDIF

!
!-----READ IN GENERAL PARAMETERS FROM GENPARM.TBL
!
  OPEN(19, FILE=trim(FILENAME_GENERAL),FORM='FORMATTED',STATUS='OLD',IOSTAT=ierr)
  IF(ierr .NE. OPEN_OK ) THEN
     WRITE(message,FMT='(A)') &
          'module_sf_noahlsm.F: soil_veg_gen_parm: failure opening GENPARM.TBL'
     CALL wrf_error_fatal ( message )
  END IF

  READ (19,*)
  READ (19,*)
  READ (19,*) NUM_SLOPE

  SLPCATS=NUM_SLOPE
! prevent possible array overwrite, Bill Bovermann, IBM, May 6, 2008
  IF ( SIZE(slope_data) < NUM_SLOPE ) THEN
     CALL wrf_error_fatal('NUM_SLOPE too large for slope_data array in module_sf_noahdrv')
  ENDIF

  DO LC=1,SLPCATS
     READ (19,*)SLOPE_DATA(LC)
  ENDDO

  READ (19,*)
  READ (19,*)SBETA_DATA
  READ (19,*)
  READ (19,*)FXEXP_DATA
  READ (19,*)
  READ (19,*)CSOIL_DATA
  READ (19,*)
  READ (19,*)SALP_DATA
  READ (19,*)
  READ (19,*)REFDK_DATA
  READ (19,*)
  READ (19,*)REFKDT_DATA
  READ (19,*)
  READ (19,*)FRZK_DATA
  READ (19,*)
  READ (19,*)ZBOT_DATA
  READ (19,*)
  READ (19,*)CZIL_DATA
  READ (19,*)
  READ (19,*)SMLOW_DATA
  READ (19,*)
  READ (19,*)SMHIGH_DATA
  READ (19,*)
  READ (19,*)LVCOEF_DATA
  CLOSE (19)

!-----------------------------------------------------------------
END SUBROUTINE SOIL_VEG_GEN_PARM
!-----------------------------------------------------------------
