/*
Description: Retention models by teacher value-added quartile.
Run from project root.
*/

version 17

local prepared_data "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
tab post_adoption, m
	//   (firstnm) |
	// post_adopti |
	//          on |      Freq.     Percent        Cum.
	// ------------+-----------------------------------
	//           0 |  3,009,120       99.36       99.36
	//           1 |     19,342        0.64      100.00
	// ------------+-----------------------------------
	//       Total |  3,028,462      100.00
tab ever4DSW, m
	//   (firstnm) |
	//    ever4DSW |      Freq.     Percent        Cum.
	// ------------+-----------------------------------
	//           0 |  2,929,779       96.74       96.74
	//           1 |     98,683        3.26      100.00
	// ------------+-----------------------------------
	//       Total |  3,028,462      100.00
capture mkdir "code/4DSW student teacher analysis/replication/output/tables"

foreach v in teachid syear district campus is_incumbent post_adoption ever4DSW va_quartile stay_school_t1 stay_district_t1 {
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
* ================ Descriptive: retention by VA quartile x period ==============
capture mkdir "code/4DSW student teacher analysis/replication/output/descriptives"

preserve
keep if is_incumbent == 1 & !missing(stay_school_t1) & !missing(va_quartile)

* Three-way period classification
gen period = .
replace period = 0 if ever4DSW == 0
replace period = 1 if ever4DSW == 1 & post_adoption == 0
replace period = 2 if ever4DSW == 1 & post_adoption == 1
label define period_lbl 0 "Never-treated" 1 "Ever-treated, pre-adoption" 2 "Ever-treated, post-adoption"
label values period period_lbl
tab period, m
	//                      period |      Freq.     Percent        Cum.
	// ----------------------------+-----------------------------------
	//               Never-treated |    448,218       96.72       96.72
	//  Ever-treated, pre-adoption |     14,015        3.02       99.75
	// Ever-treated, post-adoption |      1,175        0.25      100.00
	// ----------------------------+-----------------------------------
	//                       Total |    463,408      100.00
tab post_adoption, m
	//   (firstnm) |
	// post_adopti |
	//          on |      Freq.     Percent        Cum.
	// ------------+-----------------------------------
	//           0 |    462,233       99.75       99.75
	//           1 |      1,175        0.25      100.00
	// ------------+-----------------------------------
	//       Total |    463,408      100.00

collapse (mean) mean_stay_school_t1 = stay_school_t1 ///
	(count) n = stay_school_t1, ///
	by(period va_quartile)
	
sort period va_quartile
export delimited using "code/4DSW student teacher analysis/replication/output/descriptives/retention_by_va_pre_post.csv", replace 
restore 

* ==============================================================================

local tcontrols "female certified exper totalpay fte"
local ccontrols "class_size class_frpl_share class_nonwhite_share class_prior_ach"

tempfile results 
tempname posth
postfile `posth' str30 spec str40 outcome int va_quartile double coef se pvalue long N using "`results'", replace

foreach y in stay_school_t1 stay_district_t1 {

// 	* Baseline - by quartile (separate regressions)
// 	forvalues q = 0/3 {
// 		quietly areg `y' post_adoption i.syear if is_incumbent == 1 & va_quartile == `q' & !missing(`y'), absorb(campus) vce(cluster district)
// 		local b = _b[post_adoption]
// 		local s = _se[post_adoption]
// 		local z = `b' / `s'
// 		local p = 2 * normal(-abs(`z'))
// 		local n = e(N)
// 		post `posth' ("baseline") ("`y'") (`q') (`b') (`s') (`p') (`n')
// 	}
//
// 	* Full controls - by quartile 
// 	forvalues q = 0/3 {
// 		quietly areg `y' post_adoption i.syear if is_incumbent == 1 & va_quartile == `q' & !missing(`y'), absorb(campus) vce(cluster district)
// 		local b = _b[post_adoption]
// 		local s = _se[post_adoption]
// 		local z = `b' / `s'
// 		local p = 2 * normal(-abs(`z'))
// 		local n = e(N)
// 		post `posth' ("full_controls") ("`y'") (`q') (`b') (`s') (`p') (`n')
// 	}
	
	* Interaction model: i.va_quartiles##i.post_adoption includes:
	* - post_adoption main effect (Q1 effect)
	* - va_quartile main effect (baseline retention differences)
	* - interaction (differential effects by teacher quality)
	quietly areg `y' i.va_quartile##i.post_adoption `tcontrols' i.syear if is_incumbent == 1 & !missing(`y') & !missing(va_quartile), absorb(campus) vce(cluster district)
	
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
		post `posth' ("main effect") ("`y'") (`q') (`b') (`s') (`p') (`n')
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