#!/bin/bash

# Used to run the test cases for SUMMA

# There are two classes of test cases:
#  1) Test cases based on synthetic/lab data; and
#  2) Test cases based on field data.

# The commands assume that you are in the directory {localInstallation}/settings/
# and that the control files are in {localInstallation}/settings/

# =================================================================================================
# User-configurable component

# Define the experiment (e.g., the name of the current branch)
expName=_master

# Set the path to the SUMMA executable (e.g. /usr/local/bin/ or wherever you have installed SUMMA)
summaPath=/Users/mclark/check/upstream/summa/bin

# end of user-configuable component
# =================================================================================================

# check the summa path is provided
if  [ -z ${summaPath} ]; then
 echo "Must define the path to the SUMMA executable in $0"
 exit 1
fi

# define new settings and output directories
settingsNew='settings'${expName}
outputNew='output'${expName}

# Define the summa executable
SUMMA_EXE=${summaPath}/summa${expName}.exe

# Copy the executable
cp ${summaPath}/summa.exe ${SUMMA_EXE}

# Configure control files and directories for the current experiment
./modifyTestCases.sh $expName

# *************************************************************************************************
# * PART 1: TEST CASES BASED ON SYNTHETIC OR LAB DATA

# Synthetic test case 1: Simulations from Celia (WRR 1990)
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/celia1990/summa_fileManager_celia1990.txt > ${outputNew}/log/a1.log
echo ${outputNew} 'completed synthetic test case 1'

# Synthetic test case 2: Simulations from Miller (WRR 1998)
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/miller1998/summa_fileManager_millerClay.txt > ${outputNew}/log/a2a.log
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/miller1998/summa_fileManager_millerLoam.txt > ${outputNew}/log/a2b.log
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/miller1998/summa_fileManager_millerSand.txt > ${outputNew}/log/a2c.log
echo ${outputNew} 'completed synthetic test case 2'

# Synthetic test case 3: Simulations of the lab experiment of Mizoguchi (1990)
#                         as described by Hansson et al. (VZJ 2005)
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/mizoguchi1990/summa_fileManager_mizoguchi.txt > ${outputNew}/log/a3.log
echo ${outputNew} 'completed synthetic test case 3'

# Synthetic test case 4: Simulations of rain on a sloping hillslope from Wigmosta (WRR 1999)
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/wigmosta1999/summa_fileManager-exp1.txt > ${outputNew}/log/a4a.log
${SUMMA_EXE} _testSumma ${settingsNew}/syntheticTestCases/wigmosta1999/summa_fileManager-exp2.txt > ${outputNew}/log/a4b.log
echo ${outputNew} 'completed synthetic test case 4'

# End of test cases based on synthetic/lab data
# *************************************************************************************************
# * PART 2: TEST CASES BASED ON FIELD DATA, AS DESCRIBED BY CLARK ET AL. (WRR 2015B)

# Figure 1: Radiation transmission through an Aspen stand, Reynolds Mountain East
${SUMMA_EXE} _riparianAspenBeersLaw        ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenBeersLaw.txt  > ${outputNew}/log/b1a.log
${SUMMA_EXE} _riparianAspenNLscatter       ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenNLscatter.txt > ${outputNew}/log/b1b.log
${SUMMA_EXE} _riparianAspenUEB2stream      ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenUEB2stream.txt > ${outputNew}/log/b1c.log
${SUMMA_EXE} _riparianAspenCLM2stream      ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenCLM2stream.txt > ${outputNew}/log/b1d.log
${SUMMA_EXE} _riparianAspenVegParamPerturb ${settingsNew}/wrrPaperTestCases/figure01/summa_fileManager_riparianAspenVegParamPerturb.txt > ${outputNew}/log/b1e.log
echo ${outputNew} 'completed field test case 1'

# Figure 2: Wind attenuation through an Aspen stand, Reynolds Mountain East
${SUMMA_EXE} _riparianAspenWindParamPerturb ${settingsNew}/wrrPaperTestCases/figure02/summa_fileManager_riparianAspenWindParamPerturb.txt > ${outputNew}/log/b2.log
echo ${outputNew} 'completed field test case 2'

# Figure 3: Impacts of canopy wind profile on surface fluxes, surface temperature, and snow melt (Aspen stand, Reynolds Mountain East)
${SUMMA_EXE} _riparianAspenExpWindProfile ${settingsNew}/wrrPaperTestCases/figure03/summa_fileManager_riparianAspenExpWindProfile.txt > ${outputNew}/log/b3.log
echo ${outputNew} 'completed field test case 3'

# Figure 4: Form of different interception capacity parameterizations
# (no model simulations conducted/needed)

# Figure 5: Snow interception at Umpqua
${SUMMA_EXE} _hedpom9697 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9697_hedpom.txt > ${outputNew}/log/b5a.log
${SUMMA_EXE} _hedpom9798 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9798_hedpom.txt > ${outputNew}/log/b5b.log
${SUMMA_EXE} _storck9697 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9697_storck.txt > ${outputNew}/log/b5c.log
${SUMMA_EXE} _storck9798 ${settingsNew}/wrrPaperTestCases/figure05/summa_fileManager_9798_storck.txt > ${outputNew}/log/b5d.log
echo ${outputNew} 'completed field test case 5'

# Figure 6: Sensitivity to snow albedo representations at Reynolds Mountain East and Senator Beck
${SUMMA_EXE} _reynoldsConstantDecayRate ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_reynoldsConstantDecayRate.txt > ${outputNew}/log/b6a.log
${SUMMA_EXE} _reynoldsVariableDecayRate ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_reynoldsVariableDecayRate.txt > ${outputNew}/log/b6b.log
${SUMMA_EXE} _senatorConstantDecayRate  ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_senatorConstantDecayRate.txt > ${outputNew}/log/b6c.log
${SUMMA_EXE} _senatorVariableDecayRate  ${settingsNew}/wrrPaperTestCases/figure06/summa_fileManager_senatorVariableDecayRate.txt > ${outputNew}/log/b6d.log
echo ${outputNew} 'completed field test case 6'

# Figure 7: Sensitivity of ET to the stomatal resistance parameterization (Aspen stand at Reynolds Mountain East)
${SUMMA_EXE} _jarvis           ${settingsNew}/wrrPaperTestCases/figure07/summa_fileManager_riparianAspenJarvis.txt > ${outputNew}/log/b7a.log
${SUMMA_EXE} _ballBerry        ${settingsNew}/wrrPaperTestCases/figure07/summa_fileManager_riparianAspenBallBerry.txt > ${outputNew}/log/b7b.log
${SUMMA_EXE} _simpleResistance ${settingsNew}/wrrPaperTestCases/figure07/summa_fileManager_riparianAspenSimpleResistance.txt > ${outputNew}/log/b7c.log
echo ${outputNew} 'completed field test case 7'

# Figure 8: Sensitivity of ET to the root distribution and the baseflow parameterization (Aspen stand at Reynolds Mountain East)
#  (NOTE: baseflow simulations conducted as part of Figure 9)
${SUMMA_EXE} _perturbRoots ${settingsNew}/wrrPaperTestCases/figure08/summa_fileManager_riparianAspenPerturbRoots.txt > ${outputNew}/log/b8.log
echo ${outputNew} 'completed field test case 8'

# Figure 9: Simulations of runoff using different baseflow parameterizations (Reynolds Mountain East)
${SUMMA_EXE} _1dRichards          ${settingsNew}/wrrPaperTestCases/figure09/summa_fileManager_1dRichards.txt > ${outputNew}/log/b9c.log
${SUMMA_EXE} _lumpedTopmodel      ${settingsNew}/wrrPaperTestCases/figure09/summa_fileManager_lumpedTopmodel.txt > ${outputNew}/log/b9c.log
${SUMMA_EXE} _distributedTopmodel ${settingsNew}/wrrPaperTestCases/figure09/summa_fileManager_distributedTopmodel.txt > ${outputNew}/log/b9c.log
echo ${outputNew} 'completed field test case 9'

# End of test cases based on field data
# *************************************************************************************************
