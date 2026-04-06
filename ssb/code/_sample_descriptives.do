/*******************************************************************************
Export final sample size to LaTeX file. 

FUNC NAME: export_sample_size_to_latex
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports final sample size to file specified earlier. 
*******************************************************************************/

capture program drop export_sample_size_to_latex
program define export_sample_size_to_latex
	preserve
	
	keep id 
	duplicates drop 
	
	loc sample_size: di _N
	
	latex_rounded, name("ssbSampleSize") value(`sample_size') digits(0)
	
	restore 
end

export_sample_size_to_latex


/*******************************************************************************
Export other "easy" scalars that don't require econometric estimation. 

FUNC NAME: export_other_scalars
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following scalars:
    - Distortion as percentage of price  
    - Average nutrition knowledge
	- Average self-control
*******************************************************************************/

capture program drop export_other_scalars
program define export_other_scalars
	preserve 
	
	* distortion as percentage of price 
	sum distortion, d
	local avg_distortion = r(mean)
	local distortion_over_price = (`avg_distortion' / 4) * 100
	
	latex_rounded, name("ssbDistortionOverPrice") value(`distortion_over_price') digits(0)
	
	* average nutrition knowledge 
	sum pct_correct, d
	local avg_nutrition_knowledge = r(mean)
	
	latex_rounded, name("ssbAverageNutritionKnowledge") value(`avg_nutrition_knowledge') digits(2)
	
	* average self-control 
	sum self_control, d
	local avg_self_control = r(mean)
	
	latex_rounded, name("ssbAverageSelfControl") value(`avg_self_control') digits(2)
	
	restore 
end 

export_other_scalars


/*******************************************************************************
Generate sample demographics table comparing our sample to the US population. 

FUNC NAME: gen_sample_demog_table
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following table:
    - [ssb/output/] sample_demog.tex  
*******************************************************************************/

capture program drop gen_sample_demog_table
program define gen_sample_demog_table
	preserve 
	
	* keep only desired columns 
	keep id income college male white age pct_correct self_control
	
	* drop duplicates so only one row per person 
	duplicates drop
	
	* add columns w/ stats for sample (pop==1 --> sample)
	gen incomeunder50k = 0
	replace incomeunder50k = 1 if income < 50
	sum incomeunder50k, d 
	return list
	gen propunder50k1 = r(mean)
	
	sum college if age >= 25, d 
	return list
	gen college25over1 = r(mean)
	
	sum male, d 
	return list
	gen male1 = r(mean)
	
	sum white, d
	return list
	gen white1 = r(mean)
	
	gen under45 = 0 
	replace under45 = 1 if age < 45
	sum under45 if age > 19, d 
	return list 
	gen propunder451 = r(mean)
	
	sum pct_correct, d
	return list 
	gen pct_correct1 = r(mean)

	sum self_control, d
	return list 
	gen self_control1 = r(mean)
	
	* drop prior used columns 
	drop income college male white age pct_correct self_control
	
	* add separate column for US average (pop==2 --> US)
	* using ACS 2020 5-year estimates 

	file open external_data using "$rootdir/ssb/input/external_data.txt", read
	file read external_data line

	while r(eof) == 0 {
		quietly capture `line'
		file read external_data line
	}

	file close external_data

	local propunder50k = (`0to10k' + `10kto15k' + `15kto25k' + `25kto35k' + `35kto50k') / `total_hh'
	gen propunder50k2 = `propunder50k'
	
	gen college25over2 = `college25over'
	gen male2 = `male'
	gen white2 = `white' 
		
	local over19 = `total' - (`u5' + `5to9' + `10to14' + `15to19')
	local propunder45 = (`20to24' + `25to34' + `35to44') / `over19'
	gen propunder452 = `propunder45' 
	
	gen pct_correct2 = 0.70
	gen self_control2 = 0.77

	* reshape long by every variable 
	reshape long propunder50k college25over male white propunder45 pct_correct self_control, ///
			i(id) j(pop)
	
	* create variable for population
	gen population = ""
	replace population = "Sample" if pop == 1
	replace population = "US" if pop == 2
	
	* sort by population
	sort population
	
	* label variables 
	label var propunder50k "Income under \\$50,000"
	label var college25over "College degree (for age $\ge$ 25)"
	label var male "Male"
	label var white "White"
	label var propunder45 "Under age 45"
	label var pct_correct "Nutrition knowledge"
	label var self_control "Self-control"
	
	* get averages by population and export
	estpost tabstat propunder50k college25over male white propunder45 pct_correct self_control, ///
	by(population) ///
	statistics(mean) columns(statistics)
	
	est store sample_demog	
	
	esttab sample_demog using "$rootdir/ssb/output/sample_demog.tex", replace ///
	cells("mean(fmt(2))") label ///
	nomtitle nonumber noobs ///
	drop(Total:) unstack ///
	collabels(none) eqlabels("\shortstack{(1)\\Experiment\\sample}" ///
	                         "\shortstack{(2)\\US\\population}") ///

	restore
end 

gen_sample_demog_table


/*******************************************************************************
Generate balance table across treatment groups. 

FUNC NAME: gen_bal_tab
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following table:
    - [ssb/output/] Balance_fullsample.tex  
*******************************************************************************/

capture program drop gen_bal_tab
program define gen_bal_tab
	preserve 
	
	* generate and export balance table 
	iebaltab income college male white age, ///
	grpvar(T) order(1 3 4 2) control(1) ///
	pftest pttest vce(robust) stdev grplabels(1 Control @ 2 Graphic @ 3 Nutrition @ 4 Stop sign) ///
	savetex("$rootdir/ssb/output/balance_full.tex") ///
	rowlabels("income Household income (\textdollar000s) @ college College degree @ male Male @ white White @ age Age") ///
	replace onenrow ftest rowvarlabel tblnonote format(%8.2fc)
	
	restore
end

gen_bal_tab 

