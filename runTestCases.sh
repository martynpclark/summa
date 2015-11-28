#!/bin/bash

# Used to run the test cases for SUMMA

# There are two classes of test cases:
#  1) Test cases based on synthetic/lab data; and
#  2) Test cases based on field data.

# The commands assume that you are in the directory {localInstallation}/settings/
# and that the control files are in {localInstallation}/settings/

# =================================================================================================
# User-configurable component

# Define the number of processors
nProcessors=20

# Define the summa instance (core directory where summa is installed)
summaPath=/home/mclark/check/origin/summa

# Define the experiment (e.g., the name of the current branch)
expName=feature/metadata

# end of user-configuable component
# =================================================================================================

# check the summa path is provided
if  [ -z ${summaPath} ]; then
 echo "Must define the path to the SUMMA executable in $0"
 exit 1
fi

# define the current directory
currentDir=`pwd`

# change directory to the summa installation and check out the desired branch
cd $summaPath/build
git checkout $expName

# compile
make 2> make.log

# change back to the current directory
cd $currentDir

# define an experiment descriptor (get rid of the "/" in the branch name, if one exists)
expDesc=${expName//\//_}

# define new settings and output directories
settingsNew='settings_'${expDesc}
outputNew='output_'${expDesc}

# Define the summa executable
SUMMA_EXE=${summaPath}/bin/summa_${expDesc}.exe

# Copy the executable
cp ${summaPath}/bin/summa.exe ${SUMMA_EXE}

# create a new copy of the settings directory
mkdir -p $settingsNew
cp -rp settings/* $settingsNew

# make the output directory
mkdir -p $outputNew

# create a directory for some log files
mkdir -p ${outputNew}/log

# create the paths for the output files
mkdir -p ${outputNew}/syntheticTestCases/celia1990
mkdir -p ${outputNew}/syntheticTestCases/miller1998
mkdir -p ${outputNew}/syntheticTestCases/mizoguchi1990
mkdir -p ${outputNew}/syntheticTestCases/wigmosta1999
mkdir -p ${outputNew}/wrrPaperTestCases/figure01
mkdir -p ${outputNew}/wrrPaperTestCases/figure02
mkdir -p ${outputNew}/wrrPaperTestCases/figure03
mkdir -p ${outputNew}/wrrPaperTestCases/figure04
mkdir -p ${outputNew}/wrrPaperTestCases/figure05
mkdir -p ${outputNew}/wrrPaperTestCases/figure06
mkdir -p ${outputNew}/wrrPaperTestCases/figure07
mkdir -p ${outputNew}/wrrPaperTestCases/figure08
mkdir -p ${outputNew}/wrrPaperTestCases/figure09

# modify the paths in the settings files
for file in `grep -l '/output/' -R ${settingsNew}`; do
 sed "s|/settings/|/${settingsNew}/|" $file > junk
 sed "s|/output/|/${outputNew}/|" junk > $file
 rm junk
done

# *************************************************************************************************
# *************************************************************************************************
# *************************************************************************************************
# define a function to call summa
runSumma ()
{	

# define what the arguments mean
exeName=$1         # name of executable
uniqueID=$2        # unique identifier
runName=$3         # name of experiment
fileManager=$4     # name of the fileManager file
logFile=$5         # name of the log file

echo '* running experiment ' $uniqueID

# make a control file
ctlFile=summa.${uniqueID}.control
touch $ctlFile

# run the model
$exeName $runName $fileManager > $logFile

# remove the control file
rm $ctlFile

}

# *************************************************************************************************
# * PART 1: TEST CASES BASED ON SYNTHETIC OR LAB DATA

# loop through experiments
for ix in `seq -w 1 7`; do

 # define experiment name
 exp=s${ix}

 # Synthetic test case 1: Simulations from Celia (WRR 1990)
 if [ "$ix" = 1 ]; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/celia1990/summa_fileManager_celia1990.txt ${outputNew}/log/${exp}.log & fi

 # Synthetic test case 2: Simulations from Miller (WRR 1998)
 if [ "$ix" = 2 ] ; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/miller1998/summa_fileManager_millerClay.txt ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 3 ] ; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/miller1998/summa_fileManager_millerLoam.txt ${outputNew}/log/${exp}b.log & fi
 if [ "$ix" = 4 ] ; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/miller1998/summa_fileManager_millerSand.txt ${outputNew}/log/${exp}c.log & fi

 # Synthetic test case 3: Simulations of the lab experiment of Mizoguchi (1990) as described by Hansson et al. (VZJ 2005)
 if [ "$ix" = 5 ] ; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/mizoguchi1990/summa_fileManager_mizoguchi.txt ${outputNew}/log/${exp}.log & fi

 # Synthetic test case 4: Simulations of rain on a sloping hillslope from Wigmosta (WRR 1999)
 if [ "$ix" = 6 ]; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/wigmosta1999/summa_fileManager-exp1.txt ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 7 ]; then runSumma ${SUMMA_EXE} ${exp} _testSumma ${settingsNew}/syntheticTestCases/wigmosta1999/summa_fileManager-exp2.txt ${outputNew}/log/${exp}b.log & fi

 # sleep awhile, to ensure not rapidly executing programs before we realized it
 sleep 1

 # sleep if using the desired number of processors
 while [ `ls -1 summa.*.control | wc -l` -ge $nProcessors ]; do
  sleep 5
 done  # check if using the number of processors

done  # End of test cases based on synthetic/lab data
# *************************************************************************************************


# *************************************************************************************************
# * PART 2: TEST CASES BASED ON FIELD DATA, AS DESCRIBED BY CLARK ET AL. (WRR 2015B)

# loop through experiments
for ix in `seq -w 1 22`; do

 # define experiment name
 exp=f${ix}

 # Figure 1: Radiation transmission through an Aspen stand, Reynolds Mountain East
 if [ "$ix" = 01 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenBeersLaw        ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenBeersLaw.txt  ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 02 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenNLscatter       ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenNLscatter.txt ${outputNew}/log/${exp}b.log & fi
 if [ "$ix" = 03 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenUEB2stream      ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenUEB2stream.txt ${outputNew}/log/${exp}c.log & fi
 if [ "$ix" = 04 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenCLM2stream      ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenCLM2stream.txt ${outputNew}/log/${exp}d.log & fi
 if [ "$ix" = 05 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenVegParamPerturb ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenVegParamPerturb.txt ${outputNew}/log/${exp}e.log & fi

 # Figure 2: Wind attenuation through an Aspen stand, Reynolds Mountain East
 if [ "$ix" = 06 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenWindParamPerturb ${settingsNew}/wrrPaperTestCases/figure02/summa_fileManager_riparianAspenWindParamPerturb.txt ${outputNew}/log/${exp}.log & fi

 # Figure 3: Impacts of canopy wind profile on surface fluxes, surface temperature, and snow melt (Aspen stand, Reynolds Mountain East)
 if [ "$ix" = 07 ]; then runSumma ${SUMMA_EXE} ${exp} _riparianAspenExpWindProfile ${settingsNew}/wrrPaperTestCases/figure03/summa_fileManager_riparianAspenExpWindProfile.txt ${outputNew}/log/${exp}.log & fi

 # Figure 4: Form of different interception capacity parameterizations
 # (no model simulations conducted/needed)

 # Figure 5: Snow interception at Umpqua
 if [ "$ix" = 08 ]; then runSumma ${SUMMA_EXE} ${exp} _hedpom9697 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9697_hedpom.txt ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 09 ]; then runSumma ${SUMMA_EXE} ${exp} _hedpom9798 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9798_hedpom.txt ${outputNew}/log/${exp}b.log & fi
 if [ "$ix" = 10 ]; then runSumma ${SUMMA_EXE} ${exp} _storck9697 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9697_storck.txt ${outputNew}/log/${exp}c.log & fi
 if [ "$ix" = 11 ]; then runSumma ${SUMMA_EXE} ${exp} _storck9798 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9798_storck.txt ${outputNew}/log/${exp}d.log & fi

 # Figure 6: Sensitivity to snow albedo representations at Reynolds Mountain East and Senator Beck
 if [ "$ix" = 12 ]; then runSumma ${SUMMA_EXE} ${exp} _reynoldsConstantDecayRate ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_reynoldsConstantDecayRate.txt ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 13 ]; then runSumma ${SUMMA_EXE} ${exp} _reynoldsVariableDecayRate ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_reynoldsVariableDecayRate.txt ${outputNew}/log/${exp}b.log & fi
 if [ "$ix" = 14 ]; then runSumma ${SUMMA_EXE} ${exp} _senatorConstantDecayRate  ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_senatorConstantDecayRate.txt ${outputNew}/log/${exp}c.log & fi
 if [ "$ix" = 15 ]; then runSumma ${SUMMA_EXE} ${exp} _senatorVariableDecayRate  ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_senatorVariableDecayRate.txt ${outputNew}/log/${exp}d.log & fi

 # Figure 7: Sensitivity of ET to the stomatal resistance parameterization (Aspen stand at Reynolds Mountain East)
 if [ "$ix" = 16 ]; then runSumma ${SUMMA_EXE} ${exp} _jarvis           ${settingsNew}/wrrPaperTestCases/figure07/summa_fileManager_riparianAspenJarvis.txt ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 17 ]; then runSumma ${SUMMA_EXE} ${exp} _ballBerry        ${settingsNew}/wrrPaperTestCases/figure07/summa_fileManager_riparianAspenBallBerry.txt ${outputNew}/log/${exp}b.log & fi
 if [ "$ix" = 18 ]; then runSumma ${SUMMA_EXE} ${exp} _simpleResistance ${settingsNew}/wrrPaperTestCases/figure07/summa_fileManager_riparianAspenSimpleResistance.txt ${outputNew}/log/${exp}c.log & fi

 # Figure 8: Sensitivity of ET to the root distribution and the baseflow parameterization (Aspen stand at Reynolds Mountain East)
 #  (NOTE: baseflow simulations conducted as part of Figure 9)
 if [ "$ix" = 19 ]; then runSumma ${SUMMA_EXE} ${exp} _perturbRoots ${settingsNew}/wrrPaperTestCases/figure08/summa_fileManager_riparianAspenPerturbRoots.txt ${outputNew}/log/${exp}.log & fi

 # Figure 9: Simulations of runoff using different baseflow parameterizations (Reynolds Mountain East)
 if [ "$ix" = 20 ]; then runSumma ${SUMMA_EXE} ${exp} _1dRichards          ${settingsNew}/wrrPaperTestCases/figure09/summa_fileManager_1dRichards.txt ${outputNew}/log/${exp}a.log & fi
 if [ "$ix" = 21 ]; then runSumma ${SUMMA_EXE} ${exp} _lumpedTopmodel      ${settingsNew}/wrrPaperTestCases/figure09/summa_fileManager_lumpedTopmodel.txt ${outputNew}/log/${exp}b.log & fi
 if [ "$ix" = 22 ]; then runSumma ${SUMMA_EXE} ${exp} _distributedTopmodel ${settingsNew}/wrrPaperTestCases/figure09/summa_fileManager_distributedTopmodel.txt ${outputNew}/log/${exp}c.log& fi

 # sleep awhile, to ensure not rapidly executing programs before we realized it
 sleep 1

 # sleep if using the desired number of processors
 while [ `ls -1 summa.*.control | wc -l` -ge $nProcessors ]; do
  sleep 5
 done  # check if using the number of processors

done # End of test cases based on field data
# *************************************************************************************************

