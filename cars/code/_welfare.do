/*******************************************************************************
Core welfare estimation for the cars experiment. Defines and calls
calc_welfare, parameters, and gen_param_estimates.
*******************************************************************************/

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
