/*******************************************************************************
TITLE: pre_build.do
AUTHOR(S): Daniel Cohen 
DESCRIPTION: Reads in raw cars survey data, removes unnecessary fields, and
             deidentifies Amerispeak IDs. 
DATE LAST MODIFIED: APR 2024
FILE(S) USED: 
    - cars_only.csv (raw data from cars experiment)
    - regular.csv (raw data from cars experiment)
    - modified.csv (raw data from cars experiment)
	- client_demos.csv (raw demographic data from Amerispeak)
*******************************************************************************/

clear all

/*******************************************************************************
Remove unnecessary fields for 'cars_only' dataset and export resulting dataset. 
*******************************************************************************/

cap program drop clean_cars_only_dataset
program define clean_cars_only_dataset

	* import data 
	import delimited "$rootdir/cars/input/data_with_PII/cars_only.csv", varnames(1)

	* drop two extra rows in CSV 
	drop in 1/2

	* rename and drop fields to match rest of build
	rename state_of_res_1 county_of_res_1
	rename v308 amerispeak_id 
	drop p

	* generate missing values for financial literacy
	local numeracy_vars "fi006 fi007 fi008"
	foreach q in `numeracy_vars' {
		gen `q' = ""
	}

	* label everyone in cars-only as car user
	gen car_user = "Yes"

	* remove unnecessary fields 
	local vars_to_keep = "car_user enddate county_of_res_1 miles_driven_2019 " + ///
						 "gas_price_estimate treatment cstatus " + ///
						 "*_enjoy_js *_l *_r " + ///
						 "amerispeak_id " + ///
						 "nissan_lease_wtp_b nissan_lease_wtp_e " + ///
						 "honda_lease_wtp_b honda_lease_wtp_e " + ///
						 "dodge_lease_wtp_b_nissan dodge_lease_wtp_b_honda " + ///
						 "ford_lease_wtp_e_nissan ford_lease_wtp_e_honda " + ///
						 "gas_cost_thirty gas_cost_twentythree " + ///
						 "first_seen_base first_seen_end " + ///
						 "left_car_nissan_base left_car_nissan_end " + ///
						 "left_car_honda_base left_car_honda_end " + ///
						 "is_sh is_mobile variable_incentive_dollars " + ///
						 "nissan_enjoy1 nissan_enjoy2 honda_enjoy1 " + ///
						 "honda_enjoy2 subaru_enjoy1 subaru_enjoy2 " + ///
						 "ford_enjoy1 ford_enjoy2" 
	keep `vars_to_keep' `numeracy_vars'

	* export semi-processed data 
	qui compress
	save "$rootdir/cars/input/data_with_PII/cars_only", replace

end 

clean_cars_only_dataset


/*******************************************************************************
Remove unnecessary fields for 'regular' dataset and export resulting dataset. 
*******************************************************************************/

cap program drop clean_regular_dataset
program define clean_regular_dataset

	clear 
	
	* import data 
	import delimited "$rootdir/cars/input/data_with_PII/regular.csv", varnames(1)

	* drop two extra rows in CSV 
	drop in 1/2

	* ensure amerispeak ID correctly identified  
	rename v362 amerispeak_id 

	* remove unnecessary fields 
	keep `vars_to_keep' `numeracy_vars'

	* export semi-processed data 
	qui compress
	save "$rootdir/cars/input/data_with_PII/regular", replace

end 

clean_regular_dataset


/*******************************************************************************
Remove unnecessary fields for 'modified' dataset and export resulting dataset. 
*******************************************************************************/

cap program drop clean_modified_dataset
program define clean_modified_dataset

	clear 

	* imort data 
	import delimited "$rootdir/cars/input/data_with_PII/modified.csv", varnames(1)

	* drop two extra rows in CSV 
	drop in 1/2

	* ensure amerispeak ID correctly identified 
	rename v366 amerispeak_id

	* remove unnecessary fields 
	keep `vars_to_keep' `numeracy_vars'

	* export semi-processed data 
	qui compress
	save "$rootdir/cars/input/data_with_PII/modified", replace

end 

clean_modified_dataset


/*******************************************************************************
Combine three datasets and remove Amerispeak test observations.
*******************************************************************************/

cap program drop combine_datasets
program define combine_datasets 

clear 

	* read and combine datasets  
	use "$rootdir/cars/input/data_with_PII/modified"
	append using "$rootdir/cars/input/data_with_PII/cars_only" ///
				 "$rootdir/cars/input/data_with_PII/regular"

	* clean up: p values == 6 are test IDs; real IDs are < 6 digits, 
	* equal to 8 digits, or 7 digits beginning with "333"
	keep if strlen(amerispeak_id) < 6 | strlen(amerispeak_id) == 8 | ///
		   (strlen(amerispeak_id) == 7 & substr(amerispeak_id, 1, 3) == "333")

end 

combine_datasets


/*******************************************************************************
Define func. to hash Amerispeak IDs so they can be used 
for linking later w/o PII.

FUNC NAME: hash_PII
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Hashes email addresses. 
*******************************************************************************/

capture program drop hash_PII
program define hash_PII
	syntax, amerispeak_id(int) 
	
	if (`amerispeak_id' == 1) {
		
		* ensure Amerispeak ID is string for hashing 
		tostring amerispeak_id, replace
		
		* generate new variables to store hashed amerispeak_id 
		gen str64 amerispeak_id_hashed = ""
		
	}
	
	* conduct SHA-256 hashing in Java
	hash_pii_java `amerispeak_id' 
	
	* replace hashed values with empty string if original is also empty string
	replace amerispeak_id_hashed = "" if amerispeak_id == ""
	
end


/*******************************************************************************
Hash and replace Amerispeak ID
*******************************************************************************/

hash_PII, amerispeak_id(1) 
drop amerispeak_id


/*******************************************************************************
Export combined & PII-free dataset 
*******************************************************************************/

cap program drop export_no_PII_dataset
program define export_no_PII_dataset

	save "$rootdir/cars/input/surveys_combined.dta", replace

end 

export_no_PII_dataset


/*******************************************************************************
Read in client_demos.csv and anonymize Amerispeak ID
*******************************************************************************/

cap program drop import_client_demos
program define import_client_demos
 
	clear 

	* import data 
	import delimited "$rootdir/cars/input/data_with_PII/client_demos.csv", ///
		   varnames(1) encoding("utf-8")
	   
end 

import_client_demos


/*******************************************************************************
Hash and replace Amerispeak ID in client_demos 
*******************************************************************************/

hash_PII, amerispeak_id(1) 
drop amerispeak_id


/*******************************************************************************
Export PII-free version of client_demos 
*******************************************************************************/

cap program drop export_no_PII_client_demos
program define export_no_PII_client_demos

	save "$rootdir/cars/input/client_demos", replace

end 

export_no_PII_client_demos

