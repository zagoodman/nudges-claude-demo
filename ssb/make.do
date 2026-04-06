version 18

/*******************************************************************************
TITLE: make.do
AUTHOR(S): Daniel Cohen
DESCRIPTION: Master file for the SSB experiment. Performs the following:
	(0) runs pre-build (pre_build.do)
	(1) ensures all relevant sub-folders exist and removes old 
	    scalar export file 
	(2) builds final dataset (clean_build.do)
	(3) runs all relevant analyses (analysis.do)
DATE LAST MODIFIED: APR 2024
FILE(S) USED: N/A
*******************************************************************************/

/*******************************************************************************
(0) perform pre-build step (only done internally)
*******************************************************************************/

// do "$rootdir/ssb/code/pre_build.do"


/*******************************************************************************
(1) ensure all relevant subfolder(s) exist & remove old scalar file 
*******************************************************************************/

* build sub-folders

capture mkdir "$rootdir/ssb/intermediate_data"

* analysis sub-folders

capture mkdir "$rootdir/ssb/output"
capture mkdir "$rootdir/ssb/output/welfare"
capture mkdir "$rootdir/ssb/output/calories and sugar"

* remove old version of file

cap rm "$rootdir/ssb/output/numbersSSBAnalysis.tex"


/*******************************************************************************
(2) build dataset
*******************************************************************************/

do "$rootdir/ssb/code/clean_build.do"


/*******************************************************************************
(3) run analyses
*******************************************************************************/

do "$rootdir/ssb/code/analysis.do"
