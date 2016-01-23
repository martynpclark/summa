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
#        (e.g., hydro-c1:~/check/summaTestCases> ~/summa_tools/diffNetcdfSummaOutput.sh)
#  (2) It is assumed that SUMMA has already run for the specified branch, and the output
#        is in the sub-directory of the summaTestCases directory named output_$branch.

# ---------------------------------------------------------------------------------------
# user-configurable component

# define the branch to test
branchName=feature/numericalSolution

# ---------------------------------------------------------------------------------------

# replace the slash (/) with an underscore
branch=${branchName//\//_}

# define the original and new output directories
outputOrig=output_org
outputNew=output_$branch
echo $outputNew

# define the temporary file
tmpFile=temp.nc

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
      echo '**'
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
        mLayerTemp \
        mLayerVolFracLiq \
        scalarSurfaceTemp
        do

        # difference the files
        ncdiff -O -v $varname $file01 $file02 -o $tmpFile

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

      done  # looping through variables
    done  # looping through output files for a given experiment
  done  # looping through experiments
done  # looping through experiment types


