/*******************************************************************************
Sets up LaTeX helper functions, globals, and imports data for
the cars experiment analysis.
*******************************************************************************/

clear all

/*******************************************************************************
Set up scalar exporting to LyX
*******************************************************************************/

* create helper function that writes to latex

cap program drop latex
program latex
   syntax, name(str) value(str)

   local command = "\newcommand{\\`name'}{`value'}"

   file open scalars using "$rootdir/cars/output/numbersCarsAnalysis.tex", write append
   file write scalars `"`command'"' _n
   file close scalars
end

* create function that exports rounded values to latex

cap program drop latex_rounded
program latex_rounded
   syntax, name(str) value(str) digits(str)

   local value : display %8.`digits'fc `value'
   local value = trim("`value'")

   latex, name(`name') value(`value')
end

* create function that exports precise values to latex

cap program drop latex_precision
program latex_precision
   syntax, name(str) value(str) digits(str)

   autofmt, input(`value') dec(`digits') strict
   local value = r(output1)

   latex, name(`name') value(`value')
end


/*******************************************************************************
Use current version of iebaltab from ietoolkit
*******************************************************************************/


/*******************************************************************************
Set globals across analysis.

FUNC NAME: set_globals
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Sets globals within session.
*******************************************************************************/

cap program drop set_globals
program define set_globals

	* unit of WTP (include delimiting for .tex version)

	global wtp_unit_vis = "$/vehicle-year"
	global wtp_unit_tex = "\\$/vehicle-year"

	* passthrough, markup, and psychic benefit constants

	global rho = 0.8
	global mu = 0
	global DeltaI = 0

	* controls (product pair, baseline order, endline order)

	global CONTROLS = "i.product_pair_strict first_baseline " + ///
	                  "second_baseline first_endline second_endline"

end

set_globals


/*******************************************************************************
Import processed data from cars experiment.

FUNC NAME: import_data
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Reads in data for session.
*******************************************************************************/

capture program drop import_data
program define import_data

	* import processed data
	use "$rootdir/cars/intermediate_data/merged", clear

	* isolate to in-sample observations
	keep if baddata_final == 0

end

import_data
