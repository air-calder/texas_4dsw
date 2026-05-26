/*
Description: Retention models by teacher value-added quartile.
Run from project root.
*/

version 17

local prepared_data "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
capture mkdir "code/4DSW student teacher analysis/replication/output/tables"

foreach v in teachid syear district campus is_incumbent post_adoption va_quartile stay_school_t1 stay_district_t1 {
	capture confirm variable `v'
	if _rc {
		di as error "Missing required variable `v' in `prepared_data'"
		exit 459
	}
}

foreach y in stay_school_t1 stay_district_t1 {
	quietly count if is_incumbent == 1 & !missing(`y') & !missing(va_quartile)
	if r(N) == 0 {
		di as error "Outcome `y' has no nonmissing values in VA quartile sample"
		exit 459
	}
}

local tcontrols "female certified exper totalpay fte"
local ccontrols "class_size class_frpl_share class_nonwhite_share class_prior_ach"

tempfile results 
tempname posth
postfile `posth' str30 spec str40 outcome int va_quartile double coef se pvalue long N using "`results'", replace

foreach y in stay_school_t1 stay_district_t1 {

	* Baseline - by quartile (separate regressions)
	forvalues q = 0/3 {
		quietly areg `y' post_adoption i.syear if is_incumbent == 1 & va_quartile == `q' & !missing(`y'), absorb(campus) vce(cluster district)
		local b = _b[post_adoption]
		local s = _se[post_adoption]
		local z = `b' / `s'
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("baseline") ("`y'") (`q') (`b') (`s') (`p') (`n')
	}

	* Full controls - by quartile 
	forvalues q = 0/3 {
		quietly areg `y' post_adoption i.syear if is_incumbent == 1 & va_quartile == `q' & !missing(`y'), absorb(campus) vce(cluster district)
		local b = _b[post_adoption]
		local s = _se[post_adoption]
		local z = `b' / `s'
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("full_controls") ("`y'") (`q') (`b') (`s') (`p') (`n')
	}
	
	* Interaction model: i.va_quartiles##i.post_adoption includes:
	* - post_adoption main effect (Q1 effect)
	* - va_quartile main effect (baseline retention differences)
	* - interaction (differential effects by teacher quality)
	quietly areg `y' i.va_quartile##i.post_adoption `tcontrols' `ccontrols' i.syear if is_incumbent == 1 & !missing(`y') & !missing(va_quartile), absorb(campus) vce(cluster district)
	
	* Main effect: post_adoption (Q0 = reference quartile effect)
	local b = _b[1.post_adoption]
	local s = _se[1.post_adoption]
	local z = `b' / `s'
	local p = 2 * normal(-abs(`z'))
	local n = e(N)
	post `posth' ("interaction") ("`y'") (1) (`b') (`s') (`p') (`n')
	
	* Main effect: va_quartile (baseline retention differences between quartiles)
	forvalues q = 1/3 {
		local b = _b[`q'.va_quartile]
		local s = _se[`q'.va_quartile]
		local z = `b' / `s'
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("interaction") ("`y'") (`q') (`b') (`s') (`p') (`n')
	}

	* Interaction: post_adoption x va_quartile (differential treatment effects)
	forvalues q = 1/3 {
		local b = _b[`q'.va_quartile#1.post_adoption]
		local s = _se[`q'.va_quartile#1.post_adoption]
		local z = `b' / `s'
		local p = 2 * normal(-abs(`z'))
		local n = e(N)
		post `posth' ("interaction") ("`y'") (`q') (`b') (`s') (`p') (`n')
	}
} 
postclose `posth'

use "`results'", clear 
sort outcome spec va_quartile 
export delimited using "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_by_va.csv", replace