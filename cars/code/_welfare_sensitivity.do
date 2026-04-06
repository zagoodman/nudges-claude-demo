/*******************************************************************************
Welfare sensitivity analysis and bar graph for the cars experiment.
*******************************************************************************/

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
