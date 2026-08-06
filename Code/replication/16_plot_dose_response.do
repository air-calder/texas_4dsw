/*
Description: Plot dose-response of teacher retention vs. 4DSW intensity group.
Reads teacher_retention_deciles.csv, plots baseline coefficients with 95% CIs.
Group count detected from data (not hardcoded).
Run from project root.
*/

version 17

* Deciles
local results_csv "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_deciles.csv"
capture mkdir "code/4DSW student teacher analysis/replication/output/figures"

capture confirm file "`results_csv'"
if _rc {
    di as error "Missing input: `results_csv'"
	exit 601
}

import delimited "`results_csv'", clear stringcols(_all)

* (a) Keep baseline specification, stay_school_t1 outcome
keep if outcome == "stay_school_t1"
keep if regexm(spec, "^baseline_[0-9]+$")

* (b) Extract numeric group from spec suffix (e.g. baseline_3 -> 3)
gen group = real(regexs(1)) if regexm(spec, "^baseline_([0-9]+)$")

* Cast numeric columns from string import
destring coef se pvalue n, replace force 

quietly count
if r(N) == 0 {
    di as error "No rows match outcome=stay_school_t1 baseline spec in `results_csv'"
	exit 459
}

* 95% confidence interval
gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se

sort group
quietly summarize group, meanonly
local ngroups = r(max)

* (c) Coefficient plot: point + CI vs group
twoway ///
	(rcap ci_hi ci_lo group, lcolor(navy%70) lwidth(medium)) ///
	(scatter coef group, mcolor(navy) msymbol(0) msize(medium)), ///
	yline(0, lcolor(gray) lpattern(dash)) ///
	xlabel(1(1)`ngroups') ///
	xtitle("4DSW intensity group (1 = lowest, `ngroups' = highest)") ///
	ytitle("Coefficient: stay in school (t+1)") ///
	title("Dose-response: retention by 4-day-week intensity") ///
	subtitle("Baseline specification, 95% CIs") ///
	legend(off) ///
	graphregion(color(white)) plotregion(color(white))
	
graph export "code/4DSW student teacher analysis/replication/output/figures/dose_response_stay_school_deciles.png", replace width(1400) height(900)

* Quartiles 
local results_csv "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_quartiles.csv"
capture mkdir "code/4DSW student teacher analysis/replication/output/figures"

capture confirm file "`results_csv'"
if _rc {
    di as error "Missing input: `results_csv'"
	exit 601
}

import delimited "`results_csv'", clear stringcols(_all)

* (a) Keep baseline specification, stay_school_t1 outcome
keep if outcome == "stay_school_t1"
keep if regexm(spec, "^baseline_[0-9]+$")

* (b) Extract numeric group from spec suffix (e.g. baseline_3 -> 3)
gen group = real(regexs(1)) if regexm(spec, "^baseline_([0-9]+)$")

* Cast numeric columns from string import
destring coef se pvalue n, replace force 

quietly count
if r(N) == 0 {
    di as error "No rows match outcome=stay_school_t1 baseline spec in `results_csv'"
	exit 459
}

* 95% confidence interval
gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se

sort group
quietly summarize group, meanonly
local ngroups = r(max)

* (c) Coefficient plot: point + CI vs group
twoway ///
	(rcap ci_hi ci_lo group, lcolor(navy%70) lwidth(medium)) ///
	(scatter coef group, mcolor(navy) msymbol(0) msize(medium)), ///
	yline(0, lcolor(gray) lpattern(dash)) ///
	xlabel(1(1)`ngroups') ///
	xtitle("4DSW intensity group (1 = lowest, `ngroups' = highest)") ///
	ytitle("Coefficient: stay in school (t+1)") ///
	title("Dose-response: retention by 4-day-week intensity") ///
	subtitle("Baseline specification, 95% CIs") ///
	legend(off) ///
	graphregion(color(white)) plotregion(color(white))
	
graph export "code/4DSW student teacher analysis/replication/output/figures/dose_response_stay_school_quartiles.png", replace width(1400) height(900)