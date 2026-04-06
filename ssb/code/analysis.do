/*******************************************************************************
TITLE: analysis.do
AUTHOR(S): Daniel Cohen <-- Victoria Pu/William Morrison
DESCRIPTION: Reads in processed data and produces all tables and figures for
    the SSB experiment.
DATE LAST MODIFIED: APR 2025
FILE(S) USED:
    - merged.dta (processed data from SSB experiment)
*******************************************************************************/

clear all

do "$rootdir/ssb/code/_setup.do"
do "$rootdir/ssb/code/_sample_descriptives.do"
do "$rootdir/ssb/code/_label_avoidance.do"
do "$rootdir/ssb/code/_beliefs_satisfaction.do"
do "$rootdir/ssb/code/_ate_plots.do"
do "$rootdir/ssb/code/_demand_curves.do"
do "$rootdir/ssb/code/_welfare.do"
do "$rootdir/ssb/code/_welfare_sensitivity.do"
