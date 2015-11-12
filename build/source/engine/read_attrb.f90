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

module read_attrb_module
USE netcdf
USE nrtype
USE netcdf_util_module, only: check
implicit none
private
public::read_attrb
contains

 ! ************************************************************************************************
 ! public subroutine read_attrb: read information on local attributes
 ! ************************************************************************************************
 subroutine read_attrb(err,message)
 ! provide access to subroutines
 USE netcdf_util_module,only:file_open             ! open netCDF file
 USE allocspace_module,only:alloc_attr             ! module to allocate space for local attributes
 USE allocspace_module,only:alloc_type             ! module to allocate space for categorical data
 ! provide access to data
 USE summaFileManager,only:SETNGS_PATH             ! path for metadata files
 USE summaFileManager,only:LOCAL_ATTRIBUTES        ! file containing information on local attributes
 USE data_struc,only: gru_struc, nGRU, nHRU        ! gru-hru structures
 USE data_struc,only:index_map                     ! index mapping 
 USE data_struc,only:attr_meta,type_meta           ! metadata structures
 USE data_struc,only:attr_gru,type_gru             ! data structures
 USE var_lookup,only:iLookATTR,iLookTYPE           ! named variables for elements of the data structures
 USE get_ixname_module,only:get_ixAttr,get_ixType  ! access function to find index of elements in structure
 
 implicit none
 ! define output
 integer(i4b),intent(out)             :: err       ! error code
 character(*),intent(out)             :: message   ! error message
 ! define general variables
 real(dp),parameter                   :: missingDouble=-9999._dp  ! missing data
 character(len=256)                   :: cmessage                 ! error message for downwind routine
 character(LEN=256)                   :: infile                   ! input filename
 
 ! define variables for NetCDF file operation
 integer(i4b)                         :: mode               ! netCDF file open mode
 integer(i4b)                         :: ncid, grp_ncid     ! integer variables for NetCDF IDs
 integer(i4b), allocatable            :: varids(:)          ! integer variables for NetCDF IDs
 integer(i4b)                         :: hruDimID, varid    ! integer variables for NetCDF IDs
 integer(i4b), allocatable            :: start(:), count(:) ! specification for data reading          
 ! define local variables
 integer(i4b)                         :: varIndx            ! index of variable within its data structure
 integer(i4b)                         :: iAtt               ! index of an attribute name
 integer(i4b)                         :: iHRU,iGRU          ! index of HRU and GRU
 integer(i4b)                         :: iVar               ! index of an HRU
 integer(i4b)                         :: nvar_f             ! number of variables readed from netcdf input file
 integer(i4b)                         :: nVar_attr          ! number of variables in the model attribute structure
 integer(i4b)                         :: nVar_type          ! number of variables in the model category structure
 integer(i4b),allocatable             :: buf_int_1d(:)      ! temporal buffer for reading data
 real(dp),allocatable                 :: buf_flt_1d(:)      ! temporal buffer for reading data
 integer(i4b)                         :: jVar, jStruct      ! index for variables and structures
 integer(i4b)                         :: hruCount           ! number of hrus in a gru
 integer(i4b)                         :: hru_ix             ! hru index; it is sequential over entire domain,but not necessary within a gru


 ! define indicators for different data structures
 integer(i4b),parameter               :: ixType=1           ! indicator for type_gru structure
 integer(i4b),parameter               :: ixAttr=2           ! indicator for attr_gru structure 
 integer(i4b)                         :: hit                ! number of variables with same name across all data structures 
 character(len=64)                    :: varname=''         ! variable name
 integer(i4b), parameter              :: imiss = -999       ! missing value for variable id
 
 ! Start procedure here
 err=0; message="read_attrb/"

 ! **********************************************************************************************
 !8 (0) get number of variables in each data structure in model
 ! **********************************************************************************************
 ! check that metadata structures are initialized
 if(.not.associated(attr_meta) .or. .not.associated(type_meta))then
  err=10; message=trim(message)//"metadataNotInitialized"; return
 endif
 nVar_attr = size(attr_meta)
 nVar_type = size(type_meta)

 ! **********************************************************************************************
 ! (1) open hru_attributes file and allocate memory for data structure according to data file
 ! **********************************************************************************************
 ! build filename
 infile = trim(SETNGS_PATH)//trim(LOCAL_ATTRIBUTES)
 ! open file
 mode=nf90_NoWrite
 call file_open(trim(infile), mode, ncid, err, cmessage)
 if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

 ! allocate space
 call alloc_type(err,cmessage); if(err/=0)then; message=trim(message)//trim(cmessage); return; endif
 call alloc_attr(err,cmessage); if(err/=0)then; message=trim(message)//trim(cmessage); return; endif
 
 allocate(varids(nVar_attr+nVar_type), stat=err)
 if(err/=0)then; err=20; message=trim(message)//"problem allocating space for varids"; return; endif

 allocate(buf_int_1d(nHRU), buf_flt_1d(nHRU), stat=err)
 if(err/=0)then; err=20; message=trim(message)//'problem allocating space for buffer reading'; return; endif

 allocate ( start(1), count(1), stat=err )
 if(err/=0)then; err=20; message=trim(message)//'problem allocating space for netcdf reading specification'; return; endif
 ! **********************************************************************************************
 ! (3) read local attributes and types  from netCDF file group "hru_attributes"
 ! (ie., 'hruIndex','vegTypeIndex','soilTypeIndex','slopeTypeIndex','downHRUindex',
 ! 'latitude','longitude','elevation','tan_slope','contourLength','HRUarea','mHeight')
 ! **********************************************************************************************
 varIndx= imiss
 
 ! get group id
 call check(nf90_inq_ncid(ncid, 'hru_attributes', grp_ncid), message) 

 ! get variable ids in the group
 call check(nf90_inq_varids(grp_ncid, nvar_f, varids), message)
 if((nVar_type + nVar_attr)/=nvar_f) then; err=20; message=trim(message)//'the number of variables '// &
    'in the input file is not correct'; return; endif

 jVar    = imiss
 jStruct =imiss
 start = (/ 1 /)
 count = (/ nHRU /)

 !***** Read all the variables in the group of input files, and then populate them to their corresponding
 ! hierachical data strucutres, according to their variable names. *************************************!  
 do iVar=1, nvar_f ! iVar loop
  call check(nf90_inquire_variable(grp_ncid, varids(iVar), varname), message)
 
  ! "hit" is used to indicate the times of a variable name that can be found from summa data structures.
  ! Only once of hit (i.e., hit=1) is expected to be correct. If hit>1, it means there are same variable names
  ! showed up in different data structures. SUMMA only allows unique variable names accross all 
  ! internal data structures.
  hit=0 
  varIndx= get_ixType(varname)
  if(varIndx/=imiss)then; hit=hit+1; jVar = varIndx; jStruct=ixType; endif
  varIndx = get_ixAttr(varname)
  if(varIndx /= imiss)then; hit=hit+1; jVar= varIndx; jStruct=ixAttr; endif
  
  if(hit==0) then; err=20; message=trim(message)//'unable to find data structure '// &
    'for ['//trim(varname)//']'; return; endif
  if(hit>1)then; err=20; message=trim(message)//'the variable name ['//trim(varname)//'] is found '// &
    'in multiple data structures'; return; endif
 
  ! Read data according to the data type associated to data structures
  select case(jStruct)
    case(ixType);  
     call check(nf90_get_var(grp_ncid, varids(iVar), buf_int_1d, start = start, count = count),message)
    case(ixAttr)
     call check(nf90_get_var(grp_ncid, varids(iVar), buf_flt_1d, start = start, count = count),message)
  end select

  ! populate the data structure. Note:
  ! (1) The data for each variable stored in netcdf file have to be in the same order as the hru_ix and hru_id.
  ! (2) The index "hru_ix" is sequential over the entire model spatial domain, but not necessary sequential within a gru.
  do iGRU=1, nGRU
   hruCount=gru_struc(iGRU)%hruCount
   do iHRU=1, hruCount ! iHRU loop
    hru_ix=gru_struc(iGRU)%hru(iHRU)%hru_ix
   
    select case(jStruct)
     case(ixType);
      type_gru(iGRU)%hru(iHRU)%var(jVar)=buf_int_1d(hru_ix)
     case(ixAttr)
      attr_gru(iGRU)%hru(iHRU)%var(jVar)=buf_flt_1d(hru_ix)
    endselect
   enddo  ! end of iHRU loop
  enddo ! end of iGRU loop
    
 enddo ! end of iVar loop

 ! close the HRU_ATTRIBUTES netCDF file
 call check(nf90_close(ncid), message)

 ! **********************************************************************************************
 ! (4) deallocate space
 ! **********************************************************************************************
 deallocate(buf_int_1d, buf_flt_1d, stat=err)
 if(err/=0)then; err=20; message=trim(message)//'problem deallocating space'; return; endif

 ! test
 !  do iHRU=1,nHRU
 !   print*, '*****'
 !   print*, 'hruIndex       = ', type_hru(iHRU)%var(iLookTYPE%hruIndex)
 !   print*, 'latitude       = ', attr_hru(iHRU)%var(iLookATTR%latitude)
 !   print*, 'longitude      = ', attr_hru(iHRU)%var(iLookATTR%longitude)
 !   print*, 'elevation      = ', attr_hru(iHRU)%var(iLookATTR%elevation)
 !   print*, 'mHeight        = ', attr_hru(iHRU)%var(iLookATTR%mHeight)
 !   print*, 'vegTypeIndex   = ', type_hru(iHRU)%var(iLookTYPE%vegTypeIndex)
 !   print*, 'soilTypeIndex  = ', type_hru(iHRU)%var(iLookTYPE%soilTypeIndex)
 !   print*, 'slopeTypeIndex = ', type_hru(iHRU)%var(iLookTYPE%slopeTypeIndex)
 !  end do 
 !  pause


 end subroutine read_attrb


end module read_attrb_module
