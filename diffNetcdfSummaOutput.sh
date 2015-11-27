#!/bin/bash

# ---------------------------------------------------------------------------------------
# Purpose:
# --------
# Compare the outputs (*.nc files) of the local SUMMA installation to the original (reference)
# outputs. This version uses "ncdiff" for file comparison.
#
# ---------------------------------------------------------------------------------------

# define the branch to test
branch=master

# define the original and new output directories
outputOrig=output_org
outputNew=output_$branch


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

			# monitor progress
			echo '**'
		    echo $typeTestCases $dirPaperOrFigure # print experiment to monitor progress

			# loop through desired variables
			for varname in  mLayerTemp \
							mLayerVolFracLiq \
							scalarSWE \
							scalarSenHeatTotal \
							scalarLatHeatTotal \
							scalarCanopyAbsorbedSolar \
							scalarGroundAbsorbedSolar \
							scalarCanopyLiq \
							scalarCanopyTemp \
							scalarSurfaceTemp
			do

				# difference the files
            	ncdiff -O -v $varname $file01 $file02 -o $tmpFile

				# check that the difference operation was successful
				if [ "$?" = "0" ]; then

					# get the maximum absolute value
					ncwa -O -y mabs $tmpFile $tmpFile # Maximum absolute value

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


