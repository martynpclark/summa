#!/bin/bash

# modify the settings and output directories for specific test cases

# The first command line argument is the experiment
exp=$1

# ensure that we have a command line argument
if  [ -z ${exp} ]; then
	echo "Must define the experiment name as a command-line argument"
	exit 1
fi

# define new settings and output directories
settingsNew='settings'${exp}
outputNew='output'${exp}

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
