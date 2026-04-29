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

foreach v in id2 syear district campus exper fte totalpay first_cert_year sex degree {
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

tempfile teacher_panel
save "`teacher_panel'", replace

* ==================== Treatment Timing ====================
use "data/clean/yearly_tracker_merge.dta", clear

foreach v in district school_year firstyear ever4DSW post_adoption pct_four Decision {
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

collapse (firstnm) firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar, by(district syear)

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
save "`calendar_panel'", replace

* ==================== Merge Teacher + Treatment ====================
use "`teacher_panel'", clear
merge m:1 district syear using "`calendar_panel'"
quietly count
local total_tch = r(N)
quietly count if _merge != 3
local unmatched_tch = r(N)
if `unmatched_tch' > 0 {
    local pct_tch = string(100 * `unmatched_tch' / `total_tch', "%5.2f")
    di as text "WARNING: Teacher-calendar merge — `unmatched_tch' of `total_tch' rows unmatched (`pct_tch'%), dropping"
}
keep if _merge == 3
drop _merge

* ==================== Classroom Characteristics ====================
merge 1:1 id2 syear using "replication/output/intermediate/classroom_controls_teacher_year.dta"
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

foreach v in id2 syear district campus firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar rural female certified exper totalpay fte {
    capture confirm variable `v'
    if _rc {
        di as error "Missing final required variable `v'"
        exit 459
    }
}

isid id2 syear
sort id2 syear
tsset id2 syear

* ==================== Panel Construction ====================

* Entrant outcomes from full-panel histories.
gen is_entrant = (missing(L.syear) | district != L.district)
gen incoming_from_tx = (is_entrant == 1 & !missing(L.syear) & district != L.district)
gen incoming_first_time = (is_entrant == 1 & missing(L.syear))
gen incoming_experience = exper if is_entrant == 1
gen incoming_alt_path = cert_alt if is_entrant == 1
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

sort id2 syear
save "replication/output/intermediate/teacher_year_analysis.dta", replace

* Final analysis window.
keep if inrange(syear, 2017, 2024)

sort id2 syear
save "replication/output/intermediate/teacher_year_prepared.dta", replace
