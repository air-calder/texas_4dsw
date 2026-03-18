/*
Description: Build teacher-year analysis file from cleaned Code/ outputs.
Run from project root.
Fail fast on missing required inputs.
*/

version 17

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"

* Teacher-year base from teacher_background.
use "data/clean/teacher_background.dta", clear

foreach v in id2 syear district campus exper fte salary first_cert_year sex {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in data/clean/teacher_background.dta"
        exit 459
    }
}

capture confirm numeric variable syear
if _rc {
    capture noisily destring syear, replace
    if _rc {
        di as error "Variable syear must be numeric or cleanly destringable in data/clean/teacher_background.dta"
        exit 459
    }
}

capture confirm numeric variable exper
if _rc {
    capture noisily destring exper, replace
    if _rc {
        di as error "Variable exper must be numeric or cleanly destringable in data/clean/teacher_background.dta"
        exit 459
    }
}

capture confirm numeric variable fte
if _rc {
    capture noisily destring fte, replace
    if _rc {
        di as error "Variable fte must be numeric or cleanly destringable in data/clean/teacher_background.dta"
        exit 459
    }
}

capture confirm numeric variable salary
if _rc {
    capture noisily destring salary, replace ignore(",$")
    if _rc {
        di as error "Variable salary must be numeric or cleanly destringable in data/clean/teacher_background.dta"
        exit 459
    }
}

capture confirm numeric variable first_cert_year
if _rc {
    capture noisily destring first_cert_year, replace
    if _rc {
        di as error "Variable first_cert_year must be numeric or cleanly destringable in data/clean/teacher_background.dta"
        exit 459
    }
}

capture confirm numeric variable sex
if _rc == 0 {
    gen female = (sex == 2) if !missing(sex)
}
else {
    gen female = (upper(trim(sex)) == "F") if !missing(sex)
}

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

gen incoming_adv_degree = .
gen incoming_no_degree = .

local adv_src ""
foreach v in adv_degree has_adv_degree advanced_degree graduate_degree masters doctorate phd {
    capture confirm variable `v'
    if _rc == 0 & "`adv_src'" == "" {
        local adv_src "`v'"
    }
}

local nodeg_src ""
foreach v in no_degree has_no_degree degree_none no_bachelor {
    capture confirm variable `v'
    if _rc == 0 & "`nodeg_src'" == "" {
        local nodeg_src "`v'"
    }
}

if "`adv_src'" != "" {
    replace incoming_adv_degree = `adv_src' if is_entrant == 1
}
if "`nodeg_src'" != "" {
    replace incoming_no_degree = `nodeg_src' if is_entrant == 1
}

quietly count if is_entrant == 1 & !missing(incoming_adv_degree)
local has_adv = (r(N) > 0)
quietly count if is_entrant == 1 & !missing(incoming_no_degree)
local has_nodeg = (r(N) > 0)

if !`has_adv' | !`has_nodeg' {
    local degree_text ""
    foreach v in degree highest_degree degree_level deg_level {
        capture confirm variable `v'
        if _rc == 0 & "`degree_text'" == "" {
            local degree_text "`v'"
        }
    }

    if "`degree_text'" == "" {
        di as error "Need degree information to build incoming_adv_degree and incoming_no_degree"
        exit 459
    }

    capture confirm string variable `degree_text'
    if _rc {
        di as error "Degree source variable `degree_text' must be string to parse advanced/no degree"
        exit 459
    }

    gen __deg_text = upper(trim(`degree_text'))
    if !`has_adv' {
        replace incoming_adv_degree = 1 if is_entrant == 1 & (strpos(__deg_text, "MASTER") > 0 | strpos(__deg_text, "DOCTOR") > 0 | strpos(__deg_text, "PHD") > 0 | strpos(__deg_text, "GRAD") > 0)
        replace incoming_adv_degree = 0 if is_entrant == 1 & __deg_text != "" & missing(incoming_adv_degree)
    }
    if !`has_nodeg' {
        replace incoming_no_degree = 1 if is_entrant == 1 & (strpos(__deg_text, "NO DEG") > 0 | strpos(__deg_text, "NONE") > 0 | strpos(__deg_text, "LESS") > 0)
        replace incoming_no_degree = 0 if is_entrant == 1 & __deg_text != "" & missing(incoming_no_degree)
    }
    drop __deg_text
}

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
use "data/clean/ccd_district_weighted.dta", clear

capture confirm variable district
if _rc {
    di as error "rural source must include district"
    exit 459
}

capture confirm variable school_year
if _rc {
    capture confirm variable year
    if _rc {
        di as error "rural source must include school_year or year"
        exit 459
    }
    gen school_year = year
}

capture confirm numeric variable school_year
if _rc {
    capture noisily destring school_year, replace
    if _rc {
        di as error "school_year in rural source must be numeric or cleanly destringable"
        exit 459
    }
}

capture confirm variable rural
if _rc {
    capture confirm variable District_Urbanicity
    if _rc {
        di as error "Need rural or District_Urbanicity in data/clean/ccd_district_weighted.dta"
        exit 459
    }
    gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
}

gen syear = school_year
keep district syear rural
collapse (firstnm) rural, by(district syear)

tempfile rural_panel
save "`rural_panel'", replace

use "`calendar_panel'", clear
merge 1:1 district syear using "`rural_panel'"
quietly count if _merge != 3
if r(N) > 0 {
    di as error "Rural merge to calendar panel is incomplete; unmatched district-year rows found"
    exit 459
}
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
    collapse (firstnm) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear section_id)
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

foreach v in id2 syear district campus firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar rural female certified exper salary fte is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing final required variable `v'"
        exit 459
    }
}

sort id2 syear
save "replication/output/intermediate/teacher_year_analysis.dta", replace
