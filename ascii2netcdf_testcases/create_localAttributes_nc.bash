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

if [[ "$#" -ne 2 ]]; then
  echo "Wrong number of input arguments"
  echo "Should be: " "$0" "cdl_file (absolute path and file name to cdl file describing structure of netcdf file to be generated) testCases_path (path to setttings folder of summaTestCases)"
  exit
fi

cdl_file=$1
test_path=$2

cd ${test_path}
for cases in syntheticTestCases wrrPaperTestCases  
do
  cd ${cases}

  for example in *
#  for example in wigmosta*
  do
    echo ${cases}/${example}

    cd ${example}
    
    for att in summa_zLocalAttributes*.txt
    do 
      if [ "${cases}" = "wrrPaperTestCases" ]; then
        token="${att#summa_zLocalAttributes}"
        runtype="${token%.txt}"
      else
        runtype=""
      fi
      
      #create list of hrus
      awk '{if(substr($1,1,1) != "!" && substr($1,1,1) != "h") print $1}' < ${att} > hru_list.txt
      num_hru=`cat hru_list.txt | wc -l`
       

      #copy base cdl file and modify as necessary for hru dimension
      cp ${cdl_file} .
      awk '{nh="'${num_hru}'"; if($1=="nhru"){printf("        nhru = %s ;\n",nh)} else {print $0}}' < meta_zLocalAttributes.cdl > t.txt
      mv t.txt meta_zLocalAttributes.cdl

      #make netcdf file quick
      ncgen ./meta_zLocalAttributes.cdl -o summa_zLocalAttributes${runtype}.nc

      #populate gru index with one value for testing
      ncap2 -h -s 'gru_id(0)=1001' summa_zLocalAttributes${runtype}.nc -O summa_zLocalAttributes${runtype}.nc

      hcnt=0
      while read line
      do
        first_char="${line:0:1}"
        if [ ${first_char} = "h" ]; then
          cnt=0
	  for token in ${line}
	  do
	    
	    attrib[cnt]=${token}
            cnt=$(($cnt+1))
	  done

	fi
	
         if [[ "${first_char}" != "h" && "${first_char}" != "!" ]]; then
	  cnt=0
          for token in ${line}
          do
#            echo ${token} ${attrib[cnt]}
            if [ "${attrib[cnt]}" = "hruIndex" ]; then
              ncap2 -h -s 'hru_id('${hcnt}')='${token}'' summa_zLocalAttributes${runtype}.nc -O summa_zLocalAttributes${runtype}.nc
            else
              ncap2 -h -s ''${attrib[cnt]}'('${hcnt}')='${token}'' summa_zLocalAttributes${runtype}.nc -O summa_zLocalAttributes${runtype}.nc
            fi
	    cnt=$(($cnt+1))
	  done

	  ncap2 -h -s 'hru2gru_id('${hcnt}')=1001' summa_zLocalAttributes${runtype}.nc -O summa_zLocalAttributes${runtype}.nc

	  hcnt=$(($hcnt+1))
        fi

      done < ${att}

    done  #end of localAttributes loop

    #clean up a bit
#    rm hru_list.txt
#    rm meta_zLocalAttributes.cdl
    cd ../
  done    #end of example loop
  cd ../
done      #end of test cases loop

