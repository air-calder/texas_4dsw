/*
Description: decile-based dose-response analysis for teacher retention.
Run from project root. 
Uses post_adoption districts broken into deciles by (pct_lt4 + pct_four).
deciles computed at district-year level, not teacher-year level.
*/

version 17

local prepared_data "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
capture mkdir "code/4DSW student teacher analysis/replication/output/tables"

foreach v in teachid syear district campus is_incumbent post_adoption pct_lt4 pct_four female certified exper totalpay fte class_size class_frpl_share class_nonwhite_share class_prior_ach stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `v'
	if _rc {
	    di as error "Missing required variables `v' in `prepared_data'"
		exit 459
	}
}

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
	if r(N) == 0 {
	    di as error "Outcome `y' has no nonmissing values in incumbent sample"
		exit 459
	}
}

local tcontrols "female certified exper totalpay fte"
local ccontrols "class_size class_frpl_share class_nonwhite_share class_prior_ach"
local full_controls "`tcontrols' `ccontrols'"

* Compute pct_4day at district-year level
gen pct_4day = pct_lt4 + pct_four

* Collapse to district-year to compute deciles 
collapse (first) pct_4day post_adoption, by(district syear)
rename pct_4day pct_4day_dist

* Compute deciles cutoffs within each year for post_adoption districts
forvalues y = 2017/2024 {
    _pctile pct_4day_dist if post_adoption == 1 & syear == `y' & !missing(pct_4day_dist), p(10 20 30 40 50 60 70 80 90)
	local q10_`y' = r(r1)
	local q20_`y' = r(r2)
	local q30_`y' = r(r3)
	local q40_`y' = r(r4)
	local q50_`y' = r(r5)  
	local q60_`y' = r(r6) 
	local q70_`y' = r(r7) 
	local q80_`y' = r(r8) 
	local q90_`y' = r(r9) 
}
 
gen decile = 0 
forvalues y = 2017 / 2024 {
    replace decile = 1 if syear == `y' & post_adoption == 1 & pct_4day_dist <= `q10_`y''
	replace decile = 2 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q10_`y'' & pct_4day_dist <= `q20_`y''
	replace decile = 3 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q20_`y'' & pct_4day_dist <= `q30_`y''
	replace decile = 4 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q30_`y'' & pct_4day_dist <= `q40_`y''
	replace decile = 5 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q40_`y'' & pct_4day_dist <= `q50_`y''
	replace decile = 6 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q50_`y'' & pct_4day_dist <= `q60_`y''
	replace decile = 7 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q60_`y'' & pct_4day_dist <= `q70_`y''
	replace decile = 8 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q70_`y'' & pct_4day_dist <= `q80_`y''
	replace decile = 9 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q80_`y'' & pct_4day_dist <= `q90_`y''
	replace decile = 10 if syear == `y' & post_adoption == 1 & pct_4day_dist > `q90_`y'' 
}

keep district syear decile 
tempfile district_deciles
save "`district_deciles'"

* Merge back to teacher-year data
use "`prepared_data'", clear
merge m:1 district syear using "`district_deciles'"
drop if _merge == 2
drop _merge

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    noisily areg `y' i.decile i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
	forvalues q = 1/10 {
	    local b = _b[`q'.decile]
		local s = _se[`q'.decile]
		local z = `b' / `s' 
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("baseline_`q'") ("`y'") (`b') (`s') (`p') (`n')
	}
	
	noisily areg `y' i.decile `tcontrols' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
	forvalues q = 1/10 {
	    local b = _b[`q'.decile]
		local s = _se[`q'.decile]
		local z = `b' / `s' 
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("plus_teacher_ctrl_`q'") ("`y'") (`b') (`s') (`p') (`n')
	}
	
	noisily areg `y' i.decile `full_controls' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
	forvalues q = 1/4 {
	    local b = _b[`q'.decile]
		local s = _se[`q'.decile]
		local z = `b' / `s' 
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("plus_teacher_class_ctrl_`q'") ("`y'") (`b') (`s') (`p') (`n')
	}
}
postclose `posth'

use "`results'", clear
sort outcome spec
export delimited using "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_deciles.csv", replace