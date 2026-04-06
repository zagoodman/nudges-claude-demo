clear all

/************************************************************
Set up scalar exporting to LyX
*************************************************************/

* helper function that writes to latex 

cap program drop latex
program latex
   syntax, name(str) value(str)
   
   local command = "\newcommand{\\`name'}{`value'}"
   
   file open scalars using "$rootdir/ssb/output/numbersSSBAnalysis.tex", write append
   file write scalars `"`command'"' _n
   file close scalars
end

* function that exports rounded values to latex 

cap program drop latex_rounded
program latex_rounded
   syntax, name(str) value(str) digits(str)
   
   local value : display %8.`digits'fc `value'
   local value = trim("`value'")
   
   latex, name(`name') value(`value')
end

* function that exports precise values to latex 

cap program drop latex_precision
program latex_precision
   syntax, name(str) value(str) digits(str)
   
   autofmt, input(`value') dec(`digits') strict
   local value = r(output1)
   
   latex, name(`name') value(`value')
end


/*******************************************************************************
Import locally-stored, deprecated version of iebaltab command 
*******************************************************************************/

cap program drop import_deprecated_iebaltab
program define import_deprecated_iebaltab

	quietly do "$rootdir/lib/ado/i/iebaltab_v64.ado"

end 

import_deprecated_iebaltab


/*******************************************************************************
Set globals across analysis.

FUNC NAME: set_globals
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Sets globals within session. 
*******************************************************************************/

cap program drop set_globals 
program define set_globals

	* global for WTP unit (include delimiting for .tex version)

	global wtp_unit_vis = "$/12-pack"
	global wtp_unit_tex = "\\$/12-pack"

	* global for passthrough and markup 

	global rho = 0.8
	global mu = 0
	global DeltaI = 0

	* global for controls 

	global CONTROLS = "i.prod_no first_baseline second_baseline " + /// 
	                  "third_baseline first_endline second_endline " + ///
					  "third_endline"

end 

set_globals


/*******************************************************************************
Import processed data from SSB experiment. 

FUNC NAME: import_data
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Reads in data within session. 
*******************************************************************************/

capture program drop import_data 
program define import_data 

	* import processed data 
	use "$rootdir/ssb/intermediate_data/merged", clear

	* remove out-of-sample observations 
	keep if insample == 1

end

import_data
