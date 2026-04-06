/*******************************************************************************
Generates baseline demand curve for the cars experiment.
*******************************************************************************/


/*******************************************************************************
Generate baseline demand curve across all groups (control + treatments).

FUNC NAME: gen_baseline_demand_curve
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Exports the following figure:
    - [cars/output/] demand_pre (all).pdf
*******************************************************************************/

capture program drop gen_baseline_demand_curve
program define gen_baseline_demand_curve
	preserve

	* reshape data for aggregation by price
	keep id T product_pair demand*
	reshape long demand_pre demand_post, i(id product_pair) j(index)
	gen price = 100*index - 1600

	* aggregate by price to get demand curve
	collapse demand_pre, by(price)
	sort price

	* graph demand curve
	twoway (line price demand_pre, c(stepstair) lc(dknavy) lwidth(thick) msymbol(none) ), ///
			plotregion(fcolor(white) lcolor(white) margin(b = 0 r = 3)) ///
			graphregion(fcolor(white) lcolor(white)) ///
			xtitle("Demand") ///
			ytitle("Relative price of lower-MPG car ($wtp_unit_vis)") ///
			xscale(range(0 1)) ///
			xlab(0(0.2)1) ///
			ylab(-1500(500)1500, format(%15.0gc)) ///
			legend(label(1 "Pre-NPI"))

	* export
	graph export "$rootdir/cars/output/baseline_demand.pdf", replace

	restore
end

gen_baseline_demand_curve
