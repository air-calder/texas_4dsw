/*
Description: Build teacher-year analysis file from cleaned Code/ outputs.
Run from project root.
Fail fast on missing required inputs.
*/

version 17

local clean_dir "data/clean"
local teacher_file "`clean_dir'/teacher_background.dta"
local calendar_file "`clean_dir'/yearly_tracker_merge.dta"
local rural_file "`clean_dir'/ccd_district_weighted.dta"
local analysis_data "replication/output/intermediate/teacher_year_analysis.dta"

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"

capture confirm file "`teacher_file'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`teacher_file'" "missing_clean_teacher_file"
    di as error "Missing cleaned teacher file: `teacher_file'"
    exit 601
}

capture confirm file "`calendar_file'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`calendar_file'" "missing_clean_calendar_file"
    di as error "Missing cleaned calendar file: `calendar_file'"
    exit 601
}

capture confirm file "`rural_file'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "`rural_file'" "missing_rural_source_file"
    di as error "Missing rural source file: `rural_file'"
    exit 601
}

forvalues i = 1/4 {
    local vam_file "`clean_dir'/vam_data_idsgroup`i'.dta"
    capture confirm file "`vam_file'"
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`vam_file'" "missing_vam_file"
        di as error "Missing VAM input file: `vam_file'"
        exit 601
    }
}

* Teacher-year base from teacher_background.
use "`teacher_file'", clear

foreach v in id2 syear district campus exper fte salary {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`v'" "missing_required_variable_in_teacher_file"
        di as error "Missing required variable `v' in `teacher_file'"
        exit 459
    }
}

capture confirm numeric variable syear
if _rc {
    capture noisily destring syear, replace
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "syear" "syear_not_numeric"
        di as error "Variable syear must be numeric or cleanly destringable in `teacher_file'"
        exit 459
    }
}

capture confirm numeric variable exper
if _rc {
    capture noisily destring exper, replace
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "exper" "exper_not_numeric"
        di as error "Variable exper must be numeric or cleanly destringable in `teacher_file'"
        exit 459
    }
}

capture confirm numeric variable fte
if _rc {
    capture noisily destring fte, replace
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "fte" "fte_not_numeric"
        di as error "Variable fte must be numeric or cleanly destringable in `teacher_file'"
        exit 459
    }
}

capture confirm numeric variable salary
if _rc {
    capture noisily destring salary, replace ignore(",$")
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "salary" "salary_not_numeric"
        di as error "Variable salary must be numeric or cleanly destringable in `teacher_file'"
        exit 459
    }
}

capture confirm variable female
if _rc {
    capture confirm variable sex
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "female/sex" "missing_gender_source"
        di as error "Need female or sex in `teacher_file'"
        exit 459
    }

    capture confirm numeric variable sex
    if _rc == 0 {
        gen female = (sex == 2) if !missing(sex)
    }
    else {
        gen female = (upper(trim(sex)) == "F") if !missing(sex)
    }
}

capture confirm variable certified
if _rc {
    capture confirm variable ever_cert
    if _rc == 0 {
        gen certified = ever_cert
    }
    else {
        foreach v in tier1 tier2 tier3 {
            capture confirm variable `v'
            if _rc {
                do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "tier1/tier2/tier3" "missing_certification_source"
                di as error "Need certified or ever_cert or tier1/tier2/tier3 in `teacher_file'"
                exit 459
            }
        }
        gen certified = (tier1 == 1 | tier2 == 1 | tier3 == 1) if !missing(tier1) | !missing(tier2) | !missing(tier3)
    }
}

sort id2 syear
drop if missing(id2) | missing(syear)
gsort id2 syear -fte
by id2 syear: keep if _n == 1

* Entrant outcomes from teacher histories.
sort id2 syear
by id2: gen __prev_year = syear[_n-1]
by id2: gen __prev_dist = district[_n-1]

gen is_entrant = (missing(__prev_year) | syear > (__prev_year + 1) | district != __prev_dist)
gen incoming_from_tx = (is_entrant == 1 & !missing(__prev_year) & district != __prev_dist)
gen incoming_first_time = (is_entrant == 1 & missing(__prev_year))
gen incoming_experience = exper if is_entrant == 1

capture confirm variable incoming_alt_path
if _rc {
    capture confirm variable cert_alt
    if _rc == 0 {
        gen incoming_alt_path = cert_alt if is_entrant == 1
    }
    else {
        capture confirm variable tier2
        if _rc == 0 {
            gen incoming_alt_path = tier2 if is_entrant == 1
        }
        else {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_alt_path" "missing_alt_certification_proxy"
            di as error "Need incoming_alt_path, cert_alt, or tier2 in `teacher_file'"
            exit 459
        }
    }
}

capture confirm variable incoming_adv_degree
local have_adv = (_rc == 0)
capture confirm variable incoming_no_degree
local have_nodeg = (_rc == 0)

if !`have_adv' | !`have_nodeg' {
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

    if !`have_adv' & "`adv_src'" != "" {
        gen incoming_adv_degree = `adv_src' if is_entrant == 1
        local have_adv = 1
    }
    if !`have_nodeg' & "`nodeg_src'" != "" {
        gen incoming_no_degree = `nodeg_src' if is_entrant == 1
        local have_nodeg = 1
    }

    if !`have_adv' | !`have_nodeg' {
        local degree_text ""
        foreach v in degree highest_degree degree_level deg_level {
            capture confirm variable `v'
            if _rc == 0 & "`degree_text'" == "" {
                local degree_text "`v'"
            }
        }

        if "`degree_text'" == "" {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_adv_degree/incoming_no_degree" "missing_degree_information"
            di as error "Need degree information to build incoming_adv_degree and incoming_no_degree"
            exit 459
        }

        capture confirm string variable `degree_text'
        if _rc {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "`degree_text'" "degree_variable_not_string"
            di as error "Degree source variable `degree_text' must be string to parse advanced/no degree"
            exit 459
        }

        gen __deg_text = upper(trim(`degree_text'))
        if !`have_adv' {
            gen incoming_adv_degree = 1 if is_entrant == 1 & (strpos(__deg_text, "MASTER") > 0 | strpos(__deg_text, "DOCTOR") > 0 | strpos(__deg_text, "PHD") > 0 | strpos(__deg_text, "GRAD") > 0)
            replace incoming_adv_degree = 0 if is_entrant == 1 & __deg_text != "" & missing(incoming_adv_degree)
            local have_adv = 1
        }
        if !`have_nodeg' {
            gen incoming_no_degree = 1 if is_entrant == 1 & (strpos(__deg_text, "NO DEG") > 0 | strpos(__deg_text, "NONE") > 0 | strpos(__deg_text, "LESS") > 0)
            replace incoming_no_degree = 0 if is_entrant == 1 & __deg_text != "" & missing(incoming_no_degree)
            local have_nodeg = 1
        }
        drop __deg_text
    }
}

quietly count if is_entrant == 1 & !missing(incoming_alt_path)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_alt_path" "entrant_outcome_all_missing"
    di as error "incoming_alt_path is missing for all entrant rows"
    exit 459
}
quietly count if is_entrant == 1 & !missing(incoming_adv_degree)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_adv_degree" "entrant_outcome_all_missing"
    di as error "incoming_adv_degree is missing for all entrant rows"
    exit 459
}
quietly count if is_entrant == 1 & !missing(incoming_no_degree)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_no_degree" "entrant_outcome_all_missing"
    di as error "incoming_no_degree is missing for all entrant rows"
    exit 459
}

drop __prev_year __prev_dist

tempfile teacher_panel
save "`teacher_panel'", replace

* District-year treatment timing from yearly_tracker_merge.
use "`calendar_file'", clear

foreach v in district school_year firstyear ever4DSW post_adoption pct_four {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`v'" "missing_required_variable_in_calendar_file"
        di as error "Missing required variable `v' in `calendar_file'"
        exit 459
    }
}

capture confirm numeric variable school_year
if _rc {
    capture noisily destring school_year, replace
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "school_year" "school_year_not_numeric"
        di as error "school_year must be numeric or cleanly destringable in `calendar_file'"
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
use "`rural_file'", clear

capture confirm variable district
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "district" "missing_district_in_rural_file"
    di as error "rural source must include district"
    exit 459
}

capture confirm variable school_year
if _rc {
    capture confirm variable year
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "school_year/year" "missing_year_in_rural_file"
        di as error "rural source must include school_year or year"
        exit 459
    }
    gen school_year = year
}

capture confirm numeric variable school_year
if _rc {
    capture noisily destring school_year, replace
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "school_year" "school_year_not_numeric_in_rural_file"
        di as error "school_year in rural source must be numeric or cleanly destringable"
        exit 459
    }
}

capture confirm variable rural
if _rc {
    capture confirm variable District_Urbanicity
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural/District_Urbanicity" "missing_rural_indicator_source"
        di as error "Need rural or District_Urbanicity in `rural_file'"
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
    do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural" "incomplete_rural_merge"
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
    do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "calendar merge" "teacher_rows_missing_calendar_match"
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
    local vam_file "`clean_dir'/vam_data_idsgroup`i'.dta"
    use "`vam_file'", clear

    foreach v in teachid syear {
        capture confirm variable `v'
        if _rc {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`v'" "missing_required_variable_in_vam_file"
            di as error "Missing `v' in `vam_file'"
            exit 459
        }
    }

    capture confirm variable section_id
    if _rc {
        capture confirm variable class_id
        if _rc {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "section_id/class_id" "missing_section_identifier_in_vam_file"
            di as error "Need section_id or class_id in `vam_file'"
            exit 459
        }
        gen section_id = class_id
    }

    capture confirm variable class_frpl_share
    if _rc {
        capture confirm variable classx_frl
        if _rc {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "class_frpl_share/classx_frl" "missing_frpl_source_in_vam_file"
            di as error "Need class_frpl_share or classx_frl in `vam_file'"
            exit 459
        }
        gen class_frpl_share = classx_frl
    }

    capture confirm variable class_nonwhite_share
    if _rc {
        capture confirm variable classx_white
        if _rc == 0 {
            gen class_nonwhite_share = 1 - classx_white
        }
        else {
            foreach v in classx_black classx_hispanic classx_asian classx_other {
                capture confirm variable `v'
                if _rc {
                    do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "class_nonwhite_share" "missing_race_shares_in_vam_file"
                    di as error "Need class_nonwhite_share or race-share variables in `vam_file'"
                    exit 459
                }
            }
            gen class_nonwhite_share = classx_black + classx_hispanic + classx_asian + classx_other
        }
    }

    capture confirm variable class_prior_ach
    if _rc {
        capture confirm variable classx_lag_r_ssc_std
        local has_r = (_rc == 0)
        capture confirm variable classx_lag_m_ssc_std
        local has_m = (_rc == 0)

        if !`has_r' & !`has_m' {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "class_prior_ach" "missing_lag_achievement_source_in_vam_file"
            di as error "Need class_prior_ach or lag achievement variables in `vam_file'"
            exit 459
        }

        if `has_r' & `has_m' {
            egen class_prior_ach = rowmean(classx_lag_r_ssc_std classx_lag_m_ssc_std)
        }
        else if `has_r' {
            gen class_prior_ach = classx_lag_r_ssc_std
        }
        else {
            gen class_prior_ach = classx_lag_m_ssc_std
        }
    }

    capture confirm variable class_size
    if _rc {
        capture confirm variable num_students
        if _rc == 0 {
            gen class_size = num_students
        }
        else {
            capture confirm variable id1
            if _rc {
                do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "class_size" "missing_class_size_source_in_vam_file"
                di as error "Need class_size, num_students, or id1 with section_id in `vam_file'"
                exit 459
            }
            by teachid syear section_id: gen __n_students = _N
            gen class_size = __n_students
            drop __n_students
        }
    }

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
        do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`v'" "failed_to_construct_classroom_control"
        di as error "Missing classroom control `v' after VAM merge"
        exit 459
    }
    quietly count if !missing(`v')
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`v'" "classroom_control_all_missing"
        di as error "Classroom control `v' is all missing after VAM merge"
        exit 459
    }
}

foreach v in id2 syear district campus firstyear ever4DSW post_adoption pct_four event_time hybrid_calendar rural female certified exper salary fte is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`v'" "missing_final_required_variable"
        di as error "Missing final required variable `v'"
        exit 459
    }
}

sort id2 syear
save "`analysis_data'", replace
