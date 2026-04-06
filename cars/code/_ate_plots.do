/*******************************************************************************
Generates ATE spike plots for the cars experiment, including
unconditional ATEs, conditional ATEs by above/below median covariates,
and combined bias/externality spike plots.
*******************************************************************************/


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
