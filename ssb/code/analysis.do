/*******************************************************************************
TITLE: analysis.do
AUTHOR(S): Daniel Cohen <-- Victoria Pu/William Morrison
DESCRIPTION: Reads in processed data and produces all tables and figures for 
    the SSB experiment. 
DATE LAST MODIFIED: APR 2025
FILE(S) USED: 
    - merged.dta (processed data from SSB experiment)
*******************************************************************************/

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


/*******************************************************************************
Generate aversion plots of WTP to avoid labels. 

FUNC NAME: gen_wtp_avoid_labels
FUNC ARGUMENT(S): 
	(1) whether or not to censor WTPs at [-5, 5]
FUNC RESULT(S): Exports the following figure:
    - [ssb/output/] wtp_receive_labels_spike_plot[_cens].pdf  
*******************************************************************************/

capture program drop gen_wtp_avoid_labels_spike_plot
program define gen_wtp_avoid_labels_spike_plot
	preserve

	* start with just WTP for labels 
	
	* remove outlandish values for WTP to avoid labels 
	replace wtp_avoid_labels = . if wtp_avoid_labels <= -100 & wtp_avoid_labels != . 
	replace wtp_avoid_labels = . if wtp_avoid_labels >= 100 & wtp_avoid_labels != . 

	* replace "indifferent" responses w/ 0 WTP instead of .
	replace wtp_avoid_labels = 0 if label_pref == "I would not care at all"
	
	* if "cens" provided as argument, also censor WTP below/above at [-5, 5]
	if "`1'" == "cens" {
		replace wtp_avoid_labels = -5 if wtp_avoid_labels < -5 & wtp_avoid_labels != .
		replace wtp_avoid_labels = 5 if wtp_avoid_labels > 5 & wtp_avoid_labels != .
	}
	
	* generate wtp_receive_labels as negative of wtp_avoid_labels
	gen wtp_receive_labels = (-1) * wtp_avoid_labels
	
	* run basic regressions to get average wtp_receive_labels by treatment 
	reg wtp_receive_labels i.T if T == 2, noconstant cluster(id)
	eststo wtp_receive_graphic

	reg wtp_receive_labels i.T if T == 3, noconstant cluster(id)
	eststo wtp_receive_nutrition

	reg wtp_receive_labels i.T if T == 4, noconstant cluster(id)
	eststo wtp_receive_stopsign

	reg wtp_receive_labels is_treated, noconstant cluster(id)
	eststo wtp_receive_binary

	* generate spike plot 
	coefplot (wtp_receive_graphic wtp_receive_nutrition wtp_receive_stopsign wtp_receive_binary, msymbol(smtriangle) label("Receive labels")), vertical ///
	keep(3.T 4.T 2.T is_treated) ///
	order(3.T 4.T 2.T is_treated) ///
	coeflabels(2.T = "Graphic" 3.T = "Nutrition facts" 4.T = "Stop sign" is_treated = "Pooled") ///
	ciopts(recast(rcap)) ///
	plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	yscale(range(-3 2)) ///
	ylabel(-3(1)2) ///
	xtitle("Treatment group") ytitle("Willingness to pay to receive labels ($wtp_unit_vis)") ///

	* export graph 
	if "`1'" == "cens" {
		graph export "$rootdir/ssb/output/wtp_receive_labels_spike_plot_cens.pdf", replace
	}
	else {
		graph export "$rootdir/ssb/output/wtp_receive_labels_spike_plot.pdf", replace
	}

	restore
end 

gen_wtp_avoid_labels_spike_plot
gen_wtp_avoid_labels_spike_plot "cens"


/*******************************************************************************
Generate bar graphs of reason given for label avoidance selection. 

FUNC NAME: gen_wtp_label_bars
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figures:
    - [ssb/output/] reason_for_yes_label_bars.pdf  
    - [ssb/output/] reason_for_no_label_bars.pdf  
*******************************************************************************/

capture program drop gen_label_avoidance_bars
program define gen_label_avoidance_bars
	preserve

	* keep only 1 count for each person
	bysort id : gen dup = cond(_N==1,0,_n)
	drop if dup > 1
	drop dup

	* generate counts for each type of reason:
	
	* for answering "yes"
	gen yes_reminder = 1 if strpos(reason_yes, "remind me to drink less")
	gen yes_useful_info = 1 if strpos(reason_yes, "information on the label is useful")
	gen yes_other = 1 if strpos(reason_yes, "Other")

	* for answering no 
	gen no_gross = 1 if strpos(reason_no, "label is gross")
	gen no_feel_bad = 1 if strpos(reason_no, "label makes me feel bad")
	gen no_not_useful = 1 if strpos(reason_no, "information isn't useful")
	gen no_government = 1 if strpos(reason_no, "don't need the government")
	gen no_other = 1 if strpos(reason_no, "Other")

	* collapse into counts by response
	collapse (sum) yes_reminder yes_useful_info yes_other no_gross no_feel_bad no_not_useful no_government no_other, by(treatment)

	* drop control because they did not see the MPL for labels questions
	drop if treatment == "control"

	local bars "yes_reminder yes_useful_info yes_other no_gross no_feel_bad no_not_useful no_government no_other"

	gen order = .
	replace order = 1 if treatment == "nutrition"
	replace order = 2 if treatment == "stoplight"
	replace order = 3 if treatment == "graphic"

	* convert to percents 
	gen yes_total = yes_reminder + yes_useful_info + yes_other
	gen no_total = no_gross + no_feel_bad + no_not_useful + no_government + no_other 
	
	local yes_bars = "yes_reminder yes_useful_info yes_other"
	local no_bars = "no_gross no_feel_bad no_not_useful no_government no_other"
	foreach bar in `yes_bars' {
		gen `bar'_percent = (`bar' / yes_total) * 100
	}
	foreach bar in `no_bars' {
		gen `bar'_percent = (`bar' / no_total) * 100
	}
	
	* produce "yes" bar graph
	graph bar (asis) yes_reminder_percent yes_useful_info_percent yes_other_percent, ///
	over(treatment, relabel(1 "Graphic" 2 "Nutrition facts" 3 "Stop sign") sort(order)) ///
	b1title("Treatment group") ytitle("Percent of responses that selected reason") ///
	plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	legend(lab(1 "Reminder to drink less") lab(2 "Info is useful") lab(3 "Other")) ///
	ylab(, nogrid)

	graph export "$rootdir/ssb/output/reason_for_yes_label_bars.pdf", replace

	* produce "no" bar graph
	graph bar (asis) no_gross_percent no_feel_bad_percent no_other_percent no_not_useful_percent no_government_percent, ///
	over(treatment, relabel(1 "Graphic" 2 "Nutrition facts" 3 "Stop sign") sort(order)) ///
	b1title("Treatment group") ytitle("Percent of responses that selected reason") ///
	plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	legend(lab(1 "Label is gross") lab(2 "Makes me feel bad") lab(3 "Other") ///
	       lab(4 "Info isn't useful") lab(5 "Don't need government")) ///
	ylab(, nogrid)

	graph export "$rootdir/ssb/output/reason_for_no_label_bars.pdf", replace

	restore
	
end 

gen_label_avoidance_bars


/*******************************************************************************
Generate visualizations pertaining to beliefs updating w.r.t sugar/calories.

FUNC NAME: gen_sugar_calorie_belief_results
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figures:
    - [ssb/output/calories and sugar] (various figures)  
*******************************************************************************/

capture program drop gen_sugar_calorie_belief_results
program define gen_sugar_calorie_belief_results
	preserve

	keep id T product sugar *_sugar* *_calories* is_treated distortion wtp_base prod_no ///
	     first_baseline second_baseline third_baseline first_endline second_endline third_endline
	drop high_low*

	* 4) Plots
	* A. (i)  non-SSBs sugar pre/post
	* A. (ii) non-SSBs calories pre/post
	* B. (i) SSBs sugar pre/post
	* B. (ii) SSBs calories pre/post
	* C. (i) difference sugar pre/post
	* C. (iii) difference calories pre/post

	local drink_types "nonssb ssb diff"
	local component "sugar calories"

	foreach comp in `component' {
		foreach type in `drink_types' {
			
			* generate string for type (e.g., ssb --> SSB)
			if "`type'" == "ssb" {
				local type_str = "SSB"
			} 
			else {
				local type_str = "`type'"
			}
			
			* fill in . for any observation that is above the 95th or 
			* below the 5th percentile 
			sum `type'_`comp'_error_pre, d
			replace `type'_`comp'_error_pre = . if `type'_`comp'_error_pre > r(p95) ///
			                                     | `type'_`comp'_error_pre < r(p5)
			replace `type'_`comp'_error_post = . if `type'_`comp'_error_pre > r(p95) ///
			                                     | `type'_`comp'_error_pre < r(p5)  
			
			* drop both pre and post if either pre or post is > its respective percentile
			sum `type'_`comp'_error_post, d
			replace `type'_`comp'_error_post = . if `type'_`comp'_error_post > r(p95) ///
			                                      | `type'_`comp'_error_post < r(p5)
			replace `type'_`comp'_error_pre = . if `type'_`comp'_error_post > r(p95) /// 
			                                     | `type'_`comp'_error_post < r(p5)
			
			* convert s.t. underestimates are positive
			replace `type'_`comp'_error_pre = `type'_`comp'_error_pre * -1
			replace `type'_`comp'_error_post = `type'_`comp'_error_post * -1
			
			* generate spike plots 
			qui cap gen control = (T==1)
			
			reg `type'_`comp'_error_pre control i.T, nocons
			eststo `type'_`comp'_err_pre
			reg `type'_`comp'_error_post control i.T, nocons
			eststo `type'_`comp'_err_post
			
			reg `type'_`comp'_error_pre control 1.is_treated, nocons
			eststo `type'_`comp'_err_pre_b
			reg `type'_`comp'_error_post control 1.is_treated, nocons
			eststo `type'_`comp'_err_post_b

			coefplot (`type'_`comp'_err_pre `type'_`comp'_err_pre_b, label("Pre-intervention")) /// 
			(`type'_`comp'_err_post `type'_`comp'_err_post_b, msymbol(smdiamond) label("Post-intervention")), vertical ///
			keep(control 2.T 3.T 4.T 1.is_treated) ///
			order(control 3.T 4.T 2.T 1.is_treated) ///
			coeflabels(control = "Control" 2.T = "Graphic warning label" 3.T = "Nutrition facts label" 4.T = "Stop sign warning label" 1.is_treated = "Any treatment", /// 
					   wrap(13)) ///
			ciopts(recast(rcap)) ///
			plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
			graphregion(fcolor(white) lcolor(white)) ///
			xtitle("Treatment group") ytitle("Actual - perceived `comp'")
			
			graph export "$rootdir/ssb/output/calories and sugar/`type'_`comp'_error_spike_plots.pdf", replace
		}
		
		* compute change in SSB calorie/sugar errors at baseline vs. endline
		gen delta_ssb_`comp'_error = ssb_`comp'_error_post - ssb_`comp'_error_pre
		
		* generate histogram of belief errors 
		
		* generate min value 
		sum ssb_`comp'_error_post, d
		
		* generate min value 
		if "`comp'" == "sugar" {
			local min_val = -25
			
			* create values for histogram 
			gen ssb_`comp'_error_post_adj = floor(ssb_`comp'_error_post/5)*5 
			
			twoway__histogram_gen ssb_`comp'_error_post_adj if is_treated == 0, percent start(`min_val') width(0.5) gen(h0 x0)
			replace x0 = . if x0 <= `min_val'

			twoway__histogram_gen ssb_`comp'_error_post_adj  if is_treated == 1, percent start(`min_val') width(0.5) gen(h1 x1)
			replace x1 = . if x1 <= `min_val'

			* labels for histogram
			label define x_series -25 "{&le}-25" -20 "-20" -15 "-15" -10 "-10" -5 "-5" ///
			0 "0" 5 "5" 10 "10" 15 "15" 20 "20" 25 "25" 30 "30" 35 "{&ge}30"
			
			label values x0 x_series

			twoway(bar h0 x0 if inrange(x0,-25,35), barw(5) bc(gs11) bstyle(histogram)) ///
				  (bar h1 x1 if inrange(x1,-25,35), barw(5) blc(black) bfc(none) bstyle(histogram)), ///
						plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
						graphregion(fcolor(white) lcolor(white)) ///
						xtitle("Actual - perceived `comp'") ///
						xscale(range(-25 35)) ///
						ytitle("Percent") ///
						xlab(-25(5)35, valuelabel axis(1)) ///
						legend(label(1 "Control") label(2 "Treatment"))

			graph export "$rootdir/ssb/output/calories and sugar/ssb_`comp'_hist.pdf", replace
			
			drop x0 h0 x1 h1
			label drop x_series
		}
		else if "`comp'" == "calories" {
			local min_val = -300
			
			* create values for histogram 
			gen ssb_`comp'_error_post_adj = floor(ssb_`comp'_error_post/50)*50
			
			twoway__histogram_gen ssb_`comp'_error_post_adj if is_treated == 0, percent start(`min_val') width(0.5) gen(h0 x0)
			replace x0 = . if x0 <= `min_val'

			twoway__histogram_gen ssb_`comp'_error_post_adj  if is_treated == 1, percent start(`min_val') width(0.5) gen(h1 x1)
			replace x1 = . if x1 <= `min_val'

			* labels for histogram
			label define x_series -300 "{&le}-300" -250 "-250" -200 "-200" -150 "-150" -100 "-100" ///
			-50 "-50" 0 "0" 50 "{&ge}50"
			
			label values x0 x_series

			twoway(bar h0 x0 if inrange(x0,-300,50), barw(50) bc(gs11) bstyle(histogram)) ///
				  (bar h1 x1 if inrange(x1,-300,50), barw(50) blc(black) bfc(none) bstyle(histogram)), ///
						plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
						graphregion(fcolor(white) lcolor(white)) ///
						xtitle("Actual - perceived `comp'") ///
						xscale(range(-300 50)) ///
						ytitle("Percent") ///
						xlab(-300(50)50, valuelabel axis(1)) ///
						legend(label(1 "Control") label(2 "Treatment"))

			graph export "$rootdir/ssb/output/calories and sugar/ssb_`comp'_hist.pdf", replace
			
			drop x0 h0 x1 h1
			label drop x_series
		}		
	}	
	
	
	* add visualization for change in SSB calorie error vs. above- and below-median baseline error

	foreach comp in `component' {
		sum ssb_`comp'_error_pre, d
		gen ssb_`comp'_error_pre_med = r(p50)

		gen ssb_`comp'_error_pre_above_med = ssb_`comp'_error_pre >= ssb_`comp'_error_pre_med
		gen ssb_`comp'_error_pre_below_med = ssb_`comp'_error_pre <= ssb_`comp'_error_pre_med
	
		if "`comp'" == "sugar" {
			local ymin = -7
			local ymax = 3
			local ystep = 1
		}
		else if "`comp'" == "calories" {
			local ymin = -20
			local ymax = 30
			local ystep = 10
		}
		
		qui reg delta_ssb_`comp'_error ssb_`comp'_error_pre i.T $CONTROLS if ssb_`comp'_error_pre_below_med == 1, cluster(id) 
		eststo below

		qui reg delta_ssb_`comp'_error ssb_`comp'_error_pre is_treated $CONTROLS if ssb_`comp'_error_pre_below_med == 1, cluster(id) 
		eststo below_binary

		qui reg delta_ssb_`comp'_error ssb_`comp'_error_pre i.T $CONTROLS if ssb_`comp'_error_pre_above_med == 1, cluster(id) 
		eststo above

		qui reg delta_ssb_`comp'_error ssb_`comp'_error_pre is_treated $CONTROLS if ssb_`comp'_error_pre_above_med == 1, cluster(id) 
		eststo above_binary

		qui reg delta_ssb_`comp'_error ssb_`comp'_error_pre i.T $CONTROLS, cluster(id) 
		eststo all

		qui reg delta_ssb_`comp'_error ssb_`comp'_error_pre is_treated $CONTROLS, cluster(id) 
		eststo all_binary

		coefplot (below below_binary, label("Below-median baseline error")) ///
				 (all all_binary, label("All") msymbol(square) mcolor(black) ciopts(lcolor(black) recast(rcap))) ///
				 (above above_binary, label("Above-median baseline error") msymbol(smdiamond) mcolor(maroon) ciopts(lcolor(maroon) recast(rcap))), vertical ///
		coeflabels(2.T = "Graphic warning label" ///
				   3.T = "Nutrition facts label" ///
				   4.T = "Stop sign warning label" ///
				   is_treated = "All treatments", wrap(13)) ///
		order(3.T 4.T 2.T is_treated) ///
		keep(2.T 3.T 4.T is_treated) ///
		yscale(r(`ymin' `ymax')) ylab(`ymin'(`ystep')`ymax') ///
		ciopts(recast(rcap)) ///
		plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		graphregion(fcolor(white) lcolor(white)) ///
		xtitle("Treatment group") ytitle("Actual - perceived `comp'") ///
		ylab(, format(%15.0gc)) ///
		legend(rows(1))

		graph export "$rootdir/ssb/output/calories and sugar/`comp' error above and below median baseline error spike plot_v2.pdf", replace
	
	}
	
	restore
end

gen_sugar_calorie_belief_results


/*******************************************************************************
Generate tables/figures analyzing responses to satisfaction questions. 

FUNC NAME: gen_satisf_analysis
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figures:
    - [ssb/output/] satisf_score_regression.tex 
    - [ssb/output/] satisf_score_bar_graph.pdf  
    - [ssb/output/] satisf_score_spike_plot.pdf  
*******************************************************************************/

capture program drop gen_satisf_analysis
program define gen_satisf_analysis
	preserve

	* output table of drink pair chosen for satisfaction questions
	eststo clear
	estpost tabulate satisf_drink, sort
	esttab using "$rootdir/ssb/output/satisf_drink_freq.tex", replace ///
	varlabels(coke Coke crush Crush lemonade "Minute Maid lemonade" pepsi Pepsi seagrams "Seagram's ginger ale" sprite "Sprite") ///
	cells("b(lab(Frequency)) pct(fmt(0) lab(Percent)) cumpct(fmt(0) lab(Cumulative percent))") ///
	nonumber nomtitle noobs

	* only work with the relevant columns
	keep id *_ssb_satisf* *_alt_satisf* satisf_drink T order*
	destring *_ssb_satisf* *_alt_satisf*, replace

	* keep only the first row for each id (because this part is MPL product invariant)
	sort id
	quietly by id: gen dup = cond(_N==1,0,_n)
	drop if dup > 1

	* parse satisfaction questions to create 2 variables for SSB and its non-SSB alternative
	local drink_names "lemonade coke pepsi seagrams sprite crush"

	* generate satisfaction scores 
	gen satisf_score1 = .
	gen satisf_score2 = .
	foreach drink in `drink_names' {
		// for the SSB
		replace satisf_score1 = `drink'_ssb_satisf_5 if `drink'_ssb_satisf_5 != .
		// for the non-SSB
		replace satisf_score2 = `drink'_alt_satisf_5 if `drink'_alt_satisf_5 != .
	}

	* keep only these new columns
	keep id satisf_drink satisf_score* T order*

	* reshape wide to long
	reshape long satisf_score, i(id) j(drink_idx)

	* add new variable (SSB vs. non-SSB indicator) for regression:
	bysort id: gen is_ssb = 1 if _n == 1
	replace is_ssb = 0 if is_ssb == .

	* run regressions 
	eststo reg1: reghdfe satisf_score i.T##is_ssb, absorb(satisf_drink order_base order_end) cluster(id)

	* export regression table
	esttab using "$rootdir/ssb/output/satisf_score_regression.tex", replace ///
	b(2) se(2) label starlevels( * 0.10 ** 0.05 *** 0.010) stats(num_indiv, labels("N. of Individuals") fmt(0)) nonotes ///
	coeflabels(1.is_ssb "Is SSB" 2.T "Graphic" 3.T "Nutrition" 4.T "Stop sign" 2.T#1.is_ssb "Graphic * Is SSB" 3.T#1.is_ssb "Nutrition * Is SSB" 4.T#1.is_ssb "Stop sign * Is SSB") ///
	order(1.is_ssb 2.T 3.T 4.T 2.T#1.is_ssb 3.T#1.is_ssb 4.T#1.is_ssb _cons) ///
	keep(1.is_ssb 2.T 3.T 4.T 2.T#1.is_ssb 3.T#1.is_ssb 4.T#1.is_ssb _cons) ///
	refcat(label("N")) ///
	mtitle("Satisfaction score")

	* bar graph
	* 	- 3 groups of 2 bars
	* 		- each group is an endline
	* 		- bars are: (i) control mean for ssb; (ii) control mean for non-ssb

	* distinguish between SSB and non-SSB for graph 
	gen drink_type_price = 1  // SSB
	replace drink_type_price = 2 if is_ssb == 0

	* define desired order in bar graph 
	gen order = .
	replace order = 1 if T == 1
	replace order = 2 if T == 3
	replace order = 3 if T == 4
	replace order = 4 if T == 2

	graph bar (mean) satisf_score, ///
	over(drink_type_price) over(T, relabel(1 "Control" 2 "Graphic" 3 "Nutrition" 4 "Stop sign") sort(order)) asyvars ///
	bar(1, fcolor(dknavy) lcolor(dknavy)) bar(2, fcolor(maroon) lcolor(maroon)) ///
	legend(order(1 "SSB" 2 "Non-SSB")) ///
	b1title("Treatment group") ytitle("Mean satisfaction (out of 10 pts)") ///
	blabel(bar, format(%9.1fc)) ///
	plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
	graphregion(fcolor(white) lcolor(white))

	graph export "$rootdir/ssb/output/satisf_score_bar_graph.pdf", replace

	* run regressions for spike plot 
	reg satisf_score ibn.T if is_ssb == 1, nocons cluster(id)
	eststo ssb_reg

	reg satisf_score ibn.T if is_ssb == 0, nocons cluster(id)
	eststo non_ssb_reg
	
	* create spike plot 
	coefplot (ssb_reg, label("SSB") msymbol(smdiamond)) (non_ssb_reg, label("Non-SSB") msymbol(square) mcolor(black) ///
	ciopts(lc(black) recast(rcap))), vertical ///
	ciopts(recast(rcap)) ///
	keep(1.T 2.T 3.T 4.T) ///
	order(1.T 3.T 4.T 2.T) ///
	yscale(range(3 8.5)) ///
	ylab(3(1)8) ///
	coeflabels(1.T = "Control" 2.T = "Graphic" 3.T = "Nutrition" 4.T = "Stop sign") ///
	plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Mean satisfaction (out of 10 pts)") ///

	* export plot 
	graph export "$rootdir/ssb/output/satisf_score_spike_plot.pdf", replace
	
	restore

end

gen_satisf_analysis


/*******************************************************************************
Generate histogram of change in WTP. 

FUNC NAME: gen_delta_wtp_hist
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [ssb/output/] ssb_hist.pdf
*******************************************************************************/

capture program drop gen_delta_wtp_hist
program define gen_delta_wtp_hist
	preserve

	* bin delta-WTP

	gen delta_WTP_adj = floor(delta_WTP/.5)*.5 
	replace delta_WTP_adj = ceil(delta_WTP/.5)*.5 if delta_WTP < 0
	replace delta_WTP_adj = -3.5 if delta_WTP_adj <= -3.5

	local ctrl_min = -3.75
	local treat_min = -3.75

	* create values for histogram by treated (binary)
	twoway__histogram_gen delta_WTP_adj if is_treated ==0, percent start(`ctrl_min') width(0.5) gen(h0 x0)
	replace x0 = . if x0 == `ctrl_min'

	twoway__histogram_gen delta_WTP_adj if is_treated ==1, percent start(`treat_min') width(0.5) gen(h1 x1)
	replace x1 = . if x1 == `treat_min'

	* create values for histogram by treatment (category)

	* labels for histogram
	label define x_series -35 "{&le}-3.5 " -30 "-3" -25 "-2.5" -20 "-2" -15 "-1.5" -10 "-1" -5 "-0.5" 0 "0" ///
	5 "0.5" 10 "1" 15 "1.5" 20 "2" 25 "2.5"

	forval j = 0/1 {
		replace x`j' = 10*x`j'
		label values x`j' x_series
	}

	* labels for legend
	local label1 = "Control"
	local label2 = "Graphic warning label"
	local label3 = "Nutrition facts label"
	local label4 = "Stop sign warning label"

	* generate histogram 
	twoway(bar h0 x0 if inrange(x0,-35,25), barw(2.5) bc(gs11) bstyle(histogram)) (bar h1 x1 if inrange(x1,-35,25), barw(2.5) blc(black) bfc(none) bstyle(histogram)), ///
				plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
				graphregion(fcolor(white) lcolor(white)) ///
				xtitle("Change in relative WTP for sugary drink ($wtp_unit_vis)") ///
				xscale(range(-35 25)) ///
				xlab(-35(5)25, valuelabel) ///
				legend(label(1 "Control") label(2 "Treatment (any)")) ///
				
	* export histogram 
	graph export "$rootdir/ssb/output/ssb_hist.pdf", replace

	restore
end

gen_delta_wtp_hist


/*******************************************************************************
Generate spike plot of ATEs by treatment and pooled.  

FUNC NAME: gen_ATE_spike_plot
FUNC ARGUMENT(S): 
FUNC RESULT(S): Exports the following figure:
    - [ssb/output/] ATE_spike_plot.pdf  
*******************************************************************************/

capture program drop gen_ATE_spike_plot
program define gen_ATE_spike_plot
	preserve 
	
	* run pooled regression
	reg delta_WTP i.is_treated gamma_hat $CONTROLS, cluster(id)
	eststo TpooledATE
	
	* run treatment-specific regressions 
	forval t = 2/4 {
		reg delta_WTP `t'.T gamma_hat $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'ATE
	}
	
	* generate spike plot 
	coefplot (T2ATE T3ATE T4ATE TpooledATE, /// 
				  label("All") msymbol(square) mcolor(black) ///
				  ciopts(lcolor(black) recast(rcap)) ///
				  keep(2.T 3.T 4.T 1.is_treated)), vertical ///
	coeflabels(2.T = "Graphic" ///
			   3.T = "Nutrition facts" ///
			   4.T = "Stop sign" ///
			   1.is_treated = "Pooled", wrap(13)) ///
	order(3.T 4.T 2.T is_treated) ///
	yscale(range(-0.8 0.2)) /// 
	ylab(-0.8(0.2)0.2, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Treatment effect on relative WTP" "for sugary drinks ($wtp_unit_vis)") ///
	legend(off)

	* export graph 
	graph export "$rootdir/ssb/output/ATE_spike_plot.pdf", replace
	
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
    - [ssb/output/] ATE_above_and_below_median_`2'_spike_plot.pdf  
*******************************************************************************/


capture program drop gen_ATE_med_spike_plot 
program define gen_ATE_med_spike_plot 
	preserve

	* rename comparison covariate in case it's too long 
	gen het = `1'
	
	* summarize variable of interest to get median 
	sum het, d
	gen het_median = r(p50)

	gen het_above_median = het >= het_median
	gen het_below_median = het < het_median

	* generate treatment-specific interactions 
	forval t = 2/4 {
		foreach m in above below {
			gen T`t'`m' = `t'.T * het_`m'_median
		}
	}
		
	* generate pooled interactions 
	foreach m in above below {
		gen is_treated`m' = is_treated * het_`m'_median
	}

	* define lists of interaction terms 
	local interactions = "is_treatedabove is_treatedbelow"
	
	* run pooled regressions 
	reg delta_WTP i.is_treated gamma_hat $CONTROLS, cluster(id)
	eststo TpooledATE
	
	reg delta_WTP `interactions' het_above_median gamma_hat $CONTROLS, cluster(id)
	eststo TpooledMed

	* run treatment-specific regressions 
	forval t = 2/4 {
		reg delta_WTP `t'.T gamma_hat $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'ATE
		
		reg delta_WTP T`t'above T`t'below het_above_median gamma_hat $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'Med
	}
	
	* generate spike plot 
	coefplot (T2Med T3Med T4Med TpooledMed, ///
				label("Below-median" "`2'") ciopts(recast(rcap)) /// 
				rename(T2below = 2.T T3below = 3.T T4below = 4.T ///
					   is_treatedbelow = 1.is_treated) ///
				keep(T2below T3below T4below is_treatedbelow)) ///
			 (T2ATE T3ATE T4ATE TpooledATE, /// 
				  label("All") msymbol(square) mcolor(black) ///
				  ciopts(lcolor(black) recast(rcap)) ///
				  keep(2.T 3.T 4.T 1.is_treated)) ///
	         (T2Med T3Med T4Med TpooledMed, ///
				  label("Above-median" "`2'") msymbol(smdiamond) mcolor(maroon) ///
				  ciopts(lcolor(maroon) recast(rcap)) ///
				  rename(T2above = 2.T T3above = 3.T T4above = 4.T ///
						 is_treatedabove = 1.is_treated) ///
				  keep(T2above T3above T4above is_treatedabove)), vertical ///
	coeflabels(2.T = "Graphic" ///
			   3.T = "Nutrition facts" ///
			   4.T = "Stop sign" ///
			   1.is_treated = "Pooled", wrap(13)) ///
	order(3.T 4.T 2.T is_treated) ///
	yscale(range(-0.8 0.2)) /// 
	ylab(-0.8(0.2)0.2, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Treatment effect on relative WTP" "for sugary drinks ($wtp_unit_vis)") ///
	legend(rows(1))

	* export plot 
	graph export "$rootdir/ssb/output/ATE_above_and_below_median_`2'_spike_plot.pdf", replace

	restore 
	
end 

gen_ATE_med_spike_plot gamma_hat "bias"
gen_ATE_med_spike_plot distortion "bias + externality"
gen_ATE_med_spike_plot pct_correct "nutrition knowledge"
gen_ATE_med_spike_plot self_control "self-control"


/*******************************************************************************
Generate ATE spike plot that reports conditional ATEs specifically for above-
and below-median bias, all in the same figure. 

FUNC NAME: gen_combo_ATE_med_spike_plot
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figures:
    - [ssb/output/] ATE_above_and_below_median_combo_spike_plot.pdf
	- [ssb/output/] ATE_above_and_below_median_combo_spike_plot_alt.pdf
*******************************************************************************/

capture program drop gen_combo_ATE_med_spike_plot
program define gen_combo_ATE_med_spike_plot
	preserve
	
	* generate above- and below-median bias 
	sum gamma_hat, d
	gen bias_median = r(p50)

	gen bias_above_median = gamma_hat >= bias_median
	gen bias_below_median = gamma_hat < bias_median

	* generate treatment-specific interactions 
	forval t = 2/4 {
		foreach m in above below {
			gen T`t'`m'_bias = `t'.T * bias_`m'_median
		}
	}
	
	* generate pooled interactions for bias
	foreach m in above below {
		gen treated`m'_bias = is_treated * bias_`m'_median
	}

	* run ATE regression  
	reg delta_WTP i.is_treated gamma_hat $CONTROLS, cluster(id)
	eststo TpooledATE

	* run bias regression
	reg delta_WTP treatedabove_bias treatedbelow_bias gamma_hat bias_above_median $CONTROLS, cluster(id)
	eststo TpooledMedBias	

	* run treatment-specific regressions 
	forval t = 2/4 {
		reg delta_WTP `t'.T gamma_hat $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'ATE
		
		reg delta_WTP T`t'above_bias T`t'below_bias bias_above_median gamma_hat $CONTROLS if (T == 1 | T == `t'), cluster(id)
		eststo T`t'MedBias
	}

	* produce visualization
	coefplot (TpooledMedBias TpooledATE, ///
				ciopts(recast(rcap)) ///
				keep(treatedbelow_bias 1.is_treated treatedabove_bias)), vertical ///
	coeflabels(treatedbelow_bias = "Below-median bias" ///
			   1.is_treated = "All" ///
			   treatedabove_bias = "Above-median bias", wrap(13) labsize(3.2)) ///
	order(treatedbelow_bias 1.is_treated treatedabove_bias) ///
	yscale(range(-0.8 0.2)) /// 
	ylab(-0.8(0.2)0.2, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	ytitle("Treatment effect on relative WTP" "for sugary drinks ($wtp_unit_vis)") ///
	legend(off)
	
	* export 
	graph export "$rootdir/ssb/output/ATE_above_and_below_median_combo_spike_plot_alt.pdf", replace	
	
	* produce alternate visualization 
	coefplot (TpooledATE T2ATE T3ATE T4ATE, ///
				label("All") ciopts(recast(rcap) ///
				lcolor(black)) mcolor(black) msymbol(square) ///
				keep(1.is_treated 2.T 3.T 4.T)) ///
			 (TpooledMedBias T2MedBias T3MedBias T4MedBias, ///
				label("Below-median" "bias") ciopts(recast(rcap) ///
				lcolor(ebblue*2)) mcolor(ebblue*2) msymbol(triangle) ///
				rename(treatedbelow_bias = 1.is_treated T2below_bias = 2.T ///
				       T3below_bias = 3.T T4below_bias = 4.T) ///
				keep(treatedbelow_bias T2below_bias T3below_bias T4below_bias)) ///
			 (TpooledMedBias T2MedBias T3MedBias T4MedBias, ///
				label("Above-median" "bias") ciopts(recast(rcap) ///
				lcolor(maroon)) mcolor(maroon) ///
				rename(treatedabove_bias = 1.is_treated T2above_bias = 2.T ///
				       T3above_bias = 3.T T4above_bias = 4.T) msymbol(triangle) ///
				keep(treatedabove_bias T2above_bias T3above_bias T4above_bias)), vertical ///
	coeflabels(2.T = "Graphic" ///
			   3.T = "Nutrition facts" ///
			   4.T = "Stop sign" ///
			   1.is_treated = "Pooled", wrap(13)) ///
	order(3.T 4.T 2.T is_treated) ///
	yscale(range(-0.8 0.2)) /// 
	ylab(-0.8(0.2)0.2, format(%15.0gc)) ///
	ciopts(recast(rcap)) plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
	graphregion(fcolor(white) lcolor(white)) ///
	xtitle("Treatment group") ytitle("Treatment effect on relative WTP" "for sugary drinks ($wtp_unit_vis)") ///
	legend(rows(1))
	
	* export
	graph export "$rootdir/ssb/output/ATE_above_and_below_median_combo_spike_plot.pdf", replace	
	
	restore 
end 

gen_combo_ATE_med_spike_plot


/*******************************************************************************
Generate baseline demand curve across all groups (control + treatments). 

FUNC NAME: gen_baseline_demand_curve
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [ssb/output/] demand_pre (all).pdf
*******************************************************************************/

capture program drop gen_baseline_demand_curve
program define gen_baseline_demand_curve
	preserve
	
	* keep only relevant variables and reshape 
	keep id T order_base demand*  // order_base uniquely indexes each mpl
	reshape long demand_pre demand_post, i(id order_base) j(index)
	gen price = 0.5*index - 5

	* collapse to get count by demand level 
	collapse demand_pre, by(price)
	sort price 

	* generate plot 
	twoway (line price demand_pre, c(stepstair) lc(dknavy) lwidth(thick) msymbol(none) ), ///
			plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
			graphregion(fcolor(white) lcolor(white)) ///
			xtitle("Demand") ///
			ytitle("Price") ///
			xscale(range(0 1)) ///
			xlab(0(0.2)1) ///
			ylab(, format(%15.0gc)) ///
			legend(label(1 "Pre-NPI"))
	
	* export 		
	graph export "$rootdir/ssb/output/baseline_demand.pdf", replace	
	
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
	- Other (market share reduction, distortion offset)
*******************************************************************************/

capture program drop parameters
program define parameters, rclass
	
	/******************************
	E[gamma] (pooled)
	******************************/

	qui reg gamma_hat, cluster(id)
	scalar e_gamma = _b[_cons]
	return scalar e_gamma = e_gamma
	local e_gamma = e_gamma 
	
	scalar se_e_gamma = _se[_cons]
	return scalar se_e_gamma = se_e_gamma

	
	/******************************
	SD(gamma) (pooled)
	******************************/

	sum gamma_hat, d
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
	E[distortion] (pooled)
	******************************/

	qui reg distortion, cluster(id)
	scalar e_distortion = _b[_cons]
	return scalar e_distortion = e_distortion
	local e_distortion = e_distortion 
	
	scalar se_e_distortion= _se[_cons]
	return scalar se_e_distortion = se_e_distortion


	/******************************
	E[distortion] (middle 50%)
	******************************/

	qui reg distortion if middle50ind == 1
	scalar e_distortion_mid50 = _b[_cons]
	return scalar e_distortion_mid50 = e_distortion_mid50
	local e_distortion_mid50 = e_distortion_mid50 
	
	scalar se_e_distortion_mid50 = _se[_cons]
	return scalar se_e_distortion_mid50 = se_e_distortion_mid50


	/******************************
	E[tau] (pooled)
	******************************/

	qui reg delta_WTP i.is_treated gamma_hat $CONTROLS, cluster(id)
	scalar e_tau = _b[1.is_treated]
	return scalar e_tau = e_tau
	local e_tau = e_tau
	
	scalar se_e_tau = _se[1.is_treated]
	return scalar se_e_tau = se_e_tau
	
	scalar neg_e_tau = e_tau * (-1)
	return scalar neg_e_tau = neg_e_tau
	
	
	/******************************
	E[tau] (by treatment)
	******************************/

	forval t = 2/4 {
		qui reg delta_WTP i.is_treated gamma_hat $CONTROLS if (T == 1 | T == `t'), cluster(id)
		scalar e_tau`t' = _b[1.is_treated]
		return scalar e_tau`t' = e_tau`t'
		local e_tau`t' = e_tau`t' 
		
		scalar se_e_tau`t' = _se[1.is_treated]
		return scalar se_e_tau`t' = se_e_tau`t'
	}
	
	
	/******************************
	E[tau] (middle 50%)
	******************************/

	qui reg delta_WTP i.is_treated gamma_hat $CONTROLS if middle50ind == 1, cluster(id)
	scalar e_tau_mid50 = _b[1.is_treated]
	return scalar e_tau_mid50 = e_tau_mid50
	local e_tau_mid50 = e_tau_mid50
	
	scalar se_e_tau_mid50 = _se[1.is_treated]
	return scalar se_e_tau_mid50 = se_e_tau_mid50

	
	/******************************
	Dp (pooled)
	******************************/

	* get demand at each relevant price
	local demand_points "9 11"
	foreach j in `demand_points' {
		egen sum_demand`j' = mean(demand_pre`j')
	}

	* get slope of demand at relative price of $0 (j = 10 corresponds to $0 relative price)
	gen slope_D = (sum_demand11-sum_demand9) / (0.5 * 2)
	sum slope_D
	scalar Dp = r(mean)
	return scalar Dp = Dp
	local Dp = Dp

	drop slope_D sum_demand9 sum_demand11

	
	/******************************
	Dp (middle 50%)
	******************************/

	foreach j in `demand_points' {
		gen demand_pre`j'_mid50 = .
		replace demand_pre`j'_mid50 = demand_pre`j' if middle50ind == 1
		egen sum_demand`j'_mid50 = mean(demand_pre`j'_mid50)
	}

	gen slope_D_mid50 = (sum_demand11_mid50-sum_demand9_mid50) / (0.5 * 2)
	sum slope_D_mid50
	scalar Dp_mid50 = r(mean)
	return scalar Dp_mid50 = Dp_mid50
	local Dp_mid50 = Dp_mid50

	drop slope_D_mid50 sum_demand9_mid50 sum_demand11_mid50 /// 
	     demand_pre9_mid50 demand_pre11_mid50 
	

	/******************************
	Var(tau) (simple ME)
	******************************/
	
	* pooled 
	xi i.is_treated
	xi: xtmixed delta_WTP i.is_treated gamma_hat $CONTROLS || id: i.is_treated, iter(100) vce(cluster id) variance nolr
	eststo simple_ME_reg
	_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
	return list
	scalar var_tau = r(est)
	scalar se_var_tau = r(se)
	return scalar var_tau = var_tau 
	local var_tau = var_tau
	return scalar se_var_tau = se_var_tau

	scalar sd_tau = var_tau ^ 0.5
	local sd_tau = sd_tau 
	return scalar sd_tau = sd_tau 
		
	* by-treatment 
	forval t = 2/4 {
		xi i.is_treated
		xi: xtmixed delta_WTP i.is_treated gamma_hat $CONTROLS if (T == 1 | T == `t') || ///
		        id: i.is_treated, iter(100) vce(cluster id) variance nolr
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
	xi i.is_treated
	xi: xtmixed delta_WTP i.is_treated gamma_hat $CONTROLS if middle50ind == 1 || ///
	        id: i.is_treated, iter(100) vce(cluster id) variance nolr
	eststo simple_ME_reg_mid50
	_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
	return list
	scalar var_tau_mid50 = r(est)
	scalar se_var_tau_mid50 = r(se)
	return scalar var_tau_mid50 = var_tau_mid50
	local var_tau_mid50 = var_tau_mid50
	return scalar se_var_tau_mid50 = se_var_tau_mid50

	
	/******************************
	Cov[bias, tau] & Cov[externality, tau] (full ME)
	******************************/

	* Obtain Var(bias) and Var(externality) for later use 
	sum gamma_hat, d
	scalar var_bias = r(Var)

	sum externality, d
	scalar var_ext = r(Var)
	
	* pooled 
	cap gen bias_treated = gamma_hat * is_treated
	
	xi i.is_treated
	xi: xtmixed delta_WTP gamma_hat bias_treated i.is_treated $CONTROLS || id: i.is_treated, iter(100) vce(cluster id) variance nolr
	
	scalar cov_bias_tau = _b[bias_treated] * var_bias
	return scalar cov_bias_tau = cov_bias_tau 
	local cov_bias_tau = cov_bias_tau
	scalar se_cov_bias_tau = _se[bias_treated] * var_bias
	return scalar se_cov_bias_tau = se_cov_bias_tau

	scalar cov_ext_tau = 0
	return scalar cov_ext_tau = cov_ext_tau 
	local cov_ext_tau = cov_ext_tau
	scalar se_cov_ext_tau = 0 * var_ext
	return scalar se_cov_ext_tau = se_cov_ext_tau

	scalar cov_distortion_tau = cov_bias_tau + cov_ext_tau
	return scalar cov_distortion_tau = cov_distortion_tau
	local cov_distortion_tau = cov_distortion_tau
	
	eststo full_ME_reg

	* by treatment 
	forval t = 2/4 {
	
		sum gamma_hat, d
		scalar var_bias`t' = r(Var)

		sum externality, d
		scalar var_ext`t' = r(Var)

		cap gen T`t' = (T == `t')
		cap gen bias_treated`t' = gamma_hat * T`t'
		
		xi T`t'
		xi: xtmixed delta_WTP gamma_hat T`t' bias_treated`t' $CONTROLS if (T == 1 | T == `t') || id: T`t', vce(cluster id) iter(100) variance nolr 
		
		scalar cov_bias_tau`t' = _b[bias_treated`t'] * var_bias`t'
		return scalar cov_bias_tau`t' = cov_bias_tau`t'
		local cov_bias_tau`t' = cov_bias_tau`t'
		scalar se_cov_bias_tau`t' = _se[bias_treated`t'] * var_bias`t'
		return scalar se_cov_bias_tau`t' = se_cov_bias_tau`t'

		scalar cov_ext_tau`t' = 0 * var_ext`t'
		return scalar cov_ext_tau`t' = cov_ext_tau`t'
		local cov_ext_tau`t' = cov_ext_tau`t'
		scalar se_cov_ext_tau`t' = 0 * var_ext`t'
		return scalar se_cov_ext_tau`t' = se_cov_ext_tau`t'

		scalar cov_distortion_tau`t' = cov_bias_tau`t' + cov_ext_tau`t'
		return scalar cov_distortion_tau`t' = cov_distortion_tau`t'
		local cov_distortion_tau`t' = cov_distortion_tau`t'
	
		eststo full_ME_reg`t'
		
	}
	
	* middle-50% sample 
	sum gamma_hat if middle50ind == 1, d
	scalar var_bias_mid50 = r(Var)

	sum externality if middle50ind == 1, d
	scalar var_ext_mid50 = r(Var)
	
	xi i.is_treated
	xi: xtmixed delta_WTP gamma_hat bias_treated i.is_treated $CONTROLS if middle50ind == 1 || ///
	            id: i.is_treated, iter(100) vce(cluster id) variance nolr
	
	scalar cov_bias_tau_mid50 = _b[bias_treated] * var_bias_mid50
	return scalar cov_bias_tau_mid50 = cov_bias_tau_mid50
	local cov_bias_tau_mid50 = cov_bias_tau_mid50
	scalar se_cov_bias_tau_mid50 = _se[bias_treated] * var_bias_mid50
	return scalar se_cov_bias_tau_mid50 = se_cov_bias_tau_mid50

	scalar cov_ext_tau_mid50 = 0
	return scalar cov_ext_tau_mid50 = cov_ext_tau_mid50
	local cov_ext_tau_mid50 = cov_ext_tau_mid50
	scalar se_cov_ext_tau_mid50 = 0 * var_ext_mid50
	return scalar se_cov_ext_tau_mid50 = se_cov_ext_tau_mid50

	scalar cov_distortion_tau_mid50 = cov_bias_tau_mid50 + cov_ext_tau_mid50
	return scalar cov_distortion_tau_mid50 = cov_distortion_tau_mid50
	local cov_distortion_tau_mid50 = cov_distortion_tau_mid50
	
	eststo full_ME_reg_mid50
	
	
	/******************************
	Cov[distortion, tau] (alternate method)
	******************************/
	
	correlate distortion delta_WTP if is_treated == 1, cov
	scalar cov_gamma_tau_diff = r(C)[2,1]
	return scalar cov_gamma_tau_diff = cov_gamma_tau_diff


	/******************************
	Coefficient of variation 
	******************************/
	
	scalar coef_of_var = sd_tau / abs(e_tau)
	local coef_of_var = coef_of_var
	return scalar coef_of_var = coef_of_var

	
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
	
	* by treatment 
	forval t = 2/4 {		
		calc_welfare, e_tau("`e_tau`t''") e_distortion("`e_distortion'") dp("`Dp'") var_tau("`var_tau`t''") ///
	                  cov_distortion_tau("`cov_distortion_tau`t''") delta_i("$DeltaI") rho("$rho") mu("$mu")
		return list
		
		return scalar welfare_tax_w_npi`t' = r(welfare_tax_w_npi_temp)
		return scalar welfare_tax_wo_npi`t' = r(welfare_tax_wo_npi_temp)
		return scalar welfare_npi_w_tax`t' = r(welfare_npi_w_tax_temp)
		return scalar welfare_npi_wo_tax`t' = r(welfare_npi_wo_tax_temp)
	}
	
	* middle-50% sample 
	calc_welfare, e_tau("`e_tau_mid50'") e_distortion("`e_distortion_mid50'") dp("`Dp_mid50'") ///
	              var_tau("`var_tau_mid50'") cov_distortion_tau("`cov_distortion_tau_mid50'") ///
				  delta_i("$DeltaI") rho("$rho") mu("$mu")
	return list
	
	return scalar welfare_tax_w_npi_mid50 = r(welfare_tax_w_npi_temp)
	return scalar welfare_tax_wo_npi_mid50 = r(welfare_tax_wo_npi_temp)
	return scalar welfare_npi_w_tax_mid50 = r(welfare_npi_w_tax_temp)
	return scalar welfare_npi_wo_tax_mid50 = r(welfare_npi_wo_tax_temp)


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
	
	* set locals
	
	parameters 
	return list

	* save important coefficients to numbers.tex 

	local e_tau: di r(e_tau)
	local neg_e_tau: di r(neg_e_tau)
	local e_gamma: di r(e_gamma)
	local sd_gamma: di r(sd_gamma)
	local e_phi: di r(e_phi)
	local e_distortion: di r(e_distortion)
	local Dp: di r(Dp)
	local var_tau: di r(var_tau)
	local sd_tau: di r(sd_tau)
	local coef_of_var: di r(coef_of_var)
	local cov_bias_tau: di r(cov_bias_tau)
	local cov_ext_tau: di r(cov_ext_tau)
	local cov_distortion_tau: di r(cov_distortion_tau)
	local welfare_npi_w_tax: di r(welfare_npi_w_tax)
	local welfare_npi_wo_tax: di r(welfare_npi_wo_tax)
	local welfare_zero_var_cov: di r(welfare_zero_var_cov)
	local welfare_zero_tau: di r(welfare_zero_tau)
	local welfare_zero_tau_cov: di r(welfare_zero_tau_cov)
	local welfare_zero_cov: di r(welfare_zero_cov)
	local cov_gamma_tau_diff: di r(cov_gamma_tau_diff)
	local market_share_reduction: di r(market_share_reduction)
	local distortion_offset: di r(distortion_offset)

	local se_e_tau: di r(se_e_tau)
	local se_e_gamma: di r(se_e_gamma)
	local se_e_phi: di r(se_e_phi)
	local se_e_distortion: di r(se_e_distortion)
	local se_var_tau: di r(se_var_tau)
	local se_cov_bias_tau: di r(se_cov_bias_tau)
	local se_cov_ext_tau: di r(se_cov_ext_tau)
	
	latex_rounded, name("ssbETau") value(`e_tau') digits(2)
	latex_rounded, name("ssbNegETau") value(`neg_e_tau') digits(2)
	latex_rounded, name("ssbEGamma") value(`e_gamma') digits(2)
	latex_rounded, name("ssbSDGamma") value(`sd_gamma') digits(2)
	latex_rounded, name("ssbEPhi") value(`e_phi') digits(2)
	latex_rounded, name("ssbEDistortion") value(`e_distortion') digits(2)
	latex_rounded, name("ssbEDelta") value(`e_distortion') digits(2)
	latex_rounded, name("ssbDp") value(`Dp') digits(2)
	latex_rounded, name("ssbVarTau") value(`var_tau') digits(2)
	latex_rounded, name("ssbSDTau") value(`sd_tau') digits(2)
	latex_rounded, name("ssbCoefOfVar") value(`coef_of_var') digits(1)
	latex_rounded, name("ssbCovBiasTau") value(`cov_bias_tau') digits(2)
	latex_rounded, name("ssbCovExtTau") value(`cov_ext_tau') digits(0)
	latex_rounded, name("ssbCovDistortionTau") value(`cov_distortion_tau') digits(0)
	latex_rounded, name("ssbWelfareNPIWithTax") value(`welfare_npi_w_tax') digits(2)
	latex_rounded, name("ssbWelfareNPIWithoutTax") value(`welfare_npi_wo_tax') digits(2)
	latex_rounded, name("ssbWelfareNPIWithoutTaxZeroVarCov") value(`welfare_zero_var_cov') digits(2)
	latex_rounded, name("ssbWelfareNPIWithoutTaxZeroTau") value(`welfare_zero_tau') digits(2)
	latex_rounded, name("ssbWelfareNPIWithoutTaxZeroTauCov") value(`welfare_zero_tau_cov') digits(2)
	latex_rounded, name("ssbWelfareNPIWithoutTaxZeroCov") value(`welfare_zero_cov') digits(2)
	latex_rounded, name("ssbRho") value("$rho") digits(2)
	latex_rounded, name("ssbMu") value("$mu") digits(0)
	latex_rounded, name("ssbCovDiff") value(`cov_gamma_tau_diff') digits(2)
	latex_rounded, name("ssbMktShareReduction") value(`market_share_reduction') digits(0)
	latex_rounded, name("ssbDistOffset") value(`distortion_offset') digits(0)

	latex_rounded, name("ssbSEETau") value(`se_e_tau') digits(2)
	latex_rounded, name("ssbSEEGamma") value(`se_e_gamma') digits(2)
	latex_rounded, name("ssbSEEPhi") value(`se_e_phi') digits(2)
	latex_rounded, name("ssbSEEDistortion") value(`se_e_distortion') digits(2)
	latex_rounded, name("ssbSEVarTau") value(`se_var_tau') digits(2)
	latex_rounded, name("ssbSECovBiasTau") value(`se_cov_bias_tau') digits(2)
	latex_rounded, name("ssbSECovExtTau") value(`se_cov_ext_tau') digits(2)
	latex_rounded, name("ssbSERho") value(0) digits(2)
	latex_rounded, name("ssbSEMu") value(0) digits(0)
	
	* iterate over each treatment and store values, accounting for the fact
	* that spelled numbers (e.g., Two, Three) must be used to name scalars
	
	local Ts 2 3 4
	local TStrs Two Three Four
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

		latex_rounded, name("ssbETau`tstr'T") value(`e_tau') digits(2)
		latex_rounded, name("ssbVarTau`tstr'T") value(`var_tau') digits(2)
		latex_rounded, name("ssbCovBiasTau`tstr'T") value(`cov_bias_tau') digits(2)
		latex_rounded, name("ssbCovExtTau`tstr'T") value(`cov_ext_tau') digits(2)
		latex_rounded, name("ssbWelfareNPIWithTax`tstr'T") value(`welfare_npi_w_tax') digits(2)
		latex_rounded, name("ssbWelfareNPIWithoutTax`tstr'T") value(`welfare_npi_wo_tax') digits(2)
		
		latex_rounded, name("ssbSEETau`tstr'T") value(`se_e_tau') digits(2)
		latex_rounded, name("ssbSEVarTau`tstr'T") value(`se_var_tau') digits(2)
		latex_rounded, name("ssbSECovBiasTau`tstr'T") value(`se_cov_bias_tau') digits(2)
		latex_rounded, name("ssbSECovExtTau`tstr'T") value(`se_cov_ext_tau') digits(2)
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
	
	latex_rounded, name("ssbETauMidFifty") value(`e_tau') digits(2)
	latex_rounded, name("ssbEDistortionMidFifty") value(`e_distortion') digits(2)
	latex_rounded, name("ssbDpMidFifty") value(`Dp') digits(2)
	latex_rounded, name("ssbVarTauMidFifty") value(`var_tau') digits(2)
	latex_rounded, name("ssbCovBiasTauMidFifty") value(`cov_bias_tau') digits(2)
	latex_rounded, name("ssbCovExtTauMidFifty") value(`cov_ext_tau') digits(2)
	latex_rounded, name("ssbWelfareNPIWithTaxMidFifty") value(`welfare_npi_w_tax') digits(2)
	latex_rounded, name("ssbWelfareNPIWithoutTaxMidFifty") value(`welfare_npi_wo_tax') digits(2)

	latex_rounded, name("ssbSEETauMidFifty") value(`se_e_tau') digits(2)
	latex_rounded, name("ssbSEEDistortionMidFifty") value(`se_e_distortion') digits(2)
	latex_rounded, name("ssbSEVarTauMidFifty") value(`se_var_tau') digits(2)
	latex_rounded, name("ssbSECovBiasTauMidFifty") value(`se_cov_bias_tau') digits(2)
	latex_rounded, name("ssbSECovExtTauMidFifty") value(`se_cov_ext_tau') digits(2)
	
	restore 
end 

gen_param_estimates


/*******************************************************************************
Generate data for welfare comparative statics figures by estimating and 
exporting various counterfactual welfare statistics. 

FUNC NAME: gen_welfare_sensitivity_data
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Saves treatment-specific statistics to the following files:
    - [ssb/output/] welfare_plot_table_1.xlsx
    - [ssb/output/] welfare_plot_table_2.xlsx
    - [ssb/output/] welfare_plot_table_3.xlsx
    - [ssb/output/] welfare_plot_table_4.xlsx
    - [ssb/output/] welfare_plot_table_5.xlsx
    - [ssb/output/] welfare_plot_table_all.xlsx
*******************************************************************************/

* create function to go through entire data calculation process 

capture program drop gen_welfare_sensitivity_data
program define gen_welfare_sensitivity_data
	preserve 
	
	* iterate over all treatment options, exporting data for each one 
	foreach t in -1 2 3 4 {
		
		* run parameters function to get point estimates for variance, covariance,
		* Dp, E[tau], and E[distortion]
		parameters
		return list
		
		* determine which treatment is being used (pooled (-1) or T=2,3,4)
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
		local var_xlim_min = ((`cov')^2) / `var_tau'
		local var_xlim_min : display %8.0f `var_xlim_min'

		local var_xlim_max = 10
		local cov_xlim_min = -5
		local cov_xlim_max = 5
		local rho_xlim_min = 0
		local rho_xlim_max = 1
		local mu_xlim_min = -1
		local mu_xlim_med = 0
		local mu_xlim_max = 1
		local delta_xlim_min = -8
		local delta_xlim_med = 0
		local delta_xlim_max = 8
		local DeltaI_xlim_min = -4
		local DeltaI_xlim_max = 4
		
		* use parameters to create excel spreadsheet that can then be used
		* for basic algebraic plot 
		putexcel set "$rootdir/ssb/output/welfare/welfare_plot_table_`Tstr'.xlsx", sheet(Sheet1) replace

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
    - [cars/output/] welfare_vs_var_`T'.pdf
    - [cars/output/] welfare_vs_cov_`T'.pdf
    - [cars/output/] welfare_vs_var_and_cov_panel_`T'.pdf
    - [cars/output/] welfare_vs_rho_`T'.pdf
    - [cars/output/] welfare_vs_mu_`T'.pdf
    - [cars/output/] welfare_vs_rho_and_mu_panel_`T'.pdf
    - [cars/output/] welfare_vs_delta_`T'.pdf
*******************************************************************************/

capture program drop gen_welfare_sensitivity_graphs
program define gen_welfare_sensitivity_graphs
	preserve
	
	* determine which treatment is being used (pooled (-1) or T=2,3,4)
	
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
	import excel "$rootdir/ssb/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	mkmat est_var est_cov, mat(est)
	local est_var = est[1, 1]
	local est_cov = est[1, 2]

	* create plot where variance varies
	
	local var_xmin = ((`est_cov')^2) / `est_var'
	local var_xmin : display %8.0f `var_xmin'
	keep if varying == "var"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   lfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   lfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Variance of label effect (($wtp_unit_vis)^2)") ytitle("Total surplus gain ($wtp_unit_vis)") ///
		   yscale(range(-1 1)) ///
		   ylabel(-1(0.25)1) ///
		   xscale(range(`var_xmin' 10)) ///
		   xlabel(`var_xmin'(2)10, format(%13.0fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) || ///
		   scatteri -1 `est_var' 1 `est_var' 0, recast(line) xaxis(2) ///
		   lcolor(green%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(`var_xmin' 10) axis(2)) ///
		   xlab(`est_var' "Estimated value", axis(2)) ///
		   legend(order(4 2 3 1))
	
	graph save "$rootdir/ssb/output/welfare/welfare_vs_var", replace
	graph export "$rootdir/ssb/output/welfare/welfare_vs_var_`Tstr'.pdf", replace
	
	* create plot where covariance varies
	
	clear 
	import excel "$rootdir/ssb/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	mkmat est_var est_cov, mat(est)
	local est_cov = est[1, 2]
	keep if varying == "cov"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   lfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   lfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Covariance between bias + externality and label effect (($wtp_unit_vis)^2)") ytitle("") ///
		   yscale(range(-1 1)) ///
		   ylabel(-1(0.25)1) ///
		   xscale(range(-5 5)) ///
		   xlabel(-5(1)5, format(%13.0fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) || ///
		   scatteri -1 `est_cov' 1 `est_cov' 0, recast(line) xaxis(2) ///
		   lcolor(orange%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(-5 5) axis(2)) ///
		   xlab(`est_cov' "Estimated value", axis(2)) ///
		   legend(order(4 2 3 1))
	
	graph save "$rootdir/ssb/output/welfare/welfare_vs_cov", replace
	graph export "$rootdir/ssb/output/welfare/welfare_vs_cov_`Tstr'.pdf", replace
	
	* create side-by-side combo plot 
	
	clear
	graph combine "$rootdir/ssb/output/welfare/welfare_vs_var" "$rootdir/ssb/output/welfare/welfare_vs_cov", ///
	xsize(8) graphregion(fcolor(white) lcolor(white)) ///
	
	graph export "$rootdir/ssb/output/welfare/welfare_vs_var_and_cov_panel_`Tstr'.pdf", replace

	******************************
	*         PANEL 2            *
	******************************

	* create plot where rho varies 
	
	clear 
	import excel "$rootdir/ssb/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	keep if varying == "rho"
	
	twoway lfit welfare_tax x, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x, lpattern("dash") lcolor(red%30) || ///
		   lfit welfare_npi x, lpattern("solid") lcolor(blue%30) || ///
		   lfit welfare_nonpi x, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Pass-through rate difference") ytitle("Total surplus gain ($wtp_unit_vis)") ///
		   yscale(range(-0.25 1.25)) ///
		   ylabel(-0.25(0.25)1.25) ///
		   xscale(range(0 1)) ///
		   xlabel(0(0.2)1, format(%13.1fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) ///
		   legend(order(4 2 3 1)) || ///
		   scatteri -.25 $rho 1.25 $rho 0, recast(line) xaxis(2) ///
		   lcolor(orange%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(0 1) axis(2)) ///
		   xlab($rho "Assumed value", axis(2)) 
	
	graph save "$rootdir/ssb/output/welfare/welfare_vs_rho", replace
	graph export "$rootdir/ssb/output/welfare/welfare_vs_rho_`Tstr'.pdf", replace
	
	* create plot where mu varies 
	
	clear 
	import excel "$rootdir/ssb/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
	keep if varying == "mu"
	gen x_proportion = x / 4
	
	twoway lfit welfare_tax x_proportion, lpattern("solid") lcolor(red%30) || ///
		   lfit welfare_notax x_proportion, lpattern("dash") lcolor(red%30) || ///
		   qfit welfare_npi x_proportion, lpattern("solid") lcolor(blue%30) || ///
		   qfit welfare_nonpi x_proportion, lpattern("dash") lcolor(blue%30) ///
		   plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		   graphregion(fcolor(white) lcolor(white)) ///
		   xtitle("Markup difference / price") ytitle("") ///
		   yscale(range(-.25 1.5)) ///
		   ylabel(-.25(.25)1.5) ///
		   xscale(range(-0.25 0.25)) ///
		   xlabel(-0.25(0.05)0.25, format(%13.2fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) ///
		   legend(order(4 2 3 1)) || ///
		   scatteri -.25 $mu 1.5 $mu 0, recast(line) xaxis(2) ///
		   lcolor(green%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(-0.25 0.25) axis(2)) ///
		   xlab($mu "Assumed value", axis(2)) 
	
	graph save "$rootdir/ssb/output/welfare/welfare_vs_mu", replace
	graph export "$rootdir/ssb/output/welfare/welfare_vs_mu_`Tstr'.pdf", replace

	* create panel of rho and mu varying 
	
	clear
	graph combine "$rootdir/ssb/output/welfare/welfare_vs_rho" "$rootdir/ssb/output/welfare/welfare_vs_mu", ///
	xsize(8) graphregion(fcolor(white) lcolor(white)) ///
	
	graph export "$rootdir/ssb/output/welfare/welfare_vs_rho_and_mu_panel_`Tstr'.pdf", replace
	
	******************************
	*         PANEL 3            *
	******************************

	* create plot where delta varies 
	
	clear 
	import excel "$rootdir/ssb/output/welfare/welfare_plot_table_`Tstr'.xlsx", firstrow
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
		   yscale(range(-1 5)) ///
		   ylabel(-1(1)5) ///
		   xscale(range(-8 8)) ///
		   xlabel(-8(2)8, format(%13.0fc)) ///
		   legend(label(1 "Label (w/ tax)") label(2 "Label (w/o tax)") label(3 "Tax (w/ label)") label (4 "Tax (w/o label)")) ///
		   legend(order(4 2 3 1)) || ///
		   scatteri -1 `est_delta' 5 `est_delta' 0, recast(line) xaxis(2) ///
		   lcolor(orange%30) lpattern("dash") ///
		   xtitle("", axis(2)) ///
		   xscale(range(-8 8) axis(2)) ///
		   xlab(`est_delta' "Estimated value", axis(2)) 
	
	graph save "$rootdir/ssb/output/welfare/welfare_vs_delta", replace
	graph export "$rootdir/ssb/output/welfare/welfare_vs_delta_`Tstr'.pdf", replace
		
	restore
end

gen_welfare_sensitivity_graphs -1


/*******************************************************************************
Generate welfare bar graph (originally for NBER). 

FUNC NAME: gen_welfare_bar_graph
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [ssb/output/welfare/] welfare_bar_graph.pdf
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
		  ylabel(-.05(.05).15, format(%13.2fc)) ///
		  yline(0) ///
		  plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 8)) ///
		  graphregion(fcolor(white) lcolor(white)) ///
		  xsize(7)
		  
	* export graph 
	graph export "$rootdir/ssb/output/welfare/welfare_bar_graph.pdf", replace
	
	restore 
end 

gen_welfare_bar_graph


/*******************************************************************************
Generate histogram of bias. 

FUNC NAME: gen_bias_hist
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [ssb/output/] bias_hist.pdf
*******************************************************************************/

capture program drop gen_bias_hist
program define gen_bias_hist
	preserve
	
	* keep only id and bias
	keep id gamma_hat externality
	
	* drop duplicates
	duplicates drop
	
	* generate scalars for average bias and externality 
	sum gamma_hat
	local avg_bias = r(mean)

	sum externality
	local avg_ext = r(mean)

	* generate min value 
	local min_val = 0
	
	* create values for histogram 
	gen gamma_hat_adj = floor(gamma_hat/0.5)*0.5
	twoway__histogram_gen gamma_hat_adj, percent start(`min_val') width(0.25) gen(h0 x0)
	replace x0 = . if x0 <= `min_val'

	* labels for histogram
	label define x_series 0 "0" 1 "1" 2 "2" 3 "3" ///
	4 "4" 5 "5" 
	label values x0 x_series

	* generate histogram 
	twoway(bar h0 x0 if inrange(x0,0,5.5), barw(.5) bc(gs11) blc(black) bstyle(histogram)), ///
				plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
				graphregion(fcolor(white) lcolor(white)) ///
				xtitle("$wtp_unit_vis") ///
				xscale(range(0 5.5)) ///
				ytitle("Percent") ///
				xlab(0(1)5, valuelabel axis(1)) || ///
				scatteri 0 `avg_bias' 30 `avg_bias' 0, ///
				xscale(range(0 5.5) axis(2)) ///
			    recast(line) xaxis(2) ///
			    lcolor(red%100) lpattern("dash") lwidth(0.75) ///
			    xtitle("", axis(2)) ///
				legend(off) || ///
				scatteri 0 `avg_ext' 30 `avg_ext' 0, ///
			    recast(line) xaxis(2) ///
			    lcolor(blue%100) lpattern("dash") lwidth(0.75) ///
			    xlab(`avg_ext' "Average externality      " ///
				     `avg_bias' "      Average bias", ///
				     axis(2) format(%-20s %20s)) ///
				legend(off)

	* export histogram 
	graph export "$rootdir/ssb/output/bias_hist.pdf", replace

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
	
	* if doing middle-50% specification instead of full, restrict 
	* dataset accordingly 
	
	if "`1'" == "middle50" { 
		* remove all observations for any ID w/ one or more above-median WTPs
		keep if middle50ind == 1
	}

	* if only using a specific treatment, restrict to only observations
	* that received that treatment or were in control 
	
	if "`2'" != "pooled" {
		keep if (T == `2' | T == 1)
	}

	* run regressions and store 
	
	* generate bias * treated interaction 
	cap gen bias_treated = gamma_hat * is_treated
	
	* OLS ATE 
	
	reg delta_WTP i.is_treated gamma_hat $CONTROLS, cluster(id)
	eststo OLS_ATE_reg
	estadd scalar num_indiv = _N / 3

	* OLS covariance 
	
	reg delta_WTP gamma_hat bias_treated i.is_treated $CONTROLS, cluster(id)
	eststo OLS_cov_reg
	
	sum gamma_hat, d
	scalar var_bias = r(Var)
	
	scalar cov_bias_tau = _b[bias_treated] * var_bias
	estadd scalar cov_bias_tau = cov_bias_tau 
	local cov_bias_tau = cov_bias_tau
	
	scalar se_cov_bias_tau = _se[bias_treated] * var_bias
	
	local se_cov_bias_tau : display %9.3fc se_cov_bias_tau
	estadd local se_cov_bias_tau = subinstr("(`se_cov_bias_tau')", " ", "", .)

	estadd scalar num_indiv = _N / 3

	* Simple ME
	
	xi i.is_treated
	xi: xtmixed delta_WTP i.is_treated gamma_hat $CONTROLS || id: i.is_treated, iter(100) vce(cluster id) variance nolr
	eststo ME_var_reg
	_diparm lns1_1_1, f(exp(@)^2) d(2*exp(@)^2)
	return list
	scalar var_tau = r(est)
	scalar se_var_tau = r(se)
	estadd scalar var_tau = var_tau 
		
	local se_var_tau : display %9.3fc se_var_tau
	estadd local se_var_tau = subinstr("(`se_var_tau')", " ", "", .)

	estadd scalar num_indiv = _N / 3

	* Full ME
	
	xi: xtmixed delta_WTP gamma_hat bias_treated i.is_treated $CONTROLS || id: i.is_treated, iter(100) vce(cluster id) variance nolr
	
	scalar cov_bias_tau = _b[bias_treated] * var_bias
	estadd scalar cov_bias_tau = cov_bias_tau 
	local cov_bias_tau = cov_bias_tau
	
	scalar se_cov_bias_tau = _se[bias_treated] * var_bias
		
	local se_cov_bias_tau : display %9.3fc se_cov_bias_tau
	estadd local se_cov_bias_tau = subinstr("(`se_cov_bias_tau')", " ", "", .)

	eststo ME_cov_reg
	estadd scalar num_indiv = _N / 3
	
	* combine into table and export 
	esttab OLS_ATE_reg OLS_cov_reg ME_var_reg ME_cov_reg using "$rootdir/ssb/output/combined_reg_table_`1'_`2'.tex", replace /// 
	mtitle("OLS" "OLS" "Mixed effects" "Mixed effects") ///
	b(2) se(2) label starlevels( * 0.10 ** 0.05 *** 0.010) stats(cov_bias_tau se_cov_bias_tau var_tau se_var_tau num_indiv N, /// 
	labels("Cov(bias, treatment effect)" "(standard error)" "Var(treatment effect)" /// 
	"(standard error)" "Number of participants" "Number of observations") fmt(%9.3fc %9.3fc %9.3fc %9.3fc %9.0fc %9.0fc)) nonotes ///
	eqlabels(" " " " " " " ") ///
	rename(_Itreated_1 1.is_treated _Iis_treate_1 1.is_treated) ///
	coeflabels(1.is_treated "\shortstack[l]{Treated}" ///
			   gamma_hat "\shortstack[l]{Bias}" ///
			   bias_treated "\shortstack[l]{Bias $\times$ Treated}") ///
	order(1.is_treated ///
		  bias_treated ///
		  gamma_hat) ///
	keep(1.is_treated ///
		 bias_treated) ///
	refcat(label("N"))
	
	* export relevant coefficients if pooled 
	if ("`1'" == "full" & "`2'" == "pooled") {
		local alpha_one = _b[bias_treated]
		latex_rounded, name("ssbAlphaOne") value(`alpha_one') digits(2)
	}

	* clear esttab results for future analyses 
	eststo clear 
	
	restore
end

gen_combo_reg_tbl "full" "pooled"
gen_combo_reg_tbl "full" "2"
gen_combo_reg_tbl "full" "3"
gen_combo_reg_tbl "full" "4"
gen_combo_reg_tbl "middle50" "pooled"

