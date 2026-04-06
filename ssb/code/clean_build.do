version 18

/*******************************************************************************
TITLE: clean_build.do
AUTHOR(S): Daniel Cohen <-- Victoria Pu 
DESCRIPTION: Reads in PII-free raw data and produces cleaned/processed dataset
	for the SSB experiment. 
DATE LAST MODIFIED: APR 2024
FILE(S) USED: 
    - [ssb/input/] survey2.csv 
    - [ssb/input/] survey1.csv 
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
Set globals across analysis.
*******************************************************************************/

cap program drop set_globals 
program define set_globals

	* drink names, MPL baseline vs. endline, endline labels 

	global ssb_drink_names = "lemonade coke pepsi seagrams sprite crush"
	global all_drink_names = "lemonade coke pepsi seagrams sprite crush lacroix"
	global mpl_base_or_end = "b e"
	global endlines = "c g n w"
	global endlines_wo_control = "g n w"
	
end 

set_globals


/*******************************************************************************
Import Part 2 data 
*******************************************************************************/

cap program drop import_part2_data
program define import_part2_data

	* import data 
	use "$rootdir/ssb/input/survey2", clear

end 

import_part2_data


/*******************************************************************************
Perform basic cleaning of Part 2 data 
*******************************************************************************/

cap program drop clean_part2_data 
program define clean_part2_data 

	* exclude those who did not finish part 2 of the experiment
	destring part2allquestionsanswered, replace 
	drop if part2allquestionsanswered == 0

	* drop duplicates from master (Part 2 responses), if any, based on hashed 
	* email address; keep the first response in the event of duplicates 
	gsort contactemail_hashed enddate
	quietly by contactemail: gen dup_email = cond(_N==1,0,_n) 
	drop if dup_email > 1

	* generate a subject id variable and move it to the left when browsing
	gen id = _n
	order id

end 

clean_part2_data


/*******************************************************************************
Collect WTP estimates. For censored responses, will need to manually 
overwrite Qualtrics exported value. 
*******************************************************************************/

cap program drop gen_WTP_estimates
program define gen_WTP_estimates

	* destring self-reported WTP entries (i.e. left and right censored entries)
	* and pre-calculated WTPs
	foreach drink in $ssb_drink_names {
		qui: destring wtp_`drink'_b, replace float
		qui: destring wtp_`drink'_e, replace float
		
		qui: destring `drink'_b_left, replace float
		qui: destring `drink'_b_right, replace float

		foreach end in $endlines {
			qui: destring `drink'_`end'_left, replace float
			qui: destring `drink'_`end'_right, replace float
		}
	}

	* replace censored WTP with self-reported values at endline and baseline
	foreach drink in $ssb_drink_names {
		foreach end in $endlines {
			di "`drink' `end' left"
			qui: replace wtp_`drink'_e = `drink'_`end'_left - 4 if `drink'_`end'_left != .
			
			di "`drink' `end' right"
			qui: replace wtp_`drink'_e = `drink'_`end'_right - 4 if `drink'_`end'_right != .
		}
	}

	foreach drink in $ssb_drink_names {
		qui: replace wtp_`drink'_b = `drink'_b_left - 4 if `drink'_b_left != .
		qui: replace wtp_`drink'_b = `drink'_b_right - 4 if `drink'_b_right != .
	}
	
	* rename _b/_e to _base/_end for consistency throughout build
	foreach drink in $ssb_drink_names {
		rename wtp_`drink'_b wtp_`drink'_base
		rename wtp_`drink'_e wtp_`drink'_end
	}

end 

gen_WTP_estimates


/*******************************************************************************
Identify treatment conditions and rename variables for consistency 
*******************************************************************************/

cap program drop clean_treatments
program define clean_treatments

	* identify treatment assigned to each individual
	qui: replace treatment = "control" if treatment == "1"
	qui: replace treatment = "graphic" if treatment == "2"
	qui: replace treatment = "nutrition" if treatment == "3"
	qui: replace treatment = "stoplight" if treatment == "4"

end

clean_treatments


/*******************************************************************************
Save processed Part 2 dataset. It is called "merged" because it will 
later be merged with the Part 1 data. 
*******************************************************************************/

cap program drop export_cleaned_part2_data
program define export_cleaned_part2_data

	qui compress
	save "$rootdir/ssb/intermediate_data/merged", replace 

end 

export_cleaned_part2_data


/*******************************************************************************
Import Survey I (no PII)
*******************************************************************************/

cap program drop import_part1_data
program define import_part1_data 

	* import data 
	use "$rootdir/ssb/input/survey1", clear

end 

import_part1_data


/*******************************************************************************
Export num. of consented participants 
*******************************************************************************/

cap program drop export_num_consented
program define export_num_consented
	preserve 

	drop if eligible == "0"
	local sample_size:  di _N
	latex_rounded, name("ssbSampleSizeConsented") value(`sample_size') digits(0)

	restore 
end 

export_num_consented


/*******************************************************************************
Perform preliminary cleaning of Part 1 data  
*******************************************************************************/

cap program drop clean_part1_data
program define clean_part1_data

	* exclude those who did not finish the experiment
	destring part1allquestionsanswered, replace
	drop if part1allquestionsanswered == 0 | age == "" 

	* exclude those who are below the age cutoff
	destring age, replace
	drop if age < 18

	* drop duplicates based on hashed email address and phone number;
	* keep the first response if duplicate detected 
	gsort contactemail_hashed enddate
	quietly by contactemail_hashed: gen dup_email = cond(_N==1,0,_n) 
	drop if dup_email > 1

	gsort contactphone_hashed enddate
	quietly by contactphone_hashed: gen dup_phone = cond(_N==1,0,_n) 
	drop if dup_phone > 1

end 

clean_part1_data


/*******************************************************************************
Export num. participants that finished Part 1 (incl. attention check) 
*******************************************************************************/

cap program drop export_num_finished_part1
program define export_num_finished_part1
	preserve 

	destring part1attentioncheckfailed, replace

	drop if part1allquestionsanswered == .
	drop if part1attentioncheckfailed == 1
	local sample_size:  di _N
	latex_rounded, name("ssbSampleSizeFinishedPartOne") value(`sample_size') digits(0)

	restore 
end 

export_num_finished_part1


/*******************************************************************************
Merge Part 1 and Part 2 data for later use. This includes labeling those 
who failed attention checks/didn't complete both parts.
*******************************************************************************/

cap program drop merge_part1_part2
program define merge_part1_part2

	* save Survey I responses as temp
	tempfile survey1
	save "$rootdir/ssb/intermediate_data/survey1_temp.dta", replace

	* perform merge w/ Survey II responses on hashed email address
	use "$rootdir/ssb/intermediate_data/merged.dta", clear

	merge 1:1 contactemail_hashed using "$rootdir/ssb/intermediate_data/survey1_temp.dta"

	* drop hashed contact email and phone number
	drop contactemail_hashed contactphone_hashed

	* immediately drop those who didn't complete Survey I 
	drop if id == . 
	drop if part1allquestionsanswered == .

	* identify those who completed both surveys but failed one or more 
	* attention checks -- they are not immediately dropped, but will 
	* be excluded in the analysis
	destring part1attentioncheckfailed part2attentioncheckfailed, replace
	gen insample = 1
	replace insample = 0 if part1attentioncheckfailed == 1
	replace insample = 0 if part2attentioncheckfailed == 1
	
end 

merge_part1_part2


/*******************************************************************************
Export final post-merge, post-cleaning sample size (incl. those who completed
both parts, passed both attention checks, and met age cutoffs)
*******************************************************************************/

cap program drop export_final_sample_size
program define export_final_sample_size
	preserve 

	keep if insample == 1

	distinct id 
	local sample_size:  di r(ndistinct)
	latex_rounded, name("ssbSampleSizeFinal") value(`sample_size') digits(0)

	restore 
end 

export_final_sample_size


/*******************************************************************************
Export merged dataset  
*******************************************************************************/

cap program drop export_merged_dataset
program define export_merged_dataset

	save "$rootdir/ssb/intermediate_data/merged", replace

end 

export_merged_dataset


/*******************************************************************************
Clean any categorical fields that are needed for future analysis 
*******************************************************************************/

cap program drop clean_categorical_vars
program define clean_categorical_vars 

	* generate treatment number 
	gen treatment_number = 1
	replace treatment_number = 2 if treatment == "graphic"
	replace treatment_number = 3 if treatment == "nutrition"
	replace treatment_number = 4 if treatment == "stoplight"

	* convert factors to binary
	replace sex = "1" if sex == "Male"
	replace sex = "0" if sex != "1"
	destring sex, replace 
	rename sex male

	* generate variable for college 
	gen college = education
	replace college = "1" if college == "Bachelor's degree (for example: BA, BS)" | college == "Above bachelor's degree (for example: MA, MBA, MD, JD, PhD)"
	replace college = "0" if college != "1"
	destring college, replace

	* generate variable for education (years)
	gen education_num = 10 if education == "Less than high school"
	replace education_num = 12 if education == "High school diploma or GED"
	replace education_num = 14 if education == "Associate's degree (for example: AA, AS)"
	replace education_num = 16 if education == "Bachelor's degree (for example: BA, BS)"
	replace education_num = 18 if education == "Above bachelor's degree (for example: MA, MBA, MD, JD, PhD)"

	* generate variable for white 
	gen white = race
	replace white = "1" if white == "White"
	replace white = "0" if white != "1"
	destring white, replace

	* generate variable for black 
	gen black = race
	replace black = "1" if black == "Black or African American"
	replace black = "0" if black != "1"
	destring black, replace

	* assign each person an income level equal to the median income of their reported segment
	replace income = "5" if income == "0 to $10,000"
	replace income = "15" if income == "$10,000 to $20,000"
	replace income = "25" if income == "$20,000 to $30,000"
	replace income = "35" if income == "$30,000 to $40,000"
	replace income = "45" if income == "$40,000 to $50,000"
	replace income = "55" if income == "$50,000 to $60,000"
	replace income = "65" if income == "$60,000 to $70,000"
	replace income = "75" if income == "$70,000 to $80,000"
	replace income = "85" if income == "$80,000 to $90,000"
	replace income = "95" if income == "$90,000 to $100,000"
	replace income = "112.5" if income == "$100,000 to $125,000"
	replace income = "137.5" if income == "$125,000 to $150,000"
	replace income = "150" if income == "$150,000 and above"
	destring income, replace

	destring age, replace

	* Self-control: self-reported frequency of sugary drinks
	gen self_control = 1
	replace self_control = float(2/3) if self_frequency_1 == "Somewhat"
	replace self_control = float(1/3) if self_frequency_1 == "Mostly"
	replace self_control = 0 if self_frequency_1 == "Definitely"

	destring health_importance_1, replace
	replace health_importance_1 = float(health_importance_1 / 10)

end 

clean_categorical_vars


/*******************************************************************************
Convert responses for nutrition knowledge questions to meaningful form
*******************************************************************************/

cap program drop process_nutrition_responses
program define process_nutrition_responses

	* general nutrition knowledge questions 

	// V28
	forval q = 1/8 {
		replace more_same_less_`q' = "1" if more_same_less_`q' == "More"
		replace more_same_less_`q' = "2" if more_same_less_`q' == "Same"
		replace more_same_less_`q' = "3" if more_same_less_`q' == "Less"
		replace more_same_less_`q' = "4" if more_same_less_`q' == "Not sure"
		destring more_same_less_`q', replace
	}
	// V29
	forval q = 1/3 {
		replace more_less_fats_`q' = "1" if more_less_fats_`q' == "Eat less"
		replace more_less_fats_`q' = "2" if more_less_fats_`q' == "Not eat less"
		replace more_less_fats_`q' = "3" if more_less_fats_`q' == "Not sure"
		destring more_less_fats_`q', replace
	}
	// V30
	forval q = 1/5 {
		replace high_low_sugar_`q' = "1" if high_low_sugar_`q' == "High in added sugar"
		replace high_low_sugar_`q' = "2" if high_low_sugar_`q' == "Low in added sugar"
		replace high_low_sugar_`q' = "3" if high_low_sugar_`q' == "Not sure"
		destring high_low_sugar_`q', replace
	}
	// V31
	forval q = 1/6 {
		replace high_low_salt_`q' = "1" if high_low_salt_`q' == "High in salt"
		replace high_low_salt_`q' = "2" if high_low_salt_`q' == "Low in salt"
		replace high_low_salt_`q' = "3" if high_low_salt_`q' == "Not sure"
		destring high_low_salt_`q', replace
	}
	// V32
	forval q = 1/6 {
		replace high_low_fiber_`q' = "1" if high_low_fiber_`q' == "High in fiber"
		replace high_low_fiber_`q' = "2" if high_low_fiber_`q' == "Low in fiber"
		replace high_low_fiber_`q' = "3" if high_low_fiber_`q' == "Not sure"
		destring high_low_fiber_`q', replace
	}
	// V33
	forval q = 1/6 {
		replace protein_source_`q' = "1" if protein_source_`q' == "Good source of protein"
		replace protein_source_`q' = "2" if protein_source_`q' == "Not a good source of protein"
		replace protein_source_`q' = "3" if protein_source_`q' == "Not sure"
		destring protein_source_`q', replace
	}
	// V34
	forval q = 1/5 {
		replace starchy_foods_`q' = "1" if starchy_foods_`q' == "Starchy food"
		replace starchy_foods_`q' = "2" if starchy_foods_`q' == "Not a starchy food"
		replace starchy_foods_`q' = "3" if starchy_foods_`q' == "Not sure"
		destring starchy_foods_`q', replace
	}
	// V35
	forval q = 1/4 {
		replace main_fat_`q' = "1" if main_fat_`q' == "Polyunsaturated fat"
		replace main_fat_`q' = "2" if main_fat_`q' == "Monounsaturated fat"
		replace main_fat_`q' = "3" if main_fat_`q' == "Saturated fat"
		replace main_fat_`q' = "4" if main_fat_`q' == "Cholesterol"
		replace main_fat_`q' = "5" if main_fat_`q' == "Not sure"
		destring main_fat_`q', replace
	}
	// V36
	replace most_trans_fat = "1" if most_trans_fat == "Biscuits, cakes, and pastries"
	replace most_trans_fat = "2" if most_trans_fat == "Fish"
	replace most_trans_fat = "3" if most_trans_fat == "Rapeseed oil"
	replace most_trans_fat = "4" if most_trans_fat == "Eggs"
	replace most_trans_fat = "5" if most_trans_fat == "Not sure"
	destring most_trans_fat, replace

	// V37
	replace milk_calcium = "1" if milk_calcium == "Much higher"
	replace milk_calcium = "2" if milk_calcium == "About the same"
	replace milk_calcium = "3" if milk_calcium == "Much lower"
	replace milk_calcium = "4" if milk_calcium == "Not sure"
	destring milk_calcium, replace

	// V38
	replace most_calories = "1" if most_calories == "Sugar"
	replace most_calories = "2" if most_calories == "Starch"
	replace most_calories = "3" if most_calories == "Fiber/roughage"
	replace most_calories = "4" if most_calories == "Fat"
	replace most_calories = "5" if most_calories == "Not sure"
	destring most_calories, replace

	// V39
	replace yogurts = "1" if yogurts == "0% fat cherry yogurt"
	replace yogurts = "2" if yogurts == "Plain yogurt"
	replace yogurts = "3" if yogurts == "Creamy fruit yogurt"
	replace yogurts = "4" if yogurts == "Not sure"
	destring yogurts, replace

	// V40
	replace soups = "1" if soups == "Mushroom risotto soup (eld mushrooms, porcini mushrooms, arborio rice, butter, cream, parsley and cracked black pepper)"
	replace soups = "2" if soups == "Carrot, butternut squash and spice soup (carrot, butternut squash, sweet potato, cumin, red chilies, coriander seeds and lemon)"
	replace soups = "3" if soups == "Cream of chicken soup (British chicken, onions, carrots, celery, potatoes, garlic, sage, wheat flour, double cream)"
	replace soups = "4" if soups == "Not sure"
	destring soups, replace

	// V41
	replace salad_combos = "1" if salad_combos == "Lettuce, green peppers and cabbage"
	replace salad_combos = "2" if salad_combos == "Broccoli, carrot and tomatoes"
	replace salad_combos = "3" if salad_combos == "Red peppers, tomatoes and lettuce"
	replace salad_combos = "4" if salad_combos == "Not sure"
	destring salad_combos, replace

	// V42
	replace add_flavor = "1" if add_flavor == "Coconut milk"
	replace add_flavor = "2" if add_flavor == "Herbs"
	replace add_flavor = "3" if add_flavor == "Soy sauce"
	replace add_flavor = "4" if add_flavor == "Not sure"
	destring add_flavor, replace

	// V43
	replace sugar_disease = "1" if sugar_disease == "High blood pressure"
	replace sugar_disease = "2" if sugar_disease == "Tooth decay"
	replace sugar_disease = "3" if sugar_disease == "Anemia"
	replace sugar_disease = "4" if sugar_disease == "Not sure"
	destring sugar_disease, replace

	// V44
	replace salt_disease = "1" if salt_disease == "Hypothyroidism"
	replace salt_disease = "2" if salt_disease == "Diabetes"
	replace salt_disease = "3" if salt_disease == "High blood pressure"
	replace salt_disease = "4" if salt_disease == "Not sure"
	destring salt_disease, replace

	// V45
	replace prevt_heart_disease = "1" if prevt_heart_disease == "Taking nutritional supplements"
	replace prevt_heart_disease = "2" if prevt_heart_disease == "Eating less oily fish"
	replace prevt_heart_disease = "3" if prevt_heart_disease == "Eating less trans-fats"
	replace prevt_heart_disease = "4" if prevt_heart_disease == "Not sure"
	destring prevt_heart_disease, replace

	// V46
	replace prevent_diabetes = "1" if prevent_diabetes == "Eating less refined foods"
	replace prevent_diabetes = "2" if prevent_diabetes == "Drinking more fruit juice"
	replace prevent_diabetes = "3" if prevent_diabetes == "Eating more processed meat"
	replace prevent_diabetes = "4" if prevent_diabetes == "Not sure"
	destring prevent_diabetes, replace

	// V47
	replace raise_cholesterol = "1" if raise_cholesterol == "Eggs"
	replace raise_cholesterol = "2" if raise_cholesterol == "Vegetable oils"
	replace raise_cholesterol = "3" if raise_cholesterol == "Animal fat"
	replace raise_cholesterol = "4" if raise_cholesterol == "Not sure"
	destring raise_cholesterol, replace

	// V48
	replace high_gi = "1" if high_gi == "Wholegrain cereals"
	replace high_gi = "2" if high_gi == "White bread"
	replace high_gi = "3" if high_gi == "Fruit and vegetables"
	replace high_gi = "4" if high_gi == "Not sure"
	destring high_gi, replace

	// V49
	replace fiber_weight_gain = "1" if fiber_weight_gain == "Agree"
	replace fiber_weight_gain = "2" if fiber_weight_gain == "Disagree"
	replace fiber_weight_gain = "3" if fiber_weight_gain == "Not sure"
	destring fiber_weight_gain, replace

	// V54, V59
	forval q = 1/2 {
		replace bmi_`q' = "1" if bmi_`q' == "Underweight"
		replace bmi_`q' = "2" if bmi_`q' == "Normal weight"
		replace bmi_`q' = "3" if bmi_`q' == "Overweight"
		replace bmi_`q' = "4" if bmi_`q' == "Obese"
		replace bmi_`q' = "5" if bmi_`q' == "Not sure"
		destring bmi_`q', replace
	}

	* assign dummies for each question and response   

	// fruit
	gen V28_A_1 = (more_same_less_1 == 1)

	// food and drinks with added sugar
	gen V28_A_2 = (more_same_less_2 == 3)

	//2 veggies
	gen V28_A_3 = (more_same_less_3 == 1)

	//3 fatty foods
	gen V28_A_4 = (more_same_less_4 == 3)

	//4 processed red meat
	gen V28_A_5 = (more_same_less_5 == 3)

	//5 whole grains
	gen V28_A_6 = (more_same_less_6 == 1)

	//6 salty foods
	gen V28_A_7 = (more_same_less_7 == 3)

	//7 water
	gen V28_A_8 = (more_same_less_8 == 1)

	* part 2: fat types
	//8 unsaturated fats
	gen V29_A_1 = (more_less_fats_1 == 2)

	//9 tran fats
	gen V29_A_2 = (more_less_fats_2 == 1)

	//10 saturated fats
	gen V29_A_3 = (more_less_fats_3 == 1)

	* part 3: added sugars
	//11 diet soda 
	gen V30_A_1 = (high_low_sugar_1 == 2) 

	//12 plain yogurt
	gen V30_A_2 = (high_low_sugar_2 == 2)

	//13 ice cream
	gen V30_A_3 = (high_low_sugar_3 == 1)

	//14 ketchup
	gen V30_A_4 = (high_low_sugar_4 == 1)

	//15 melon
	gen V30_A_5 = (high_low_sugar_5 == 2)

	* part 4: salt
	//16 breakfast cereals
	gen V31_A_1 = (high_low_salt_1 == 1)

	//17 frozen veggies
	gen V31_A_2 = (high_low_salt_2 == 2)

	//18 bread
	gen V31_A_3 = (high_low_salt_3 == 1)

	//19 baked beans
	gen V31_A_4 = (high_low_salt_4 == 1)

	//20 red meat
	gen V31_A_5 = (high_low_salt_5 == 2)

	//21 canned soup
	gen V31_A_6 = (high_low_salt_6 == 1)

	* part 5: fiber
	//22 oats
	gen V32_A_1 = (high_low_fiber_1 == 1)

	//23 banana
	gen V32_A_2 = (high_low_fiber_2 == 1)

	//24 white rice
	gen V32_A_3 = (high_low_fiber_3 == 2)

	//25 eggs
	gen V32_A_4 = (high_low_fiber_4 == 2)

	//26 potatoes
	gen V32_A_5 = (high_low_fiber_5 == 1)

	//27 pasta
	gen V32_A_6 = (high_low_fiber_6 == 2)

	* part 6: protein
	//28 poultry
	gen V33_A_1 = (protein_source_1 == 1)

	//29 cheese
	gen V33_A_2 = (protein_source_2 == 1)

	//30 fruit
	gen V33_A_3 = (protein_source_3 == 2)

	//31 baked beans
	gen V33_A_4 = (protein_source_4 == 1)

	//32 butter
	gen V33_A_5 = (protein_source_5 == 2)

	//33 nuts
	gen V33_A_6 = (protein_source_6 == 1)

	* part 7: starchy
	//34 cheese
	gen V34_A_1 = (starchy_foods_1 == 2)

	//35 pasta
	gen V34_A_2 = (starchy_foods_2 == 1)

	//36 potato
	gen V34_A_3 = (starchy_foods_3 == 1)

	//37 nuts
	gen V34_A_4 = (starchy_foods_4 == 3)

	//38 plantains
	gen V34_A_5 = (starchy_foods_5 == 1)

	* part 8: fat types
	//39 olive oil
	gen V35_A_1 = (main_fat_1 == 2)

	//40 butter
	gen V35_A_2 = (main_fat_2 == 3)

	//41 sunflower oil
	gen V35_A_3 = (main_fat_3 == 1)

	//42 eggs
	gen V35_A_4 = (main_fat_4 == 4)

	* part 9: assorted multiple choice
	//43 trans fat
	gen V36 = (most_trans_fat == 1)

	//44 milks
	gen V37 = (milk_calcium == 1)

	//45 cals by weight
	gen V38 = (most_calories == 4)

	//46 yogurts
	gen V39 = (yogurts == 2)

	//47 soup
	gen V40 = (soups == 2)

	//48 variety
	gen V41 = (salad_combos == 2)

	//49 add flavour
	gen V42 = (add_flavor == 2)

	//50 sugar disease
	gen V43 = (sugar_disease == 2)

	//51 sodium disease
	gen V44 = (salt_disease == 3)

	//52 heart disease
	gen V45 = (prevt_heart_disease == 3)

	//53 diabetes prevention
	gen V46 = (prevent_diabetes == 1)

	//54 raise blood cholesterol
	gen V47 = (raise_cholesterol == 3)

	//55 glycemic index
	gen V48 = (high_gi == 2)

	//56 fiber and weight gain
	gen V49 = (fiber_weight_gain == 1)

	//57 BMI - 23
	gen V54 = (bmi_1 == 2)

	//58 BMI - 31
	gen V55 = (bmi_2 == 4)


	* proportion of nutrition knowledge questions this repsondent answered correctly

	gen pct_correct = float((V28_A_1 + V28_A_2 + V28_A_3 + V28_A_4 + V28_A_5 + ///
							 V28_A_6 + V28_A_7 + V28_A_8 + V29_A_1 + V29_A_2 + ///
							 V29_A_3 + V30_A_1 + V30_A_2 + V30_A_3 + V30_A_4 + ///
							 V30_A_5 + V31_A_1 + V31_A_2 + V31_A_3 + V31_A_4 + ///
							 V31_A_5 + V31_A_6 + V32_A_1 + V32_A_2 + V32_A_3 + ///
							 V32_A_4 + V32_A_5 + V32_A_6 + V33_A_1 + V33_A_2 + ///
							 V33_A_3 + V33_A_4 + V33_A_5 + V33_A_6 + V34_A_1 + ///
							 V34_A_2 + V34_A_3 + V34_A_4 + V34_A_5 + V35_A_1 + ///
							 V35_A_2 + V35_A_3 + V35_A_4 + V36 + V37 + V38 + ///
							 V39 + V40 + V41 + V42 + V43 + V44 + V45 + V46 + ///
							 V47 + V48 + V49 + V54 + V55)/59)

end 

process_nutrition_responses


/*******************************************************************************
Parse answers to satisfaction questions
*******************************************************************************/

cap program drop clean_satisfaction_scores
program define clean_satisfaction_scores
 
	* identify drink for which score was given
	gen satisf_drink_str = ""
	foreach drink in $ssb_drink_names {
		replace satisf_drink_str = "`drink'" if `drink'_ssb_satisf_5 != ""
	}

	* encode as factor 
	encode satisf_drink_str, generate(satisf_drink)

end 

clean_satisfaction_scores


/*******************************************************************************
Reshape dataset from wide to long (for parameter estimation)
*******************************************************************************/

cap program drop reshape_long_merged_data
program define reshape_long_merged_data

	* generate ID variable 
	local idx = 1
	foreach drink in $ssb_drink_names {
		rename wtp_`drink'_base drink`idx'  // odd-numbered suffixes correspond to baselines
		local idx = `idx' + 1
		rename wtp_`drink'_end drink`idx'  // even-numbered suffixes correspond to endlines
		local idx = `idx' + 1
	}

	drop if id == .

	* reshape 
	reshape long drink, i(id) j(timing_temp)

	* order based on id, then generate timing  
	sort id
	gen timing = "base" if mod(timing_temp, 2) == 1
	replace timing = "end" if mod(timing_temp, 2) == 0

	* create the product column (hardcoding)
	gen product = "lemonade"
	replace product = "coke" if timing_temp == 3 | timing_temp == 4
	replace product = "pepsi" if timing_temp == 5 | timing_temp == 6
	replace product = "seagrams" if timing_temp == 7 | timing_temp == 8
	replace product = "sprite" if timing_temp == 9 | timing_temp == 10
	replace product = "crush" if timing_temp == 11 | timing_temp == 12

	drop if drink == .
	rename drink wtp
	drop timing_temp

	* generate product rank variable (hardcoding beverage_selection_0_###_rank)
	gen product_rank = "0"
	replace product_rank = beverage_selection_0_1_rank if product == "lemonade"
	replace product_rank = beverage_selection_0_5_rank if product == "coke"
	replace product_rank = beverage_selection_0_6_rank if product == "pepsi"
	replace product_rank = beverage_selection_0_7_rank if product == "seagrams"
	replace product_rank = beverage_selection_0_9_rank if product == "sprite"
	replace product_rank = beverage_selection_0_19_rank if product == "crush"
	destring product_rank, replace

end 

reshape_long_merged_data


/*******************************************************************************
Add reference variables for each of the 15 drinks (price, sugar, oz, cans)
*******************************************************************************/

cap program drop add_drink_spec_info
program define add_drink_spec_info

	gen price = 0
	replace price = 4.79 if product == "lemonade"
	replace price = 4.88 if product == "coke"
	replace price = 3.67 if product == "pepsi"
	replace price = 4.89 if product == "seagrams"
	replace price = 4.79 if product == "sprite"
	replace price = 4.98 if product == "crush"

	gen sugar = 0
	replace sugar = 40 if product == "lemonade"
	replace sugar = 39 if product == "coke"
	replace sugar = 41 if product == "pepsi"
	replace sugar = 33 if product == "seagrams"
	replace sugar = 38 if product == "sprite"
	replace sugar = 43 if product == "crush"

	gen oz = 0
	replace oz = 12 if product == "lemonade"
	replace oz = 12 if product == "coke"
	replace oz = 12 if product == "pepsi"
	replace oz = 12 if product == "seagrams"
	replace oz = 12 if product == "sprite"
	replace oz = 12 if product == "crush"

	gen cans = 12

end 

add_drink_spec_info


/*******************************************************************************
Reshape back into wide format s.t. there is one row per product pair
*******************************************************************************/

cap program drop reshape_wide_merged_data
program define reshape_wide_merged_data 

	* reshape 
	drop _merge
	reshape wide wtp, i(id product) j(timing) string
	rename wtpbase wtp_base
	rename wtpend wtp_end

end 

reshape_wide_merged_data


/*******************************************************************************
Add fields for order each drink was seen in 
*******************************************************************************/

cap program drop add_order_seen
program define add_order_seen 

	* order in which drink was seen
	gen order_base = "1"
	gen order_end = "4"
	foreach drink in $ssb_drink_names {
		replace order_base = `drink'_seen_order_pre if product == "`drink'"
		replace order_end = `drink'_seen_order_post if product == "`drink'"
	}
	
	destring order_base order_end, replace
	replace order_end = order_end + 3

	order id product treatment wtp_base wtp_end product_rank order_base order_end

	* also add binaries for baseline and endline order 
	gen first_baseline = 0
	gen second_baseline = 0
	gen third_baseline = 0
	gen first_endline = 0
	gen second_endline = 0
	gen third_endline = 0

	replace first_baseline = 1 if order_base == 1
	replace second_baseline = 1 if order_base == 2
	replace third_baseline = 1 if order_base == 3

	replace first_endline = 1 if order_end == 4
	replace second_endline = 1 if order_end == 5
	replace third_endline = 1 if order_end == 6

end 

add_order_seen


/*******************************************************************************
Generate miscellaneous fields for subsequent analysis
*******************************************************************************/

cap program drop add_misc_fields
program define add_misc_fields
 
	* generate dummy that includes all observations 
	gen all = 1

	* ensure treatment/product no. are encoded correctly 
	encode treatment, gen(T) // control is T=1; ordered alphabetically: graphic (2), nutrition (3), stoplight (4)
	encode product, gen(prod_no) // ordered alphabetically

	* generate additional sugar/price variables 
	gen package_oz = oz*cans
	gen price_per_oz = 100*price/package_oz
	tab price_per_oz product
	gen sugar_per_oz = sugar/oz

	* generate binary is_treated 
	gen is_treated = 1 if T != 1
	replace is_treated = 0 if T == 1
	
end 

add_misc_fields


/*******************************************************************************
Generate gamma proxy 
*******************************************************************************/

cap program drop gen_gamma_hat
program define gen_gamma_hat 

	* define scale 
	local scale = 100

	* generate gamma proxy 
	gen gamma_hat = (0.854*(0.92 - pct_correct)+0.825*(1-self_control))*3.63/1.39*package_oz/`scale'

end 

gen_gamma_hat
 

/*******************************************************************************
Create uncensored WTP estimates 
*******************************************************************************/

cap program drop gen_uncens_WTPs
program define gen_uncens_WTPs 

	* create columns for left and right responses for censored;
	* {drink}_{b/c/n/w/g}_{left/right}

	gen base_cens_left = .
	gen base_cens_right = .

	foreach drink in $ssb_drink_names {
		replace base_cens_left = `drink'_b_left if product == "`drink'"
		replace base_cens_right = `drink'_b_right if product == "`drink'"
	}

	gen end_cens_left = .
	gen end_cens_right = .

	foreach drink in $ssb_drink_names {
		foreach endline in $endlines {
			replace end_cens_left = `drink'_`endline'_left if product == "`drink'" & `drink'_`endline'_left != .
			replace end_cens_right = `drink'_`endline'_right if product == "`drink'" & `drink'_`endline'_right != .
		}
	}

	gen wtp_base_uncens = wtp_base
	gen wtp_end_uncens = wtp_end

end 

gen_uncens_WTPs



/*******************************************************************************
Create WTP estimates with off-MPL responses censored via median of self-reports
*******************************************************************************/

cap program drop gen_median_cens_WTPs
program define gen_median_cens_WTPs 

	* generate above- and below-censored medians for baseline and endline WTP 
	sum wtp_base_uncens if wtp_base_uncens > 2.60, d
	scalar cens_val_b_above = r(p50)

	sum wtp_base_uncens if wtp_base_uncens < -2.60, d
	scalar cens_val_b_below = r(p50)

	sum wtp_end_uncens if wtp_end_uncens > 2.60, d
	scalar cens_val_e_above = r(p50)

	sum wtp_end_uncens if wtp_end_uncens < -2.60, d
	scalar cens_val_e_below = r(p50)

	* replace off-MPL WTPs with these medians 
	gen base_cens = (wtp_base > 2.60) - (wtp_base < -2.60)
	gen end_cens = (wtp_end > 2.60) - (wtp_end < -2.60)

	replace wtp_base = cens_val_b_above if base_cens == 1
	replace wtp_base = cens_val_b_below if base_cens == -1

	replace wtp_end = cens_val_e_above if end_cens == 1
	replace wtp_end = cens_val_e_below if end_cens == -1

end 

gen_median_cens_WTPs


/*******************************************************************************
Create delta-WTP field 
*******************************************************************************/

cap program drop gen_delta_WTP
program define gen_delta_WTP 

	* use censored values to generate delta_WTP
	gen delta_WTP = wtp_end - wtp_base

end 

gen_delta_WTP


/*******************************************************************************
Generate WTP to avoid labels 
*******************************************************************************/

cap program drop gen_WTP_avoid_labels
program define gen_WTP_avoid_labels 

	* generate columns for reason (yes) and reason (no)

	local yes_answers "1 2 4"
	local no_answers "1 2 5 6 7"
	
	gen reason_yes = ""
	gen reason_no = ""
	foreach drink in $ssb_drink_names {
		foreach end in $endlines_wo_control {
			foreach answer in `yes_answers' {
				* reason for answering "yes"
				replace reason_yes = `drink'_hyp_`end'_why_y_`answer' if `drink'_hyp_`end'_why_y_`answer' != ""
			}
			
			foreach answer in `no_answers' {
				* reason for answering "no"
				replace reason_no = `drink'_hyp_`end'_why_n_`answer' if `drink'_hyp_`end'_why_n_`answer' != ""
			}
		}
	}

	* generate column containing response to question "would you like the labels?"

	gen label_pref = ""

	foreach drink in $ssb_drink_names {
		foreach end in $endlines_wo_control {
			replace label_pref = `drink'_hyp_`end'_intro if `drink'_hyp_`end'_intro != ""
		}
	}
	
	* generate WTP to avoid labels 

	foreach drink in $ssb_drink_names {
		* split field, e.g., 4left -> 4 & left 
		split xnormchoicefinal_`drink'_hyp, parse (left)
		split xnormchoicefinal_`drink'_hyp1, parse (right)
		
		* destring and rename
		rename xnormchoicefinal_`drink'_hyp11 `drink'_hyp_num
		destring `drink'_hyp_num, replace
	}

	* start with interior response (not 12left in YES case or 2right in NO case)

	gen wtp_avoid_labels = .

	foreach drink in $ssb_drink_names {
		replace wtp_avoid_labels = -0.25 if `drink'_hyp_num == 2 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -0.75 if `drink'_hyp_num == 3 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -1.25 if `drink'_hyp_num == 4 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -1.75 if `drink'_hyp_num == 5 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -2.25 if `drink'_hyp_num == 6 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -2.75 if `drink'_hyp_num == 7 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -3.25 if `drink'_hyp_num == 8 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -3.75 if `drink'_hyp_num == 9 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -4.25 if `drink'_hyp_num == 10 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		replace wtp_avoid_labels = -4.75 if `drink'_hyp_num == 11 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "With the label"
		
		replace wtp_avoid_labels = 0.00 if `drink'_hyp_num == 2 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -0.25 if `drink'_hyp_num == 3 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -0.75 if `drink'_hyp_num == 4 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -1.25 if `drink'_hyp_num == 5 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -1.75 if `drink'_hyp_num == 6 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -2.25 if `drink'_hyp_num == 7 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -2.75 if `drink'_hyp_num == 8 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -3.25 if `drink'_hyp_num == 9 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -3.75 if `drink'_hyp_num == 10 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -4.25 if `drink'_hyp_num == 11 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"
		replace wtp_avoid_labels = -4.75 if `drink'_hyp_num == 12 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "With the label"

		replace wtp_avoid_labels = 4.75 if `drink'_hyp_num == 2 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 4.25 if `drink'_hyp_num == 3 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 3.75 if `drink'_hyp_num == 4 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 3.25 if `drink'_hyp_num == 5 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 2.75 if `drink'_hyp_num == 6 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 2.25 if `drink'_hyp_num == 7 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 1.75 if `drink'_hyp_num == 8 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 1.25 if `drink'_hyp_num == 9 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 0.75 if `drink'_hyp_num == 10 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 0.25 if `drink'_hyp_num == 11 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		replace wtp_avoid_labels = 0.00 if `drink'_hyp_num == 12 & strpos(xnormchoicefinal_`drink'_hyp, "left") & label_pref == "Without the label"
		
		replace wtp_avoid_labels = 4.75 if `drink'_hyp_num == 3 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 4.25 if `drink'_hyp_num == 4 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 3.75 if `drink'_hyp_num == 5 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 3.25 if `drink'_hyp_num == 6 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 2.75 if `drink'_hyp_num == 7 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 2.25 if `drink'_hyp_num == 8 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 1.75 if `drink'_hyp_num == 9 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 1.25 if `drink'_hyp_num == 10 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 0.75 if `drink'_hyp_num == 11 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
		replace wtp_avoid_labels = 0.25 if `drink'_hyp_num == 12 & strpos(xnormchoicefinal_`drink'_hyp, "right") & label_pref == "Without the label"
	}

	* account for censored selections on the MPL
	foreach drink in $ssb_drink_names {
		foreach end in $endlines_wo_control {
			destring `drink'_hyp_`end'_y_cen, replace
			destring `drink'_hyp_`end'_n_cen, replace

			replace wtp_avoid_labels = -1 * (`drink'_hyp_`end'_y_cen) if xnormchoicefinal_`drink'_hyp == "12left" & `drink'_hyp_`end'_y_cen != .  // answered "yes" to receive labels and would prefer labels > no labels + $5
			replace wtp_avoid_labels = 1 * (`drink'_hyp_`end'_n_cen) if xnormchoicefinal_`drink'_hyp == "2right" & `drink'_hyp_`end'_n_cen != .  // answered "no" to receive labels and would prefer no labels > labels + $5
		}
	}

end 

gen_WTP_avoid_labels


/*******************************************************************************
Generate calorie and sugar error based on responses 
*******************************************************************************/

cap program drop gen_calorie_sugar_error
program define gen_calorie_sugar_error

	* destring all values
	local component "sugar calories"
	
	foreach drink in $all_drink_names {
		foreach comp in `component' {
			destring `drink'_`comp'_2, replace
			destring `drink'_`comp', replace
		}
	}

	* 0) correct calorie numbers (correct sugar numbers are already stored in "sugar" variable)
	gen calories = 0
	replace calories = 150 if product == "lemonade"
	replace calories = 140 if product == "coke"
	replace calories = 150 if product == "pepsi"
	replace calories = 130 if product == "seagrams"
	replace calories = 140 if product == "sprite"
	replace calories = 160 if product == "crush"

	* 1) Non-SSB

	* raw estimates 
	foreach comp in `component' {
		gen nonssb_`comp'_pre = lacroix_`comp'
		gen nonssb_`comp'_post = lacroix_`comp'_2
	}

	* error of beliefs 
	foreach comp in `component' {
		gen nonssb_`comp'_error_pre = nonssb_`comp'_pre - 0
		gen nonssb_`comp'_error_post = nonssb_`comp'_post - 0
	}

	* 2) SSB
	gen ssb_sugar_pre = .
	gen ssb_sugar_post = .
	gen ssb_calories_pre = .
	gen ssb_calories_post = .

	* raw estimate 
	foreach drink in $all_drink_names {
		foreach comp in `component' {
			replace ssb_`comp'_pre = `drink'_`comp' if product == "`drink'"
			replace ssb_`comp'_post = `drink'_`comp'_2 if product == "`drink'"
		}
	}
	* error of beliefs 
	foreach comp in `component' {
		gen ssb_`comp'_error_pre = ssb_`comp'_pre - `comp'
		gen ssb_`comp'_error_post = ssb_`comp'_post - `comp'
	}

	* 3) difference between SSB and non-SSB

	* compute difference in estimates 
	foreach comp in `component' {
		gen diff_`comp'_pre = ssb_`comp'_pre - nonssb_`comp'_pre
		gen diff_`comp'_post = ssb_`comp'_post - nonssb_`comp'_post
	}

	* compute error of beliefs 
	foreach comp in `component' {
		gen diff_`comp'_error_pre = diff_`comp'_pre - `comp'
		gen diff_`comp'_error_post = diff_`comp'_post - `comp'
	}

	* generate combined z-score of calorie and sugar errors

	* Winsorize outliers
	sum ssb_sugar_error_post, d

	replace ssb_sugar_error_post = r(p95) if ssb_sugar_error_post > r(p95) 
	replace ssb_sugar_error_post = r(p5) if ssb_sugar_error_post < r(p5) 

	sum ssb_calories_error_post, d

	replace ssb_calories_error_post = r(p95) if ssb_calories_error_post > r(p95) 
	replace ssb_calories_error_post = r(p5) if ssb_calories_error_post < r(p5) 

	* generate average error by ID
	by id: egen avg_ssb_calories_error_post = mean(ssb_calories_error_post) 
	by id: egen avg_ssb_sugar_error_post = mean(ssb_sugar_error_post) 

	* convert average error into one z-score each for calorie and sugar 
	sum avg_ssb_calories_error_post, d

	gen avg_ssb_calories_error_post_mean = r(mean)
	gen avg_ssb_calories_error_post_sd = r(sd)
	gen avg_ssb_calories_error_post_z = (avg_ssb_calories_error_post - avg_ssb_calories_error_post_mean) /// 
										/ (avg_ssb_calories_error_post_sd)

	sum avg_ssb_sugar_error_post, d	
					
	gen avg_ssb_sugar_error_post_mean = r(mean)
	gen avg_ssb_sugar_error_post_sd = r(sd)
	gen avg_ssb_sugar_error_post_z = (avg_ssb_sugar_error_post - avg_ssb_sugar_error_post_mean) /// 
									  / (avg_ssb_sugar_error_post_sd)

	* average z-scores by ID 
	gen avg_calorie_sugar_error_post_z = (avg_ssb_calories_error_post_z + avg_ssb_sugar_error_post_z) / 2

end 

gen_calorie_sugar_error


/*******************************************************************************
Generate demand dummies
*******************************************************************************/

cap program drop gen_demand_dummies 
program define gen_demand_dummies 

	forval j = 1/19 {
		gen demand_pre`j' = (wtp_base >= 0.5*`j'-5) 
		gen demand_post`j' = (wtp_end >= 0.5*`j'-5) 
	}

end 

gen_demand_dummies


/*******************************************************************************
Add variable for distortion
*******************************************************************************/

cap program drop gen_distortion
program define gen_distortion

	* externality is constant 0.85 cents per oz. 
	* --> ($0.0085) * (12 oz. per can) * (12 cans per 12-pack) = $1.224

	gen externality = 1.224 

	* create distortion based on externality 

	gen distortion = gamma_hat + externality 

end 

gen_distortion


/*******************************************************************************
Add variable for "middle 50% of baseline WTP" (on the margin)
*******************************************************************************/

cap program drop gen_middle50_ind
program define gen_middle50_ind
 
	* get median of WTP distances from zero
	gen abs_wtp = abs(wtp_base)
	sum abs_wtp, d
	gen med_abs_wtp = r(p50)

	* identify WTPs that are above the median 
	gen abs_wtp_above_med = 0
	replace abs_wtp_above_med = 1 if abs_wtp > med_abs_wtp 

	* create column w/ total number of above-median WTPs by ID 
	bysort id: egen tot_abs_wtp_above_med = sum(abs_wtp_above_med)

	* create indicator for IDs that have no above-median WTPs 
	gen middle50ind = 0
	replace middle50ind = 1 if tot_abs_wtp_above_med == 0

end 

gen_middle50_ind


/*******************************************************************************
Compress and save final dataset
*******************************************************************************/

cap program drop export_final_dataset
program define export_final_dataset 

	compress
	save "$rootdir/ssb/intermediate_data/merged.dta", replace

end 

export_final_dataset

