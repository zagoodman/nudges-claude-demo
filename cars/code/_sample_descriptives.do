/*******************************************************************************
DESCRIPTION: Generates sample description tables and scalars for the cars
experiment, including dropped observations, sample size, summary stats,
demographics, and balance tables.
*******************************************************************************/


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
