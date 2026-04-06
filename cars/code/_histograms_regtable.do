/*******************************************************************************
DESCRIPTION: Histogram figures and combined regression table for the cars
experiment.
*******************************************************************************/

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

	* Simple OLS ATE
	reg delta_wtp_median i.treated overvaluation_b_median externality $CONTROLS, cluster(id)
	eststo OLS_ATE_reg

	estadd scalar num_indiv = _N / 2

	* OLS with covariates
	xi i.treated
	xi i.product_pair_strict
	reg delta_wtp_median i.treated overvaluation_b_median bias_treated externality ext_treated $CONTROLS, cluster(id)

	* covariance parameter estimates
	scalar cov_bias_tau = (_b[bias_treated] * var_bias) + (cov_bias_ext * _b[ext_treated])
	estadd scalar cov_bias_tau = cov_bias_tau
	local cov_bias_tau = cov_bias_tau

	scalar cov_ext_tau = (_b[ext_treated] * var_ext) + (cov_bias_ext * _b[bias_treated])
	estadd scalar cov_ext_tau = cov_ext_tau
	local cov_ext_tau = cov_ext_tau

	* covariance SEs
	nlcom (bias_treated_scaled_OLS_cov: (var_bias * _b[bias_treated]) + ///
	                                    (cov_bias_ext * _b[ext_treated])) ///
	      (ext_treated_scaled_OLS_cov: (var_ext * _b[ext_treated]) + ///
		                               (cov_bias_ext * _b[bias_treated])), post

	scalar se_cov_bias_tau_lin_cov = _se[bias_treated_scaled_OLS_cov]
	scalar se_cov_ext_tau_lin_cov = _se[ext_treated_scaled_OLS_cov]

	est restore OLS_ATE_reg

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
