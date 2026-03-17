/*
Description: Prepare teacher-year analysis file with defensive transition outcomes.
Computes t+1 outcomes even if precomputed versions already exist.
*/

version 17

capture confirm file "${analysis_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/02_build_teacher_year_analysis.do"
}

capture confirm file "${analysis_data}"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "04_prepare" "teacher_outcome_prep" "${analysis_data}" "analysis_data_missing_after_build"
    di as error "Missing analysis dataset: ${analysis_data}"
    exit 601
}

use "${analysis_data}", clear

capture mkdir "${rep_output}/intermediate"
capture mkdir "${rep_output}/checks"

* Restrict to configured analysis years.
keep if inrange(${year_var}, ${analysis_start_year}, ${analysis_end_year})

* Resolve duplicate teacher-year rows (max FTE wins if available).
quietly count
local n_before = r(N)

capture noisily isid ${id_teacher} ${year_var}
if _rc {
    gen __orig_order = _n
    capture confirm variable ${fte_var}
    if _rc == 0 {
        gsort ${id_teacher} ${year_var} -${fte_var} __orig_order
    }
    else {
        sort ${id_teacher} ${year_var} __orig_order
    }
    by ${id_teacher} ${year_var}: keep if _n == 1
    drop __orig_order
}

quietly count
local n_after = r(N)

preserve
clear
set obs 1
gen rows_before = `n_before'
gen rows_after = `n_after'
gen rows_dropped = rows_before - rows_after
export delimited using "${rep_output}/checks/duplicate_resolution.csv", replace
restore

* Save precomputed transition variables for mismatch checks if they exist.
local trans_vars "${y_observed_t1} ${y_stay_school} ${y_stay_district} ${y_switch_district} ${y_exit_public}"
foreach v of local trans_vars {
    capture confirm variable `v'
    if _rc == 0 {
        capture drop old_`v'
        clonevar old_`v' = `v'
    }
}

* Build treatment timing if missing.
capture confirm variable ${ever_treat_var}
if _rc {
    gen ${ever_treat_var} = !missing(${adopt_year_var})
}

capture confirm variable ${treat_var}
if _rc {
    gen ${treat_var} = (${year_var} >= ${adopt_year_var}) if !missing(${adopt_year_var})
    replace ${treat_var} = 0 if missing(${treat_var})
}

capture confirm variable ${event_time_var}
if _rc {
    gen ${event_time_var} = ${year_var} - ${adopt_year_var} if !missing(${adopt_year_var})
}

* Build transition outcomes from t to t+1.
sort ${id_teacher} ${year_var}
by ${id_teacher}: gen __next_year = ${year_var}[_n+1]
by ${id_teacher}: gen __next_school = ${id_school}[_n+1]
by ${id_teacher}: gen __next_district = ${id_district}[_n+1]

quietly summarize ${year_var}, meanonly
local max_year = r(max)

capture drop ${y_observed_t1}
gen ${y_observed_t1} = (__next_year == ${year_var} + 1) if ${year_var} < `max_year'

capture drop ${y_stay_school}
gen ${y_stay_school} = (${y_observed_t1} == 1 & __next_school == ${id_school}) if ${year_var} < `max_year'
replace ${y_stay_school} = 0 if ${year_var} < `max_year' & ${y_observed_t1} == 1 & __next_school != ${id_school}

capture drop ${y_stay_district}
gen ${y_stay_district} = (${y_observed_t1} == 1 & __next_district == ${id_district}) if ${year_var} < `max_year'
replace ${y_stay_district} = 0 if ${year_var} < `max_year' & ${y_observed_t1} == 1 & __next_district != ${id_district}

capture drop ${y_switch_district}
gen ${y_switch_district} = (${y_observed_t1} == 1 & __next_district != ${id_district}) if ${year_var} < `max_year'
replace ${y_switch_district} = 0 if ${year_var} < `max_year' & ${y_observed_t1} == 1 & __next_district == ${id_district}

capture drop ${y_exit_public}
gen ${y_exit_public} = (${y_observed_t1} == 0) if ${year_var} < `max_year'

capture drop ${y_turnover_teacher}
gen ${y_turnover_teacher} = 1 - ${y_stay_school} if !missing(${y_stay_school})

* Incumbent and entrant flags.
capture drop ${incumbent_var}
gen ${incumbent_var} = !missing(${y_stay_school})

capture confirm variable ${entrant_var}
if _rc {
    by ${id_teacher}: egen __first_obs_year = min(${year_var})
    gen ${entrant_var} = (${year_var} == __first_obs_year) if !missing(__first_obs_year)
    drop __first_obs_year

    local incoming_avail ""
    foreach y of global outcomes_entrant {
        capture confirm variable `y'
        if _rc == 0 {
            local incoming_avail "`incoming_avail' `y'"
        }
    }
    if "`incoming_avail'" != "" {
        egen __incoming_nonmiss = rownonmiss(`incoming_avail')
        replace ${entrant_var} = 1 if __incoming_nonmiss > 0
        drop __incoming_nonmiss
    }
}

* Experience bins for heterogeneity if experience exists.
capture confirm variable ${experience_var}
if _rc == 0 {
    capture confirm variable exp_le5
    if _rc {
        gen exp_le5 = (${experience_var} <= 5) if !missing(${experience_var})
    }
    capture confirm variable exp_gt5
    if _rc {
        gen exp_gt5 = (${experience_var} > 5) if !missing(${experience_var})
    }
    capture confirm variable exp_gt9
    if _rc {
        gen exp_gt9 = (${experience_var} > 9) if !missing(${experience_var})
    }
}

* Mismatch audit against pre-existing transition variables.
tempfile mm
tempname mmpost
postfile `mmpost' str40 variable long n_compared long n_mismatch double mismatch_share using "`mm'", replace

foreach v of local trans_vars {
    capture confirm variable old_`v'
    if _rc == 0 {
        quietly count if !missing(old_`v') & !missing(`v')
        local n_comp = r(N)
        quietly count if !missing(old_`v') & !missing(`v') & old_`v' != `v'
        local n_diff = r(N)
        local s_diff = .
        if `n_comp' > 0 {
            local s_diff = `n_diff' / `n_comp'
        }
        post `mmpost' ("`v'") (`n_comp') (`n_diff') (`s_diff')
        drop old_`v'
    }
}
postclose `mmpost'

preserve
use "`mm'", clear
export delimited using "${rep_output}/checks/transition_mismatch_audit.csv", replace
restore

drop __next_year __next_school __next_district
save "${prepared_data}", replace
