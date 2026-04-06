version 18

/*******************************************************************************
TITLE: make.do
AUTHOR(S): Daniel Cohen
DESCRIPTION: Master file for the project. Performs the following:
	(1) sets global directory for the user
	(2) sets global graphics scheme 
	(3) calls the make.do file for each subdirectory
DATE LAST MODIFIED: APR 2024
FILE(S) USED: N/A
*******************************************************************************/

/*******************************************************************************
(1) set the global directory for each user
*******************************************************************************/

include "SetGlobals.do"


/*******************************************************************************
(2) ensure the correct graphics scheme is enabled
*******************************************************************************/

set scheme s2color, permanently


/*******************************************************************************
(3) call the make.do file from each subdirectory
*******************************************************************************/

do "$rootdir/ssb/make.do"
do "$rootdir/cars/make.do"
