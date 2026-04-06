version 18

/*******************************************************************************
TITLE: analysis.do
AUTHOR(S): Daniel Cohen <-- Victoria Pu 
DESCRIPTION: Reads in processed data and produces all tables and figures for 
    the cars experiment. 
DATE LAST MODIFIED: APR 2024
FILE(S) USED: 
    - merged.dta (processed data from cars experiment)
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


/*******************************************************************************
Generate confusion matrix for dropped observations in build file. 

FUNC NAME: gen_dropped_obs_conf_matrix
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Generates confusion matrix for 4 exclusion conditions. 
*******************************************************************************/

capture program drop gen_dropped_obs_conf_matrix
program define gen_dropped_obs_conf_matrix
	preserve 

	* import processed data
	use "$rootdir/cars/intermediate_data/merged", clear
	
	* keep only id and the four exclusion conditions (strict and weak)
	keep id baddata_cond_enjoy_id_5 baddata_cond_gas_id_5 baddata_cond_ov_b_id_5 baddata_cond_delta_wtp_id_5 ///
	baddata_cond_enjoy_id_5s baddata_cond_gas_id_5s baddata_cond_ov_b_id_5s baddata_cond_delta_wtp_id_5s
	
	* restrict to one observation for each id 
	duplicates drop 
	
	* rename variables for ease of analysis  
	rename baddata_cond_enjoy_id_5 C1w
	rename baddata_cond_gas_id_5 C2w
	rename baddata_cond_ov_b_id_5 C3w
	rename baddata_cond_delta_wtp_id_5 C4w
	
	rename baddata_cond_enjoy_id_5s C1s
	rename baddata_cond_gas_id_5s C2s
	rename baddata_cond_ov_b_id_5s C3s
	rename baddata_cond_delta_wtp_id_5s C4s
	
	* for each id, generate variable containing total number of conditions violated
	gen num_violated_w = C1w + C2w + C3w + C4w
	gen num_violated_s = C1s + C2s + C3s + C4s
	
	* generate variables for each condition interaction 
	local conditions "C1 C2 C3 C4"
	local inequalities "w s"
	
	foreach ineq in `inequalities' {
		
		* no conditions met (i.e., included)
		gen included`ineq' = 0
		replace included`ineq' = 1 if num_violated_`ineq' == 0

		* exactly one condition met 
		foreach c in `conditions' {
			gen only_`c'`ineq' = 0 
			replace only_`c'`ineq' = 1 if (`c'`ineq' == 1) & (num_violated_`ineq' == 1)
		}
		
		* exactly two conditions met 
		gen C1_C2`ineq' = 0
		gen C1_C3`ineq' = 0
		gen C1_C4`ineq' = 0
		gen C2_C3`ineq' = 0
		gen C2_C4`ineq' = 0
		gen C3_C4`ineq' = 0
		
		replace C1_C2`ineq' = 1 if (C1`ineq' == 1) & (C2`ineq' == 1) & (num_violated_`ineq' == 2)
		replace C1_C3`ineq' = 1 if (C1`ineq' == 1) & (C3`ineq' == 1) & (num_violated_`ineq' == 2)
		replace C1_C4`ineq' = 1 if (C1`ineq' == 1) & (C4`ineq' == 1) & (num_violated_`ineq' == 2)
		replace C2_C3`ineq' = 1 if (C2`ineq' == 1) & (C3`ineq' == 1) & (num_violated_`ineq' == 2)
		replace C2_C4`ineq' = 1 if (C2`ineq' == 1) & (C4`ineq' == 1) & (num_violated_`ineq' == 2)
		replace C3_C4`ineq' = 1 if (C3`ineq' == 1) & (C4`ineq' == 1) & (num_violated_`ineq' == 2)
		
		* exactly three conditions met
		gen C1_C2_C3`ineq' = 0 
		gen C1_C2_C4`ineq' = 0 
		gen C1_C3_C4`ineq' = 0 
		gen C2_C3_C4`ineq' = 0 

		replace C1_C2_C3`ineq' = 1 if (num_violated_`ineq' == 3) & (C4`ineq' == 0)
		replace C1_C2_C4`ineq' = 1 if (num_violated_`ineq' == 3) & (C3`ineq' == 0)
		replace C1_C3_C4`ineq' = 1 if (num_violated_`ineq' == 3) & (C2`ineq' == 0)
		replace C2_C3_C4`ineq' = 1 if (num_violated_`ineq' == 3) & (C1`ineq' == 0)
		
		* four conditions met 
		gen C1_C2_C3_C4`ineq' = 0
		replace C1_C2_C3_C4`ineq' = 1 if num_violated_`ineq' == 4

	}
	
	* keep only relevant interactions 
	keep id includedw C1w C2w C3w C4w only_C1w only_C2w only_C3w only_C4w ///
	C1_C2w C1_C3w C1_C4w C2_C3w C2_C4w C3_C4w ///
	C1_C2_C3w C1_C2_C4w C1_C3_C4w C2_C3_C4w C1_C2_C3_C4w ///
	includeds C1s C2s C3s C4s only_C1s only_C2s only_C3s only_C4s ///
	C1_C2s C1_C3s C1_C4s C2_C3s C2_C4s C3_C4s ///
	C1_C2_C3s C1_C2_C4s C1_C3_C4s C2_C3_C4s C1_C2_C3_C4s ///
	
	* reshape data into long format so each id has row for weak and strict 
	local reshape_conditions1 "included C1 C2 C3 C4 only_C1 only_C2 only_C3 only_C4"
	local reshape_conditions2 "C1_C2 C1_C3 C1_C4 C2_C3 C2_C4 C3_C4"
	local reshape_conditions3 "C1_C2_C3 C1_C2_C4 C1_C3_C4 C2_C3_C4 C1_C2_C3_C4"
	local reshape_conditions "`reshape_conditions1' `reshape_conditions2' `reshape_conditions3'"
	reshape long `reshape_conditions', i(id) j(inequality) string
	
	* generate summary stats table that takes average of each of eight 
	* conditions for both weak and strict inequalities
	drop id 
	collapse (mean) `reshape_conditions', by(inequality)
	
	* truncate all proportions to two decimals for display purposes 
	foreach var in `reshape_conditions' {
		format `var' %3.3f
	}

	* rename C1 --> C1_total, ...
	rename C1 C1_total
	rename C2 C2_total
	rename C3 C3_total
	rename C4 C4_total
	
	* replace s/w with strict/weak in inequality column 
	replace inequality = "strict" if inequality == "s"
	replace inequality = "weak" if inequality == "w"	
	
	restore 
end 

// gen_dropped_obs_conf_matrix


/*******************************************************************************
Export final sample size to LaTeX file. 

FUNC NAME: export_sample_size_to_latex
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports final sample size to file specified earlier. 
*******************************************************************************/

capture program drop export_sample_size_to_latex
program define export_sample_size_to_latex
	preserve
	
	* remove duplicates
	keep id 
	duplicates drop 
	
	* record and export sample size 
	loc sample_size: di _N
	latex_rounded, name("carsSampleSize") value(`sample_size') digits(0)
	
	restore 
end

export_sample_size_to_latex


/*******************************************************************************
Export other "easy" scalars that don't require econometric estimation. 

FUNC NAME: export_other_scalars
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following scalars:
    - Distortion as percentage of price  
    - Average miles driven in 2019  
    - Average price per gallon of gas paid in 2019  
    - Average WTP for lease in experiment if gas were free  
    - Average baseline WTP   
    - Average gas cost savings from fuel-efficient car  
*******************************************************************************/

capture program drop export_other_scalars
program define export_other_scalars
	preserve 
	
	* distortion as percentage of price 
	sum distortion_b_median, d
	local avg_distortion = r(mean)
	local distortion_over_price = (`avg_distortion' / 5600) * 100
	
	latex_rounded, name("carsDistortionOverPrice") value(`distortion_over_price') digits(0)
		
	* average miles driven 
	sum miles_driven_2019, d 
	local avg_miles_driven = round(r(mean) * 1000, 100)
	
	latex_rounded, name("carsAverageMilesDriven") value(`avg_miles_driven') digits(0)
	
	* average gas price per gallon 
	sum gas_price_estimate, d 
	local avg_gas_price = r(mean)
	
	latex_rounded, name("carsAverageGasPrice") value(`avg_gas_price') digits(2)

	* average WTP if gas were free 
	sum average_wtp_nogas, d	
	local avg_wtp_no_gas = round(r(mean) * 1000, 10)
	
	latex_rounded, name("carsAverageWTPNoGas") value(`avg_wtp_no_gas') digits(0)

	* average baseline WTP 
	sum wtp_b_median, d
	local avg_wtp_b_median = round(r(mean) + 2000, 10)
	
	latex_rounded, name("carsAverageBaselineWTP") value(`avg_wtp_b_median') digits(0)
	
	* average gas cost savings 
	sum cost_savings, d
	local avg_cost_savings = r(mean)
	
	latex_rounded, name("carsAverageCostSavings") value(`avg_cost_savings') digits(0)
	
	restore 
end 

export_other_scalars


/*******************************************************************************
Set labels for covariates that will be used in summary statistics and sample
demographics tables.

FUNC NAME: set_var_labels
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Sets labels for 13 covariates. 
*******************************************************************************/

capture program drop set_var_labels 
program define set_var_labels

	label var income "Household income (\\$000s)"
	label var education_num "Education (years)"
	label var male "Male"
	label var age "Age"
	label var white "White"
	label var black "Black"
	label var environmentalism "Environmentalism"
	label var financial_literacy "Financial literacy"
	label var miles_driven_2019 "2019 miles driven (000s)"
	label var gas_price_estimate "2019 gas price (\\$/gallon)"
	label var cost_savings "Personal cost savings from higher-MPG car (\\$/year)"
	label var average_wtp_nogas "Average WTP if gas is free (\\$000s/year)"
	label var average_baseline_wtp "Average baseline relative \\WTP for lower-MPG car (\\$000s/year)"

end 

set_var_labels


/*******************************************************************************
Generate summary statistics table. 

FUNC NAME: gen_summ_stats
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following table:
    - [cars/output/] summary_statistics.tex  
*******************************************************************************/

capture program drop gen_summ_stats
program define gen_summ_stats
	preserve 
	
	estpost tabstat income education_num male age white black environmentalism ///
					miles_driven_2019 gas_price_estimate cost_savings ///
					average_wtp_nogas average_baseline_wtp, ///
	statistics(mean sd min max) columns(statistics)
	est store sum_stats
	esttab sum_stats using "$rootdir/cars/output/summary_statistics.tex", replace ///
	cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") label ///
	collabels("Mean" "Std. dev." "Minimum" "Maximum") ///
	nomtitle nonumber noobs
	
	restore
end

gen_summ_stats 


/*******************************************************************************
Generate sample demographics table comparing our sample to the US population. 

FUNC NAME: gen_sample_demog_table
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following table:
    - [cars/output/] sample_demog.tex  
*******************************************************************************/

capture program drop gen_sample_demog_table
program define gen_sample_demog_table
	preserve 
	
	* generate new column for college
	gen college = 0
	replace college = 1 if education_num >= 16
	
	* generate column for average baseline WTP 
	by id: egen average_wtp_b_median = mean(wtp_b_median)
	
	* keep only desired columns 
	keep id income college male white age miles_driven_2019 ///
	     gas_price_estimate average_wtp_nogas average_wtp_b_median
		
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
	
	sum miles_driven_2019, d
	return list
	gen milesdriven1 = r(mean) * 1000  // account for scaling

	sum gas_price_estimate, d
	return list
	gen gasprice1 = r(mean)

	sum average_wtp_nogas, d
	return list
	gen wtpnogas1 = r(mean) * 1000  // account for scaling

	sum average_wtp_b_median, d
	return list
	gen baselinewtp1 = r(mean) + 2000  // convert relative to absolute WTP
	
	* drop prior used columns 
	drop income college male white age miles_driven_2019 ///
	     gas_price_estimate average_wtp_nogas average_wtp_b_median
	
	* add separate column for US average (pop==2 --> US) 
	* using ACS 2020 5-year estimates 
	
	file open external_data using "$rootdir/cars/input/external_data.txt", read
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
	
	gen milesdriven2 = `milesdriven'
	gen gasprice2 = `gasprice'
	gen wtpnogas2 = 111
	gen baselinewtp2 = 111
	
	* reshape long by every variable 
	reshape long propunder50k college25over male white propunder45 milesdriven ///
	        gasprice wtpnogas baselinewtp, ///
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
	label var milesdriven "2019 miles driven"
	label var gasprice "2019 gas price (\\$/gallon)"
	label var wtpnogas "Average WTP if gas is free ($wtp_unit_tex)"
	label var baselinewtp "Average baseline WTP ($wtp_unit_tex)"
	
	* get averages by population and export
	estpost tabstat propunder50k college25over male white propunder45 milesdriven ///
	        gasprice wtpnogas baselinewtp, ///
	by(population) ///
	statistics(mean) columns(statistics)
	
	est store sample_demog
	
	* generate and export final table
	esttab sample_demog using "$rootdir/cars/output/sample_demog.tex", replace ///
	cells("mean(fmt(2 2 2 2 2 %8.0fc 2 %8.0fc %8.0fc))") label ///
	substitute(" 111" "  ") ///
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
    - [cars/output/] Balance_fullsample.tex  
*******************************************************************************/

capture program drop gen_bal_tab
program define gen_bal_tab
	preserve 
	
	* generate new column for college
	gen college = 0
	replace college = 1 if education_num >= 16

	* generate and export balance table
	iebaltab income college male white age, ///
	grpvar(T) order(1 3 2 4 5) control(1) ///
	pftest pttest vce(robust) stdev grplabels(1 Control @ 2 Fuel cost @ 3 Full MPG @ 4 Personalized fuel cost @ 5 SmartWay) ///
	savetex("$rootdir/cars/output/balance_full.tex") ///
	rowlabels("income Household income (\textdollar000s) @ college College degree @ male Male @ white White @ age Age") ///
	replace onenrow ftest rowvarlabel tblnonote format(%8.2fc)
	
	restore
end

gen_bal_tab


/*******************************************************************************
Generate spike plot of ATEs by treatment (incl. pooled).  

FUNC NAME: gen_ATE_spike_plot
FUNC ARGUMENT(S): 
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] ATE_spike_plot.pdf  
*******************************************************************************/

capture program drop gen_ATE_spike_plot
program define gen_ATE_spike_plot
	preserve 
	
	* run pooled regression
	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS, cluster(id)
	eststo TpooledATE
	
	* run treatment-specific regressions 
	forval t = 2/5 {
		reg delta_wtp_median `t'.T overvaluation_b_median externality $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'ATE
	}
	
	* generate spike plot 
	coefplot (T2ATE T3ATE T4ATE T5ATE TpooledATE, /// 
				  msymbol(square) mcolor(black) ///
				  ciopts(lcolor(black) recast(rcap)) ///
				  keep(2.T 3.T 4.T 5.T 1.treated)), vertical ///
	coeflabels(2.T = "Average cost" ///
			   3.T = "Full MPG" ///
			   4.T = "Personalized cost" ///
			   5.T = "SmartWay" ///
			   1.treated = "Pooled", wrap(13)) ///
	order(3.T 2.T 4.T 5.T 1.treated) ///
	yscale(range(-200 50)) /// 
	ylab(-200(50)50, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Treatment effect on relative WTP" "for lower-MPG car ($wtp_unit_vis)") ///
	legend(off)

	* export graph 
	graph export "$rootdir/cars/output/ATE_spike_plot.pdf", replace
	
	restore 
end 

gen_ATE_spike_plot


/*******************************************************************************
Generate ATE spike plots that report conditional ATEs by above- and below-
median values for a specific covariate, along with unconditional ATEs. 

FUNC NAME: gen_ATE_med_spike_plot
FUNC ARGUMENT(S): 
	(1) covariate for above- vs. below-median comparison 
	(2) desired name of covariate in exports
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] ATE_above_and_below_median_`2'_spike_plot.pdf  
*******************************************************************************/

capture program drop gen_ATE_med_spike_plot 
program define gen_ATE_med_spike_plot
	preserve
	
	* rename heterogeneity axis in case name is long 
	gen het = `1'
	
	* summarize variable of interest to get median 
	sum het, d
	gen het_median = r(p50)

	gen het_above_median = het >= het_median
	gen het_below_median = het < het_median

	* generate treatment-specific interactions 
	forval t = 2/5 {
		foreach m in above below {
			gen T`t'`m' = `t'.T * het_`m'_median
		}
	}
		
	* generate pooled interactions 
	foreach m in above below {
		gen treated`m' = treated * het_`m'_median
	}

	* define lists of interaction terms 
	local interactions = "treatedabove treatedbelow"
	
	* run pooled regressions 
	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS, cluster(id)
	eststo TpooledATE
	
	reg delta_wtp_median `interactions' overvaluation_b_median externality het_above_median $CONTROLS, cluster(id)
	eststo TpooledMed

	* run treatment-specific regressions 
	forval t = 2/5 {
		reg delta_wtp_median `t'.T overvaluation_b_median externality $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'ATE
		
		reg delta_wtp_median T`t'above T`t'below overvaluation_b_median externality het_above_median $CONTROLS  if (T == 1 | T == `t'), cluster(id)
		eststo T`t'Med
	}
	
	* generate spike plot combining all relevant coefficients 
	coefplot (T2Med T3Med T4Med T5Med TpooledMed, ///
				label("Below-median" "`2'") ciopts(recast(rcap)) /// 
				rename(T2below = 2.T T3below = 3.T T4below = 4.T ///
					   T5below = 5.T treatedbelow = 1.treated) ///
				keep(T2below T3below T4below T5below treatedbelow)) ///
			 (T2ATE T3ATE T4ATE T5ATE TpooledATE, /// 
				  label("All") msymbol(square) mcolor(black) ///
				  ciopts(lcolor(black) recast(rcap)) ///
				  keep(2.T 3.T 4.T 5.T 1.treated)) ///
	         (T2Med T3Med T4Med T5Med TpooledMed, ///
				  label("Above-median" "`2'") msymbol(smdiamond) mcolor(maroon) ///
				  ciopts(lcolor(maroon) recast(rcap)) ///
				  rename(T2above = 2.T T3above = 3.T T4above = 4.T ///
						 T5above = 5.T treatedabove = 1.treated) ///
				  keep(T2above T3above T4above T5above treatedabove)), vertical ///
	coeflabels(2.T = "Average cost" ///
			   3.T = "Full MPG" ///
			   4.T = "Personalized cost" ///
			   5.T = "SmartWay" ///
			   1.treated = "Pooled", wrap(13)) ///
	order(3.T 2.T 4.T 5.T 1.treated) ///
	yscale(range(-200 50)) /// 
	ylab(-200(50)50, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Treatment effect on relative WTP" "for lower-MPG car ($wtp_unit_vis)") ///
	legend(rows(1))

	* export spike plot 
	graph export "$rootdir/cars/output/ATE_above_and_below_median_`2'_spike_plot.pdf", replace
	
	restore
end 

gen_ATE_med_spike_plot overvaluation_b_median "bias" 
gen_ATE_med_spike_plot externality "externality"
gen_ATE_med_spike_plot distortion_b_median "bias + externality"
gen_ATE_med_spike_plot miles_driven_2019 "miles traveled"


/*******************************************************************************
Generate ATE spike plot that reports conditional ATEs specifically for above-
and below-median bias and externality, all in the same figure. 

FUNC NAME: gen_combo_ATE_med_spike_plot
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figures:
    - [cars/output/] ATE_above_and_below_median_combo_spike_plot.pdf
	- [cars/output/] ATE_above_and_below_median_combo_spike_plot_alt.pdf
*******************************************************************************/

capture program drop gen_combo_ATE_med_spike_plot
program define gen_combo_ATE_med_spike_plot
	preserve
	
	* generate above- and below-median bias 
	sum overvaluation_b_median, d
	gen bias_median = r(p50)

	gen bias_above_median = overvaluation_b_median >= bias_median
	gen bias_below_median = overvaluation_b_median < bias_median
	
	* generate above- and below-median externality 
	sum externality, d
	gen ext_median = r(p50)

	gen ext_above_median = externality >= ext_median
	gen ext_below_median = externality < ext_median
	
	* generate pooled interactions for bias and externality 
	foreach h in bias ext {
		foreach m in above below {
			gen treated`m'_`h' = treated * `h'_`m'_median
		}
	}

	* generate treatment-specific interactions 
	forval t = 2/5 {
		foreach h in bias ext {
			foreach m in above below {
				gen T`t'`m'_`h' = `t'.T * `h'_`m'_median
			}
		}
	}
		
	* run treatment-specific regressions 
	forval t = 2/5 {
		reg delta_wtp_median `t'.T overvaluation_b_median externality $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'ATE
		
		reg delta_wtp_median T`t'above_bias T`t'below_bias overvaluation_b_median externality bias_above_median $CONTROLS  if (T == 1 | T == `t'), cluster(id)
		eststo T`t'MedBias

		reg delta_wtp_median T`t'above_ext T`t'below_ext overvaluation_b_median externality ext_above_median $CONTROLS  if (T == 1 | T == `t'), cluster(id)
		eststo T`t'MedExt
	}
	
	* run ATE regression  
	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS, cluster(id)
	eststo TpooledATE

	* run bias regression
	reg delta_wtp_median treatedabove_bias treatedbelow_bias overvaluation_b_median externality bias_above_median $CONTROLS, cluster(id)
	eststo TpooledMedBias	
	
	* run externality regression
	reg delta_wtp_median treatedabove_ext treatedbelow_ext overvaluation_b_median externality ext_above_median $CONTROLS, cluster(id)
	eststo TpooledMedExt
	
	* produce visualization 
	coefplot (TpooledATE T2ATE T3ATE T4ATE T5ATE, ///
				label("All") ciopts(recast(rcap) ///
				lcolor(black)) mcolor(black) msymbol(square) ///
				keep(1.treated 2.T 3.T 4.T 5.T)) ///
			 (TpooledMedBias T2MedBias T3MedBias T4MedBias T5MedBias, ///
				label("Below-median" "bias") ciopts(recast(rcap) ///
				lcolor(ebblue*2)) mcolor(ebblue*2) msymbol(triangle) ///
				rename(treatedbelow_bias = 1.treated T2below_bias = 2.T ///
				       T3below_bias = 3.T T4below_bias = 4.T T5below_bias = 5.T) ///
				keep(treatedbelow_bias T2below_bias T3below_bias T4below_bias T5below_bias)) ///
			 (TpooledMedBias T2MedBias T3MedBias T4MedBias T5MedBias, ///
				label("Above-median" "bias") ciopts(recast(rcap) ///
				lcolor(maroon)) mcolor(maroon) msymbol(triangle) ///
				rename(treatedabove_bias = 1.treated T2above_bias = 2.T ///
				       T3above_bias = 3.T T4above_bias = 4.T T5above_bias = 5.T) ///
				keep(treatedabove_bias T2above_bias T3above_bias T4above_bias T5above_bias)) ///
			 (TpooledMedExt T2MedExt T3MedExt T4MedExt T5MedExt, ///
				label("Below-median" "externality") ciopts(recast(rcap) ///
				lcolor(ebblue*2)) mcolor(ebblue*2) msymbol(circle) ///
				rename(treatedbelow_ext = 1.treated T2below_ext = 2.T ///
				       T3below_ext = 3.T T4below_ext = 4.T T5below_ext = 5.T) ///
				keep(treatedbelow_ext T2below_ext T3below_ext T4below_ext T5below_ext)) ///
			 (TpooledMedExt T2MedExt T3MedExt T4MedExt T5MedExt, ///
				label("Above-median" "externality") ciopts(recast(rcap) ///
				lcolor(maroon)) mcolor(maroon) msymbol(circle) ///
				rename(treatedabove_ext = 1.treated T2above_ext = 2.T ///
				       T3above_ext = 3.T T4above_ext = 4.T T5above_ext = 5.T) ///
				keep(treatedabove_ext T2above_ext T3above_ext T4above_ext T5above_ext)), vertical ///
	coeflabels(2.T = "Average cost" ///
			   3.T = "Full MPG" ///
			   4.T = "Personalized cost" ///
			   5.T = "SmartWay" ///
			   1.treated = "Pooled", wrap(13)) ///
	order(3.T 2.T 4.T 5.T 1.treated) ///
	yscale(range(-200 50)) /// 
	ylab(-200(50)50, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Treatment effect on relative WTP" "for lower-MPG car ($wtp_unit_vis)") ///
	legend(rows(1)) ///
	xsize(6)
	
	* export
	graph export "$rootdir/cars/output/ATE_above_and_below_median_combo_spike_plot.pdf", replace	
	
	* produce alternate visualization
	coefplot (TpooledMedBias TpooledMedExt TpooledATE, ///
				ciopts(recast(rcap)) ///
				keep(treatedbelow_bias treatedbelow_ext 1.treated ///
				     treatedabove_ext treatedabove_bias)), vertical ///
	coeflabels(treatedbelow_bias = "Below-median bias" ///
			   treatedbelow_ext = "Below-median externality" ///
			   1.treated = "All" ///
			   treatedabove_ext = "Above-median externality" ///
			   treatedabove_bias = "Above-median bias", wrap(13) labsize(3.2)) ///
	order(1.treated treatedbelow_bias treatedabove_bias treatedbelow_ext treatedabove_ext) ///
	yscale(range(-200 50)) /// 
	ylab(-200(50)50, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	ytitle("Treatment effect on relative WTP" "for lower-MPG car ($wtp_unit_vis)") ///
	legend(off)
	
	* export 
	graph export "$rootdir/cars/output/ATE_above_and_below_median_combo_spike_plot_alt.pdf", replace	

	restore 
end 

gen_combo_ATE_med_spike_plot


/*******************************************************************************
Generate baseline demand curve across all groups (control + treatments). 

FUNC NAME: gen_baseline_demand_curve
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] demand_pre (all).pdf
*******************************************************************************/

capture program drop gen_baseline_demand_curve
program define gen_baseline_demand_curve 
	preserve
	
	* reshape data for aggregation by price 
	keep id T product_pair demand*
	reshape long demand_pre demand_post, i(id product_pair) j(index)
	gen price = 100*index - 1600

	* aggregate by price to get demand curve 
	collapse demand_pre, by(price)
	sort price 

	* graph demand curve 
	twoway (line price demand_pre, c(stepstair) lc(dknavy) lwidth(thick) msymbol(none) ), ///
			plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
			graphregion(fcolor(white) lcolor(white)) ///
			xtitle("Demand") ///
			ytitle("Relative price of lower-MPG car ($wtp_unit_vis)") ///
			xscale(range(0 1)) ///
			xlab(0(0.2)1) ///
			ylab(-1500(500)1500, format(%15.0gc)) ///
			legend(label(1 "Pre-NPI"))
			
	* export 
	graph export "$rootdir/cars/output/baseline_demand.pdf", replace	
	
	restore
end

gen_baseline_demand_curve


/*******************************************************************************
Create helper function to calculate welfare statistics in parameters function. 

FUNC NAME: calc_welfare
FUNC ARGUMENT(S): 
    (1) E[tau]
	(2) E[distortion]
	(3) Dp 
	(4) Var[tau]
	(5) Cov[distortion, tau]
	(6) DeltaI 
	(7) Rho
	(8) Mu
FUNC RESULT(S): Saves the following welfare statistics locally:
    - welfare_tax_w_npi_temp (welfare of tax in the presence of NPI)
    - welfare_tax_wo_npi_temp (welfare of tax without the presence of NPI)
    - welfare_npi_w_tax_temp (welfare of NPI in the presence of tax)
    - welfare_npi_wo_tax_temp (welfare of NPI without the presence of tax)
    - welfare_zero_var_cov_temp (counterfactual NPI welfare w/ zero var and cov)
    - welfare_zero_tau_temp (counterfactual NPI welfare w/ zero tau)
    - welfare_zero_tau_cov_temp (counterfactual NPI welfare w/ zero tau and cov)
    - welfare_zero_cov_temp (counterfactual NPI welfare w/ zero cov)
*******************************************************************************/

capture program drop calc_welfare
program define calc_welfare, rclass

	syntax, e_tau(str) e_distortion(str) dp(str) var_tau(str) ///
	        cov_distortion_tau(str) delta_i(str) rho(str) mu(str)
	
	* calculate primary welfare estimates
	
	cap scalar drop welfare_tax_w_npi_temp welfare_tax_wo_npi_temp ///
	                welfare_npi_w_tax_temp welfare_npi_wo_tax_temp
	
	local welfare_tax_w_npi_temp = -(`rho' / 2) * ((`mu' - `e_distortion' - `e_tau') ^ 2) * `dp'
	local welfare_tax_wo_npi_temp = -(`rho' / 2) * ((`mu' - `e_distortion') ^ 2) * `dp'
	
	local welfare_npi_w_tax_temp = (0.5) * (`var_tau' + 2 * `cov_distortion_tau') * `dp' + `delta_i' 
	local welfare_npi_wo_tax_temp = (0.5) * (`var_tau' + 2 * `cov_distortion_tau' + ///
	                           `rho' * ((`e_tau')^2 + 2 * `e_tau' * (`e_distortion' - `mu'))) * `dp' + `delta_i'

	return scalar welfare_tax_w_npi_temp = `welfare_tax_w_npi_temp'
	return scalar welfare_tax_wo_npi_temp = `welfare_tax_wo_npi_temp'
	return scalar welfare_npi_w_tax_temp = `welfare_npi_w_tax_temp'
	return scalar welfare_npi_wo_tax_temp = `welfare_npi_wo_tax_temp'
	
	* calculate special-case welfare estimates 
	
	cap scalar drop welfare_zero_var_cov_temp welfare_zero_tau_temp ///
	                welfare_zero_tau_cov_temp welfare_zero_cov_temp

	local welfare_zero_var_cov_temp = (0.5) * (0 + 2 * 0 + ///
	                           `rho' * ((`e_tau')^2 + 2 * `e_tau' * (`e_distortion' - `mu'))) * `dp' + `delta_i'
	local welfare_zero_tau_temp = (0.5) * (`var_tau' + 2 * `cov_distortion_tau' + ///
	                           `rho' * ((0)^2 + 2 * 0 * (`e_distortion' - `mu'))) * `dp' + `delta_i'
	local welfare_zero_tau_cov_temp = (0.5) * (`var_tau' + 2 * 0 + ///
	                           `rho' * ((0)^2 + 2 * 0 * (`e_distortion' - `mu'))) * `dp' + `delta_i'
	local welfare_zero_cov_temp = (0.5) * (`var_tau' + 2 * 0 + ///
	                           `rho' * ((`e_tau')^2 + 2 * `e_tau' * (`e_distortion' - `mu'))) * `dp' + `delta_i'
	
	return scalar welfare_zero_var_cov_temp = `welfare_zero_var_cov_temp'
	return scalar welfare_zero_tau_temp = `welfare_zero_tau_temp'
	return scalar welfare_zero_tau_cov_temp = `welfare_zero_tau_cov_temp'
	return scalar welfare_zero_cov_temp = `welfare_zero_cov_temp'

end 


/*******************************************************************************
Estimate main results. 

FUNC NAME: parameters
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Saves all relevant parameters and statistics locally. There are 
    too many to enumerate specifically, but they generally fall into the 
	following categories: 
	- Bias
	- Externality
	- Distortion
	- Tau
	- Dp 
	- Var[tau]
	- Cov[distortion, tau]
	- Welfare
	- Other (inattention, market share reduction, distortion offset)
*******************************************************************************/

capture program drop parameters
program define parameters, rclass
	preserve 
	
	/******************************
	E[gamma] (pooled)
	******************************/

	qui reg overvaluation_b_median, cluster(id)
	scalar e_gamma = _b[_cons]
	return scalar e_gamma = e_gamma
	local e_gamma = e_gamma 
	
	scalar se_e_gamma = _se[_cons]
	return scalar se_e_gamma = se_e_gamma

	
	/******************************
	SD(gamma) (pooled)
	******************************/

	sum overvaluation_b_median, d
	scalar sd_gamma = r(sd)
	return scalar sd_gamma = sd_gamma
	
	
	/******************************
	E[externality] (pooled)
	******************************/
	
	qui reg externality, cluster(id)
	scalar e_phi = _b[_cons]
	return scalar e_phi = e_phi
	local e_phi = e_phi 
	
	scalar se_e_phi = _se[_cons]
	return scalar se_e_phi = se_e_phi
	
	
	/******************************
	SD(externality) (pooled)
	******************************/

	sum externality, d
	scalar sd_phi = r(sd)
	return scalar sd_phi = sd_phi
	
	
	/******************************
	E[distortion] (pooled)
	******************************/

	qui reg distortion_b_median, cluster(id)
	scalar e_distortion = _b[_cons]
	return scalar e_distortion = e_distortion
	local e_distortion = e_distortion 
	
	scalar se_e_distortion= _se[_cons]
	return scalar se_e_distortion = se_e_distortion
	
	
	/******************************
	E[distortion] (middle 50%)
	******************************/

	qui reg distortion if middle50ind == 1, cluster(id)
	scalar e_distortion_mid50 = _b[_cons]
	return scalar e_distortion_mid50 = e_distortion_mid50
	local e_distortion_mid50 = e_distortion_mid50 
	
	scalar se_e_distortion_mid50 = _se[_cons]
	return scalar se_e_distortion_mid50 = se_e_distortion_mid50
	
	
	/******************************
	E[tau] (pooled)
	******************************/

	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS, cluster(id)
	scalar e_tau = _b[1.treated]
	return scalar e_tau = _b[1.treated]
	local e_tau = e_tau
	
	scalar se_e_tau = _se[1.treated]
	return scalar se_e_tau = se_e_tau
	
	scalar neg_e_tau = e_tau * -1
	return scalar neg_e_tau = neg_e_tau
	

	/******************************
	E[tau] (by T)
	******************************/

	forval t = 2/5 {
		reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS if (T == `t' | T == 1), cluster(id)
		scalar e_tau`t' = _b[1.treated]
		return scalar e_tau`t' = _b[1.treated]
		local e_tau`t' = e_tau`t'
		
		scalar se_e_tau`t' = _se[1.treated]
		return scalar se_e_tau`t' = se_e_tau`t'
	}
	
	
	/******************************
	E[tau] (middle 50%)
	******************************/

	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS if middle50ind == 1, cluster(id)
	scalar e_tau_mid50 = _b[1.treated]
	return scalar e_tau_mid50 = _b[1.treated]
	local e_tau_mid50 = e_tau_mid50

	scalar se_e_tau_mid50 = _se[1.treated]
	return scalar se_e_tau_mid50 = se_e_tau_mid50

	
	/******************************
	Dp (pooled)
	******************************/
	
	* get demand at each relevant price
	local demand_points "15 17"
	foreach j in `demand_points' {
		egen sum_demand_pre`j' = mean(demand_pre`j')
	}
	
	* get slope of demand at relative price of $0 (j = 16 corresponds to $0)
	gen slope_D = (sum_demand_pre17 - sum_demand_pre15) / (100 * 2)
	sum slope_D
	scalar Dp = r(mean)
	return scalar Dp = Dp
	local Dp = Dp
	
	drop slope_D sum_demand_pre15 sum_demand_pre17
	
	
	/******************************
	Dp (middle 50%)
	******************************/

	foreach j in `demand_points' {
		gen demand_pre`j'_mid50 = .
		replace demand_pre`j'_mid50 = demand_pre`j' if middle50ind == 1
		egen sum_demand_pre`j'_mid50 = mean(demand_pre`j'_mid50)
	}

	gen slope_D_mid50 = (sum_demand_pre17_mid50-sum_demand_pre15_mid50) / (100 * 2)
	sum slope_D_mid50
	scalar Dp_mid50 = r(mean)
	return scalar Dp_mid50 = Dp_mid50
	local Dp_mid50 = Dp_mid50

	drop slope_D_mid50 sum_demand_pre15_mid50 sum_demand_pre17_mid50 ///
	     demand_pre15_mid50 demand_pre17_mid50
	
	
	/******************************
	Var(tau) via simple ME 
	******************************/
	
	* pooled 
	xi i.treated
	xi i.product_pair_strict
	xi: xtmixed delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS || id: i.treated, ///
	            vce(cluster id) iter(100) variance nolr
	eststo simple_ME_reg
	_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
	return list
	scalar var_tau = r(est)
	scalar se_var_tau = r(se)
	return scalar var_tau = var_tau 
	local var_tau = var_tau
	return scalar se_var_tau = se_var_tau
	
	scalar sd_tau = (var_tau) ^ .5
	local sd_tau = sd_tau
	return scalar sd_tau = sd_tau 
	
	* by treatment 
	forval t = 2/5 {
		xi i.treated
		xi i.product_pair_strict
		xi: xtmixed delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS ///
		            if (T == 1 | T == `t') || id: i.treated, vce(cluster id) iter(100) variance nolr
		eststo simple_ME_reg`t'
		_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
		return list
		scalar var_tau`t' = r(est)
		scalar se_var_tau`t' = r(se)
		return scalar var_tau`t' = var_tau`t' 
		local var_tau`t' = var_tau`t'
		return scalar se_var_tau`t' = se_var_tau`t'
	}
	
	* middle-50% sample 
	xi i.treated
	xi i.product_pair_strict
	xi: xtmixed delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS ///
	            if middle50ind == 1 || id: i.treated, vce(cluster id) iter(100) variance nolr
	eststo simple_ME_reg_mid50
	_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
	return list
	scalar var_tau_mid50 = r(est)
	scalar se_var_tau_mid50 = r(se)
	return scalar var_tau_mid50 = var_tau_mid50 
	local var_tau_mid50 = var_tau_mid50
	return scalar se_var_tau_mid50 = se_var_tau_mid50

	
	/******************************
	Cov[distortion, tau] via full ME
	******************************/
	
	* Var(bias), Var(ext), Cov(bias, ext) for use in calculating Cov[distortion, tau]
	sum overvaluation_b_median, d
	scalar var_bias = r(Var)
	
	sum externality, d
	scalar var_ext = r(Var)
	
	correlate overvaluation_b_median externality, covariance
	scalar cov_bias_ext = r(cov_12)
	return scalar cov_bias_ext = cov_bias_ext
	
	* pooled 
	xi i.treated
	xi i.product_pair_strict
	
	cap gen bias_treated = overvaluation_b_median * treated
	cap gen ext_treated = externality * treated
	
	xi: xtmixed delta_wtp_median i.treated overvaluation_b_median bias_treated externality ext_treated $CONTROLS || id: i.treated, vce(cluster id) iter(100) variance nolr
	
	* covariance parameter estimates 
	scalar cov_bias_tau = (_b[bias_treated] * var_bias) + (_b[ext_treated] * cov_bias_ext)
	return scalar cov_bias_tau = cov_bias_tau 
	local cov_bias_tau = cov_bias_tau
	
	scalar cov_ext_tau = (_b[ext_treated] * var_ext) + (_b[bias_treated] * cov_bias_ext)
	return scalar cov_ext_tau = cov_ext_tau 
	local cov_ext_tau = cov_ext_tau
	
	scalar cov_distortion_tau = cov_bias_tau + cov_ext_tau
	return scalar cov_distortion_tau = cov_distortion_tau
	local cov_distortion_tau = cov_distortion_tau

	* covariance SE estimates
	nlcom (bias_treated_scaled: (var_bias * _b[bias_treated]) + (cov_bias_ext * _b[ext_treated])) ///
	      (ext_treated_scaled: (var_ext * _b[ext_treated]) + (cov_bias_ext * _b[bias_treated])), post
	
	scalar se_cov_bias_tau = _se[bias_treated_scaled]
	return scalar se_cov_bias_tau = se_cov_bias_tau

	scalar se_cov_ext_tau = _se[ext_treated_scaled]
	return scalar se_cov_ext_tau = se_cov_ext_tau

	eststo full_ME_reg
	
	* by treatment 
	forval t = 2/5 {
		
		* treatment-specific Var(bias) and Var(ext) for use in calculating Cov[distortion, tau]
		sum overvaluation_b_median if (T == 1 | T == `t'), d
		scalar var_bias`t' = r(Var)
		
		sum externality if (T == 1 | T == `t'), d
		scalar var_ext`t' = r(Var)

		correlate overvaluation_b_median externality if (T == 1 | T == `t'), covariance
		scalar cov_bias_ext`t' = r(cov_12)

		cap gen T`t' = (T == `t')
		cap gen bias_treated`t' = overvaluation_b_median * T`t'
		cap gen ext_treated`t' = externality * T`t'
			
		xi T`t'
		xi i.product_pair_strict
		xi: xtmixed delta_wtp_median T`t' overvaluation_b_median bias_treated`t' externality ext_treated`t' $CONTROLS if (T == 1 | T == `t') || id: T`t', vce(cluster id) iter(100) variance nolr 
		
		* covariance parameter estimates
		scalar cov_bias_tau`t' = (_b[bias_treated`t'] * var_bias`t') + (cov_bias_ext`t' * _b[ext_treated`t'])
		return scalar cov_bias_tau`t' = cov_bias_tau`t'
		local cov_bias_tau`t' = cov_bias_tau`t'
		
		scalar cov_ext_tau`t' = (_b[ext_treated`t'] * var_ext`t') + (cov_bias_ext`t' * _b[bias_treated`t'])
		return scalar cov_ext_tau`t' = cov_ext_tau`t'
		local cov_ext_tau`t' = cov_ext_tau`t'
		
		scalar cov_distortion_tau`t' = cov_bias_tau`t' + cov_ext_tau`t'
		return scalar cov_distortion_tau`t' = cov_distortion_tau`t'
		local cov_distortion_tau`t' = cov_distortion_tau`t'
	
		* covariance SE estimates
		nlcom (bias_treated_scaled`t': (var_bias`t' * _b[bias_treated`t']) + ///
		                               (cov_bias_ext`t' * _b[ext_treated`t'])) ///
		      (ext_treated_scaled`t': (var_ext`t' * _b[ext_treated`t']) + ///
			                          (cov_bias_ext`t' * _b[bias_treated`t'])), post
		
		scalar se_cov_bias_tau`t' = _se[bias_treated_scaled`t']
		return scalar se_cov_bias_tau`t' = se_cov_bias_tau`t'

		scalar se_cov_ext_tau`t' = _se[ext_treated_scaled`t']
		return scalar se_cov_ext_tau`t' = se_cov_ext_tau`t'

		eststo full_ME_reg`t'
		
	}

	* middle-50% 
	sum overvaluation_b_median if middle50ind == 1, d
	scalar var_bias_mid50 = r(Var)
	
	sum externality if middle50ind == 1, d
	scalar var_ext_mid50 = r(Var)

	correlate overvaluation_b_median externality if middle50ind == 1, covariance
	scalar cov_bias_ext_mid50 = r(cov_12)

	xi i.treated
	xi i.product_pair_strict
	xi: xtmixed delta_wtp_median i.treated overvaluation_b_median bias_treated externality ext_treated $CONTROLS if middle50ind == 1 || id: i.treated, vce(cluster id) iter(100) variance nolr
	
	* covariance parameter estimates 
	scalar cov_bias_tau_mid50 = (_b[bias_treated] * var_bias_mid50) + ///
	                            (cov_bias_ext_mid50 * _b[ext_treated])
	return scalar cov_bias_tau_mid50 = cov_bias_tau_mid50
	local cov_bias_tau_mid50 = cov_bias_tau_mid50
	
	scalar cov_ext_tau_mid50 = (_b[ext_treated] * var_ext_mid50) + ///
	                           (cov_bias_ext_mid50 * _b[bias_treated])
	return scalar cov_ext_tau_mid50 = cov_ext_tau_mid50
	local cov_ext_tau_mid50 = cov_ext_tau_mid50
	
	scalar cov_distortion_tau_mid50 = cov_bias_tau_mid50 + cov_ext_tau_mid50
	return scalar cov_distortion_tau_mid50 = cov_distortion_tau_mid50
	local cov_distortion_tau_mid50 = cov_distortion_tau_mid50

	* covariance SE estimates 
	nlcom (bias_treated_scaled_mid50: (var_bias_mid50 * _b[bias_treated]) + ///
	                                  (cov_bias_ext_mid50 * _b[ext_treated])) ///
	      (ext_treated_scaled_mid50: (var_ext_mid50 * _b[ext_treated]) + ///
	                                 (cov_bias_ext_mid50 * _b[bias_treated])), post
	
	scalar se_cov_bias_tau_mid50 = _se[bias_treated_scaled_mid50]
	return scalar se_cov_bias_tau_mid50 = se_cov_bias_tau_mid50

	scalar se_cov_ext_tau_mid50 = _se[ext_treated_scaled_mid50]
	return scalar se_cov_ext_tau_mid50 = se_cov_ext_tau_mid50

	eststo var_full_ME_reg_mid50

	
	/******************************
	Coefficient of variation
	******************************/
	
	scalar coef_of_var = sd_tau / abs(e_tau)
	local coef_of_var = coef_of_var
	return scalar coef_of_var = coef_of_var
	
	
	/******************************
	Cov[distortion, tau] via alt. method
	******************************/
	
	correlate distortion_b_median delta_wtp_median if treated == 1, cov
	scalar cov_gamma_tau_diff = r(C)[2,1]
	return scalar cov_gamma_tau_diff = cov_gamma_tau_diff
	
	
	/******************************
	Welfare
	******************************/
	
	* pooled 
	calc_welfare, e_tau("`e_tau'") e_distortion("`e_distortion'") dp("`Dp'") var_tau("`var_tau'") ///
	              cov_distortion_tau("`cov_distortion_tau'") delta_i("$DeltaI") rho("$rho") mu("$mu")
	return list
	
	return scalar welfare_tax_w_npi = r(welfare_tax_w_npi_temp)
	return scalar welfare_tax_wo_npi = r(welfare_tax_wo_npi_temp)
	return scalar welfare_npi_w_tax = r(welfare_npi_w_tax_temp)
	return scalar welfare_npi_wo_tax = r(welfare_npi_wo_tax_temp)

	return scalar welfare_zero_var_cov = r(welfare_zero_var_cov_temp)
	return scalar welfare_zero_tau = r(welfare_zero_tau_temp)
	return scalar welfare_zero_tau_cov = r(welfare_zero_tau_cov_temp)
	return scalar welfare_zero_cov = r(welfare_zero_cov_temp)
	
	scalar neg_welfare_zero_tau = r(welfare_zero_tau_temp) * (-1)
	scalar neg_welfare_zero_tau_cov = r(welfare_zero_tau_cov_temp) * (-1)
	
	return scalar neg_welfare_zero_tau = neg_welfare_zero_tau
	return scalar neg_welfare_zero_tau_cov = neg_welfare_zero_tau_cov
	
	* by treatment 
	forval t = 2/5 {	
		
		calc_welfare, e_tau("`e_tau`t''") e_distortion("`e_distortion'") dp("`Dp'") var_tau("`var_tau`t''") ///
	                  cov_distortion_tau("`cov_distortion_tau`t''") delta_i("$DeltaI") rho("$rho") mu("$mu")
		return list
		
		return scalar welfare_tax_w_npi`t' = r(welfare_tax_w_npi_temp)
		return scalar welfare_tax_wo_npi`t' = r(welfare_tax_wo_npi_temp)
		return scalar welfare_npi_w_tax`t' = r(welfare_npi_w_tax_temp)
		return scalar welfare_npi_wo_tax`t' = r(welfare_npi_wo_tax_temp)
		
	}
	
	* middle-50% 
	calc_welfare, e_tau("`e_tau_mid50'") e_distortion("`e_distortion_mid50'") dp("`Dp_mid50'") ///
	              var_tau("`var_tau_mid50'") cov_distortion_tau("`cov_distortion_tau_mid50'") ///
				  delta_i("$DeltaI") rho("$rho") mu("$mu")
	return list
	
	return scalar welfare_tax_w_npi_mid50 = r(welfare_tax_w_npi_temp)
	return scalar welfare_tax_wo_npi_mid50 = r(welfare_tax_wo_npi_temp)
	return scalar welfare_npi_w_tax_mid50 = r(welfare_npi_w_tax_temp)
	return scalar welfare_npi_wo_tax_mid50 = r(welfare_npi_wo_tax_temp)
		
	
	/******************************
	Inattention percentage
	******************************/

	sum cost_savings, d
	scalar avg_cost_savings = r(mean)
	local avg_cost_savings = avg_cost_savings
	
	scalar inattention_percentage = (e_gamma / avg_cost_savings) * 100
	return scalar inattention_percentage = inattention_percentage
	
	
	/******************************
	Market share reduction
	******************************/

	scalar market_share_reduction = (`e_tau' * `Dp') * 100
	return scalar market_share_reduction = market_share_reduction
	
	
	/******************************
	Distortion offset percentage 
	******************************/

	scalar distortion_offset = (((-1) * `e_tau') / (`e_gamma' + `e_phi')) * 100
	return scalar distortion_offset = distortion_offset
	
	restore 
end


/*******************************************************************************
Generate parameter estimates and export to LaTeX file. 

FUNC NAME: gen_param_estimates
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports all relevant parameters and statistics to LaTeX file. 
    There are too many exports to detail here -- see documentation of the 
	`parameters`' function for a brief accounting. 
*******************************************************************************/

capture program drop gen_param_estimates
program define gen_param_estimates
	preserve 
	
	* get parameter estimates 
	
	parameters 
	return list

	* save important coefficients to numbers.tex 
	
	local e_tau: di r(e_tau)
	local neg_e_tau: di r(neg_e_tau)
	local e_gamma: di r(e_gamma)
	local sd_gamma: di r(sd_gamma)
	local e_phi: di r(e_phi)
	local sd_phi: di r(sd_phi)
	local e_distortion: di r(e_distortion)
	local Dp: di r(Dp)
	local var_tau: di r(var_tau)
	local sd_tau: di r(sd_tau)
	local coef_of_var: di r(coef_of_var)
	local cov_bias_tau: di r(cov_bias_tau)
	local cov_ext_tau: di r(cov_ext_tau)
	local cov_distortion_tau: di r(cov_distortion_tau)
	local cov_bias_ext: di r(cov_bias_ext)
	local welfare_npi_w_tax: di r(welfare_npi_w_tax)
	local welfare_npi_wo_tax: di r(welfare_npi_wo_tax)
	local welfare_zero_var_cov: di r(welfare_zero_var_cov)
	local welfare_zero_tau: di r(welfare_zero_tau)
	local welfare_zero_tau_cov: di r(welfare_zero_tau_cov)
	local welfare_zero_cov: di r(welfare_zero_cov)
	local neg_welfare_zero_tau: di r(neg_welfare_zero_tau)
	local neg_welfare_zero_tau_cov: di r(neg_welfare_zero_tau_cov)
	local cov_gamma_tau_diff: di r(cov_gamma_tau_diff)
	local inattention_percentage: di r(inattention_percentage)
	local market_share_reduction: di r(market_share_reduction)
	local distortion_offset: di r(distortion_offset)
	
	local se_e_tau: di r(se_e_tau)
	local se_e_gamma: di r(se_e_gamma)
	local se_e_phi: di r(se_e_phi)
	local se_e_distortion: di r(se_e_distortion)
	local se_var_tau: di r(se_var_tau)
	local se_cov_bias_tau: di r(se_cov_bias_tau)
	local se_cov_ext_tau: di r(se_cov_ext_tau)

	latex_rounded, name("carsETau") value(`e_tau') digits(0)
	latex_rounded, name("carsNegETau") value(`neg_e_tau') digits(0)
	latex_rounded, name("carsEGamma") value(`e_gamma') digits(0)
	latex_rounded, name("carsSDGamma") value(`sd_gamma') digits(0)
	latex_rounded, name("carsEPhi") value(`e_phi') digits(0)
	latex_rounded, name("carsSDPhi") value(`sd_phi') digits(0)
	latex_rounded, name("carsEDistortion") value(`e_distortion') digits(0)
	latex_rounded, name("carsEDelta") value(`e_distortion') digits(0)
	latex_rounded, name("carsDp") value(`Dp') digits(5)
	latex_rounded, name("carsVarTau") value(`var_tau') digits(0)
	latex_rounded, name("carsSDTau") value(`sd_tau') digits(0)
	latex_rounded, name("carsCoefOfVar") value(`coef_of_var') digits(1)
	latex_rounded, name("carsCovBiasTau") value(`cov_bias_tau') digits(0)
	latex_rounded, name("carsCovExtTau") value(`cov_ext_tau') digits(0)
	latex_rounded, name("carsCovDistortionTau") value(`cov_distortion_tau') digits(0)
	latex_rounded, name("carsCovBiasExt") value(`cov_bias_ext') digits(0)
	latex_rounded, name("carsWelfareNPIWithTax") value(`welfare_npi_w_tax') digits(2)
	latex_rounded, name("carsWelfareNPIWithoutTax") value(`welfare_npi_wo_tax') digits(2)
	latex_rounded, name("carsWelfareNPIWithoutTaxZeroVarCov") value(`welfare_zero_var_cov') digits(2)
	latex_rounded, name("carsWelfareNPIWithoutTaxZeroTau") value(`welfare_zero_tau') digits(2)
	latex_rounded, name("carsWelfareNPIWithoutTaxZeroTauCov") value(`welfare_zero_tau_cov') digits(2)
	latex_rounded, name("carsWelfareNPIWithoutTaxZeroCov") value(`welfare_zero_cov') digits(2)
	latex_rounded, name("carsNegWelfareNPIWithoutTaxZeroTau") value(`neg_welfare_zero_tau') digits(2)
	latex_rounded, name("carsNegWelfareNPIWithoutTaxZeroTauCov") value(`neg_welfare_zero_tau_cov') digits(2)
	latex_rounded, name("carsRho") value("$rho") digits(2)
	latex_rounded, name("carsMu") value("$mu") digits(0)
	latex_rounded, name("carsCovDiff") value(`cov_gamma_tau_diff') digits(0)
	latex_rounded, name("carsInattentionPercentage") value(`inattention_percentage') digits(0)
	latex_rounded, name("carsMktShareReduction") value(`market_share_reduction') digits(0)
	latex_rounded, name("carsDistOffset") value(`distortion_offset') digits(0)
	
	latex_rounded, name("carsSEETau") value(`se_e_tau') digits(0)
	latex_rounded, name("carsSEEGamma") value(`se_e_gamma') digits(1)
	latex_rounded, name("carsSEEPhi") value(`se_e_phi') digits(2)
	latex_rounded, name("carsSEEDistortion") value(`se_e_distortion') digits(0)
	latex_rounded, name("carsSEVarTau") value(`se_var_tau') digits(0)
	latex_rounded, name("carsSECovBiasTau") value(`se_cov_bias_tau') digits(0)
	latex_rounded, name("carsSECovExtTau") value(`se_cov_ext_tau') digits(0)
	latex_rounded, name("carsSERho") value(0) digits(2)
	latex_rounded, name("carsSEMu") value(0) digits(0)

	* iterate over each treatment and store values, accounting for the fact
	* that spelled numbers (e.g., Two, Three) must be used to name scalars
	
	local Ts 2 3 4 5
	local TStrs Two Three Four Five
	local n : word count `Ts'

	forvalues i = 1/`n' {
		local t : word `i' of `Ts'
		local tstr : word `i' of `TStrs'
		
		local e_tau: di r(e_tau`t')
		local var_tau: di r(var_tau`t')
		local cov_bias_tau: di r(cov_bias_tau`t')
		local cov_ext_tau: di r(cov_ext_tau`t')
		local welfare_npi_w_tax: di r(welfare_npi_w_tax`t')
		local welfare_npi_wo_tax: di r(welfare_npi_wo_tax`t')

		local se_e_tau: di r(se_e_tau`t')
		local se_var_tau: di r(se_var_tau`t')
		local se_cov_bias_tau: di r(se_cov_bias_tau`t')
		local se_cov_ext_tau: di r(se_cov_ext_tau`t')

		latex_rounded, name("carsETau`tstr'T") value(`e_tau') digits(0)
		latex_rounded, name("carsVarTau`tstr'T") value(`var_tau') digits(0)
		latex_rounded, name("carsCovBiasTau`tstr'T") value(`cov_bias_tau') digits(0)
		latex_rounded, name("carsCovExtTau`tstr'T") value(`cov_ext_tau') digits(0)
		latex_rounded, name("carsWelfareNPIWithTax`tstr'T") value(`welfare_npi_w_tax') digits(2)
		latex_rounded, name("carsWelfareNPIWithoutTax`tstr'T") value(`welfare_npi_wo_tax') digits(2)
		
		latex_rounded, name("carsSEETau`tstr'T") value(`se_e_tau') digits(0)
		latex_rounded, name("carsSEVarTau`tstr'T") value(`se_var_tau') digits(0)
		latex_rounded, name("carsSECovBiasTau`tstr'T") value(`se_cov_bias_tau') digits(0)
		latex_rounded, name("carsSECovExtTau`tstr'T") value(`se_cov_ext_tau') digits(0)
	}
	
	* also export coefficient values for the middle-50% sample 
	
	local e_tau: di r(e_tau_mid50)
	local e_distortion: di r(e_distortion_mid50)
	local Dp: di r(Dp_mid50)
	local var_tau: di r(var_tau_mid50)
	local cov_bias_tau: di r(cov_bias_tau_mid50)
	local cov_ext_tau: di r(cov_ext_tau_mid50)
	local welfare_npi_w_tax: di r(welfare_npi_w_tax_mid50)
	local welfare_npi_wo_tax: di r(welfare_npi_wo_tax_mid50)

	local se_e_tau: di r(se_e_tau_mid50)
	local se_e_distortion: di r(se_e_distortion_mid50)
	local se_var_tau: di r(se_var_tau_mid50)
	local se_cov_bias_tau: di r(se_cov_bias_tau_mid50)
	local se_cov_ext_tau: di r(se_cov_ext_tau_mid50)
	
	latex_rounded, name("carsETauMidFifty") value(`e_tau') digits(0)
	latex_rounded, name("carsEDistortionMidFifty") value(`e_distortion') digits(0)
	latex_rounded, name("carsDpMidFifty") value(`Dp') digits(5)
	latex_rounded, name("carsVarTauMidFifty") value(`var_tau') digits(0)
	latex_rounded, name("carsCovBiasTauMidFifty") value(`cov_bias_tau') digits(0)
	latex_rounded, name("carsCovExtTauMidFifty") value(`cov_ext_tau') digits(0)
	latex_rounded, name("carsWelfareNPIWithTaxMidFifty") value(`welfare_npi_w_tax') digits(2)
	latex_rounded, name("carsWelfareNPIWithoutTaxMidFifty") value(`welfare_npi_wo_tax') digits(2)

	latex_rounded, name("carsSEETauMidFifty") value(`se_e_tau') digits(0)
	latex_rounded, name("carsSEEDistortionMidFifty") value(`se_e_distortion') digits(0)
	latex_rounded, name("carsSEVarTauMidFifty") value(`se_var_tau') digits(0)
	latex_rounded, name("carsSECovBiasTauMidFifty") value(`se_cov_bias_tau') digits(0)
	latex_rounded, name("carsSECovExtTauMidFifty") value(`se_cov_ext_tau') digits(0)

	restore 
end 

gen_param_estimates


/*******************************************************************************
Generate data for welfare comparative statics figures by estimating and 
exporting various counterfactual welfare statistics. 

FUNC NAME: gen_welfare_sensitivity_data
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Saves treatment-specific statistics to the following files:
    - [cars/output/welfare/] welfare_plot_table_1.xlsx
    - [cars/output/welfare/] welfare_plot_table_2.xlsx
    - [cars/output/welfare/] welfare_plot_table_3.xlsx
    - [cars/output/welfare/] welfare_plot_table_4.xlsx
    - [cars/output/welfare/] welfare_plot_table_5.xlsx
    - [cars/output/welfare/] welfare_plot_table_all.xlsx
*******************************************************************************/

capture program drop gen_welfare_sensitivity_data
program define gen_welfare_sensitivity_data
	preserve 
	
	* iterate over all treatment options, exporting data for each one 
	foreach t in -1 2 3 4 5 {
		
		* run parameters function to get point estimates for variance, covariance,
		* Dp, E[tau], and E[distortion]
		parameters
		return list
		
		* determine which treatment is being used (pooled (-1) or T=2,3,4,5)
		if `t' == -1 {
			local T = ""
			local Tstr = "all"
		}
		else {
			local T = `t'
			local Tstr = "`t'"
		}

		local e_tau = r(e_tau`T')
		local e_distortion = r(e_distortion)
		local Dp = r(Dp)
		local var_tau = r(var_tau`T')
		local cov = r(cov_distortion_tau`T')
		
		* define x axis limits for variance, covariance, rho, and mu
		local var_xlim_min = 2500
		local var_xlim_max = 60000
		local cov_xlim_min = -30000
		local cov_xlim_max = 30000
		local rho_xlim_min = 0
		local rho_xlim_max = 1
		local mu_xlim_min = -1400
		local mu_xlim_med = 0
		local mu_xlim_max = 1400
		local delta_xlim_min = -400
		local delta_xlim_med = 0
		local delta_xlim_max = 400
		local DeltaI_xlim_min = -200
		local DeltaI_xlim_max = 200
		
		* use parameters to create excel spreadsheet that can then be used
		* for basic algebraic plot 
		putexcel set "$rootdir/cars/output/welfare/welfare_plot_table_`Tstr'.xlsx", sheet(Sheet1) replace

		* ROW 1: column labels 
		putexcel A1 = "varying"
		putexcel B1 = "x"
		putexcel C1 = "welfare_tax"
		putexcel D1 = "welfare_notax"
		putexcel E1 = "welfare_npi"
		putexcel F1 = "welfare_nonpi"
		putexcel G1 = "welfare_tax_minus_welfare_notax"
		putexcel H1 = "welfare_npi_minus_welfare_nonpi"
		putexcel I1 = "ref_val"
		putexcel J1 = "est_var"
		putexcel K1 = "est_cov"
		putexcel L1 = "est_delta"
		
		* define list of each parameter's values to iterate over 
		local num_rows = 14
		local varying_vals = "var var cov cov rho rho mu mu mu delta delta delta DeltaI DeltaI"
		local x_vals1 = "`var_xlim_min' `var_xlim_max' `cov_xlim_min' `cov_xlim_max' `rho_xlim_min' `rho_xlim_max' `mu_xlim_min' `mu_xlim_med' `mu_xlim_max'"
		local x_vals2 = "`delta_xlim_min' `delta_xlim_med' `delta_xlim_max' `DeltaI_xlim_min' `DeltaI_xlim_max'"
		local x_vals = "`x_vals1' `x_vals2'"
		
		local var_vals1 = "`var_xlim_min' `var_xlim_max' `var_tau' `var_tau' `var_tau' `var_tau' `var_tau' `var_tau' `var_tau'"
		local var_vals2 = "`var_tau' `var_tau' `var_tau' `var_tau' `var_tau'"
		local var_vals = "`var_vals1' `var_vals2'"
		
		local cov_vals1 = "`cov' `cov' `cov_xlim_min' `cov_xlim_max' `cov' `cov' `cov' `cov' `cov'"
		local cov_vals2 = "`cov' `cov' `cov' `cov' `cov'"
		local cov_vals = "`cov_vals1' `cov_vals2'"

		local rho_vals1 = "$rho $rho $rho $rho `rho_xlim_min' `rho_xlim_max' $rho $rho $rho"
		local rho_vals2 = "$rho $rho $rho $rho $rho"
		local rho_vals = "`rho_vals1' `rho_vals2'"

		local mu_vals1 = "$mu $mu $mu $mu $mu $mu `mu_xlim_min' `mu_xlim_med' `mu_xlim_max'"
		local mu_vals2 = "$mu $mu $mu $mu $mu"
		local mu_vals = "`mu_vals1' `mu_vals2'"
		
		local delta_vals1 = "`e_distortion' `e_distortion' `e_distortion' `e_distortion' `e_distortion' `e_distortion' `e_distortion' `e_distortion' `e_distortion'"
		local delta_vals2 = "`delta_xlim_min' `delta_xlim_med' `delta_xlim_max' `e_distortion' `e_distortion'"
		local delta_vals = "`delta_vals1' `delta_vals2'"
		
		local DeltaI_vals1 = "$DeltaI $DeltaI $DeltaI $DeltaI $DeltaI $DeltaI $DeltaI $DeltaI $DeltaI"
		local DeltaI_vals2 = "$DeltaI $DeltaI $DeltaI `DeltaI_xlim_min' `DeltaI_xlim_max'"
		local DeltaI_vals = "`DeltaI_vals1' `DeltaI_vals2'"
		
		* iterate over parameter sets and produce welfare statistics for each set 
		forval i = 1/`num_rows' {
			local varying : word `i' of `varying_vals'
			local xval : word `i' of `x_vals'
			
			local var_temp : word `i' of `var_vals'
			local cov_temp : word `i' of `cov_vals'
			local rho_temp : word `i' of `rho_vals'
			local mu_temp : word `i' of `mu_vals'
			local delta_temp : word `i' of `delta_vals'
			local DeltaI_temp : word `i' of `DeltaI_vals'
			
			calc_welfare, e_tau("`e_tau'") e_distortion("`delta_temp'") dp("`Dp'") /// 
			var_tau("`var_temp'") cov_distortion_tau("`cov_temp'") /// 
			delta_i("`DeltaI_temp'") rho("`rho_temp'") mu("`mu_temp'")
			return list
			
			local welfare_npi_w_tax_temp = r(welfare_npi_w_tax_temp)
			local welfare_npi_wo_tax_temp = r(welfare_npi_wo_tax_temp)
			local welfare_tax_w_npi_temp = r(welfare_tax_w_npi_temp)
			local welfare_tax_wo_npi_temp = r(welfare_tax_wo_npi_temp)
			
			local rownum = `i' + 1
			putexcel A`rownum' = "`varying'"
			putexcel B`rownum' = `xval'
			putexcel C`rownum' = `welfare_npi_w_tax_temp'
			putexcel D`rownum' = `welfare_npi_wo_tax_temp'
			putexcel E`rownum' = `welfare_tax_w_npi_temp'
			putexcel F`rownum' = `welfare_tax_wo_npi_temp'
		}
				
		putexcel J2 = `var_tau'
		putexcel K2 = `cov'
		putexcel L2 = `e_distortion'
		
		* close excel spreadsheet
		putexcel close

	}
	
	restore 
end

gen_welfare_sensitivity_data


/*******************************************************************************
Generate comparative statics figures of welfare vs. variance, covariance,
rho, and mu. 

FUNC NAME: gen_welfare_sensitivity_graphs
FUNC ARGUMENT(S): 
    (1) treatment for which figures are produced (-1 indicates full sample)
FUNC RESULT(S): Exports the following figures:
    - [cars/output/welfare/] welfare_vs_var_`T'.pdf
    - [cars/output/welfare/] welfare_vs_cov_`T'.pdf
    - [cars/output/welfare/] welfare_vs_var_and_cov_panel_`T'.pdf
    - [cars/output/welfare/] welfare_vs_rho_`T'.pdf
    - [cars/output/welfare/] welfare_vs_mu_`T'.pdf
    - [cars/output/welfare/] welfare_vs_rho_and_mu_panel_`T'.pdf
    - [cars/output/welfare/] welfare_vs_delta_`T'.pdf
*******************************************************************************/

capture program drop gen_welfare_sensitivity_graphs
program define gen_welfare_sensitivity_graphs
	preserve
		
	* determine which treatment is being used (pooled (-1) or T=2,3,4,5)
	if `1' == -1 {
		local T = ""
		local Tstr = "all"
	}
	else {
		local T = `1'
		local Tstr = "`1'"
	}

	
	******************************
	*         PANEL 1            *
	******************************
	
	* load in excel data to use for graph, based on specified treatment
	
	clear 
	import excel "$rootdir/cars/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	mkmat est_var est_cov est_delta, mat(est)
	local est_var = est[1, 1]
	local est_cov = est[1, 2]

	* create plot where variance varies
	
	local var_xmin = ((`est_cov')^2) / `est_var'
	local var_xmin = floor(`var_xmin' / 1000) * 1000
	keep if varying == "var"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   lfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   lfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Variance of label effect (($wtp_unit_vis)^2)") ///
		   ytitle("Total surplus gain ($wtp_unit_vis)") ///
		   yscale(range(-16 12)) ///
		   ylabel(-16(4)12) ///
		   xscale(range(0 65000)) ///
		   xlabel(0(10000)60000, format(%13.0fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) || ///
		   scatteri -16 `est_var' 12 `est_var' 0, recast(line) xaxis(2) ///
		   lcolor(green%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(0 65000) axis(2)) ///
		   xlab(`est_var' "Estimated value", axis(2)) ///
		   legend(order(4 2 3 1))
	
	graph save "$rootdir/cars/output/welfare/welfare_vs_var", replace
	graph export "$rootdir/cars/output/welfare/welfare_vs_var_`Tstr'.pdf", replace
	
	* create plot where covariance varies
	
	clear 
	import excel "$rootdir/cars/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	mkmat est_var est_cov est_delta, mat(est)
	local est_cov = est[1, 2]
	keep if varying == "cov"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   lfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   lfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Covariance between bias + externality and label effect (($wtp_unit_vis)^2)") ytitle("") ///
		   yscale(range(-30 15)) ///
		   ylabel(-30(5)15) ///
		   xscale(range(-35000 35000)) ///
		   xlabel(-30000(15000)30000, format(%13.0fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) || ///
		   scatteri -30 `est_cov' 15 `est_cov' 0, recast(line) xaxis(2) ///
		   lcolor(orange%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(-35000 35000) axis(2)) ///
		   xlab(`est_cov' "Estimated value", axis(2)) ///
		   legend(order(4 2 3 1))
	
	graph save "$rootdir/cars/output/welfare/welfare_vs_cov", replace
	graph export "$rootdir/cars/output/welfare/welfare_vs_cov_`Tstr'.pdf", replace
	
	* create side-by-side combo plot 
	
	clear
	
	graph combine "$rootdir/cars/output/welfare/welfare_vs_var" "$rootdir/cars/output/welfare/welfare_vs_cov", ///
	xsize(8) graphregion(fcolor(white) lcolor(white)) ///
	
	graph export "$rootdir/cars/output/welfare/welfare_vs_var_and_cov_panel_`Tstr'.pdf", replace

	
	******************************
	*         PANEL 2            *
	******************************
	
	* create plot where rho varies 
	
	clear 
	import excel "$rootdir/cars/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	keep if varying == "rho"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   lfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   lfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Pass-through rate difference") ///
		   ytitle("Total surplus gain ($wtp_unit_vis)") ///
		   yscale(range(-8 12)) ///
		   ylabel(-8(2)12) ///
		   xscale(range(0 1)) ///
		   xlabel(0(0.2)1, format(%13.1fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) ///
		   legend(order(4 2 3 1)) || ///
		   scatteri -8 $rho 12 $rho 0, recast(line) xaxis(2) ///
		   lcolor(orange%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(0 1) axis(2)) ///
		   xlab($rho "Assumed value", axis(2)) 
	
	graph save "$rootdir/cars/output/welfare/welfare_vs_rho", replace
	graph export "$rootdir/cars/output/welfare/welfare_vs_rho_`Tstr'.pdf", replace
	
	* create plot where mu varies 
	
	clear 
	import excel "$rootdir/cars/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	keep if varying == "mu"
	gen x_proportion = x / 5600
	
	twoway lfit welfare_tax x_proportion, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x_proportion, lpattern("dash") lcolor(red%30) || ///
		   qfit welfare_npi x_proportion, lpattern("solid") lcolor(blue%30) || ///
		   qfit welfare_nonpi x_proportion, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Markup difference / price") ytitle("") ///
		   yscale(range(-100 600)) ///
		   ylabel(-100(100)600) ///
		   xscale(range(-0.25 0.25)) ///
		   xlabel(-0.25(0.05)0.25, format(%13.2fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) ///
		   legend(order(4 2 3 1)) || ///
		   scatteri -100 $mu 600 $mu 0, recast(line) xaxis(2) ///
		   lcolor(green%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(-0.25 0.25)) ///
		   xlab($mu "Assumed value", axis(2)) 
	
	graph save "$rootdir/cars/output/welfare/welfare_vs_mu", replace
	graph export "$rootdir/cars/output/welfare/welfare_vs_mu_`Tstr'.pdf", replace

	* create panel of rho and mu varying 
	
	clear
	graph combine "$rootdir/cars/output/welfare/welfare_vs_rho" "$rootdir/cars/output/welfare/welfare_vs_mu", ///
	xsize(8) graphregion(fcolor(white) lcolor(white)) ///
	
	graph export "$rootdir/cars/output/welfare/welfare_vs_rho_and_mu_panel_`Tstr'.pdf", replace
	
	
	******************************
	*         PANEL 3            *
	******************************
	
	* create plot where delta varies 
	
	clear 
	import excel "$rootdir/cars/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	mkmat est_var est_cov est_delta, mat(est)
 	local est_delta = est[1, 3]
	keep if varying == "delta"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   qfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   qfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Bias + externality ($wtp_unit_vis)") ///
		   ytitle("Total surplus gain ($wtp_unit_vis)") ///
		   yscale(range(-20 50)) ///
		   ylabel(-20(10)50) ///
		   xscale(range(-400 400)) ///
		   xlabel(-400(100)400, format(%13.0fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) ///
		   legend(order(4 2 3 1)) || ///
		   scatteri -20 `est_delta' 50 `est_delta' 0, recast(line) xaxis(2) ///
		   lcolor(orange%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(-400 400) axis(2)) ///
		   xlab(`est_delta' "Estimated value", axis(2)) 
	
	graph save "$rootdir/cars/output/welfare/welfare_vs_delta", replace
	graph export "$rootdir/cars/output/welfare/welfare_vs_delta_`Tstr'.pdf", replace
	
	restore
end

gen_welfare_sensitivity_graphs -1


/*******************************************************************************
Generate welfare bar graph (originally for NBER). 

FUNC NAME: gen_welfare_bar_graph
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [cars/output/welfare/] welfare_bar_graph.pdf
*******************************************************************************/

capture program drop gen_welfare_bar_graph
program define gen_welfare_bar_graph
	preserve 

	* run parameters to get estimates 
	parameters 
	return list 
	
	* save relevant scalars 
	local welfare_npi_wo_tax = r(welfare_npi_wo_tax)
	local welfare_zero_cov = r(welfare_zero_cov)
	local welfare_zero_var_cov = r(welfare_zero_var_cov)
	local welfare_zero_tau = r(welfare_zero_tau)
	local welfare_npi_w_tax = r(welfare_npi_w_tax)
	
	* create mini-dataset  
	gen placeholder_index = 1
	gen welfare1 = `welfare_npi_wo_tax'
	gen welfare2 = `welfare_zero_cov'
	gen welfare3 = `welfare_zero_var_cov'
	gen welfare4 = `welfare_zero_tau'
	gen welfare5 = `welfare_npi_w_tax'
	
	keep placeholder_index welfare1 welfare2 welfare3 welfare4 welfare5
	duplicates drop 
	reshape long welfare, i(placeholder_index) j(welfare_type)
	
	* generate graph 
	graph hbar (mean) welfare, over(welfare_type, ///
			  relabel(1 `" "{bf:Total surplus effect}" "{bf:with no tax}" "' /// 
					  2 `" "if neutrally targeted:" "{it:Cov} [{&delta},{&tau}] = 0" "' /// 
					  3 `" "if homogeneous effect:" "{it:Cov} [{&delta},{&tau}]{it: = Var} [{&tau}] = 0" "' ///
					  4 `" "if zero average effect:" "{it:E} [{&tau}] = 0" "' ///
					  5 `" "{bf:Total surplus effect}" "{bf:with optimal tax}" "')) ///
	      ytitle("Total surplus gain ($wtp_unit_vis)") ///
		  ylabel(-4(2)4, format(%13.2fc)) ///
		  yline(0) ///
		  plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		  graphregion(fcolor(white) lcolor(white)) ///
		  xsize(7)
		  
	* export graph 
	graph export "$rootdir/cars/output/welfare/welfare_bar_graph.pdf", replace
	
	restore 
end 

gen_welfare_bar_graph


/*******************************************************************************
Generate histogram of change in WTP. 

FUNC NAME: gen_delta_wtp_hist
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] cars_hist.pdf
*******************************************************************************/

capture program drop gen_delta_wtp_hist
program define gen_delta_wtp_hist
	preserve
	
	* integer-ize and censor data so axis of histogram is reasonable
	gen treat = (T > 1)
	drop if delta_wtp_median == .

	tab delta_wtp_median treat
	gen delta_wtp_adj = floor(delta_wtp_median/300)*300 

	tab delta_wtp_adj treat

	replace delta_wtp_adj = -1500 if delta_wtp_adj <= -1500
	replace delta_wtp_adj = 1500 if delta_wtp_adj >= 1500

	tab delta_wtp_adj treat

	local ctrl_min = -1500
	local treat_min = -1500

	* create values for histogram by treated (binary)
	twoway__histogram_gen delta_wtp_adj if treat == 0, percent start(`ctrl_min') width(0.5) gen(h0 x0)
	replace x0 = . if x0 == `ctrl_min'

	twoway__histogram_gen delta_wtp_adj if treat == 1, percent start(`treat_min') width(0.5) gen(h1 x1)
	replace x1 = . if x1 == `treat_min'

	* create labels for histogram
	label define x_series -1500 "{&le}-1,500" -1200 "-1,200" -900 "-900" -600 "-600" -300 "-300" 0 "0" ///
	300 "300" 600 "600" 900 "900" 1200 "1,200" 1500 "{&ge}1,500"
	
	forval j = 0/1 {
		label values x`j' x_series
	}

	* create labels for legend
	local label1 = "Control"
	local label2 = "Graphic"
	local label3 = "Nutrition"
	local label4 = "Stoplight"

	* generate histogram 
	twoway(bar h0 x0 if inrange(x0,-1500,1500), barw(200) bc(gs11) bstyle(histogram)) (bar h1 x1 if inrange(x1,-1500,1500), barw(200) blc(black) bfc(none) bstyle(histogram)), ///
				plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
				graphregion(fcolor(white) lcolor(white)) ///
				xtitle("Change in relative valuation of lower-MPG car ($wtp_unit_vis)") ///
				xscale(range(-1500 1500)) ///
				xlab(-1500(300)1500, valuelabel) ///
				legend(label(1 "Control") label(2 "Treatment (any)")) ///
	
	* export 
	graph export "$rootdir/cars/output/cars_hist.pdf", replace
	
	restore
end

gen_delta_wtp_hist


/*******************************************************************************
Generate histogram of bias. 

FUNC NAME: gen_bias_hist
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] bias_hist.pdf
*******************************************************************************/

capture program drop gen_bias_hist
program define gen_bias_hist
	preserve
	
	* generate scalars for average bias and externality 
	sum overvaluation_b_median
	local avg_bias = r(mean)
	
	sum externality
	local avg_ext = r(mean)
	
	* generate min value 
	local min_val = -2000
	
	* create values for histogram 
	gen overvaluation_b_median_adj = floor(overvaluation_b_median/500)*500 
	twoway__histogram_gen overvaluation_b_median_adj, percent start(`min_val') width(0.5) gen(h0 x0)
	replace x0 = . if x0 <= `min_val'

	* labels for histogram
	label define x_series -2000 "{&le}-2,000" -1500 "-1,500" -1000 "-1,000" -500 "-500" ///
	0 "0" 500 "500" 1000 "1,000" 1500 "1,500" 2000 "2,000" 2500 "{&ge}2,500"
	
	label values x0 x_series

	* generate histogram 
	twoway(bar h0 x0 if inrange(x0,-2000,2500), barw(500) bc(gs11) blc(black) bstyle(histogram)), ///
				plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
				graphregion(fcolor(white) lcolor(white)) ///
				xtitle("$wtp_unit_vis") ///
				xscale(range(-2000 2500)) ///
				ytitle("Percent") ///
				xlab(-2000(500)2500, valuelabel axis(1)) || ///
				scatteri 0 `avg_bias' 30 `avg_bias' 0, ///
				xscale(range(-2000 2500) axis(2)) ///
			    recast(line) xaxis(2) ///
			    lcolor(red%100) lpattern("dash") lwidth(0.75) ///
			    xtitle("", axis(2)) ///
				legend(off) || ///
				scatteri 0 `avg_ext' 30 `avg_ext' 0, ///
			    recast(line) xaxis(2) ///
			    lcolor(blue%100) lpattern("dash") lwidth(0.75) ///
			    xlab(`avg_ext' "Average externality                               " ///
				     `avg_bias' "                       Average bias", ///
				     axis(2) format(%-20s %20s)) ///
				legend(off)

	* export histogram
	graph export "$rootdir/cars/output/bias_hist.pdf", replace

	restore
end

gen_bias_hist


/*******************************************************************************
Generate combined regression table, including ATE, covariance, and variance 
estimates, with all four primary specifications. 

FUNC NAME: gen_combo_reg_tbl
FUNC ARGUMENT(S): 
    (1) additional sample restriction 
	(2) treatment 
	(3) any additional text to append to title
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] combined_reg_table_`1'_`2'`3'.tex
*******************************************************************************/

capture program drop gen_combo_reg_tbl
program define gen_combo_reg_tbl	
	preserve 
	
	/******************************
	Prepare dataset based on 
	additional restriction
	******************************/
	
	* if doing middle-50% specification instead of full, restrict 
	* dataset accordingly 
	
	if "`1'" == "middle50" { 
		* remove all observations for any ID w/ one or more above-median WTPs
		keep if middle50ind == 1
	} 
	
	* if doing sensitivity analysis, clear and re-read dataset to bring
	* back observations that were previousy excluded
	
	else if "`1'" == "sens_baddata4_id_1" {
		use "$rootdir/cars/intermediate_data/merged", clear
		keep if baddata4_id_1 == 0 
	}
	else if "`1'" == "sens_no_drops" {
		use "$rootdir/cars/intermediate_data/merged", clear
	}
	
	* if only using a specific treatment, restrict to only observations
	* that received that treatment or were in control 
	
	if "`2'" != "pooled" {
		keep if (T == `2' | T == 1)
	}
	
	
	/******************************
	Run regressions and store vals
	******************************/
	
	* generate columns for (bias x treated) and (ext x treated)
	cap gen bias_treated = overvaluation_b_median * treated 
	cap gen ext_treated = externality * treated
	
	* Simple linear ATE
	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS, cluster(id)
	eststo OLS_ATE_reg
	estadd scalar num_indiv = _N / 2

	* Simple linear covariance
	reg delta_wtp_median i.treated overvaluation_b_median bias_treated externality ext_treated $CONTROLS, cluster(id)
	
	sum overvaluation_b_median, d
	scalar var_bias = r(Var)
	
	sum externality, d
	scalar var_ext = r(Var)
	
	correlate overvaluation_b_median externality, covariance
	scalar cov_bias_ext = r(cov_12)
	
	* covariance estimates 
	scalar cov_bias_tau = (_b[bias_treated] * var_bias) + (cov_bias_ext * _b[ext_treated])
	estadd scalar cov_bias_tau = cov_bias_tau 
	local cov_bias_tau = cov_bias_tau

	scalar cov_ext_tau = (_b[ext_treated] * var_ext) + (cov_bias_ext * _b[bias_treated])
	estadd scalar cov_ext_tau = cov_ext_tau 
	local cov_ext_tau = cov_ext_tau

	eststo OLS_cov_reg
	
	* SEs of covariance estimates 
	nlcom (bias_treated_scaled_lin_cov: (var_bias * _b[bias_treated]) + ///
	                                    (cov_bias_ext * _b[ext_treated])) ///
	      (ext_treated_scaled_lin_cov: (var_ext * _b[ext_treated]) + ///
		                               (cov_bias_ext * _b[bias_treated])), post
	
	scalar se_cov_bias_tau_lin_cov = _se[bias_treated_scaled_lin_cov]	
	scalar se_cov_ext_tau_lin_cov = _se[ext_treated_scaled_lin_cov]
	
	est restore OLS_cov_reg 
	
	local se_cov_bias_tau_lin_cov : display %9.0fc se_cov_bias_tau_lin_cov
	local se_cov_ext_tau_lin_cov : display %9.0fc se_cov_ext_tau_lin_cov	
	estadd local se_cov_bias_tau = subinstr("(`se_cov_bias_tau_lin_cov')", " ", "", .)
	estadd local se_cov_ext_tau = subinstr("(`se_cov_ext_tau_lin_cov')", " ", "", .)
	
	estadd scalar num_indiv = _N / 2
	
	eststo OLS_cov_reg
	
	* Simple ME 
	xi i.treated
	xi i.product_pair_strict
	xi: xtmixed delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS || id: i.treated, ///
	            vce(cluster id) iter(100) variance nolr
	eststo ME_var_reg
	_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
	return list
	scalar var_tau = r(est)
	scalar se_var_tau = r(se)
	estadd scalar var_tau = var_tau 
	
	local se_var_tau : display %9.0fc se_var_tau
	estadd local se_var_tau = subinstr("(`se_var_tau')", " ", "", .)
	
	estadd scalar num_indiv = _N / 2

	* Full ME 
	xi i.treated
	xi i.product_pair_strict
	xi: xtmixed delta_wtp_median i.treated overvaluation_b_median bias_treated externality ext_treated $CONTROLS || id: i.treated, vce(cluster id) iter(100) variance nolr
	
	* covariance parameter estimates 
	scalar cov_bias_tau = (_b[bias_treated] * var_bias) + (cov_bias_ext * _b[ext_treated])
	estadd scalar cov_bias_tau = cov_bias_tau 
	local cov_bias_tau = cov_bias_tau

	scalar cov_ext_tau = (_b[ext_treated] * var_ext) + (cov_bias_ext * _b[bias_treated])
	estadd scalar cov_ext_tau = cov_ext_tau 
	local cov_ext_tau = cov_ext_tau
	
	eststo ME_cov_reg 
	
	* covariance SEs
	nlcom (bias_treated_scaled_ME_cov: (var_bias * _b[bias_treated]) + ///
	                                   (cov_bias_ext * _b[ext_treated])) ///
	      (ext_treated_scaled_ME_cov: (var_ext * _b[ext_treated]) + ///
		                              (cov_bias_ext * _b[bias_treated])), post
	
	scalar se_cov_bias_tau_ME_cov = _se[bias_treated_scaled_ME_cov]
	scalar se_cov_ext_tau_ME_cov = _se[ext_treated_scaled_ME_cov]
	
	est restore ME_cov_reg
	
	local se_cov_bias_tau_ME_cov : display %9.0fc se_cov_bias_tau_ME_cov
	local se_cov_ext_tau_ME_cov : display %9.0fc se_cov_ext_tau_ME_cov	
	estadd local se_cov_bias_tau = subinstr("(`se_cov_bias_tau_ME_cov')", " ", "", .)
	estadd local se_cov_ext_tau = subinstr("(`se_cov_ext_tau_ME_cov')", " ", "", .)

	estadd scalar num_indiv = _N / 2
	
	eststo ME_cov_reg

	
	/******************************
	Combine regs and export 
	******************************/

	* generate and export combined table 
	esttab OLS_ATE_reg OLS_cov_reg ME_var_reg ME_cov_reg using "$rootdir/cars/output/combined_reg_table_`1'_`2'`3'.tex", replace /// 
	mtitle("OLS" "OLS" "Mixed effects" "Mixed effects") ///
	b(2) se(2) label starlevels( * 0.10 ** 0.05 *** 0.010) stats(cov_bias_tau se_cov_bias_tau cov_ext_tau se_cov_ext_tau var_tau se_var_tau num_indiv N, /// 
	labels("Cov(bias, treatment effect)" "(standard error)" "Cov(externality, treatment effect)" ///
	       "(standard error)" "Var(treatment effect)" "(standard error)" "Number of participants" ///
		   "Number of observations") fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.0fc %9.0fc %9.0fc %9.0fc)) nonotes ///
	eqlabels(" " " " " " " ") ///
	rename(_Itreated_1 1.treated) ///
	coeflabels(1.treated "\shortstack[l]{Treated}" ///
			   overvaluation_b_median "\shortstack[l]{Bias}" ///
			   bias_treated "\shortstack[l]{Bias $\times$ Treated}" ///
			   externality "\shortstack[l]{Externality}" ///
			   ext_treated "\shortstack[l]{Externality $\times$ Treated}") ///
	order(1.treated ///
		  bias_treated ///
		  ext_treated ///
		  overvaluation_b_median ///
		  externality) ///
	keep(1.treated ///
		 bias_treated ///
		 ext_treated) ///
	refcat(label("N"))
	
	* export relevant coefficients if pooled 
	if ("`1'" == "full" & "`2'" == "pooled") {
		local alpha_one = _b[bias_treated]
		latex_rounded, name("carsAlphaOne") value(`alpha_one') digits(2)

		local alpha_two = _b[ext_treated]
		latex_rounded, name("carsAlphaTwo") value(`alpha_two') digits(3)
	}
	
	* reset esttab memory 
	eststo clear 
	
	restore
end

gen_combo_reg_tbl "full" "pooled"
gen_combo_reg_tbl "full" "2"
gen_combo_reg_tbl "full" "3"
gen_combo_reg_tbl "full" "4"
gen_combo_reg_tbl "full" "5"
gen_combo_reg_tbl "middle50" "pooled"
gen_combo_reg_tbl "sens_baddata4_id_1" "pooled"
gen_combo_reg_tbl "sens_no_drops" "pooled"

