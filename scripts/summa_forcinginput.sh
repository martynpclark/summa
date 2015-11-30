#!/bin/bash
#
#=======================================================================================
# Process netCDF-4 files with classic structure into netCDF-4 files with (nested) groups
# as summa forcing inputs
# Huan Wu
# 09-16-2015
#======================================================================================
#- Directory of input and output 

#inputpath='/home/huanwu/summa/fork/summa/setup_tools/input/hcdn/forcings/'
inputpath='/d3/mizukami/forcing_data/leap/maurer12k/hcdn/'
outputpath='/home/huanwu/summa/fork/summa/setup_tools/output/hcdn/forcings/'

#------------------------------------------------------------ 
# Create groups
#------------------------------------------------------------
# Input files as top level groups; group name = file name
#   - The input files are:
#       MAURER12K_Forcing.yyyy-mm.nc
#   - One file looks like:
#   dimensions:
#	  time = UNLIMITED ; // (744 currently)
#	  hru_id = 677 ;
#   variables:
#	  float ppt(time, hru_id) ;
#		ppt:units = "kg/m^2/s" ;
#		ppt:long_name = "Precipitation rate" ;
#		ppt:_FillValue = -999.f ;
# 	  float temp(time, hru_id) ;
#		temp:units = "K" ;
#		temp:long_name = "Air Temperature" ;
#		temp:_FillValue = -999.f ;
#	  float q(time, hru_id) ;
#		q:units = "kg/kg" ;
#		q:long_name = "Specific Humidity" ;
#		q:_FillValue = -999.f ;
#	  float press(time, hru_id) ;
#		press:units = "Pa" ;
#		press:long_name = "Surface pressure" ;
#		press:_FillValue = -999.f ;
#     ...
#------------------------------------------------------------         

for infile in ${inputpath}*.nc; do
  outname="${infile##*/}"         #get the filename without the path
  #outname=$(basename "$infile")
  oldgroupname="${outname%.*}"    #get the filename without extension

# Convert the input file with the original file as top level group; group name = file name
  ncecat --gag $infile ${outputpath}${outname}

#change the group name to summa standard name
  ncrename -g $oldgroupname,forcings_input ${outputpath}${outname}

#change dimension
#ncrename -d /forcings_input/hru_id,/forcings_input/hru ${outputpath}${outname}

#change variable names to be consistent to summa model code
  ncrename -v /forcings_input/ppt,pptrate ${outputpath}${outname}
  ncrename -v /forcings_input/sw,SWRadAtm ${outputpath}${outname}
  ncrename -v /forcings_input/lw,LWRadAtm ${outputpath}${outname}
  ncrename -v /forcings_input/temp,airtemp ${outputpath}${outname}
  ncrename -v /forcings_input/wnd,windspd ${outputpath}${outname}
  ncrename -v /forcings_input/press,airpres ${outputpath}${outname}
  ncrename -v /forcings_input/q,spechum ${outputpath}${outname}

#change global attribute
#  newAttr=`ncks -M -m ${outputpath}${outname} | grep -E -i "^time attribute [0-9]+: units" \
#		   | sed 's/days/hours/'| cut -d'=' -f 3 `
#  echo $newAttr

#change variable attributes
  ncrename -a ./forcings_input/pptrate:long_name,"precipitation rate" ${outputpath}${outname}
  ncrename -a ./forcings_input/SWRadAtm:long_name,"downward shortwave radiation at the upper boundary" ${outputpath}${outname}
  ncrename -a ./forcings_input/LWRadAtm:long_name,"downward longwave radiation at the upper boundary" ${outputpath}${outname}
  ncrename -a ./forcings_input/airtemp:long_name,"air temperature at the measurement height" ${outputpath}${outname}
  ncrename -a ./forcings_input/windspd:long_name,"wind speed at the measurement height" ${outputpath}${outname}
  ncrename -a ./forcings_input/airpres:long_name,"air pressure at the the measurement height" ${outputpath}${outname}
  ncrename -a ./forcings_input/spechum:long_name,"specific humidity at the measurement height" ${outputpath}${outname}

#add global attributes
  ncatted -h -a datasource,global,o,c,"Maurer2002" -a dataset_step,global,o,c,"1/24 day" ${outputpath}${outname}

#move some group variables to global variables
  ncks -A -G :1 -g forcings_input -v lat,lon,hru_id,time ${outputpath}${outname} ${outputpath}${outname}

#delete some variables in the group
  ncks -C -O -x -v /forcings_input/lat,/forcings_input/lon,/forcings_input/hru_id,/forcings_input/time \
   ${outputpath}${outname} ${outputpath}${outname} 

#delete those unneeded attributes (from global and group)
#the attributes have to be designated explicitly. The "left blank" for att_nm doesn't work (a little weird)
  ncatted -h -a projection,global,d,, ${outputpath}${outname}
  ncatted -h -a projection,group,d,, ${outputpath}${outname}
  ncatted -h -a 'matlab\ file',group,d,, ${outputpath}${outname}
  ncatted -h -a history,global,d,, ${outputpath}${outname}
  ncatted -h -a history_of_appended_files,global,d,, ${outputpath}${outname}

  echo "done ..."${outputpath}${outname}
   
done

