/*******************************************************************************
TITLE: CheckRequirements.do
AUTHOR(S): Daniel Cohen 
DESCRIPTION: Checks local instance of Stata for all required dependencies
             and automatically installs if not there. 
DATE LAST MODIFIED: 2022-11-04
FILE(S) USED: N/A
*******************************************************************************/

/*******************************************************************************
Checks whether or not package exists.

FUNC NAME: check_package
FUNC ARGUMENT(S): 
	- pkg (str, name of package to be installed)
FUNC RESULT(S): Alerts user to any packages that require installation.
*******************************************************************************/

capture program drop check_package
program define check_package
   syntax, pkg(str) 
	
	capture which `pkg'
	if _rc == 111 {
		dis "Installing `pkg'..."
		quietly ssc install `pkg', replace
		}

end 


/*******************************************************************************
Create list of packages and run above function for all packages.
*******************************************************************************/

* create package list 

local dependencies "outreg5 unique estout tabout outreg2"
local dependencies "`dependencies' outreg binscatter ftools distinct"
local dependencies "`dependencies' moss coefplot ietoolkit reghdfe"


* run function for all packages 

foreach dep in `dependencies' {
	check_package, pkg("`dep'")
}
