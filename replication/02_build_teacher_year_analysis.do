/*
Description: Build teacher-year analysis file from cleaned Code/ outputs.
Inputs:
  - ${clean_teacher_file} (teacher_background.dta)
  - ${clean_calendar_file} (yearly_tracker_merge.dta)
  - ${clean_vam_prefix}1-4.dta (optional; classroom controls)
  - ${clean_rural_file} (optional; rural flag)
Output:
  - ${analysis_data}
*/

version 17

capture confirm file "${clean_teacher_file}"
if _rc {
    do "replication/01_config.do"
}

capture mkdir "${rep_output}"
capture mkdir "${rep_output}/intermediate"
capture mkdir "${rep_output}/checks"

capture confirm file "${clean_teacher_file}"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "${clean_teacher_file}" "missing_clean_teacher_file"
    di as error "Missing cleaned teacher file: ${clean_teacher_file}"
    exit 601
}

capture confirm file "${clean_calendar_file}"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "${clean_calendar_file}" "missing_clean_calendar_file"
    di as error "Missing cleaned calendar file: ${clean_calendar_file}"
    exit 601
}

* Build teacher-year base panel.
use "${clean_teacher_file}", clear

capture confirm variable teacher_id
if _rc {
    capture confirm variable id2
    if _rc == 0 {
        rename id2 teacher_id
    }
}

capture confirm variable school_year
if _rc {
    capture confirm variable syear
    if _rc == 0 {
        rename syear school_year
    }
}

capture confirm variable school_id
if _rc {
    capture confirm variable campus
    if _rc == 0 {
        rename campus school_id
    }
}

capture confirm variable district_id
if _rc {
    capture confirm variable district
    if _rc == 0 {
        rename district district_id
    }
}

capture confirm variable experience
if _rc {
    capture confirm variable exper
    if _rc == 0 {
        rename exper experience
    }
}

capture confirm variable female
if _rc {
    capture confirm variable sex
    if _rc == 0 {
        gen female = .
        capture confirm numeric variable sex
        if _rc == 0 {
            replace female = (sex == 2) if !missing(sex)
        }
        else {
            replace female = (upper(trim(sex)) == "F") if !missing(sex)
        }
    }
}

capture confirm variable certified
if _rc {
    capture confirm variable ever_cert
    if _rc == 0 {
        gen certified = ever_cert
    }
    else {
        local have_tier = 0
        foreach t in tier1 tier2 tier3 cert_tier1 cert_tier2 cert_tier3 {
            capture confirm variable `t'
            if _rc == 0 {
                local have_tier = 1
                capture confirm variable certified
                if _rc {
                    gen certified = .
                }
                replace certified = 1 if `t' == 1
            }
        }
        if `have_tier' == 1 {
            replace certified = 0 if missing(certified)
        }
    }
}

capture confirm variable matched_sample
if _rc {
    gen matched_sample = 1
}

* Ensure required keys exist.
foreach v in teacher_id school_year school_id district_id {
    capture confirm variable `v'
    if _rc {
        gen `v' = .
        do "replication/utils/record_unavailable_analysis.do" "02_build" "analysis_panel_build" "`v'" "missing_required_variable_in_teacher_file"
    }
}

* Numeric conversion for keys used in sorting/estimation.
foreach v in teacher_id school_id district_id {
    capture confirm numeric variable `v'
    if _rc {
        capture destring `v', replace force
        capture confirm numeric variable `v'
        if _rc {
            egen __`v' = group(`v') if !missing(`v')
            drop `v'
            rename __`v' `v'
        }
    }
}

capture confirm numeric variable school_year
if _rc {
    capture destring school_year, replace force
}

drop if missing(teacher_id) | missing(school_year)

* Resolve duplicates in teacher-year at build stage.
capture confirm variable fte
if _rc == 0 {
    gsort teacher_id school_year -fte
}
else {
    sort teacher_id school_year
}
by teacher_id school_year: keep if _n == 1

* Entrant outcomes using district-entry default.
sort teacher_id school_year
by teacher_id: gen __prev_year = school_year[_n-1]
by teacher_id: gen __prev_dist = district_id[_n-1]

capture confirm variable is_entrant
if _rc {
    gen is_entrant = (missing(__prev_year) | school_year > (__prev_year + 1) | district_id != __prev_dist)
}

capture confirm variable incoming_from_tx
if _rc {
    gen incoming_from_tx = (is_entrant == 1 & !missing(__prev_year) & district_id != __prev_dist)
}

capture confirm variable incoming_first_time
if _rc {
    gen incoming_first_time = (is_entrant == 1 & missing(__prev_year))
}

capture confirm variable incoming_experience
if _rc {
    capture confirm variable experience
    if _rc == 0 {
        gen incoming_experience = experience if is_entrant == 1
    }
    else {
        gen incoming_experience = .
        do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "experience" "missing_source_for_incoming_experience"
    }
}

capture confirm variable incoming_alt_path
if _rc {
    gen incoming_alt_path = .
    local alt_proxy_found = 0

    capture confirm variable cert_alt
    if _rc == 0 {
        replace incoming_alt_path = cert_alt if is_entrant == 1
        local alt_proxy_found = 1
    }

    if `alt_proxy_found' == 0 {
        foreach v in tier2 cert_tier2 {
            capture confirm variable `v'
            if _rc == 0 {
                replace incoming_alt_path = `v' if is_entrant == 1
                local alt_proxy_found = 1
            }
        }
    }

    if `alt_proxy_found' == 1 {
        replace incoming_alt_path = 0 if is_entrant == 1 & missing(incoming_alt_path)
    }
    else {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_alt_path" "missing_alt_certification_proxy"
    }
}

capture confirm variable incoming_adv_degree
if _rc {
    gen incoming_adv_degree = .

    local adv_src ""
    foreach v in adv_degree has_adv_degree advanced_degree graduate_degree masters doctorate phd {
        capture confirm variable `v'
        if _rc == 0 & "`adv_src'" == "" {
            local adv_src "`v'"
        }
    }

    if "`adv_src'" != "" {
        replace incoming_adv_degree = `adv_src' if is_entrant == 1
    }
    else {
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
                drop __deg_text
            }
        }
    }

    quietly count if is_entrant == 1 & !missing(incoming_adv_degree)
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_adv_degree" "missing_degree_information"
    }
}

capture confirm variable incoming_no_degree
if _rc {
    gen incoming_no_degree = .

    local nodeg_src ""
    foreach v in no_degree has_no_degree degree_none no_bachelor {
        capture confirm variable `v'
        if _rc == 0 & "`nodeg_src'" == "" {
            local nodeg_src "`v'"
        }
    }

    if "`nodeg_src'" != "" {
        replace incoming_no_degree = `nodeg_src' if is_entrant == 1
    }
    else {
        local degree_text2 ""
        foreach v in degree highest_degree degree_level deg_level {
            capture confirm variable `v'
            if _rc == 0 & "`degree_text2'" == "" {
                local degree_text2 "`v'"
            }
        }

        if "`degree_text2'" != "" {
            capture confirm string variable `degree_text2'
            if _rc == 0 {
                gen __deg_text2 = upper(trim(`degree_text2'))
                replace incoming_no_degree = 1 if is_entrant == 1 & (strpos(__deg_text2, "NO DEG") > 0 | strpos(__deg_text2, "NONE") > 0 | strpos(__deg_text2, "LESS") > 0)
                replace incoming_no_degree = 0 if is_entrant == 1 & __deg_text2 != "" & missing(incoming_no_degree)
                drop __deg_text2
            }
        }
    }

    quietly count if is_entrant == 1 & !missing(incoming_no_degree)
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "entrant_outcomes" "incoming_no_degree" "missing_degree_information"
    }
}

drop __prev_year __prev_dist

tempfile teacher_panel
save "`teacher_panel'", replace

* Build district-year treatment/timing panel.
use "${clean_calendar_file}", clear

capture confirm variable district_id
if _rc {
    capture confirm variable district
    if _rc == 0 {
        rename district district_id
    }
}

capture confirm variable adopt_year
if _rc {
    capture confirm variable firstyear
    if _rc == 0 {
        rename firstyear adopt_year
    }
}

capture confirm variable ever_treated
if _rc {
    capture confirm variable ever4DSW
    if _rc == 0 {
        rename ever4DSW ever_treated
    }
}

capture confirm variable treated
if _rc {
    capture confirm variable post_adoption
    if _rc == 0 {
        rename post_adoption treated
    }
}

capture confirm variable school_year
if _rc {
    capture confirm variable syear
    if _rc == 0 {
        rename syear school_year
    }
}

foreach v in district_id school_year adopt_year ever_treated treated {
    capture confirm variable `v'
    if _rc {
        gen `v' = .
    }
}

foreach v in district_id adopt_year ever_treated treated {
    capture confirm numeric variable `v'
    if _rc {
        capture destring `v', replace force
        capture confirm numeric variable `v'
        if _rc {
            egen __`v' = group(`v') if !missing(`v')
            drop `v'
            rename __`v' `v'
        }
    }
}

capture confirm numeric variable school_year
if _rc {
    capture destring school_year, replace force
}

replace ever_treated = !missing(adopt_year) if missing(ever_treated)
replace treated = (school_year >= adopt_year) if missing(treated) & !missing(adopt_year)
replace treated = 0 if missing(treated)

capture confirm variable event_time
if _rc {
    gen event_time = school_year - adopt_year if !missing(adopt_year)
}
else {
    replace event_time = school_year - adopt_year if missing(event_time) & !missing(adopt_year)
}

capture confirm variable hybrid_calendar
if _rc {
    capture confirm variable pct_four
    if _rc == 0 {
        gen hybrid_calendar = (treated == 1 & pct_four > 0 & pct_four < 1) if !missing(treated) & !missing(pct_four)
    }
}

capture confirm variable AgencyNCES
if _rc {
    capture confirm variable agencynces
    if _rc == 0 {
        rename agencynces AgencyNCES
    }
}

local cal_keep "district_id school_year adopt_year ever_treated treated event_time"
foreach v in hybrid_calendar AgencyNCES {
    capture confirm variable `v'
    if _rc == 0 {
        local cal_keep "`cal_keep' `v'"
    }
}
keep `cal_keep'
sort district_id school_year
by district_id school_year: keep if _n == 1

tempfile calendar_panel
save "`calendar_panel'", replace

* Add rural indicator if optional source exists.
capture confirm file "${clean_rural_file}"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "${clean_rural_file}" "missing_rural_source_file"
}
else {
    use "${clean_rural_file}", clear

    capture confirm variable school_year
    if _rc {
        capture confirm variable year
        if _rc == 0 {
            rename year school_year
        }
    }

    capture confirm variable district_id
    if _rc {
        capture confirm variable district
        if _rc == 0 {
            rename district district_id
        }
    }

    capture confirm variable AgencyNCES
    if _rc {
        capture confirm variable agencynces
        if _rc == 0 {
            rename agencynces AgencyNCES
        }
    }

    capture confirm variable rural
    if _rc {
        capture confirm variable District_Urbanicity
        if _rc == 0 {
            gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
        }
    }

    capture confirm numeric variable school_year
    if _rc {
        capture destring school_year, replace force
    }

    local rural_key ""
    capture confirm variable district_id
    if _rc == 0 {
        local rural_key "district_id school_year"
    }
    else {
        capture confirm variable AgencyNCES
        if _rc == 0 {
            local rural_key "AgencyNCES school_year"
        }
    }

    capture confirm variable rural
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural" "missing_rural_variable"
    }
    else if "`rural_key'" == "" {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural" "missing_key_for_rural_merge"
    }
    else {
        keep `rural_key' rural
        sort `rural_key'
        by `rural_key': keep if _n == 1

        tempfile rural_panel
        save "`rural_panel'", replace

        use "`calendar_panel'", clear
        capture merge m:1 `rural_key' using "`rural_panel'"
        if _rc == 0 {
            drop if _merge == 2
            drop _merge
            save "`calendar_panel'", replace
        }
        else {
            do "replication/utils/record_unavailable_analysis.do" "02_build" "robustness_flags" "rural" "merge_failure_for_rural"
        }
    }
}

* Merge district-year timing into teacher-year panel.
use "`teacher_panel'", clear
merge m:1 district_id school_year using "`calendar_panel'"
drop if _merge == 2
drop _merge

tempfile panel_before_class
save "`panel_before_class'", replace

* Build classroom controls from optional VAM files.
tempfile class_controls
clear
set obs 0
gen teacher_id = .
gen school_year = .
gen class_size = .
gen class_frpl_share = .
gen class_nonwhite_share = .
gen class_prior_ach = .
save "`class_controls'", replace

local vam_found = 0
forvalues i = 1/4 {
    local vam_file "${clean_vam_prefix}`i'.dta"
    capture confirm file "`vam_file'"
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "`vam_file'" "missing_vam_file"
    }
    else {
        local vam_found = 1
        use "`vam_file'", clear

        capture confirm variable teacher_id
        if _rc {
            capture confirm variable teachid
            if _rc == 0 {
                rename teachid teacher_id
            }
        }

        capture confirm variable school_year
        if _rc {
            capture confirm variable syear
            if _rc == 0 {
                rename syear school_year
            }
        }

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
                    by teacher_id school_year section_id: gen __n_students = _N
                    gen class_size = __n_students
                    drop __n_students
                }
            }
        }

        foreach v in teacher_id school_year {
            capture confirm variable `v'
            if _rc {
                gen `v' = .
            }
        }

        foreach v in class_size class_frpl_share class_nonwhite_share class_prior_ach {
            capture confirm variable `v'
            if _rc {
                gen `v' = .
            }
        }

        capture confirm numeric variable teacher_id
        if _rc {
            capture destring teacher_id, replace force
            capture confirm numeric variable teacher_id
            if _rc {
                egen __teacher_id = group(teacher_id) if !missing(teacher_id)
                drop teacher_id
                rename __teacher_id teacher_id
            }
        }

        capture confirm numeric variable school_year
        if _rc {
            capture destring school_year, replace force
        }

        capture confirm variable section_id
        if _rc {
            gen section_id = .
        }

        keep teacher_id school_year section_id class_size class_frpl_share class_nonwhite_share class_prior_ach
        drop if missing(teacher_id) | missing(school_year)

        collapse (firstnm) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teacher_id school_year section_id)
        collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teacher_id school_year)

        append using "`class_controls'"
        save "`class_controls'", replace
    }
}

if `vam_found' == 1 {
    use "`class_controls'", clear
    collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teacher_id school_year)
    tempfile class_controls_final
    save "`class_controls_final'", replace
}

if `vam_found' == 1 {
    use "`panel_before_class'", clear
    merge m:1 teacher_id school_year using "`class_controls_final'"
    drop if _merge == 2
    drop _merge
}
else {
    use "`panel_before_class'", clear
    do "replication/utils/record_unavailable_analysis.do" "02_build" "classroom_controls" "class_size class_frpl_share class_nonwhite_share class_prior_ach" "all_vam_files_missing"
}

* Ensure treatment/timing variables exist and are coherent.
foreach v in adopt_year ever_treated treated {
    capture confirm variable `v'
    if _rc {
        gen `v' = .
    }
}

replace ever_treated = !missing(adopt_year) if missing(ever_treated)
replace treated = (school_year >= adopt_year) if missing(treated) & !missing(adopt_year)
replace treated = 0 if missing(treated)

capture confirm variable event_time
if _rc {
    gen event_time = school_year - adopt_year if !missing(adopt_year)
}
else {
    replace event_time = school_year - adopt_year if missing(event_time) & !missing(adopt_year)
}

capture confirm variable matched_sample
if _rc {
    gen matched_sample = 1
}

* Keep only analysis-relevant variables that exist.
local final_keep ""
foreach v in teacher_id school_id district_id school_year treated ever_treated adopt_year event_time matched_sample fte experience female certified salary rural hybrid_calendar is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree class_size class_frpl_share class_nonwhite_share class_prior_ach {
    capture confirm variable `v'
    if _rc == 0 {
        local final_keep "`final_keep' `v'"
    }
}

keep `final_keep'
sort teacher_id school_year
save "${analysis_data}", replace
