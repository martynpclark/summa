#!/bin/bash

# ---------------------------------------------------------------------------------------
# Purpose:
# --------
# Compare the outputs (*.nc files) of the local SUMMA installation to the original (reference)
# outputs. This version uses "nccmp" for file comparison. "nccmp" is silent when files are 
# equivalent and displays an error message otherwise.
#
# Note:
# --------
# According to Tor Mohling, "nccmp" relies on "nc.h", a private file that should not be used
# by 3rd-part developers (like "nccmp"). We might want to consider alternatives to "nccmp", 
# for instance to use NCO, NCL or CDO.
# ---------------------------------------------------------------------------------------

pathToSummaTestCases=`pwd` # assumes that the present directory is summaTestCases

for typeTestCases in syntheticTestCases wrrPaperTestCases; do # loop through the two types of test cases

    for dirPaperOrFigure in `ls $pathToSummaTestCases/output/$typeTestCases/`; do # loop through the different papers or figures

		for pathToNetcdfFile in `ls $pathToSummaTestCases/output/$typeTestCases/$dirPaperOrFigure/*.nc `; do # loop thourgh the *.nc files

		    filename=$(basename $pathToNetcdfFile) # extract file name

		    echo $typeTestCases $dirPaperOrFigure $filename # print current file to monitor progress

		    # compare metadata (-m) and data (-d) and check that absolute (-t) differences are smaller than 1E-15

		    nccmp -md -t 1e-15 $pathToSummaTestCases/output/$typeTestCases/$dirPaperOrFigure/$filename \
		    $pathToSummaTestCases/output_org/$typeTestCases/$dirPaperOrFigure/$filename 

		done
    done
done


