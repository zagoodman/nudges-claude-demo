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

