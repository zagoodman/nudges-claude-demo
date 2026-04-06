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

