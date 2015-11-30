
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

! "setup_summa_forcings" is used to convert forcing data to NetCDF4 for
! SUMMA main software
! By Huan Wu  08/18/2015

!Modifed by Andy Newman (NCAR/RAL/HAP)  11/19/15
!Fixed issues:
!  1) doesn't start on the start date specified in cdl file   -> FIXED
!  2) can't handle ascii forcing data files that don't start on the 0th hour  -> IN PROGRESS
!  3) Inefficient reads of ascii files
!  4) Needs to include time information in netcdf forcing files

program setup_summa_forcings
  use netcdf						!netcdf functions
  USE nrtype						!variable types, etc.
  USE time_utils_module,only:extractTime,compJulday	!time utilities

  implicit none

  ! to hold the dataset time period definition from the input CDL file
  integer(I4B) :: dataset_startyear, dataset_startmonth, dataset_startday, dataset_starthour, dataset_startmin, dataset_startsec
  !integer :: dataset_endyear, dataset_endmonth, dataset_endday, dataset_endhour, dataset_endmin
  integer(I4B) :: step_currentyear, step_currentmonth, step_currentday, step_currenthour, step_currentmin, step_currentsec, timestep

  ! integer variables for NetCDF IDs
  integer(I4B) :: ncid, nVariables, nAttributes, unlimitedDimId, formatNum
  integer(I4B) :: pptrate_varid, SWRadAtm_varid, LWRadAtm_varid, airtemp_varid, windspd_varid, airpres_varid, spechum_varid 
  integer(I4B) :: hruDimID, grpid, hru_varid,time_varid

  ! the number for dimensions defined in CDL file
  integer(I4B) :: ndims, nhrus, nrecs

  integer(I4B) 			:: err			!error status
  character(len=2000)		:: message             ! error message
  character(len=256)            :: cmessage         ! error message for downwind routine
  
  ! define the variables to hold the sttributes of the dataset
  character (120) :: data_orig_path      !The original forcing data path
  character (120) :: data_out_path       !The out forcing data path
  character (255) :: infile              !The original forcing data file name
  character (25)  :: str_hru, str_time   !for converstion of hru index to string
  character (256) :: outfile             !output NetCDF file for the forcing data
  character (30)  :: ref_time		 !string for time units from CDL file

  ! The start and count arrays will tell the netCDF library where to write the data.
  integer, allocatable :: start(:), count(:)
 
  ! forcing variable arrays will be filled by the source data
  real(SP), allocatable :: pptrate(:), SWRadAtm(:), LWRadAtm(:), airtemp(:), windspd(:), airpres(:), spechum(:)
  integer(I4B), allocatable :: hru_ix(:)  ! array of hru_ix, ie, sequential hru index defined by GRU/HRU mask file 
  integer(I4B), allocatable :: hru_id(:)  ! hru_id corresponding to a hru_ix

  integer(8), allocatable :: file_pos(:)	!file position of ascii file


  integer(I4B) :: i,j,irec		!counter variables
  integer(I4B) :: step		!step counter for noting 24-hr periods

  logical :: write_flag = .false.

  integer(I4B) :: ascii_year, ascii_month, ascii_day, ascii_hour, ascii_min,ascii_sec	!ascii time variables
  integer(I4B) :: ref_year,ref_month,ref_day,ref_hour,ref_min,ref_sec	!reference time for time variable

  real(DP)	:: ref_julday							!reference julian day (fraction)
  real(DP)	:: step_julday							!current time step julian day (fraction)
  real(DP)	:: diff_julday							!difference of current and reference julian day (fraction)

  character*255 command
 
  ! Start procedure here
  err=0; message="setup_summa_forcings/"



  ! Step (1): Using the user defined CDL file to create a NetCDF file, from which all meta data info will be loaded
  !Convert the CDL file `meta_Forcings.cdl' to a temporal netCDF file using ncgen

  write(command, *) 'ncgen -o ', 'temp.nc', ' meta_forcing_in_riparianAspenPP.cdl'
  call system(command)
  
  call check( nf90_open("temp.nc", NF90_NOWRITE, ncid) )

  !Get the number of dimensions, variables, attributes etc for NetCDF file
  call check( nf90_inquire( ncid, ndims, nVariables, nAttributes, &
          unlimitedDimId, formatNum) )
 
  call check( nf90_inq_dimid(ncid, "hru_ix", hruDimID) )
  call check( nf90_inquire_dimension( ncid,hruDimID,len=nhrus ) )
  call check( nf90_inq_varid(ncid, "hru_ix",hru_varid) )

  allocate ( hru_ix(nhrus) )
  allocate ( hru_id(nhrus) )
  allocate ( pptrate(nhrus) )
  allocate ( SWRadAtm(nhrus) )
  allocate ( LWRadAtm(nhrus) )
  allocate ( airtemp(nhrus) )
  allocate ( windspd(nhrus) )
  allocate ( airpres(nhrus) )
  allocate ( spechum(nhrus) )

  allocate ( start(ndims) )
  allocate ( count(ndims) )

  allocate ( file_pos(nhrus) )
  file_pos = 0

  ! Get the group id
  call check(nf90_inq_grp_ncid(ncid, "forcings_input", grpid)) 
  
  ! Get dataset time period information from the CDL global attributes
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_startyear", dataset_startyear) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_startmonth", dataset_startmonth) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_startday", dataset_startday) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_starthour", dataset_starthour) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_startmin", dataset_startmin) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_startsec", dataset_startsec) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_totalrecords", nrecs) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "data_step", timestep) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_out_path", data_out_path) )
  call check( nf90_get_att(grpid, NF90_GLOBAL, "dataset_orig_path", data_orig_path) )

  !get time units from CDL file
  call check( nf90_inq_varid(ncid, "time",time_varid) )
  call check( nf90_get_att(ncid,time_varid,"units",ref_time) )

print *,ref_time

  !break down into integers
  call extractTime(ref_time,    & ! input  = units string for time data
                   ref_year,           & ! output = year
                   ref_month,             & ! output = month
                   ref_day,             & ! output = day
                   ref_hour,             & ! output = hour
                   ref_min,ref_sec,      & ! output = minute/second
                   err,cmessage)                            ! output = error code and error message
  if(err/=0)then; message=trim(message)//trim(cmessage); print *,message; call EXIT(err); endif

  !calculate julian day of reference date
  call compjulday(ref_year,            & ! input  = year
                  ref_month,              & ! input  = month
                  ref_day,              & ! input  = day
                  ref_hour,              & ! input  = hour
                  ref_min,ref_sec,       & ! input  = minute/second
                  ref_julday,err,cmessage)                   ! output = julian day (fraction of day) + error control
  if(err/=0)then; message=trim(message)//trim(cmessage); print *,message; call EXIT(err); endif
 

  ! delete the temporary nc file 
  call check( nf90_close(ncid) )
  write (command,*) 'rm temp.nc'
  call system(command)

  !create hru ids and indexes
  do i=1, nhrus
    hru_ix(i) = i
    hru_id(i) = 1000 + i   ! creat the hru id for the summa test case
  end do

  ! The main loop over time
  step=1  ! used to control the data file time interval 

  do irec=1, nrecs !loop of the time

    count = (/ nhrus, 1 /)
    start = (/ 1, step/)
    !read the forcing data from data source
    !This case is from summa preprocessed hru based ascii files
    do j=1, nhrus !loop of all hru based files

      !build indivudal hru-based forcing file names
      if(irec .eq. 1) then
	write(str_hru,"('hru',I4.4)") hru_id(j)
	!write(str_hru,"(I4.4,'_forcings.txt')") j
	infile = trim(data_orig_path)//"RME_forcing_"//trim(str_hru)//".txt"
	print *, infile
  
	open(j+24,file=infile,status="old", action="read")
      end if

      !read the current line of the current hru-based forcing source data file in ascii format
      read(j+24, *) ascii_year,ascii_month,ascii_day,ascii_hour,ascii_min,ascii_sec, pptrate(j), & 
		      SWRadAtm(j), LWRadAtm(j), airtemp(j), windspd(j), airpres(j),spechum(j) 

      step_currentyear  = ascii_year
      step_currentmonth = ascii_month
      step_currentday   = ascii_day
      step_currenthour  = ascii_hour
      step_currentmin   = ascii_min
      step_currentsec   = ascii_sec

      !calc julian day and difference from ref time of current time step
      call compjulday(ascii_year,            & ! input  = year
		      ascii_month,              & ! input  = month
		      ascii_day,              & ! input  = day
		      ascii_hour,              & ! input  = hour
		      ascii_min,ascii_sec,       & ! input  = minute/second
		      step_julday,err,cmessage)                   ! output = julian day (fraction of day) + error control
      if(err/=0)then; message=trim(message)//trim(cmessage); print *,message; call EXIT(err); endif

      diff_julday = step_julday - ref_julday

!	inquire(unit=j+24,POS=file_pos(j))

      !print  *, 'the value:',j, int_t, int_t, int_t, int_t, int_t,real_t, pptrate(j), SWRadAtm(j), LWRadAtm(j), &
	!  airtemp(j), windspd(j), airpres(j),spechum(j)
      if(irec .eq. nrecs) then
	close(j+24)
      end if

    end do !loop of all hru based files

    
    if(dataset_startyear .eq. step_currentyear .and. dataset_startmonth .eq. step_currentmonth .and. &
       dataset_startday .eq. step_currentday .and. dataset_starthour .eq. step_currenthour) then
      write_flag = .true.
    end if

    if(write_flag) then

      !Step (2): Read in the data from the data source according to information in metadata
      !build the outfile names
      if(step==1) then 
	write(str_time,"(I4.4,I2.2,I2.2,I2.2,I2.2)" ) step_currentyear, step_currentmonth, step_currentday, &
	  step_currenthour, step_currentmin

	outfile = trim(data_out_path)//"forcings_"//trim(str_time)//".nc"
	print *, outfile
	
	write(command, *) 'ncgen -o ', trim(outfile), ' meta_forcing_in_riparianAspenPP.cdl'
	print *, command
	call system(command)
	
	call check( nf90_open(outfile, NF90_WRITE, ncid) )

	!Write the HRU cordinate variable data
	call check( nf90_inq_varid(ncid, "hru_ix",hru_varid) )
	    call check( nf90_put_var(ncid,hru_varid,hru_ix) )

	call check( nf90_inq_varid(ncid, "hru_id",hru_varid) )
	    call check( nf90_put_var(ncid,hru_varid,hru_id) )

	call check(nf90_inq_grp_ncid(ncid, "forcings_input", grpid)) 
	    !call check(nf90_inquire_dimension(grpid,hruDimID,len=nHRUs))

	!Get the variable IDs 
	!call check( nf90_inq_varid(ncid, "hru_id",hru_varid) )
	call check( nf90_inq_varid(grpid, "pptrate",pptrate_varid) )
	call check( nf90_inq_varid(grpid, "SWRadAtm",SWRadAtm_varid) )
	call check( nf90_inq_varid(grpid, "LWRadAtm",LWRadAtm_varid) )
	call check( nf90_inq_varid(grpid, "airtemp",airtemp_varid) )
	call check( nf90_inq_varid(grpid, "windspd", windspd_varid) )
	call check( nf90_inq_varid(grpid, "airpres",airpres_varid) )
	call check( nf90_inq_varid(grpid, "spechum",spechum_varid) )
      end if


      !Step (3) Write the data into "summa_forcings.nc", according to the metadata in 'meta_Forcings.cdl'
      call check( nf90_put_var(grpid, pptrate_varid, pptrate, start = start, count = count) )
      call check( nf90_put_var(grpid, SWRadAtm_varid, SWRadAtm, start = start, count = count) )
      call check( nf90_put_var(grpid, LWRadAtm_varid, LWRadAtm, start = start, count = count) )
      call check( nf90_put_var(grpid, airtemp_varid, airtemp, start = start, count = count) )
      call check( nf90_put_var(grpid, windspd_varid, windspd, start = start, count = count) )
      call check( nf90_put_var(grpid, airpres_varid, airpres, start = start, count = count) )
      call check( nf90_put_var(grpid, spechum_varid, spechum, start = start, count = count) )

      !time 
      call check( nf90_put_var(ncid, time_varid, diff_julday, start=(/step/)) )
      
      ! Close the file. This causes netCDF to flush all buffers.
      if(step==24) then ! packing hourly data into 24-step daily file
	call check( nf90_close(ncid) )
	step=0 
	    print *,"*** SUCCESS writing data file ", outfile, "!"
      end if
      step=step+1  
    end if
  
    
    call nexttimestep(step_currentyear,step_currentmonth, step_currentday, step_currenthour, step_currentmin,step_currentsec, timestep)

  end do !loop of the time
 

  deallocate(pptrate)
  deallocate(SWRadAtm)
  deallocate(LWRadAtm)
  deallocate(airtemp)
  deallocate(windspd)
  deallocate(airpres)
  deallocate(spechum)
  
  deallocate(start)
  deallocate(count)

contains

  ! Given the current time and timestep, to get the next time stamp
  subroutine nexttimestep(step_currentyear,step_currentmonth, step_currentday, &
     step_currenthour, step_currentmin, step_currentsec, timestep)
     implicit none
     integer, intent(inout) :: step_currentyear, step_currentmonth, step_currentday, &
         step_currenthour, step_currentmin, step_currentsec
     integer, intent(in) :: timestep ! in seconds
     integer :: leap
     integer :: month(12)
     month = (/31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31/)
     leap=0

    step_currentsec = step_currentsec + timestep
    if(step_currentsec>=60) then
     step_currentmin = step_currentmin + INT(step_currentsec/60)
     step_currentsec = mod(step_currentsec,60)
    endif 

     if(step_currentmin>=60) then
       step_currenthour= step_currenthour + INT(step_currentmin/60)
       step_currentmin = mod(step_currentmin, 60) 
     endif

     if(step_currenthour>=24) then
       step_currentday = step_currentday + INT(step_currenthour/24)
       step_currenthour = mod(step_currenthour,24)
     endif

     if( mod(step_currentyear,4) ==0  .and.  &
        mod(step_currentyear,100) /=0 .or.    &
        mod(step_currentyear,400) ==0 ) then
        leap =1
     endif

     if (leap ==1) then
        month(2) = 29
     endif
     
     if(step_currentday > month(step_currentmonth) ) then
       step_currentday= 1
       step_currentmonth=step_currentmonth+1
     endif 

     if(step_currentmonth>12) then
       step_currentmonth= 1
       step_currentyear= step_currentyear + 1
     endif

  end subroutine nexttimestep

  subroutine check(status)
    integer, intent ( in) :: status
    
    if(status /= nf90_noerr) then 
      print *, trim(nf90_strerror(status))
      stop "Stopped"
    end if
  end subroutine check
  
end program setup_summa_forcings
