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

