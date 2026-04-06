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

