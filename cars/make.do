/*******************************************************************************
TITLE: make.do
AUTHOR(S): Daniel Cohen
DESCRIPTION: Master file for cars experiment. Performs the following:
	(0) performs pre-build step for deidentification (pre_build.do)
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

// do "$rootdir/cars/code/pre_build.do"


/*******************************************************************************
(1) ensure all relevant subfolder(s) exist & remove old scalar file 
*******************************************************************************/

* build sub-folders 

capture mkdir "$rootdir/cars/intermediate_data"

* analysis sub-folders

capture mkdir "$rootdir/cars/output"
capture mkdir "$rootdir/cars/output/welfare"

* remove old version of file

cap rm "$rootdir/cars/output/numbersCarsAnalysis.tex"


/*******************************************************************************
(2) build dataset
*******************************************************************************/

do "$rootdir/cars/code/clean_build.do"


/*******************************************************************************
(3) run analyses
*******************************************************************************/

do "$rootdir/cars/code/analysis.do"
