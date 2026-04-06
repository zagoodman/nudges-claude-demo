/*******************************************************************************
TITLE: analysis.do
AUTHOR(S): Daniel Cohen <-- Victoria Pu
DESCRIPTION: Reads in processed data and produces all tables and figures for
    the cars experiment. Thin orchestrator — delegates to sub-files.
FILE(S) USED:
    - merged.dta (processed data from cars experiment)
*******************************************************************************/

clear all

do "$rootdir/cars/code/_setup.do"
do "$rootdir/cars/code/_sample_descriptives.do"
do "$rootdir/cars/code/_ate_plots.do"
do "$rootdir/cars/code/_demand_curves.do"
do "$rootdir/cars/code/_welfare.do"
do "$rootdir/cars/code/_welfare_sensitivity.do"
do "$rootdir/cars/code/_histograms_regtable.do"
