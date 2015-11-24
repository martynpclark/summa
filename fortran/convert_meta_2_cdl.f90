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

program read_metad
!USE nrtype
implicit none

character(LEN=256)               :: infile="./summa_zBasinModelVarMeta.txt"         ! input filename

call convert_metadata(infile)


contains



 ! ********************************************************************************************************
 ! private subroutine v_metadata: read metadata from a file and populate the appropriate metadata structure
 ! ********************************************************************************************************
 subroutine convert_metadata(infile)
 implicit none
 ! define input
 character(LEN=256),intent(in)              :: infile         ! input filename
 integer                         :: iline          ! loop through lines in the file
 integer,parameter               :: maxLines=1000  ! maximum lines in the file
 character(LEN=256)                   :: temp           ! single lime of information
 integer                        :: iend           ! check for the end of the file
 character(LEN=256)                   :: ffmt           ! file format
 character(len=1)                     :: dLim(4)        ! column delimiter
 character(len=64)                    :: varname=''        ! column delimiter
 character(len=128)                     :: varlongname=''       ! column delimiter
 character(len=64)                     :: varunit=''        ! column delimiter
 character(len=32)                     :: vartype=''       ! column delimiter
 logical                     :: varwrite=.FALSE.       ! column delimiter
 integer                         :: ivar           ! index of model variable
 ! Start procedure here
 ! open file
 open(10,file=trim(infile),status="old",action="read")
 open (unit=20,file='./test.asc',action="write",status="replace")
 
 ! get to the start of the variable descriptions
 do iline=1,maxLines
  read(10,'(a)',iostat=iend)temp; if (iend/=0)exit    ! read line of data
  if (temp(1:1)/='!') exit  ! assume first line not comment is format code
 end do ! looping through file to find the format code
 ! read in format string
 read(temp,*)ffmt
 ! loop through the lines in the file
 do iline=1,maxLines
  ! read a line of data and exit iif an error code (character read, so only possible error is end of file)
  read(10,'(a)',iostat=iend)temp; if (iend/=0)exit
  ! check that the line is not a comment
  if (temp(1:1)=='!')cycle
  ! save data into a temporary structure
  read(temp,trim(ffmt),iostat=iend) varname,dLim(1),varlongname,dLim(2),varunit,dLim(3),&
                                   vartype,dLim(4),varwrite
  if (iend/=0)exit

  write (20,150) trim(varname)
150 format(4x,'double ',a,'(hru_id);')
  write (20, 160) trim(varname), trim(varlongname)
160 format(8x,a,':long_name = ','"',a,'" ;')
  write (20, 170) trim(varname), trim(varunit)
170 format(8x,a,':units = ','"',a,'" ;')
  write (20, 180) trim(varname), trim(vartype)
180 format(8x,a,':v_type = ','"',a,'" ;')

  ! identify the index of the named variable
 enddo  ! looping through lines in the file
  
 write(*,*) "done the conversion!!"
 
close(10)
close(20)
 end subroutine convert_metadata


end program read_metad
