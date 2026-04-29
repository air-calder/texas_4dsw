/*
Description: Build teacher-year prepared file from cleaned Code/ outputs.
Run from project root.
Fail fast on missing required inputs.
*/

version 17

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"

* ==================== Teacher Background ====================
use "data/clean/teacher_background.dta", clear

	* note: we need 2024 data for p_class_roster_staff_wntr to merge fully
	merge 1:1 teachid district syear using "data/clean/teacher_school_assign.dta", gen(_merge_sch) keep(match master)
	tab syear _merge_sch
	
	* fill in school for non-merges
	* if you are in the same district as the past or future, and we don't know which school you're at, assume you're in the same school
	tsset teachid syear
	destring campus, replace
	replace campus = L.campus if district == L.district & campus == .
	replace campus = L2.campus if district == L2.district & campus == .
	replace campus = L3.campus if district == L3.district & campus == .

	replace campus = F.campus if district == F.district & campus == .
	replace campus = F2.campus if district == F2.district & campus == .
	replace campus = F3.campus if district == F3.district & campus == .
	
	count if campus == . & syear >= 2017
	tab syear if campus == .


foreach v in teachid syear district campus exper fte totalpay first_cert_year sex degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in data/clean/teacher_background.dta" 
        exit 459
    }
}

quietly count if !missing(sex) & !inlist(upper(trim(sex)), "M", "F")
if r(N) > 0 {
    di as error "Variable sex contains values outside M/F"
    exit 459
}

gen female = (upper(trim(sex)) == "F") if !missing(sex)

gen certified = (syear >= first_cert_year) if !missing(syear) & !missing(first_cert_year)
replace certified = 0 if missing(certified) & !missing(syear)

drop if syear == .

tempfile teacher_panel
save "`teacher_panel'", replace

* ==================== Treatment Timing ====================
use "data/clean/yearly_tracker_merge.dta", clear

foreach v in district school_year firstyear ever4DSW post_adoption pct_four pct_lt4 Decision {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in data/clean/yearly_tracker_merge.dta"
        exit 459
    }
}

capture confirm numeric variable school_year
if _rc {
    capture noisily destring school_year, replace
    if _rc {
        di as error "school_year must be numeric or cleanly destringable in data/clean/yearly_tracker_merge.dta"
        exit 459
    }
}

gen syear = school_year
gen event_time = syear - firstyear if !missing(firstyear)
gen __decision = upper(trim(Decision))
quietly count if !missing(__decision) & !inlist(__decision, "4DSW", "?", "HYBRID")
if r(N) > 0 {
    di as error "Decision contains unsupported values (expected 4DSW, ?, or Hybrid)"
    exit 459
}
replace __decision = "4DSW" if __decision == "?"
gen hybrid_calendar = (__decision == "HYBRID") if !missing(__decision)
replace hybrid_calendar = 0 if __decision == "4DSW"
drop __decision

collapse (firstnm) firstyear ever4DSW post_adoption pct_four pct_lt4 event_time hybrid_calendar, by(district syear)

tempfile calendar_panel
save "`calendar_panel'", replace

* ==================== CCD Urbanicity ====================
tempfile ccd_district_panel
use "data/raw/ccd_district.dta", clear

gen district = substr(StateAgencyID, 4, .)
keep district year District_Urbanicity
collapse (firstnm) District_Urbanicity, by(district year)
save "`ccd_district_panel'", replace

use "`calendar_panel'", clear
gen year = syear
merge 1:1 district year using "`ccd_district_panel'", keepusing(District_Urbanicity)
quietly count
local total_ccd = r(N)
quietly count if _merge != 3
local unmatched_ccd = r(N)
if `unmatched_ccd' > 0 {
    local pct_ccd = string(100 * `unmatched_ccd' / `total_ccd', "%5.2f")
    di as text "WARNING: CCD urbanicity merge — `unmatched_ccd' of `total_ccd' rows unmatched (`pct_ccd'%)"
}
keep if _merge == 3
drop _merge
gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
drop District_Urbanicity year
destring district, replace
save "`calendar_panel'", replace

* ==================== Merge Teacher + Treatment ====================
use "`teacher_panel'", clear
merge m:1 district syear using "`calendar_panel'"
tab syear _merge, m
quietly count if syear >= 2017
local total_tch = r(N)
quietly count if _merge != 3 & syear >= 2017
local unmatched_tch = r(N)
if `unmatched_tch' > 0 {
    local pct_tch = string(100 * `unmatched_tch' / `total_tch', "%5.2f")
    di as text "NOTE: Teacher-calendar merge — `unmatched_tch' of `total_tch' rows unmatched (`pct_tch'%), dropping"
}
keep if _merge == 3
drop _merge

* ==================== Classroom Characteristics ====================
destring teacher_id1, replace
merge m:1 teacher_id1 syear using "code/4DSW student teacher analysis/replication/output/intermediate/classroom_controls_teacher_year.dta"
tab syear _merge	
drop if _merge == 2
drop _merge

foreach v in class_size class_frpl_share class_nonwhite_share class_prior_ach {
    capture confirm variable `v'
    if _rc {
        di as error "Missing classroom control `v' after VAM merge"
        exit 459
    }
    quietly count if !missing(`v')
    if r(N) == 0 {
        di as error "Classroom control `v' is all missing after VAM merge"
        exit 459
    }
}

foreach v in teachid syear district campus firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar rural female certified exper totalpay fte {
    capture confirm variable `v'
    if _rc {
        di as error "Missing final required variable `v'"
        exit 459
    }
}

isid teachid syear
sort teachid syear
tsset teachid syear

* ==================== Panel Construction ====================

* Entrant outcomes from full-panel histories.
destring degree, replace
gen is_entrant = (missing(L.syear) | district != L.district)
gen incoming_from_tx = (is_entrant == 1 & !missing(L.syear) & district != L.district)
gen incoming_first_time = (is_entrant == 1 & missing(L.syear))
gen incoming_experience = exper if is_entrant == 1
gen incoming_alt_path = max_cert_alt if is_entrant == 1
replace incoming_alt_path = 0 if is_entrant == 1 & missing(incoming_alt_path)
gen incoming_adv_degree = inlist(degree, 2, 3) if is_entrant == 1 & !missing(degree)
gen incoming_no_degree = (degree == 0) if is_entrant == 1 & !missing(degree)

quietly count if is_entrant == 1 & !missing(incoming_alt_path)
if r(N) == 0 {
    di as error "incoming_alt_path is missing for all entrant rows"
    exit 459
}
quietly count if is_entrant == 1 & !missing(incoming_adv_degree)
if r(N) == 0 {
    di as error "incoming_adv_degree is missing for all entrant rows"
    exit 459
}
quietly count if is_entrant == 1 & !missing(incoming_no_degree)
if r(N) == 0 {
    di as error "incoming_no_degree is missing for all entrant rows"
    exit 459
}

* Build t+1 outcomes on full panel.
quietly summarize syear, meanonly
local max_year = r(max)

gen observed_t1 = !missing(F.syear) if syear < `max_year'

gen stay_school_t1 = (observed_t1 == 1 & F.campus == campus) if syear < `max_year'
replace stay_school_t1 = 0 if syear < `max_year' & observed_t1 == 1 & F.campus != campus

gen stay_district_t1 = (observed_t1 == 1 & F.district == district) if syear < `max_year'
replace stay_district_t1 = 0 if syear < `max_year' & observed_t1 == 1 & F.district != district

gen switch_district_t1 = (observed_t1 == 1 & F.district != district) if syear < `max_year'
replace switch_district_t1 = 0 if syear < `max_year' & observed_t1 == 1 & F.district == district

gen exit_tx_public_t1 = (observed_t1 == 0) if syear < `max_year'
gen turnover_teacher_t1 = 1 - stay_school_t1 if !missing(stay_school_t1)
gen is_incumbent = !missing(stay_school_t1)

gen exp_le5 = (exper <= 5) if !missing(exper)
gen exp_gt5 = (exper > 5) if !missing(exper)
gen exp_gt9 = (exper > 9) if !missing(exper)

foreach v in is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree observed_t1 stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 turnover_teacher_t1 is_incumbent exp_le5 exp_gt5 exp_gt9 {
    capture confirm variable `v'
    if _rc {
        di as error "Missing generated variable `v'"
        exit 459
    }
}

sort teachid syear
save "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_analysis.dta", replace

* Final analysis window.
keep if inrange(syear, 2017, 2024)

sort teachid syear
save "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_prepared.dta", replace
