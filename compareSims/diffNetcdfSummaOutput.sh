#!/bin/bash

# ---------------------------------------------------------------------------------------
# Purpose:
# --------
# Compare the outputs (*.nc files) of the local SUMMA installation to the original (reference)
# outputs. This version uses "ncdiff" for file comparison.
#
# History: Extension to script compareNetcdfSummaOutput.sh, which uses nccmp.
#
# Notes:
#  (1) It is assumed that the script is run within a summaTestCases directory
#        (e.g., hydro-c1:~/check/summaTestCases> ~/summa_tools/compareSims/diffNetcdfSummaOutput.sh)
#  (2) It is assumed that SUMMA has already run for the specified branch, and the output
#        is in the sub-directory of the summaTestCases directory named output_$branch.

# ---------------------------------------------------------------------------------------
# user-configurable component

# define the branch to test
branchName=feature/refactorNumerix
#branchName=develop

# define the type of test ("correlate" or "machinePrecision")
checkFile=correlate
#checkFile=machinePrecision

# ---------------------------------------------------------------------------------------

# replace the slash (/) with an underscore
branch=${branchName//\//_}

# define the original and new output directories
outputOrig=output_feature_improveConv
outputNew=output_$branch
echo $outputNew

# define the temporary file
tmpFile=temp.nc

# define a file for the standard output
junkFile=junk.txt

# define directory where all test cases reside
pathToSummaTestCases=`pwd` # assumes that the present directory is summaTestCases

# loop through the directories
for typeTestCases in syntheticTestCases wrrPaperTestCases; do # loop through the two types of test cases
  for dirPaperOrFigure in `ls $pathToSummaTestCases/$outputOrig/$typeTestCases/`; do # loop through the different papers or figures
    for pathToNetcdfFile in `ls $pathToSummaTestCases/$outputOrig/$typeTestCases/$dirPaperOrFigure/*.nc `; do # loop thourgh the *.nc files

      # define the files to compare
      filename=$(basename $pathToNetcdfFile) # extract file name

      # get the files from the different directories
      file01=$pathToSummaTestCases/$outputOrig/$typeTestCases/$dirPaperOrFigure/$filename
      file02=$pathToSummaTestCases/$outputNew/$typeTestCases/$dirPaperOrFigure/$filename
      echo '**'
      echo $file01
      echo $file02

      # check if if the original output exists
      if [ ! -f $file01 ]; then
        echo "File $file01 does not exist."
        exit 1
      fi

      # check if if the new output exists
      if [ ! -f $file02 ]; then
        echo "File $file02 does not exist."
        exit 1
      fi

      # monitor progress
      echo $typeTestCases $dirPaperOrFigure $filename # print experiment to monitor progress

      # loop through desired variables
      for varname in \
        scalarCanopyTemp \
        scalarCanopyLiq \
        scalarCanopyAbsorbedSolar \
        scalarGroundAbsorbedSolar \
        scalarSenHeatTotal \
        scalarLatHeatTotal \
        scalarSWE \
        scalarSurfaceTemp
        do

        # **************************************************
        # * check correlation...
        # **************************************************

        # case 1: basic similarity
        if [ "$checkFile" == "correlate" ]; then

          # don't do synthetic test cases
          if [ "$typeTestCases" == "syntheticTestCases" ]; then
            continue
          fi

          # define variable names
          varname1=${varname}_var1
          varname2=${varname}_var2

          # define the stat name
          statName=rPearson

          # extract a variable from file 01
          ncks -O -v $varname $file01 $tmpFile
          ncrename -O -v ${varname},${varname1} $tmpFile $tmpFile > $junkFile

          # extract a variable from file 02
          ncks -A -v $varname $file02 $tmpFile
          ncrename -O -v ${varname},${varname2} $tmpFile $tmpFile > $junkFile

          # compute the variance 
          ncap2 -O -s 'variance1=gsl_stats_variance('${varname1}',1,$time.size)' $tmpFile $tmpFile
          ncap2 -O -s 'variance2=gsl_stats_variance('${varname2}',1,$time.size)' $tmpFile $tmpFile

          # extract the variance for the 1st variable 
          varString=`ncks -C -u -v variance1 $tmpFile | grep variance1 | tail -1`
          IFS='=' read -a strTemp <<< "${varString}"  # IFS=internal field separator
          variance1=$(printf "%5.4g" ${strTemp[1]})    # convert the second value in the string array (position 1) to a float

          # extract the variance for the 2nd variable 
          varString=`ncks -C -u -v variance2 $tmpFile | grep variance2 | tail -1`
          IFS='=' read -a strTemp <<< "${varString}"  # IFS=internal field separator
          variance2=$(printf "%5.4g" ${strTemp[1]})    # convert the second value in the string array (position 1) to a float

          # compute the correlation
          ncap2 -O -s 'covariance=gsl_stats_covariance('${varname1}',1,$time.size,'${varname2}',1,$time.size)' $tmpFile $tmpFile
          ncap2 -O -s ${statName}'=covariance/(sqrt(variance1)*sqrt(variance2))' $tmpFile $tmpFile

          # extract the correlation
          varString=`ncks -C -u -v $statName $tmpFile | grep $statName | tail -1`
        
          # convert the string to a floating point number
          IFS='=' read -a strTemp <<< "${varString}"  # IFS=internal field separator
          varValue=$(printf "%5.3f" ${strTemp[1]})  # convert the second value in the string array (position 1) to a float

          # check that the value is within some precision
          if [ "$varValue" == "1.000" ]; then  # note the comparison string has the same length as above
            message=ok
          else
          echo variance for 1st variable = $variance1
          echo variance for 2nd variable = $variance2
          message=FAILURE
          fi

          # remove temporary and junk files
          rm $tmpFile
          rm $junkFile

          # print progress
          echo $message $varname $varString

        fi  # checking correlation

        # **************************************************
        # * check machine precision...
        # **************************************************

        # case 2: machine precision
        if [ "$checkFile" == "machinePrecision" ]; then
		
          # difference the variables in the two files
          ncdiff -O -v $varname $file01 $file02 -o $tmpFile 2> errors.log

          # check that the difference operation was successful
          # NOTE: the difference operation fails if the desired variables are not present in the model output file
          if [ "$?" = "0" ]; then

            # get the maximum absolute value
            # NOTE: more modern verions of ncwa have mabs (maximum absolute value) but not opn hydro-c1 yet
            ncap2 -O -s $varname'=fabs('$varname')' $tmpFile $tmpFile  # the absolute value
            ncwa -O -y max $tmpFile $tmpFile # maximum

            # get the data string
            varString=`ncks -C -u -v $varname $tmpFile | grep $varname | tail -1`

            # convert the string to a floating point number
            IFS='=' read -a strTemp <<< "${varString}"  # IFS=internal field separator
            varValue=$(printf "%17.15f" ${strTemp[1]})  # convert the second value in the string array (position 1) to a float

            # check that the value is within some precision
            if [ "$varValue" == "0.000000000000000" ]; then  # note the comparison string has the same length as above
              message=ok
            else
              message=FAILURE
            fi

            # print progress
            echo $message $varString

            # remove temporary file
            rm $tmpFile

          else
            echo $varname 'is missing'
          fi  # if the difference operation was successful

        fi  # if machine precision

      done  # looping through variables
    done  # looping through output files for a given experiment
  done  # looping through experiments
done  # looping through experiment types


