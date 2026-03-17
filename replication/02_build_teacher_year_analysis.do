/*
Description: Build teacher-year analysis file from cleaned Code/ outputs.
Run from project root.
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

* Teacher-year base from teacher_background.
use "`teacher_file'", clear

foreach v in id2 syear district campus {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`v'" "missing_required_variable_in_teacher_file"
        di as error "Missing required variable `v' in `teacher_file'"
        exit 459
    }
}

foreach v in id2 syear district campus exper fte tier1 tier2 tier3 cert_alt {
    capture confirm variable `v'
    if _rc == 0 {
        capture destring `v', replace force
    }
}

capture confirm numeric variable id2
if _rc {
    egen __id2 = group(id2) if !missing(id2)
    drop id2
    gen id2 = __id2
    drop __id2
}

capture confirm numeric variable district
if _rc {
    egen __district = group(district) if !missing(district)
    drop district
    gen district = __district
    drop __district
}

capture confirm numeric variable campus
if _rc {
    egen __campus = group(campus) if !missing(campus)
    drop campus
    gen campus = __campus
    drop __campus
}

capture confirm numeric variable syear
if _rc {
    capture destring syear, replace force
}

drop if missing(id2) | missing(syear)

capture confirm variable fte
if _rc == 0 {
    gsort id2 syear -fte
}
else {
    sort id2 syear
}
by id2 syear: keep if _n == 1

* Entrant outcomes from teacher histories.
sort id2 syear
by id2: gen __prev_year = syear[_n-1]
by id2: gen __prev_dist = district[_n-1]

capture drop is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree

gen is_entrant = (missing(__prev_year) | syear > (__prev_year + 1) | district != __prev_dist)
gen incoming_from_tx = (is_entrant == 1 & !missing(__prev_year) & district != __prev_dist)
gen incoming_first_time = (is_entrant == 1 & missing(__prev_year))
gen incoming_experience = exper if is_entrant == 1

gen incoming_alt_path = .
local alt_proxy_found = 0
capture confirm variable cert_alt
if _rc == 0 {
    replace incoming_alt_path = cert_alt if is_entrant == 1
    local alt_proxy_found = 1
}
if `alt_proxy_found' == 0 {
    capture confirm variable tier2
    if _rc == 0 {
        replace incoming_alt_path = tier2 if is_entrant == 1
        local alt_proxy_found = 1
    }
}
if `alt_proxy_found' == 1 {
    replace incoming_alt_path = 0 if is_entrant == 1 & missing(incoming_alt_path)
}
else {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_alt_path" "missing_alt_certification_proxy"
}

gen incoming_adv_degree = .
gen incoming_no_degree = .

local degree_text ""
foreach v in degree highest_degree degree_level deg_level {
    capture confirm variable `v'
    if _rc == 0 & "`degree_text'" == "" {
        local degree_text "`v'"
    }
}

if "`degree_text'" != "" {
    capture confirm string variable `degree_text'
    if _rc == 0 {
        gen __deg_text = upper(trim(`degree_text'))
        replace incoming_adv_degree = 1 if is_entrant == 1 & (strpos(__deg_text, "MASTER") > 0 | strpos(__deg_text, "DOCTOR") > 0 | strpos(__deg_text, "PHD") > 0 | strpos(__deg_text, "GRAD") > 0)
        replace incoming_adv_degree = 0 if is_entrant == 1 & __deg_text != "" & missing(incoming_adv_degree)
        replace incoming_no_degree = 1 if is_entrant == 1 & (strpos(__deg_text, "NO DEG") > 0 | strpos(__deg_text, "NONE") > 0 | strpos(__deg_text, "LESS") > 0)
        replace incoming_no_degree = 0 if is_entrant == 1 & __deg_text != "" & missing(incoming_no_degree)
        drop __deg_text
    }
}

quietly count if is_entrant == 1 & !missing(incoming_adv_degree)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_adv_degree" "missing_degree_information"
}
quietly count if is_entrant == 1 & !missing(incoming_no_degree)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_no_degree" "missing_degree_information"
}

drop __prev_year __prev_dist

tempfile teacher_panel
save "`teacher_panel'", replace

* District-year treatment timing from yearly_tracker_merge.
use "`calendar_file'", clear

foreach v in district school_year {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`v'" "missing_required_variable_in_calendar_file"
        di as error "Missing required variable `v' in `calendar_file'"
        exit 459
    }
}

foreach v in district school_year firstyear ever4DSW post_adoption pct_four AgencyNCES {
    capture confirm variable `v'
    if _rc == 0 {
        capture destring `v', replace force
    }
}

capture confirm numeric variable district
if _rc {
    egen __district = group(district) if !missing(district)
    drop district
    gen district = __district
    drop __district
}

gen syear = school_year

local keep_vars "district syear"
foreach v in firstyear ever4DSW post_adoption pct_four AgencyNCES {
    capture confirm variable `v'
    if _rc == 0 {
        local keep_vars "`keep_vars' `v'"
    }
}
keep `keep_vars'

local collapse_vars ""
foreach v in firstyear ever4DSW post_adoption pct_four AgencyNCES {
    capture confirm variable `v'
    if _rc == 0 {
        local collapse_vars "`collapse_vars' (firstnm) `v'"
    }
}
if "`collapse_vars'" == "" {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "firstyear/ever4DSW/post_adoption" "missing_timing_variables_in_calendar_file"
    di as error "No treatment timing variables found in `calendar_file'"
    exit 459
}
collapse `collapse_vars', by(district syear)

capture confirm variable event_time
if _rc {
    gen event_time = syear - firstyear if !missing(firstyear)
}
capture confirm variable hybrid_calendar
if _rc {
    capture confirm variable pct_four
    if _rc == 0 {
        gen hybrid_calendar = (post_adoption == 1 & pct_four > 0 & pct_four < 1) if !missing(post_adoption) & !missing(pct_four)
    }
}

tempfile calendar_panel
save "`calendar_panel'", replace

* Add rural indicator from district-level CCD merge if available.
capture confirm file "`rural_file'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "`rural_file'" "missing_rural_source_file"
}
else {
    use "`rural_file'", clear

    capture confirm variable district
    if _rc {
        capture confirm variable AgencyNCES
    }

    capture confirm variable school_year
    if _rc {
        capture confirm variable year
        if _rc == 0 {
            gen school_year = year
        }
    }

    capture confirm variable rural
    if _rc {
        capture confirm variable District_Urbanicity
        if _rc == 0 {
            gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
        }
    }

    capture confirm variable rural
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural" "missing_rural_variable"
    }
    else {
        capture confirm variable district
        if _rc == 0 {
            capture destring district, replace force
            capture confirm numeric variable district
            if _rc {
                egen __district = group(district) if !missing(district)
                drop district
                gen district = __district
                drop __district
            }
            capture destring school_year, replace force
            gen syear = school_year
            keep district syear rural
            collapse (firstnm) rural, by(district syear)
            tempfile rural_panel
            save "`rural_panel'", replace

            use "`calendar_panel'", clear
            merge 1:1 district syear using "`rural_panel'"
            drop if _merge == 2
            drop _merge
            save "`calendar_panel'", replace
        }
        else {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural" "missing_district_key_for_rural_merge"
        }
    }
}

* Merge calendar treatment/timing into teacher-year panel.
use "`teacher_panel'", clear
merge m:1 district syear using "`calendar_panel'"
drop if _merge == 2
drop _merge

tempfile panel_before_class
save "`panel_before_class'", replace

* Classroom controls from VAM files.
tempfile class_controls
clear
set obs 0
gen id2 = .
gen syear = .
gen class_size = .
gen class_frpl_share = .
gen class_nonwhite_share = .
gen class_prior_ach = .
save "`class_controls'", replace

local vam_found = 0
forvalues i = 1/4 {
    local vam_file "`clean_dir'/vam_data_idsgroup`i'.dta"
    capture confirm file "`vam_file'"
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`vam_file'" "missing_vam_file"
    }
    else {
        local vam_found = 1
        use "`vam_file'", clear

        capture confirm variable teachid
        local has_teachid = (_rc == 0)
        capture confirm variable syear
        local has_syear = (_rc == 0)
        if !`has_teachid' | !`has_syear' {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`vam_file'" "missing_teachid_or_syear"
            continue
        }

        capture destring teachid, replace force
        capture confirm numeric variable teachid
        if _rc {
            egen __teachid = group(teachid) if !missing(teachid)
            drop teachid
            gen teachid = __teachid
            drop __teachid
        }
        capture destring syear, replace force

        capture confirm variable class_frpl_share
        if _rc {
            capture confirm variable classx_frl
            if _rc == 0 {
                gen class_frpl_share = classx_frl
            }
        }

        capture confirm variable class_nonwhite_share
        if _rc {
            capture confirm variable classx_white
            if _rc == 0 {
                gen class_nonwhite_share = 1 - classx_white
            }
            else {
                capture confirm variable classx_black
                if _rc == 0 {
                    gen class_nonwhite_share = classx_black
                    foreach v in classx_hispanic classx_asian classx_other {
                        capture confirm variable `v'
                        if _rc == 0 {
                            replace class_nonwhite_share = class_nonwhite_share + `v'
                        }
                    }
                }
            }
        }

        capture confirm variable class_prior_ach
        if _rc {
            local prior_list ""
            foreach v in classx_lag_r_ssc_std classx_lag_m_ssc_std {
                capture confirm variable `v'
                if _rc == 0 {
                    local prior_list "`prior_list' `v'"
                }
            }
            if "`prior_list'" != "" {
                egen class_prior_ach = rowmean(`prior_list')
            }
        }

        capture confirm variable section_id
        if _rc {
            capture confirm variable class_id
            if _rc == 0 {
                gen section_id = class_id
            }
            else {
                gen section_id = .
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
                local has_id1 = (_rc == 0)
                capture confirm variable section_id
                local has_section = (_rc == 0)
                if `has_id1' & `has_section' {
                    by teachid syear section_id: gen __n_students = _N
                    gen class_size = __n_students
                    drop __n_students
                }
            }
        }

        foreach v in class_size class_frpl_share class_nonwhite_share class_prior_ach {
            capture confirm variable `v'
            if _rc {
                gen `v' = .
            }
        }

        keep teachid syear section_id class_size class_frpl_share class_nonwhite_share class_prior_ach
        drop if missing(teachid) | missing(syear)
        collapse (firstnm) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear section_id)
        collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear)

        gen id2 = teachid
        drop teachid

        append using "`class_controls'"
        save "`class_controls'", replace
    }
}

if `vam_found' == 1 {
    use "`class_controls'", clear
    collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(id2 syear)
    tempfile class_controls_final
    save "`class_controls_final'", replace

    use "`panel_before_class'", clear
    merge m:1 id2 syear using "`class_controls_final'"
    drop if _merge == 2
    drop _merge
}
else {
    use "`panel_before_class'", clear
    do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "class_size class_frpl_share class_nonwhite_share class_prior_ach" "all_vam_files_missing"
}

capture confirm variable ever4DSW
if _rc {
    gen ever4DSW = !missing(firstyear)
}
capture confirm variable post_adoption
if _rc {
    gen post_adoption = (syear >= firstyear) if !missing(firstyear)
    replace post_adoption = 0 if missing(post_adoption)
}
capture confirm variable event_time
if _rc {
    gen event_time = syear - firstyear if !missing(firstyear)
}

sort id2 syear
save "`analysis_data'", replace
