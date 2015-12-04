#!/bin/bash -u

#################################
#
#  Initial script to loop through SUMMA test cases
#  and create base gru-hru mapping file for SUMMA netcdf capability
#  from the orginal summa_zLocalAttributes text files
#
#  Author: Andy Newman NCAR/RAL/HAP
#          12/3/2015
#
###################################

if [[ "$#" -ne 1 ]]; then
  echo "Wrong number of input arguments"
  echo "Should be: " "$0" "cdl_path (path to base cdl file describing structure of netcdf file to be generated)"
  exit
fi
#cdl_path=/home/anewman/summa_tools/ascii2netcdf_testcases/cdl
cdl_path=$1


for cases in syntheticTestCases #wrrPaperTestCases
do
  cd ${cases}

  for example in *
#  for example in wi*
  do
    echo ${cases}/${example}

    cd ${example}
     
    #create list of hrus
    awk '{if(substr($1,1,1) != "!" && substr($1,1,1) != "h") print $1}' < summa_zLocalAttributes.txt > hru_list.txt
    num_hru=`cat hru_list.txt | wc -l`

    #copy base cdl file and modify as necessary for hru dimension
    cp ${cdl_path}/meta_gru_hru_map.cdl .
    awk '{nh="'${num_hru}'"; if($1=="hru_dim"){printf("        hru_dim = %s ;\n",nh)} else {print $0}}' < meta_gru_hru_map.cdl > t.txt
    mv t.txt meta_gru_hru_map.cdl

    #make netcdf file quick
    ncgen ./meta_gru_hru_map.cdl -o ${example}_gru_hru_map.nc

    #populate gru dimension with 1
    ncap2 -h -s 'gru_ix(0)=1' ${example}_gru_hru_map.nc -O ${example}_gru_hru_map.nc

    ncap2 -h -s 'hruCount(0)='$num_hru'' ${example}_gru_hru_map.nc -O ${example}_gru_hru_map.nc

    cnt=0
    while read hru
    do
      ncap2 -h -s 'hru_id('${cnt}')='${hru}'' ${example}_gru_hru_map.nc -O ${example}_gru_hru_map.nc
      ncap2 -h -s 'hru_ix('${cnt}')='$((${cnt}+1))'' ${example}_gru_hru_map.nc -O ${example}_gru_hru_map.nc
      cnt=$(($cnt+1))
    done < hru_list.txt
  
    #clean up a bit
    rm hru_list.txt
    rm meta_gru_hru_map.cdl
    cd ../
  done
  cd ../
done