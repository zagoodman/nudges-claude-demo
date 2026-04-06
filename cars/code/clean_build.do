version 18

local processors = c(processors)
if `processors' > 1 {
	set processors 1
}

/*******************************************************************************
TITLE: clean_build.do
AUTHOR(S): Daniel Cohen <-- Victoria Pu 
DESCRIPTION: Reads in PII-free raw data and produces cleaned/processed dataset
	         for the cars experiment. 
DATE LAST MODIFIED: APR 2024
FILE(S) USED: 
    - [cars/input/] surveys_combined.dta 
	- [cars/input/] client_demos.dta
*******************************************************************************/

clear all

/*******************************************************************************
Set up scalar exporting to LyX
*******************************************************************************/

* helper function that writes to latex 

cap program drop latex
program latex
   syntax, name(str) value(str)
   
   local command = "\newcommand{\\`name'}{`value'}"
   
   file open scalars using "$rootdir/cars/output/numbersCarsAnalysis.tex", write append
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
Set globals across analysis.
*******************************************************************************/

cap program drop set_globals 
program define set_globals

	* car names, baseline vs. endline MPL, etc. 
	global thirty_mpg_cars "nissan honda"
	global twentythree_mpg_cars "dodge ford"
	global all_cars "nissan honda dodge ford"
	global new_car_names "nissan honda subaru ford"
	global mpl_base_or_end "b e" 
	
end 

set_globals

/*******************************************************************************
Import combined pre-built data file  
*******************************************************************************/

cap program drop import_survey_data 
program define import_survey_data

	* read in combined data  
	use "$rootdir/cars/input/surveys_combined"
	
end

import_survey_data


/*******************************************************************************
Export initial sample size 
*******************************************************************************/

cap program drop export_init_sample_size
program define export_init_sample_size
	preserve 

	* export number of legit responses who started the survey
	drop if county_of_res_1 == ""
	distinct amerispeak_id_hashed
	
	local sample_size: di r(ndistinct)
	latex_rounded, name("carsSampleSizeStartedSurvey") value(`sample_size') digits(0)

	restore
end 

export_init_sample_size


/*******************************************************************************
Perform preliminary cleaning  
*******************************************************************************/

cap program drop prelim_clean 
program define prelim_clean

	* keep only completes 
	keep if cstatus == "1"

	* keep only car users
	keep if car_user == "Yes" 

	* drop duplicates, sorting on amerispeak ID and completion time
	gen double enddate_time = clock(enddate, "YMDhms")
	format enddate_time %tc
	set sortseed 1000
	sort amerispeak_id_hashed enddate_time
	by amerispeak_id_hashed: gen dup = cond(_N==1, 0, _n)
	drop if dup > 1
	rename county_of_res_1 state_of_res
	
end 

prelim_clean


/*******************************************************************************
Clean "enjoyment" variables for each car (WTP if gas is gree)
*******************************************************************************/

cap program drop clean_enjoyment_vals
program define clean_enjoyment_vals

	* create a single Enjoyment WTP variable and rename to be consistent with remainder of code
	foreach car in $new_car_names {
		gen `car'_enjoy = ""
		replace `car'_enjoy = `car'_enjoy_js
		forval i = 1/2 {
			replace `car'_enjoy = `car'_enjoy`i' if `car'_enjoy == "" & `car'_enjoy`i' != ""
		}
	}

	* destring enjoyment values
	foreach car in $new_car_names {
		destring `car'_enjoy, replace
	}

	* generate dodge_enjoy = subaru_enjoy for consistency with rest of the build
	gen dodge_enjoy = subaru_enjoy  

	* rename the following columns for consistency with naming below (i.e. base --> b, end --> e)
	foreach car in $thirty_mpg_cars {
		rename left_car_`car'_base left_car_`car'_b
		rename left_car_`car'_end left_car_`car'_e
	}
	
end

clean_enjoyment_vals


/*******************************************************************************
Destring WTP values and cap between 500 and 3500
*******************************************************************************/

cap program drop process_raw_WTPs
program define process_raw_WTPs

	* iterate over WTP vars and destring/cap if off-MPL
	foreach car in $thirty_mpg_cars {
		foreach letter in $mpl_base_or_end {
			destring `car'_lease_wtp_`letter', replace
			replace `car'_lease_wtp_`letter' = 500 if `car'_lease_wtp_`letter' == 450
			replace `car'_lease_wtp_`letter' = 3500 if `car'_lease_wtp_`letter' == 3550
			
			destring dodge_lease_wtp_b_`car', replace
			replace dodge_lease_wtp_b_`car' = 500 if dodge_lease_wtp_b_`car' == 450
			replace dodge_lease_wtp_b_`car' = 3500 if dodge_lease_wtp_b_`car' == 3550
			
			destring ford_lease_wtp_e_`car', replace
			replace ford_lease_wtp_e_`car' = 500 if ford_lease_wtp_e_`car' == 450
			replace ford_lease_wtp_e_`car' = 3500 if ford_lease_wtp_e_`car' == 3550
		}
	}
	
end 

process_raw_WTPs


/*******************************************************************************
Generate censored WTP that ignores user-input values on the post-censor screen.
WTP values capped at [500, 3500]
*******************************************************************************/

cap program drop gen_cens_WTPs 
program define gen_cens_WTPs

	gen wtp_b_cens_1 = dodge_lease_wtp_b_nissan - nissan_lease_wtp_b  // Baseline: Nissan v Ford
	gen wtp_b_cens_2 = dodge_lease_wtp_b_honda - honda_lease_wtp_b  // Baseline: Honda v Ford
	gen wtp_e_cens_1 = ford_lease_wtp_e_nissan - nissan_lease_wtp_e // Endline: Nissan v Ford
	gen wtp_e_cens_2 = ford_lease_wtp_e_honda - honda_lease_wtp_e // Endline: Subaru v Ford
	
end 

gen_cens_WTPs


/*******************************************************************************
Generate uncensored WTP that takes user inputs into account. Process: 
	(1) for everyone who was censored, assign user-input value
		(a) for regular left/right blocks 
		(b) for left/right blocks w/ honda & subaru order switched
	(2) compute relative WTPs

(AFTER reshaping from wide to long) Construct uncensored WTP. Process:  
	(1) replace all relative WTPs > 1500 w/ median value over 1500
	(2) replace all relative WTPs < -1500 w/ median value under -1500
*******************************************************************************/

cap program drop gen_uncens_WTPs
program define gen_uncens_WTPs

	local mpls_list "c cost cp mpg env"
	local cens_vars "l r"

	* (1)(a) For everyone who was censored, assign them their user-input value;
	* destring censored values for BASELINE mpls only 
	* (because "dodge" is the 23mpg seen in baseline)
	gen is_censored = 0
	foreach car in $thirty_mpg_cars {
		foreach cens in `cens_vars' {
			destring `car'_dodge_b_`cens', replace
			destring dodge_`car'_b_`cens', replace

			replace is_censored = 1 if `car'_dodge_b_`cens' != .
			replace is_censored = 1 if dodge_`car'_b_`cens' != .
		}
	}

	* REPEAT above for is_sh censored (nissan has no _sh blocks, 
	* so honda only) BASELINE blocks
	foreach cens in `cens_vars' {
		destring honda_dodge_b_sh_`cens', replace
		destring dodge_honda_b_sh_`cens', replace

		replace is_censored = 1 if honda_dodge_b_sh_`cens' != .
		replace is_censored = 1 if dodge_honda_b_sh_`cens' != .
	}


	* destring and get censored user input for ENDLINE mpls only 
	* (because ford is only 23mpg seen in endline)
	foreach car in $thirty_mpg_cars {
		foreach mpl in `mpls_list' {
			foreach cens in `cens_vars' {
				destring `car'_ford_`mpl'_`cens', replace
				destring ford_`car'_`mpl'_`cens', replace

				replace is_censored = 1 if `car'_ford_`mpl'_`cens' != .
				replace is_censored = 1 if ford_`car'_`mpl'_`cens' != .
			}
		}
	}

	* REPEAT above for is_sh censored (nissan has no _sh blocks, honda only) 
	* ENDLINE blocks 
	foreach mpl in `mpls_list' {
		foreach cens in `cens_vars' {
			destring honda_ford_`mpl'_sh_`cens', replace
			destring ford_honda_`mpl'_sh_`cens', replace

			replace is_censored = 1 if honda_ford_`mpl'_sh_`cens' != .
			replace is_censored = 1 if ford_honda_`mpl'_sh_`cens' != .
		}
	}

	* (1)(b) Replace censored lease WTP values with these stored censored values 
	* (raw user input or medians depending on chunks above)
	* Note: naming convention of left/right blocks is: leftcar_rightcar_b_l/r

	* BASELINE first
	foreach car in $thirty_mpg_cars {
		
		* 1) 1st set of cases: 30mpg car on left, break into 2 subcases of always left and always right
		* 1a) update 30mpg car value to user-input value if they chose always left
		replace `car'_lease_wtp_b = `car'_dodge_b_l if `car'_dodge_b_l != .  // Right Car's value is already fixed at 2000
		
		* 1b) update 30mpg car value to 500 if they chose always right (recall: 30mpg car is on left)
		replace `car'_lease_wtp_b = 500 if `car'_dodge_b_r != .
		* this must mean that the dodge was on the right, so update the dodge's value to the user-input value
		replace dodge_lease_wtp_b_`car' = `car'_dodge_b_r if `car'_dodge_b_r != .
		
		
		* 2) 2nd set of cases: dodge is on left, break into 2 subcases of always left and always right
		* 2a) update dodge value to user-input value if they chose always left
		replace dodge_lease_wtp_b_`car' = dodge_`car'_b_l if dodge_`car'_b_l != .  // Right Car's value is already fixed at 2000
		
		* 2b) update dodge value to 500 if they always chose right (and recall dodge is on left)
		replace dodge_lease_wtp_b_`car' = 500 if dodge_`car'_b_r != .
		* this must mean that the 30mpg car was on the right, so update the 30mpg car to the user-input value
		replace `car'_lease_wtp_b = dodge_`car'_b_r if dodge_`car'_b_r != .
		
	}

	* REPEAT chunk above to fill is_sh censored BASELINE values (honda only)
	* 1) 1st set of cases: 30mpg car on left, break into 2 subcases of always left and always right
	* 1a) update 30mpg car value to user-input value if they chose always left
	replace honda_lease_wtp_b = honda_dodge_b_sh_l if honda_dodge_b_sh_l != .  // Right Car's value is already fixed at 2000

	* 1b) update 30mpg car value to 500 if they chose always right (recall: 30mpg car is on left)
	replace honda_lease_wtp_b = 500 if honda_dodge_b_sh_r != .
	* this must mean that the dodge was on the right, so update the dodge's value to the user-input value
	replace dodge_lease_wtp_b_honda = honda_dodge_b_sh_r if honda_dodge_b_sh_r != .

	* 2) 2nd set of cases: dodge is on left, break into 2 subcases of always left and always right
	* 2a) update dodge value to user-input value if they chose always left
	replace dodge_lease_wtp_b_honda = dodge_honda_b_sh_l if dodge_honda_b_sh_l != .  // Right Car's value is already fixed at 2000

	* 2b) update dodge value to 500 if they always chose right (and recall dodge is on left)
	replace dodge_lease_wtp_b_honda = 500 if dodge_honda_b_sh_r != .
	* this must mean that the 30mpg car was on the right, so update the 30mpg car to the user-input value
	replace honda_lease_wtp_b = dodge_honda_b_sh_r if dodge_honda_b_sh_r != .


	* similarly, now do ENDLINES
	foreach car in $thirty_mpg_cars {
		foreach mpl in `mpls_list' {
		
			* 1) 1st set of cases: 30mpg car on left, break into 2 subcases of always left and always right
			* 1a) update 30mpg car value to user-input value if always left
			replace `car'_lease_wtp_e = `car'_ford_`mpl'_l if `car'_ford_`mpl'_l != .
			
			* 1b) update 30mpg car value to 500 if chose always right (because 30mpg car is on left in 1st set of cases)
			replace `car'_lease_wtp_e = 500 if `car'_ford_`mpl'_r != .
			* b/c 30mpg was on left, then the ford must have been on the right, so update the ford's value to their user-input value
			replace ford_lease_wtp_e_`car' = `car'_ford_`mpl'_r if `car'_ford_`mpl'_r != .
			
			
			* 2) 2nd set of cases: ford is on left, break into 2 subcases of always left and always right
			* 2a) update ford value to user-input value if they chose always left
			replace ford_lease_wtp_e_`car' = ford_`car'_`mpl'_l if ford_`car'_`mpl'_l != . 
			
			* 2b) update ford value to 500 if they always chose right (and recall ford is on left)
			replace ford_lease_wtp_e_`car' = 500 if ford_`car'_`mpl'_r != .
			* b/c ford was on left, then the 30mpg must have been on the right, so update the 30mpg's value to their user-input value
			replace `car'_lease_wtp_e = ford_`car'_`mpl'_r if ford_`car'_`mpl'_r != . 
			
		}
	}

	* REPEAT chunk above to fill is_sh censored ENDLINE values (honda only)
	foreach mpl in `mpls_list' {
		
			* 1) 1st set of cases: 30mpg car on left, break into 2 subcases of always left and always right
			* 1a) update 30mpg car value to user-input value if always left
			replace honda_lease_wtp_e = honda_ford_`mpl'_sh_l if honda_ford_`mpl'_sh_l != .
			
			* 1b) update 30mpg car value to 500 if chose always right (because 30mpg car is on left in 1st set of cases)
			replace honda_lease_wtp_e = 500 if honda_ford_`mpl'_sh_r != .
			* b/c 30mpg was on left, then the ford must have been on the right, so update the ford's value to their user-input value
			replace ford_lease_wtp_e_honda = honda_ford_`mpl'_sh_r if honda_ford_`mpl'_sh_r != .
			
			
			* 2) 2nd set of cases: ford is on left, break into 2 subcases of always left and always right
			* 2a) update ford value to user-input value if they chose always left
			replace ford_lease_wtp_e_honda = ford_honda_`mpl'_sh_l if ford_honda_`mpl'_sh_l != . 
			
			* 2b) update ford value to 500 if they always chose right (and recall ford is on left)
			replace ford_lease_wtp_e_honda = 500 if ford_honda_`mpl'_sh_r != .
			* b/c ford was on left, then the 30mpg must have been on the right, so update the 30mpg's value to their user-input value
			replace honda_lease_wtp_e = ford_honda_`mpl'_sh_r if ford_honda_`mpl'_sh_r != . 
	}


	* (2) compute relative WTPs for everyone
	* compute relative WTP of 23mpg car (less fuel efficient) minus 
	* 30mpg car (more fuel efficient)
	gen wtp_b_uncens_1 = dodge_lease_wtp_b_nissan - nissan_lease_wtp_b  // Baseline: Nissan v Ford
	gen wtp_b_uncens_2 = dodge_lease_wtp_b_honda - honda_lease_wtp_b // Baseline: Honda v Ford
	gen wtp_e_uncens_1 = ford_lease_wtp_e_nissan - nissan_lease_wtp_e // Endline: Nissan v Ford
	gen wtp_e_uncens_2 = ford_lease_wtp_e_honda - honda_lease_wtp_e  // Endline: Subaru v Ford

	gen wtp_b_median_1 = wtp_b_uncens_1
	gen wtp_b_median_2 = wtp_b_uncens_2
	gen wtp_e_median_1 = wtp_e_uncens_1
	gen wtp_e_median_2 = wtp_e_uncens_2

end 

gen_uncens_WTPs


/*******************************************************************************
Compute yearly gas cost 
*******************************************************************************/

cap program drop compute_gas_cost
program define compute_gas_cost

	* destring and clean annual mileage and gas cost estimates 
	destring miles_driven_2019, replace ignore(",")
	replace miles_driven_2019 = 0 if miles_driven_2019 == .
	replace gas_price_estimate=subinstr(gas_price_estimate,",","",.)  // replace comma (e.g. 3,30) with period (3.30)
	destring gas_price_estimate, replace

	* calculate total annual gas cost for higher-MPG cars
	foreach car in $thirty_mpg_cars { 
		gen annual_gas_cost_`car' = (miles_driven_2019 / 30.0) * gas_price_estimate
		destring annual_gas_cost_`car', replace
	}

	* calculate total annual gas cost for lower-MPG cars
	foreach car in $twentythree_mpg_cars { 
		gen annual_gas_cost_`car' = (miles_driven_2019 / 23.0) * gas_price_estimate
		destring annual_gas_cost_`car', replace
	}

	* annual_gas_cost_dodge = subaru
	replace annual_gas_cost_dodge = (miles_driven_2019 / 30.0) * gas_price_estimate
	
end 

compute_gas_cost


/*******************************************************************************
Convert miles driven to miles driven (thousands) for easier use later
*******************************************************************************/

cap program drop scale_miles_driven
program define scale_miles_driven

	replace miles_driven_2019 = miles_driven_2019 / 1000
	
end 

scale_miles_driven


/*******************************************************************************
Create and label preliminary sample restriction to determine observations 
whose off-MPL WTPs are eligible for consideration when calculating median.
*******************************************************************************/

cap program drop gen_prelim_restriction
program define gen_prelim_restriction

	gen prelim_data_flag = 0

	/*******************************************************************************
	Generate prelim restriction flag, identifying those in the top/bottom 5% of: 
		(1) enjoyment (any car)
		(2) annual gas costs
	*******************************************************************************/

	foreach car in $all_cars {
		
		* enjoyment percentiles
		sum `car'_enjoy, d
		gen `car'_enjoy_bottom_5 = r(p5)
		gen `car'_enjoy_top_5 = r(p95)

		* annual gas cost percentiles
		sum annual_gas_cost_`car', d
		gen annual_gas_cost_`car'_bottom_5 = r(p5)
		gen annual_gas_cost_`car'_top_5 = r(p95)

		replace prelim_data_flag = 1 if `car'_enjoy >= `car'_enjoy_top_5 | `car'_enjoy <= `car'_enjoy_bottom_5
		replace prelim_data_flag = 1 if annual_gas_cost_`car' >= annual_gas_cost_`car'_top_5  | annual_gas_cost_`car' <= annual_gas_cost_`car'_bottom_5
				
	}

end 

gen_prelim_restriction


/*******************************************************************************
Export processed dataset to then merge with demographic data.
*******************************************************************************/

cap program drop export_intermediate_data
program define export_intermediate_data

	save "$rootdir/cars/intermediate_data/pre_merge.dta", replace 
	
end 

export_intermediate_data


/*******************************************************************************
Merge survey data with demographic data from TESS/NORC
*******************************************************************************/

capture program drop import_demog_data 
program define import_demog_data

	* read in demographic data
	use "$rootdir/cars/input/client_demos", clear 

	* merge with survey dataset and exclude observations w/o match
	merge 1:1 amerispeak_id_hashed using "$rootdir/cars/intermediate_data/pre_merge.dta"
	keep if _merge == 3
	
end 

import_demog_data


/*******************************************************************************
Export post-merge sample size 
*******************************************************************************/

cap program drop export_post_merge_sample_size
program define export_post_merge_sample_size

	* export sample size after excluding survey respondents w/o demographic info
	distinct amerispeak_id_hashed
	local sample_size: di r(ndistinct)
	latex_rounded, name("carsSampleSizeCarUsersBothComplete") value(`sample_size') digits(0)

end 

export_post_merge_sample_size


/*******************************************************************************
Prepare data for future use in balance table
*******************************************************************************/

cap program drop prep_bal_tab_data
program define prep_bal_tab_data

	* household income
	replace income = 2.5 if income == 1
	replace income = 7.5 if income == 2
	replace income = 12.5 if income == 3
	replace income = 17.5 if income == 4
	replace income = 22.5 if income == 5
	replace income = 27.5 if income == 6
	replace income = 32.5 if income == 7
	replace income = 37.5 if income == 8
	replace income = 45 if income == 9
	replace income = 55 if income == 10
	replace income = 67.5 if income == 11
	replace income = 80 if income == 12
	replace income = 92.5 if income == 13
	replace income = 112.5 if income == 14
	replace income = 137.5 if income == 15
	replace income = 162.5 if income == 16
	replace income = 187.5 if income == 17
	replace income = 200 if income == 18

	* education (years)
	gen education_num = educ5
	replace education_num = 10 if education_num == 1
	replace education_num = 12 if education_num == 2
	replace education_num = 14 if education_num == 3
	replace education_num = 16 if education_num == 4
	replace education_num = 18 if education_num == 5

	* male
	gen male = 1 if gender == 1
	replace male = 0 if gender != 1

	* age: as is (exact age in years)

	* white
	gen white = 1 if racethnicity == 1
	replace white = 0 if racethnicity != 1

	* black
	gen black = 1 if racethnicity == 2
	replace black = 0 if racethnicity != 2

	* GOVENV
	gen environmentalism = 0  // people for whom we don't have a response are encoded as 0 (cannot encode as missing)
	destring govenv, replace
	replace environmentalism = -2 if govenv == 1
	replace environmentalism = -1 if govenv == 2
	replace environmentalism = 0 if govenv == 3 | govenv == 6
	replace environmentalism = 1 if govenv == 4
	replace environmentalism = 2 if govenv == 5

	* compute financial literacy as pct correct of the big 3 financial questions
	local numeracy_vars "fi006 fi007 fi008"
	gen fi006_num = 1 if fi006 == "More than $102"
	replace fi006_num = 0 if fi006 != "More than $102"
	gen fi007_num = 1 if fi007 == "Or less than today"
	replace fi007_num = 0 if fi007 != "Or less than today"
	gen fi008_num = 1 if fi008 == "False"
	replace fi008_num = 0 if fi008 != "False"
	gen financial_literacy = (fi006_num + fi007_num + fi008_num)/3

	* personal cost savings
	gen cost_savings = annual_gas_cost_ford - annual_gas_cost_nissan

	* construct average WTP if gas is free ($000s/year)
	// local all_cars "nissan honda dodge ford"
	gen average_wtp_nogas = 0
	foreach car in $all_cars {
		replace average_wtp_nogas = average_wtp_nogas + `car'_enjoy
	}
	replace average_wtp_nogas = (average_wtp_nogas / 4)/1000

	* construct average baseline relative WTP for lower-MPG car ($000s)
	gen average_baseline_wtp = ((dodge_lease_wtp_b_nissan + dodge_lease_wtp_b_honda) / 2) / 1000

	* treatment number: T = 1 corresponds to control, 2 = fuel cost, 3 = mpg, 
	* 4 = fuel cost (personalized), 5 = smartway
	encode treatment, gen(T) 

end 

prep_bal_tab_data


/*******************************************************************************
Reshape wide to long for analysis. Goal is to have two rows per individual:
	(1) first product pair (baseline and endline decisions) 
	(2) second product pair (baseline and endline decisions)
*******************************************************************************/

cap program drop post_merge_reshape 
program define post_merge_reshape

	* generate ID variable
	gen id = _n
	sort id

	* reshape wide to long
	* product_pair = 1 for nissan vs. ford pair, and product_pair = 2 for honda/subaru vs. ford pair
	reshape long wtp_b_uncens_ wtp_e_uncens_ wtp_b_cens_ wtp_e_cens_ wtp_b_median_ wtp_e_median_, i(id) j(product_pair)
	rename wtp_b_uncens_ wtp_b_uncens
	rename wtp_e_uncens_ wtp_e_uncens
	rename wtp_b_cens_ wtp_b_cens
	rename wtp_e_cens_ wtp_e_cens
	rename wtp_b_median_ wtp_b_median
	rename wtp_e_median_ wtp_e_median

end 

post_merge_reshape


/*******************************************************************************
Augment preliminary sample restriction with additional feature
(being "off-MPL" for difference in enjoyment minus gas cost).  
*******************************************************************************/

capture program drop augment_prelim_restriction
program define augment_prelim_restriction

	* differences in (enjoyment - gas) for 23mpg - 30mpg, for each of the 2 pairs of cars
	gen annual_gas_cost_thirty = annual_gas_cost_nissan  // annual gas cost is the same for all 30 MPG cars
	gen diff_in_enjoy_minus_gas_b = 0
	gen diff_in_enjoy_minus_gas_e = 0

	* for the nissan vs. ford pair
	replace diff_in_enjoy_minus_gas_b = (ford_enjoy - annual_gas_cost_ford) - (nissan_enjoy - annual_gas_cost_thirty) if product_pair == 1
	replace diff_in_enjoy_minus_gas_e = diff_in_enjoy_minus_gas_b if product_pair == 1

	* for the honda/subaru vs. ford pair
	destring is_sh, replace  // dummy of whether order of non-repeating pair was Subaru-Honda or Honda-Subaru
	replace diff_in_enjoy_minus_gas_b = (ford_enjoy - annual_gas_cost_ford) - (dodge_enjoy - annual_gas_cost_thirty) if product_pair == 2 & is_sh == 1
	replace diff_in_enjoy_minus_gas_b = (ford_enjoy - annual_gas_cost_ford) - (honda_enjoy - annual_gas_cost_thirty) if product_pair == 2 & is_sh == 0
	replace diff_in_enjoy_minus_gas_e = (ford_enjoy - annual_gas_cost_ford) - (dodge_enjoy - annual_gas_cost_thirty) if product_pair == 2 & is_sh == 0
	replace diff_in_enjoy_minus_gas_e = (ford_enjoy - annual_gas_cost_ford) - (honda_enjoy - annual_gas_cost_thirty) if product_pair == 2 & is_sh == 1

	* Label inconsistent individuals;
	* label all MPLs of an individual if even 1 diff_in_enjoy_minus_gas has an absolute value > 1500 & they were not censored
	foreach line in $mpl_base_or_end {
		egen n_outliers_`line' = total(abs(diff_in_enjoy_minus_gas_`line') > 1500), by(id)
	}

	replace prelim_data_flag = 1 if (n_outliers_b >= 1 | n_outliers_e >= 1)

end 

augment_prelim_restriction 


/*******************************************************************************
Create version of baseline and endline WTPs where off-MPL self-reports 
are censored by the median of "eligible" self-reports. Eligibility
determined by preliminary restriction prelim_data_flag generated above.
*******************************************************************************/

capture program drop gen_median_cens_WTPs 
program define gen_median_cens_WTPs

	foreach line in $mpl_base_or_end {
		
		* replace WTPs with overall median value over/under 1500/-1500
		sum wtp_`line'_median if wtp_`line'_median > 1500 & prelim_data_flag == 0, d
		replace wtp_`line'_median = `r(p50)' if wtp_`line'_median > 1500
		sum wtp_`line'_median if wtp_`line'_median < -1500 & prelim_data_flag == 0, d
		replace wtp_`line'_median = `r(p50)' if wtp_`line'_median < -1500
			
	}

end 

gen_median_cens_WTPs


/*******************************************************************************
Compute uncensored and median-censored overvaluation 
(baseline and endline for each pair)
*******************************************************************************/

capture program drop gen_overvaluation
program define gen_overvaluation

	* create overvaluation variable, including different versions of overvaluation for different WTP censoring methods
	foreach line in $mpl_base_or_end {
		
		* {relative wtp (i.e. WTP_23 - WTP_30)} - {diff_in_enjoy_minus_gas})
		gen overvaluation_`line'_uncens = 0
		gen overvaluation_`line'_median = 0
		
		replace overvaluation_`line'_uncens = wtp_`line'_uncens - diff_in_enjoy_minus_gas_`line'
		replace overvaluation_`line'_median = wtp_`line'_median - diff_in_enjoy_minus_gas_`line'

	}

end 

gen_overvaluation


/*******************************************************************************
Add uncensored and median-censored delta-WTP 
*******************************************************************************/

cap program drop gen_delta_WTP
program define gen_delta_WTP

	* create delta_wtp for use in structural estimation
	gen delta_wtp_uncens = wtp_e_uncens - wtp_b_uncens
	gen delta_wtp_median = wtp_e_median - wtp_b_median

end 

gen_delta_WTP


/*******************************************************************************
Add treatment dummies, auxiliary variables, and clean up
*******************************************************************************/

cap program drop add_dummies_and_FE
program define add_dummies_and_FE

	* auxiliary variables
	gen thirty_car = "nissan"
	replace thirty_car = "honda" if product_pair == 2

	* compute people's "idiosyncratic value," i.e. personalized fuel cost 
	* savings from driving 30 MPG vs. 23 MPG
	gen idiosyncratic = annual_gas_cost_ford - annual_gas_cost_nissan

	* T = 1 corresponds to control
	gen treated = (T > 1) 

	/*******************************************************************************
	Fixed effect dummies
		(1) product_pair: 1 for nissan vs. ford product pair; 2 for honda/subaru 
			vs. ford product pair
		(2) is_sh: 1 if subaru seen at base and honda at end; 0 otherwise
		(3) is_thirty_onleft_b/e: 1 if 30 MPG car was on left (in base/end); 
			0 otherwise
		(4) nissan_first_b: 1 if nissan vs. ford pair was seen first at base; 
			0 otherwise
		(5) nissan_first_e: 1 if nissan vs. ford pair was seen first at end; 
			0 otherwise
	*******************************************************************************/

	* 1 dummy for whether the 30mpg car was on the left in this pair of MPLs
	gen left_car_mpg_b = 0
	gen left_car_mpg_e = 0
	foreach car in "nissan" "honda" {
		replace left_car_mpg_b = 1 if left_car_`car'_b == thirty_car // if baseline and 30mpg car was on the left
		replace left_car_mpg_e = 1 if left_car_`car'_e == thirty_car // if endline and 30mpg car was on the left
	}

	* which of the 2 product pairs were seen first at base and end
	gen first_pair_b = 1  // nissan
	replace first_pair_b = 2 if first_seen_base == "honda"
	gen first_pair_e = 1
	replace first_pair_e = 2 if first_seen_end == "honda"

	* dummies for first/second (baseline) and first/second (endline)
	gen first_baseline = 0
	gen second_baseline = 0
	gen first_endline = 0
	gen second_endline = 0

	replace first_baseline = 1 if first_pair_b == product_pair 
	replace second_baseline = 1 if first_pair_b != product_pair 

	replace first_endline = 1 if first_pair_e == product_pair 
	replace second_endline = 1 if first_pair_e != product_pair 

	* "strict" product-pair dummy that incorporates is_sh:
	* 1 = Nissan vs. Ford
	* 2 = Subaru-then-Honda vs. Ford
	* 3 = Honda-then-Subaru vs. Ford
	gen product_pair_strict = 0
	replace product_pair_strict = 1 if product_pair == 1
	replace product_pair_strict = 2 if (product_pair == 2 & is_sh == 1)
	replace product_pair_strict = 3 if (product_pair == 2 & is_sh == 0)

end 

add_dummies_and_FE


/*******************************************************************************
Label variables 
*******************************************************************************/

cap program drop label_vars 
program define label_vars

	* product_pair
	label var product_pair "Car product pair"
	label define pair 1 "Nissan vs. Ford" 2 "Honda/Subaru vs. Ford"
	label values product_pair pair

	* product_pair_strict
	label var product_pair_strict "Car product pair (strict)"
	label define pair_strict 1 "Nissan vs. Ford" 2 "SubaruHonda vs. Ford" 3 "HondaSubaru vs. Ford"
	label values product_pair_strict pair_strict

	* left_car_mpg_b
	label var left_car_mpg_b "MPG of car on left of MPL, baseline"
	label define mpg 0 "23 MPG" 1 "30 MPG"
	label values left_car_mpg_b mpg

	* left_car_mpg_e
	label var left_car_mpg_e "MPG of car on left of MPL, endline"
	label values left_car_mpg_e mpg

	* first_pair_b
	label var first_pair_b "First product pair seen, baseline"
	label define pair2 1 "Nissan vs. Ford" 2 "Honda/Subaru vs. Ford"
	label values first_pair_b pair2

	* first_pair_e
	label var left_car_mpg_e "First product pair seen, endline"
	label values first_pair_e pair2

	* binary indicators
	label var first_baseline "Comparison appeared first in baseline (binary)"
	label var second_baseline "Comparison appeared second in baseline (binary)"
	label var first_endline "Comparison appeared first in endline (binary)"
	label var second_endline "Comparison appeared second in endline (binary)"

	* is_sh
	label var is_sh "Order of Subaru/Honda alternating pair"
	label define subaru_honda 0 "Honda at base, Subaru at end" 1 "Subaru at base, Honda at end"
	label values is_sh subaru_honda

	* overvaluation_base
	label var overvaluation_b_median "Gamma proxy (median)"
	label var overvaluation_b_uncens "Gamma proxy (uncens)"

end 

label_vars


/*******************************************************************************
Add demand dummies for consumer WTP at different prices 
*******************************************************************************/

cap program drop gen_demand_dummies
program define gen_demand_dummies 

	forval j = 1/31 {
		gen demand_pre`j' = (wtp_b_median >= 100*`j' - 1600)
		gen demand_post`j' = (wtp_e_median >= 100*`j' - 1600)
	}

end 

gen_demand_dummies


/*******************************************************************************
Add distortion field equal to bias + externality;
externality = (1) * (2) * (3), where: 
	(1) = add'l gas consumption of lower-MPG car given miles_driven_2019
	(2) = Social Cost of Carbon ($51)
	(3) = CO2 content of gasoline (8.887 * 10^(-3) metric tons per gallon)  
*******************************************************************************/

cap program drop gen_ext_and_distortion
program define gen_ext_and_distortion 

	* create component columns 
	gen addl_gas_consumption = (miles_driven_2019 * 1000 / 23) - (miles_driven_2019 * 1000 / 30)
	gen SCC = 51
	gen gas_CO2_content = 0.00887

	* create externality column 
	gen externality = addl_gas_consumption * SCC * gas_CO2_content

	* create distortion column 
	gen distortion_b_median = overvaluation_b_median + externality 

end 

gen_ext_and_distortion


/*******************************************************************************
Add variable for "middle 50%" of WTP (consumers closer to the margin)
*******************************************************************************/

cap program drop gen_middle50_ind
program define gen_middle50_ind

	* get median of WTP distances from zero
	gen abs_wtp = abs(wtp_b_median)
	sum abs_wtp, d
	gen med_abs_wtp = r(p50)

	* identify WTPs that are above the median 
	gen abs_wtp_above_med = 0
	replace abs_wtp_above_med = 1 if abs_wtp > med_abs_wtp 

	* create column w/ total number of above-median WTPs by ID 
	bysort id: egen tot_abs_wtp_above_med = sum(abs_wtp_above_med)

	* assign binary middle50 indicator = 1 if ID has no WTPs above median
	gen middle50ind = 0
	replace middle50ind = 1 if tot_abs_wtp_above_med == 0

end  

gen_middle50_ind


/*******************************************************************************
Convert product pair to string  
*******************************************************************************/

cap program drop prod_pair_to_str
program define prod_pair_to_str

	* convert product pair to string
	tostring product_pair, generate(product_pair_str)
	replace product_pair_str = "Nissan vs. Ford" if product_pair_str == "1"
	replace product_pair_str = "Honda/Subaru vs. Ford" if product_pair_str == "2"

end 

prod_pair_to_str


/*******************************************************************************
Generate additional exclusion restrictions for testing w/ multiple
percentiles p and observation- & ID-based exclusion: 
	(1) top/bottom p% for enjoyment or gas 
	(2) (1) or top/bottom p% for baseline overvaluation
	(3) (1) or top/bottom p% for delta-WTP 
	(4) (1), (2), or (3)
	(5) (1) or off-MPL WTP 
	(6) (1) or (5)
*******************************************************************************/

capture program drop gen_exclusion_restrictions_p
program gen_exclusion_restrictions_p

	* define sole argument as p, the percentile taken off each end 
	* (e.g. p = 5 --> bottom is r(p5), top is r(p95))
	args p
	
	* generate top and bottom percentiles based on p
	local p_top = 100 - `p'
	local p_bottom = `p'
	
	************************************************************
	* Generate enjoyment & gas exclusion conditions
	************************************************************

	* ENJOYMENT RATING
	
	* generate individual condition flag variables
	gen baddata_cond_enjoy_obs_`p' = 0
	gen baddata_cond_enjoy_obs_`p's = 0

	* create flag on per-car basis
	foreach car in $new_car_names {
		* get enjoyment percentiles 
		sum `car'_enjoy, d
		gen `car'_enjoy_bottom_`p' = r(p`p_bottom')
		gen `car'_enjoy_top_`p' = r(p`p_top')
		
		* generate temporary enjoyment flag for each car
		gen baddata_cond_enjoy_obs_`car'_`p' = 0
		replace baddata_cond_enjoy_obs_`car'_`p' = 1 if (`car'_enjoy >= `car'_enjoy_top_`p' | ///
		`car'_enjoy <= `car'_enjoy_bottom_`p')
		
		* generate temporary STRICT enjoyment flag for each car 
		gen baddata_cond_enjoy_obs_`car'_`p's = 0
		replace baddata_cond_enjoy_obs_`car'_`p's = 1 if (`car'_enjoy > `car'_enjoy_top_`p' | ///
		`car'_enjoy < `car'_enjoy_bottom_`p')
	}

	* create overarching per-observation enjoyment flag using car-specific flags
	replace baddata_cond_enjoy_obs_`p' = 1 if product_pair_str == "Nissan vs. Ford" & (baddata_cond_enjoy_obs_nissan_`p' == 1 | ///
	baddata_cond_enjoy_obs_ford_`p' == 1)
	replace baddata_cond_enjoy_obs_`p' = 1 if product_pair_str == "Honda/Subaru vs. Ford" & (baddata_cond_enjoy_obs_honda_`p' == 1 | ///
	baddata_cond_enjoy_obs_subaru_`p' == 1 | baddata_cond_enjoy_obs_ford_`p' == 1)

	* create overarching STRICT per-observation enjoyment flag using car-specific flags
	replace baddata_cond_enjoy_obs_`p's = 1 if product_pair_str == "Nissan vs. Ford" & (baddata_cond_enjoy_obs_nissan_`p's == 1 | ///
	baddata_cond_enjoy_obs_ford_`p's == 1)
	replace baddata_cond_enjoy_obs_`p's = 1 if product_pair_str == "Honda/Subaru vs. Ford" & (baddata_cond_enjoy_obs_honda_`p's == 1 | ///
	baddata_cond_enjoy_obs_subaru_`p's == 1 | baddata_cond_enjoy_obs_ford_`p's == 1)
	
	* create per-ID enjoyment flag 
	egen baddata_cond_enjoy_id_`p' = max(baddata_cond_enjoy_obs_`p'), by(id)
	
	* create STRICT per-ID enjoyment flag 
	egen baddata_cond_enjoy_id_`p's = max(baddata_cond_enjoy_obs_`p's), by(id)

	* GAS COST PERCENTILES

	* iterate over all cars -- note that dodge and 
	* subaru are interchangeable 
	local temp_letters "n h s f"
	forval i=1/4 {
	
		* iterate over cars 
		local car : word `i' of $all_cars
		local letter : word `i' of `temp_letters'

		* create car-specific gas cost flag
		gen baddata_cond_gas_obs_`p'_`letter' = 0
		gen baddata_cond_gas_obs_`p's_`letter' = 0
		
		* generate gas cost percentiles 
		sum annual_gas_cost_`car', d
		gen annual_gas_cost_`car'_bottom_`p' = r(p`p_bottom')
		gen annual_gas_cost_`car'_top_`p' = r(p`p_top')
		
		* identify upper- and lower-tail gas-cost observations for spec. car
		replace baddata_cond_gas_obs_`p'_`letter' = 1 if (annual_gas_cost_`car' >= annual_gas_cost_`car'_top_`p' | ///
			annual_gas_cost_`car' <= annual_gas_cost_`car'_bottom_`p')
		replace baddata_cond_gas_obs_`p's_`letter' = 1 if (annual_gas_cost_`car' > annual_gas_cost_`car'_top_`p' | ///
			annual_gas_cost_`car' < annual_gas_cost_`car'_bottom_`p')
		
	}
	
	* aggregate car-spec. flags into overarching flag for each observation 
	gen baddata_cond_gas_obs_`p' = max(baddata_cond_gas_obs_`p'_n, baddata_cond_gas_obs_`p'_h, ///
	                                   baddata_cond_gas_obs_`p'_s, baddata_cond_gas_obs_`p'_f)
	gen baddata_cond_gas_obs_`p's = max(baddata_cond_gas_obs_`p's_n, baddata_cond_gas_obs_`p's_h, ///
	                                    baddata_cond_gas_obs_`p's_s, baddata_cond_gas_obs_`p's_f)
	
	* create per-ID gas flag 
	egen baddata_cond_gas_id_`p' = max(baddata_cond_gas_obs_`p'), by(id)
	
	* create STRICT per-ID gas flag 
	egen baddata_cond_gas_id_`p's = max(baddata_cond_gas_obs_`p's), by(id)	
	
	* COMBINING ENJOYMENT & GAS COST INTO ONE FLAG
	
	* generate condition flag for the two combined (per-observation basis)
	gen baddata_cond_enjoy_gas_obs_`p' = max(baddata_cond_enjoy_obs_`p', baddata_cond_gas_obs_`p')

	* generate STRICT condition flag for the two combined (per-observation basis)
	gen baddata_cond_enjoy_gas_obs_`p's = max(baddata_cond_enjoy_obs_`p's, baddata_cond_gas_obs_`p's)

	* generate bad data condition (per-ID basis)
	egen baddata_cond_enjoy_gas_id_`p' = max(baddata_cond_enjoy_gas_obs_`p'), by(id)
	
	* generate STRICT bad data condition (per-ID basis)
	egen baddata_cond_enjoy_gas_id_`p's = max(baddata_cond_enjoy_gas_obs_`p's), by(id)


	************************************************************
	* Generate baseline overvaluation exclusion condition
	************************************************************

	* generate variables
	gen baddata_cond_ov_b_obs_`p' = 0
	gen baddata_cond_ov_b_obs_`p's = 0

	* get baseline overvaluation percentiles
	sum overvaluation_b_uncens, d
	gen ov_b_uncens_bottom_`p' = r(p`p_bottom')
	gen ov_b_uncens_top_`p' = r(p`p_top')

	* create observation-based flag based on percentiles
	replace baddata_cond_ov_b_obs_`p' = 1 if (overvaluation_b_uncens >= ov_b_uncens_top_`p') | ///
	(overvaluation_b_uncens <= ov_b_uncens_bottom_`p')

	* create STRICT observation-based flag based on percentiles
	replace baddata_cond_ov_b_obs_`p's = 1 if (overvaluation_b_uncens > ov_b_uncens_top_`p') | ///
	(overvaluation_b_uncens < ov_b_uncens_bottom_`p')

	* generate new bad data condition based on IDs, not observations
	egen baddata_cond_ov_b_id_`p' = max(baddata_cond_ov_b_obs_`p'), by(id)

	* generate new STRICT bad data condition based on IDs, not observations
	egen baddata_cond_ov_b_id_`p's = max(baddata_cond_ov_b_obs_`p's), by(id)

	
	************************************************************
	* Generate delta WTP exclusion condition
	************************************************************

	* generate variables
	gen baddata_cond_delta_wtp_obs_`p' = 0
	gen baddata_cond_delta_wtp_obs_`p's = 0

	* iterate through treatment groups 
	local treatments = "1 2 3 4 5"
	foreach t in `treatments' {
		preserve
		
		* get percentiles for that treatment group
		keep if T == `t'
		sum delta_wtp_uncens, d
		scalar delta_wtp_uncens_bottom_`p' = r(p`p_bottom')
		scalar delta_wtp_uncens_top_`p' = r(p`p_top')
		
		restore
		
		* determine membership in exclusion restriction group for particular treatment
		gen delta_wtp_`t'_topbottom_`p' = (delta_wtp_uncens <= scalar(delta_wtp_uncens_bottom_`p')) | ///
		(delta_wtp_uncens >= scalar(delta_wtp_uncens_top_`p'))
		
		* determine membership in STRICT exclusion restriction group for particular treatment
		gen delta_wtp_`t'_topbottom_`p's = (delta_wtp_uncens < scalar(delta_wtp_uncens_bottom_`p')) | ///
		(delta_wtp_uncens > scalar(delta_wtp_uncens_top_`p'))
	}

	foreach t in `treatments' {
	
		* summarize across all treatment groups depending on membership
		replace baddata_cond_delta_wtp_obs_`p' = 1 if (T == `t') & (delta_wtp_`t'_topbottom_`p' == 1)
		
		* summarize across all treatment groups (STRICT) depending on membership
		replace baddata_cond_delta_wtp_obs_`p's = 1 if (T == `t') & (delta_wtp_`t'_topbottom_`p's == 1)
	}

	* generate new bad data condition based on IDs, not observations
	egen baddata_cond_delta_wtp_id_`p' = max(baddata_cond_delta_wtp_obs_`p'), by(id)

	* generate new STRICT bad data condition based on IDs, not observations
	egen baddata_cond_delta_wtp_id_`p's = max(baddata_cond_delta_wtp_obs_`p's), by(id)


	************************************************************
	* Generate exclusion restrictions based on conditions
	************************************************************

	* #s 1-4 correspond to restrictions in following document:
	* https://docs.google.com/document/d/1AF-qfvqP5f2aom2xLJDE_702nrNPjVDNBAo3MFw1Epo/edit?usp=sharing

	* OBSERVATION-BASED EXCLUSION

	gen baddata1_obs_`p' = baddata_cond_enjoy_gas_obs_`p'

	gen baddata2_obs_`p' = 0
	replace baddata2_obs_`p' = 1 if (baddata1_obs_`p' == 1) | (baddata_cond_ov_b_obs_`p' == 1)

	gen baddata3_obs_`p' = 0
	replace baddata3_obs_`p' = 1 if (baddata1_obs_`p' == 1) | (baddata_cond_delta_wtp_obs_`p' == 1)

	gen baddata4_obs_`p' = 0
	replace baddata4_obs_`p' = 1 if (baddata1_obs_`p' == 1) | (baddata2_obs_`p' == 1) | (baddata3_obs_`p' == 1)

	gen baddata5_obs_`p' = 0
	replace baddata5_obs_`p' = 1 if (baddata1_obs_`p' == 1) | (baddata_cond_b_wtp_cens_obs == 1)
	
	gen baddata6_obs_`p' = 0
	replace baddata6_obs_`p' = 1 if (baddata4_obs_`p' == 1) | (baddata5_obs_`p' == 1)

	
	* ID-BASED EXCLUSION

	gen baddata1_id_`p' = baddata_cond_enjoy_gas_id_`p'

	gen baddata2_id_`p' = 0
	replace baddata2_id_`p' = 1 if (baddata1_id_`p' == 1) | (baddata_cond_ov_b_id_`p' == 1)

	gen baddata3_id_`p' = 0
	replace baddata3_id_`p' = 1 if (baddata1_id_`p' == 1) | (baddata_cond_delta_wtp_id_`p' == 1)

	gen baddata4_id_`p' = 0
	replace baddata4_id_`p' = 1 if (baddata1_id_`p' == 1) | (baddata2_id_`p' == 1) | (baddata3_id_`p' == 1)

	gen baddata5_id_`p' = 0
	replace baddata5_id_`p' = 1 if (baddata1_id_`p' == 1) | (baddata_cond_b_wtp_cens_id == 1)

	gen baddata6_id_`p' = 0
	replace baddata6_id_`p' = 1 if (baddata4_id_`p' == 1) | (baddata5_id_`p' == 1)

	* ID-BASED EXCLUSION (STRICT)

	gen baddata1_id_`p's = baddata_cond_enjoy_gas_id_`p's

	gen baddata2_id_`p's = 0
	replace baddata2_id_`p's = 1 if (baddata1_id_`p's == 1) | (baddata_cond_ov_b_id_`p's == 1)

	gen baddata3_id_`p's = 0
	replace baddata3_id_`p's = 1 if (baddata1_id_`p's == 1) | (baddata_cond_delta_wtp_id_`p's == 1)

	gen baddata4_id_`p's = 0
	replace baddata4_id_`p's = 1 if (baddata1_id_`p's == 1) | (baddata2_id_`p's == 1) | (baddata3_id_`p's == 1)

end 


/*******************************************************************************
Design function to generate all conditions that are not dependent 
on a particular percentile (static)
*******************************************************************************/

capture program drop gen_exclusion_conditions_s
program gen_exclusion_conditions_s

	************************************************************
	* Generate off-MPL baseline WTP exclusion condition
	************************************************************

	* generate off-MPL baseline WTP exclusion condition (per observation)
	gen baddata_cond_b_wtp_cens_obs = 0
	replace baddata_cond_b_wtp_cens_obs = 1 if abs(wtp_b_uncens) > 1500
	
	* generate same exclusion condition (per ID)
	egen baddata_cond_b_wtp_cens_id = max(baddata_cond_b_wtp_cens_obs), by(id)
		
end 


/*******************************************************************************
Generate all exclusion restrictions and baddata flags 
*******************************************************************************/

cap program drop gen_all_restriction_flags
program define gen_all_restriction_flags

	local percentile_exclusions = "4 6"
	local static_exclusions = ""
	local exclusions = "4 6"

	// local mpl_baseline_endline = "b e"
	local exclusion_types = "obs id"
	local percentiles = "1 5"

	* drop enjoyment/gas fields from build that we want to recreate
	foreach car in $all_cars {
		capture drop `car'_enjoy_bottom `car'_enjoy_top
		capture drop annual_gas_cost_`car'_bottom annual_gas_cost_`car'_top
	}

	* generate static exclusion condition (NOT one of the numbered restrictions on its own)
	gen_exclusion_conditions_s

	* generate exclusion restrictions/WTPs that depend on percentile
	foreach p in `percentiles' {
	
		* generate conditions and baddata flags for each percentile
		gen_exclusion_restrictions_p `p'
		
	}
	
	* label final baddata flag (baddata4_id_5) something neater for later use 
	rename baddata4_id_5 baddata_final
	
end 

gen_all_restriction_flags


/*******************************************************************************
Export number of observations dropped with final baddata flag (baddata4_id_5)
*******************************************************************************/

cap program drop export_final_num_obs_dropped
program define export_final_num_obs_dropped 
	preserve 

	distinct amerispeak_id_hashed
	local sample_size_pre: di r(ndistinct)

	keep if baddata_final == 0

	distinct amerispeak_id_hashed
	local sample_size_post: di r(ndistinct)
	local reduction = `sample_size_pre' - `sample_size_post'
	latex_rounded, name("carsSampleSizeBadDataReduction") value(`reduction') digits(0)

	restore 
end 

export_final_num_obs_dropped


/*******************************************************************************
Reorder variables
*******************************************************************************/

cap program drop reorder_vars
program define reorder_vars 

	order id wtp_b_median wtp_e_median delta_wtp_median ///
	wtp_b_uncens wtp_e_uncens delta_wtp_uncens ///
	overvaluation_b_median overvaluation_e_median ///
	overvaluation_b_uncens overvaluation_e_uncens ///
	product_pair is_sh left_car_mpg_b left_car_mpg_e ///
	first_pair_b first_pair_e ///
	diff_in_enjoy_minus_gas_b diff_in_enjoy_minus_gas_e ///
	nissan_enjoy honda_enjoy subaru_enjoy ford_enjoy ///
	nissan_lease_wtp_b nissan_lease_wtp_e ///
	honda_lease_wtp_b honda_lease_wtp_e ///
	dodge_lease_wtp_b_nissan dodge_lease_wtp_b_honda ///
	ford_lease_wtp_e_nissan ford_lease_wtp_e_honda

end 

reorder_vars


/*******************************************************************************
Compress and save
*******************************************************************************/

cap program drop export_final_proc_dataset
program define export_final_proc_dataset

	qui compress
	save "$rootdir/cars/intermediate_data/merged.dta", replace 

end 

export_final_proc_dataset
