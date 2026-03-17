/*
Description: Append run-level unavailable-analysis diagnostics to running tally.
Run from project root.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`prepared_data'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_modules" "`prepared_data'" "prepared_data_missing"
    exit
}

use "`prepared_data'", clear

quietly count if !missing(post_adoption)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_regressions" "post_adoption" "treatment_variable_all_missing"
}

quietly summarize post_adoption, meanonly
if r(min) == r(max) {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_regressions" "post_adoption" "treatment_has_no_variation"
}

quietly count if !missing(campus)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "school_fe_models" "campus" "school_identifier_all_missing"
}

capture confirm variable event_time
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "event_study_models" "event_time" "event_time_variable_missing"
}
else {
    quietly count if !missing(event_time)
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "event_study_models" "event_time" "event_time_all_missing"
    }
}

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `y'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "retention_models" "`y'" "outcome_variable_missing"
    }
    else {
        quietly count if is_incumbent == 1 & !missing(`y')
        if r(N) == 0 {
            do "replication/utils/record_unavailable_analysis.do" "13_tally" "retention_models" "`y'" "no_nonmissing_outcomes_in_incumbent_sample"
        }
    }
}

capture confirm variable is_entrant
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "is_entrant" "entrant_flag_missing"
}
else {
    quietly count if is_entrant == 1
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "is_entrant" "entrant_sample_has_zero_rows"
    }

    foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
        capture confirm variable `y'
        if _rc {
            do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "`y'" "entrant_outcome_variable_missing"
        }
        else {
            quietly count if is_entrant == 1 & !missing(`y')
            if r(N) == 0 {
                do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "`y'" "no_nonmissing_outcomes_in_entrant_sample"
            }
        }
    }
}
