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

module def_output_module
USE nrtype
USE netcdf
implicit none
private
public :: def_output
! define dimension names
character(len=32),parameter :: hru_DimName='hru'                       ! dimension name for the HRUs
character(len=32),parameter :: scalar_DimName='scalar'                 ! dimension name for scalar variables
character(len=32),parameter :: wLength_dimName='spectral_bands'        ! dimension name for the number of spectral bands
character(len=32),parameter :: timestep_DimName='time'                 ! dimension name for the time step
character(len=32),parameter :: routing_DimName='timeDelayRouting'      ! dimension name for thetime delay routing vectors
character(len=32),parameter :: midSnowAndTime_DimName='midSnowAndTime' ! dimension name for midSnow-time
character(len=32),parameter :: midSoilAndTime_DimName='midSoilAndTime' ! dimension name for midSoil-time
character(len=32),parameter :: midTotoAndTime_DimName='midTotoAndTime' ! dimension name for midToto-time
character(len=32),parameter :: ifcSnowAndTime_DimName='ifcSnowAndTime' ! dimension name for ifcSnow-time
character(len=32),parameter :: ifcSoilAndTime_DimName='ifcSoilAndTime' ! dimension name for ifcSoil-time
character(len=32),parameter :: ifcTotoAndTime_DimName='ifcTotoAndTime' ! dimension name for ifcToto-time
! define named variables to specify dimensions
integer(i4b),parameter  :: needHRU=1,noHRU=2    ! define if there is an HRU dimension
integer(i4b),parameter  :: needTime=1,noTime=2  ! define if there is a time dimension

contains


 ! **********************************************************************************************************
 ! public subroutine def_output: define model output file
 ! **********************************************************************************************************
 subroutine def_output(nHRU,nSoil,infile,err,message)
 USE globalData,only:structInfo                               ! information on the data structures
 USE globalData,only:forc_meta,attr_meta,type_meta            ! metadata structures
 USE globalData,only:prog_meta,diag_meta,flux_meta,deriv_meta ! metadata structures
 USE globalData,only:mpar_meta,indx_meta                      ! metadata structures
 USE globalData,only:bpar_meta,bvar_meta                      ! metadata structures
 USE globalData,only:model_decisions
 USE multiconst,only:integerMissing
 ! declare dummy variables
 integer(i4b), intent(in)    :: nHRU                          ! number of HRUs
 integer(i4b), intent(in)    :: nSoil                         ! number of soil layers in the first HRU (used to define fixed length dimensions)
 character(*), intent(in)    :: infile                        ! file suffix
 integer(i4b),intent(out)    :: err                           ! error code
 character(*),intent(out)    :: message                       ! error message
 ! local variables
 integer(i4b)                :: ivar                          ! loop through model variables
 integer(i4b)                :: iStruct                       ! index of data structure
 character(len=256)          :: cmessage                      ! temporary error message
 ! initialize errors
 err=0; message="def_output/"

 ! create initial file
 call ini_create(nHRU,nSoil,trim(infile),err,cmessage)
 if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

 ! define model decisions
 do ivar=1,size(model_decisions)
  if(model_decisions(ivar)%iDecision /= integerMissing)then
   call put_attrib(trim(infile),model_decisions(ivar)%cOption,model_decisions(ivar)%cDecision,err,cmessage)
   if(err/=0)then; message=trim(message)//trim(cmessage); return; endif
  endif
 end do

 ! define variables
 do iStruct=1,size(structInfo)
  select case(trim(structInfo(iStruct)%structName))
   case('time'); cycle                                                                               ! model time data
   case('forc'); call def_variab(trim(infile),needHRU,needTime,forc_meta, nf90_double,err,cmessage)  ! model forcing data
   case('attr'); call def_variab(trim(infile),needHRU,  noTime,attr_meta, nf90_double,err,cmessage)  ! local attributes for each HRU
   case('type'); call def_variab(trim(infile),needHRU,  noTime,type_meta, nf90_int,   err,cmessage)  ! local classification of soil veg etc. for each HRU
   case('mpar'); call def_variab(trim(infile),needHRU,  noTime,mpar_meta, nf90_double,err,cmessage)  ! model parameters
   case('indx'); call def_variab(trim(infile),needHRU,needTime,indx_meta, nf90_int,   err,cmessage)  ! model variables
   case('prog'); call def_variab(trim(infile),needHRU,needTime,prog_meta, nf90_double,err,cmessage)  ! model prognostic (state) variables
   case('diag'); call def_variab(trim(infile),needHRU,needTime,diag_meta, nf90_double,err,cmessage)  ! model diagnostic variables
   case('flux'); call def_variab(trim(infile),needHRU,needTime,flux_meta, nf90_double,err,cmessage)  ! model fluxes
   case('deriv');call def_variab(trim(infile),needHRU,needTime,deriv_meta,nf90_double,err,cmessage)  ! model derivatives
   case('bpar'); call def_variab(trim(infile),  noHRU,  noTime,bpar_meta, nf90_double,err,cmessage)  ! basin-average parameters
   case('bvar'); call def_variab(trim(infile),  noHRU,needTime,bvar_meta, nf90_double,err,cmessage)  ! basin-average variables
   case default; err=20; message=trim(message)//'unable to identify lookup structure'; return
  end select
  ! check errors
  if(err/=0)then; err=20; message=trim(message)//trim(cmessage)//' [structure =  '//trim(structInfo(iStruct)%structName)//']'; return; endif
 end do  ! looping through data structures

 end subroutine def_output


 ! **********************************************************************************************************
 ! private subroutine ini_create: initial create
 ! **********************************************************************************************************
 subroutine ini_create(nHRU,nSoil,infile,err,message)
 ! variables to define number of steps per file (total number of time steps, step length, etc.)
 USE multiconst,only:secprday           ! number of seconds per day
 USE globalData,only:data_step          ! time step of model forcing data (s)
 USE globalData,only:numtim             ! number of time steps
 ! model decisions
 USE globalData,only:model_decisions    ! model decision structure
 USE var_lookup,only:iLookDECISIONS     ! named variables for elements of the decision structure
 USE mDecisions_module,only:&
  sameRulesAllLayers, & ! SNTHERM option: same combination/sub-dividion rules applied to all layers
  rulesDependLayerIndex ! CLM option: combination/sub-dividion rules depend on layer index
 implicit none
 ! declare dummy variables
 integer(i4b),intent(in)     :: nHRU                       ! number of HRUs
 integer(i4b), intent(in)    :: nSoil                      ! number of soil layers in the first HRU (used to define fixed length dimensions)
 character(*),intent(in)     :: infile                     ! filename
 integer(i4b),intent(out)    :: err                        ! error code
 character(*),intent(out)    :: message                    ! error message
 ! define local variables
 integer(i4b)                :: ncid                       ! NetCDF file ID
 integer(i4b)                :: dimID
 integer(i4b)                :: maxRouting=1000            ! maximum length of routing vector
 integer(i4b),parameter      :: maxSpectral=2              ! maximum number of spectral bands
 integer(i4b),parameter      :: scalarLength=1             ! length of scalar variable
 integer(i4b)                :: meanSnowLayersPerStep      ! mean number of snow layers per time step
 integer(i4b)                :: maxStepsPerFile            ! maximum number of time steps to be stored in each file
 integer(i4b)                :: maxLength                  ! maximum length of the variable vector
 ! initialize error control
 err=0;message="f-iniCreate/"
 ! identify length of the variable vector
 maxStepsPerFile = min(numtim, nint(366._dp * secprday/data_step) )
 select case(model_decisions(iLookDECISIONS%snowLayers)%iDecision)
  case(sameRulesAllLayers);    meanSnowLayersPerStep = 100
  case(rulesDependLayerIndex); meanSnowLayersPerStep = 5
  case default; err=20; message=trim(message)//'unable to identify option to combine/sub-divide snow layers'; return
 end select ! (option to combine/sub-divide snow layers)
 maxLength = maxStepsPerFile*(nSoil+1 + meanSnowLayersPerStep)
 print*, 'maxStepsPerFile, maxLength = ', maxStepsPerFile, maxLength
 ! create output file
 err = nf90_create(trim(infile),nf90_classic_model,ncid)
 message='iCreate[create]'; call netcdf_err(err,message); if (err/=0) return
 ! create time dimension (unlimited)
 err = nf90_def_dim(ncid, trim(timestep_DimName), nf90_unlimited, dimId)
 message='iCreate[time]'; call netcdf_err(err,message); if (err/=0) return
 ! create scalar dimension
 err = nf90_def_dim(ncid, trim(scalar_DimName), scalarLength, dimId)
 message='iCreate[scalar]'; call netcdf_err(err,message); if (err/=0) return
 ! create HRU dimension
 err = nf90_def_dim(ncid, trim(hru_DimName), nHRU, dimId)
 message='iCreate[HRU]'; call netcdf_err(err,message); if (err/=0) return
 ! create spectral band dimension
 err = nf90_def_dim(ncid, trim(wLength_DimName), maxSpectral, dimId)
 message='iCreate[spectral]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for the time-delay routing variables
 err = nf90_def_dim(ncid, trim(routing_DimName), maxRouting, dimId)
 message='iCreate[routing]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for midSnow+time
 err = nf90_def_dim(ncid, trim(midSnowAndTime_DimName), maxLength, dimId)
 message='iCreate[midSnow]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for midSoil+time
 err = nf90_def_dim(ncid, trim(midSoilAndTime_DimName), maxLength, dimId)
 message='iCreate[midSoil]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for midToto+time
 err = nf90_def_dim(ncid, trim(midTotoAndTime_DimName), maxLength, dimId)
 message='iCreate[minToto]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for ifcSnow+time
 err = nf90_def_dim(ncid, trim(ifcSnowAndTime_DimName), maxLength, dimId)
 message='iCreate[ifcSnow]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for ifcSoil+time
 err = nf90_def_dim(ncid, trim(ifcSoilAndTime_DimName), maxLength, dimId)
 message='iCreate[ifcSoil]'; call netcdf_err(err,message); if (err/=0) return
 ! create dimension for ifcToto+time
 err = nf90_def_dim(ncid, trim(ifcTotoAndTime_DimName), maxLength, dimId)
 message='iCreate[ifcToto]'; call netcdf_err(err,message); if (err/=0) return
 ! close NetCDF file
 err = nf90_enddef(ncid); call netcdf_err(err,message); if (err/=0) return
 err = nf90_close(ncid); call netcdf_err(err,message); if (err/=0) return
 end subroutine ini_create


 ! **********************************************************************************************************
 ! private subroutine put_attrib: put global attributes as character string
 ! **********************************************************************************************************
 subroutine put_attrib(infile,attname,attvalue,err,message)
 USE data_types,only:var_info                              ! derived type for metadata
 implicit none
 ! declare dummy variables
 character(*), intent(in)   :: infile      ! filename
 character(*), intent(in)   :: attname     ! attribute name
 character(*), intent(in)   :: attvalue    ! attribute vaue
 integer(i4b),intent(out)   :: err         ! error code
 character(*),intent(out)   :: message     ! error message
 ! local variables
 integer(i4b)               :: ncid        ! NetCDF file ID
 ! initialize error control
 err=0;message="put_attrib/"//trim(attname)//"/"//trim(attvalue)//"/"
 ! open NetCDF file
 err = nf90_open(infile,nf90_write,ncid)
 call netcdf_err(err,message); if (err/=0) return
 ! allow re-definition of variables
 err = nf90_redef(ncid); call netcdf_err(err,message); if (err/=0) return
 ! put the attribute
 err = nf90_put_att(ncid,nf90_global,trim(attname),trim(attvalue))
 call netcdf_err(err,message); if (err/=0) return
 ! close output file
 err = nf90_enddef(ncid); call netcdf_err(err,message); if (err/=0) return
 err = nf90_close(ncid); call netcdf_err(err,message); if (err/=0) return
 end subroutine put_attrib


 ! **********************************************************************************************************
 ! private subroutine def_variab: define variables
 ! **********************************************************************************************************
 subroutine def_variab(infile,hruDesire,timeDesire,metadata,ivtype,err,message)
 USE data_types,only:var_info                       ! derived type for metadata
 implicit none
 ! input
 character(*), intent(in)      :: infile            ! filename
 integer(i4b), intent(in)      :: hruDesire         ! variable to define if we desire the HRU dimension
 integer(i4b), intent(in)      :: timeDesire        ! variable to define if we desire the time dimension
 type(var_info),intent(in)     :: metadata(:)       ! metadata structure for a given variable
 integer(i4b),intent(in)       :: ivtype            ! variable type
 ! output
 integer(i4b),intent(out)      :: err               ! error code
 character(*),intent(out)      :: message           ! error message
 ! local
 integer(i4b)                  :: ivar              ! variable index
 character(len=32),allocatable :: dimensionNames(:) ! vector of dimension names
 integer(i4b),allocatable      :: dimensionIDs(:)   ! vector of dimension IDs
 integer(i4b)                  :: nDims             ! number of dimensions
 integer(i4b)                  :: id                ! loop through dimensions
 integer(i4b)                  :: ncid              ! NetCDF file ID
 integer(i4b)                  :: iVarId            ! variable ID
 ! initialize error control
 err=0; message='def_variab/'

 ! open NetCDF file
 err = nf90_open(infile,nf90_write,ncid)
 call netcdf_err(err,message); if (err/=0) return

 ! allow re-definition of variables
 err = nf90_redef(ncid); call netcdf_err(err,message); if (err/=0) return

 ! loop through metadata
 do ivar=1,size(metadata)

  ! check that the variable is desired
  if (.not.metadata(ivar)%v_write .or. trim(metadata(ivar)%vartype)=='unknown') cycle

  ! deallocate dimension names and IDs
  if(allocated(dimensionNames)) deallocate(dimensionNames)
  if(allocated(dimensionIDs))   deallocate(dimensionIDs)

  ! ** get variable shape
  ! special case of the time variable
  if(metadata(ivar)%varname == 'time')then
   allocate(dimensionNames, source=(/Timestep_DimName/), stat=err)
   if(err/=0)then; err=20; message=trim(message)//'problem allocating dimensions for variable '//trim(metadata(ivar)%varname); return; endif
  ! standard case
  else
   select case(trim(metadata(ivar)%vartype))
    ! (scalar variable -- many different types)
    case('scalarv')
     if(hruDesire==needHRU .and. timeDesire==needTime) allocate(dimensionNames, source=(/hru_DimName,Timestep_DimName/), stat=err)
     if(hruDesire==needHRU .and. timeDesire==  noTime) allocate(dimensionNames, source=(/hru_DimName/)                 , stat=err)
     if(hruDesire==  noHRU .and. timeDesire==needTime) allocate(dimensionNames, source=(/Timestep_DimName/)            , stat=err)
     if(hruDesire==  noHRU .and. timeDesire==  noTime) allocate(dimensionNames, source=(/scalar_DimName/)              , stat=err)
    ! (other variables)
    case('wLength'); allocate(dimensionNames, source=(/hru_DimName,wLength_DimName,Timestep_DimName/), stat=err)
    case('midSnow'); allocate(dimensionNames, source=(/hru_DimName,midSnowAndTime_DimName/)          , stat=err)
    case('midSoil'); allocate(dimensionNames, source=(/hru_DimName,midSoilAndTime_DimName/)          , stat=err)
    case('midToto'); allocate(dimensionNames, source=(/hru_DimName,midTotoAndTime_DimName/)          , stat=err)
    case('ifcSnow'); allocate(dimensionNames, source=(/hru_DimName,ifcSnowAndTime_DimName/)          , stat=err)
    case('ifcSoil'); allocate(dimensionNames, source=(/hru_DimName,ifcSoilAndTime_DimName/)          , stat=err)
    case('ifcToto'); allocate(dimensionNames, source=(/hru_DimName,ifcTotoAndTime_DimName/)          , stat=err)
    case('routing'); allocate(dimensionNames, source=(/routing_DimName/)                             , stat=err)
   end select
   ! check errors
   if(err/=0)then
    message=trim(message)//'problem allocating dimensions for variable '//trim(metadata(ivar)%varname)
    return
   endif
  endif  ! check if we are processing the time variable
  ! check that we got the shape
  if(.not.allocated(dimensionNames))then
   message=trim(message)//'problem defining dimensions for variable '//trim(metadata(ivar)%varname)
   err=20; return
  endif

  ! create space for the dimension IDs
  nDims = size(dimensionNames)
  allocate(dimensionIds(nDims),stat=err)
  if(err/=0)then; message=trim(message)//'unable to allocate space for dimension IDs'; return; endif

  ! define dimension IDs
  do id=1,nDims
   err=nf90_inq_dimid(ncid,trim(dimensionNames(id)),dimensionIDs(id))
   call netcdf_err(err,message)
   if (err/=0) return
  end do
  
  ! define variable
  err = nf90_def_var(ncid,trim(metadata(ivar)%varname),ivtype,dimensionIDs,iVarId)
  call netcdf_err(err,message); if (err/=0) return

  ! add parameter description
  err = nf90_put_att(ncid,iVarId,'long_name',trim(metadata(ivar)%vardesc))
  call netcdf_err(err,message); if (err/=0) return

  ! add parameter units
  err = nf90_put_att(ncid,iVarId,'units',trim(metadata(ivar)%varunit))
  call netcdf_err(err,message); if (err/=0) return

 end do  ! looping through variables
  
 ! close output file
 err = nf90_enddef(ncid); call netcdf_err(err,message); if (err/=0) return
 err = nf90_close(ncid); call netcdf_err(err,message); if (err/=0) return

 end subroutine def_variab


 ! **********************************************************************************************************
 ! private subroutine netcdf_err: error control
 ! **********************************************************************************************************
 subroutine netcdf_err(err,message)
 ! used to handle errors for NetCDF calls
 implicit none
 ! declare dummies
 integer(i4b), intent(inout)   :: err
 character(*), intent(inout)   :: message
 ! start procedure here
 if (err/=nf90_noerr) then
  message=trim(message)//"["//trim(nf90_strerror(err))//"]"
  err=200
 endif
 end subroutine netcdf_err


end module def_output_module
