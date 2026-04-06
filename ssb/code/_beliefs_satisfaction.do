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

