/*
Description: Build teacher-year prepared file from cleaned Code/ outputs.
Run from project root.
Fail fast on missing required inputs.
*/

version 17

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"

* Teacher-year base from teacher_background.
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

* Entrant outcomes from teacher histories.
sort id2 syear
tsset id2 syear

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

tempfile teacher_panel
save "`teacher_panel'", replace

* District-year treatment timing from yearly_tracker_merge.
use "data/clean/yearly_tracker_merge.dta", clear

foreach v in district school_year firstyear ever4DSW post_adoption pct_four {
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
gen hybrid_calendar = (post_adoption == 1 & pct_four > 0 & pct_four < 1) if !missing(post_adoption) & !missing(pct_four)

collapse (firstnm) firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar, by(district syear)

tempfile calendar_panel
save "`calendar_panel'", replace

* Add rural indicator from district-level CCD file.
tempfile ccd_district_panel
use "data/raw/ccd_district.dta", clear

capture confirm variable StateAgencyID
if _rc {
    di as error "ccd_district must include StateAgencyID"
    exit 459
}

capture confirm variable year
if _rc {
    di as error "ccd_district must include year"
    exit 459
}

capture confirm variable District_Urbanicity
if _rc {
    di as error "ccd_district must include District_Urbanicity"
    exit 459
}

gen district = substr(StateAgencyID, 4, .)
keep district year District_Urbanicity
collapse (firstnm) District_Urbanicity, by(district year)
save "`ccd_district_panel'", replace

use "`calendar_panel'", clear
gen year = syear
merge 1:1 district year using "`ccd_district_panel'", keepusing(District_Urbanicity)
quietly count if _merge != 3
if r(N) > 0 {
    di as error "Rural merge to calendar panel is incomplete; unmatched district-year rows found"
    exit 459
}
gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
drop District_Urbanicity year
drop _merge
save "`calendar_panel'", replace

* Merge calendar/treatment into teacher-year panel.
use "`teacher_panel'", clear
merge m:1 district syear using "`calendar_panel'"
quietly count if _merge == 1
if r(N) > 0 {
    di as error "Teacher rows without matching district-year timing rows found"
    exit 459
}
drop if _merge == 2
drop _merge

tempfile panel_before_class
save "`panel_before_class'", replace

* Classroom controls from required VAM files.
local first_vam = 1
tempfile class_controls

forvalues i = 1/4 {
    use "data/clean/vam_data_idsgroup`i'.dta", clear

    gen class_frpl_share = classx_frl
    gen class_nonwhite_share = 1 - classx_white
    egen class_prior_ach = rowmean(classx_lag_r_ssc_std classx_lag_m_ssc_std)
    sort teachid syear section_id
    by teachid syear section_id: egen class_size = count(id1)

    keep teachid syear section_id class_size class_frpl_share class_nonwhite_share class_prior_ach
    drop if missing(teachid) | missing(syear)
    collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear)

    gen id2 = teachid
    drop teachid

    if `first_vam' {
        save "`class_controls'", replace
        local first_vam = 0
    }
    else {
        append using "`class_controls'"
        save "`class_controls'", replace
    }
}

use "`class_controls'", clear
collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(id2 syear)
tempfile class_controls_final
save "`class_controls_final'", replace

use "`panel_before_class'", clear
merge m:1 id2 syear using "`class_controls_final'"
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

foreach v in id2 syear district campus firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar rural female certified exper totalpay fte is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing final required variable `v'"
        exit 459
    }
}

sort id2 syear
save "replication/output/intermediate/teacher_year_analysis.dta", replace

* Build t+1 outcomes and final prepared dataset.
keep if inrange(syear, 2017, 2024)

isid id2 syear
sort id2 syear
tsset id2 syear

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

sort id2 syear
save "replication/output/intermediate/teacher_year_prepared.dta", replace
