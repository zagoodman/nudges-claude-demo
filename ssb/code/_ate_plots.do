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

