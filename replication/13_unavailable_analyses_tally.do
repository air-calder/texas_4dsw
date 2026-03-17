/*
Description: Append run-level unavailable-analysis diagnostics to running tally.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
}

capture confirm file "${prepared_data}"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_modules" "${prepared_data}" "prepared_data_missing"
    exit
}

use "${prepared_data}", clear

* Core identifying conditions for model feasibility.
quietly count if !missing(${treat_var})
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_regressions" "${treat_var}" "treatment_variable_all_missing"
}

quietly summarize ${treat_var}, meanonly
if r(min) == r(max) {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_regressions" "${treat_var}" "treatment_has_no_variation"
}

quietly count if !missing(${id_school})
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "school_fe_models" "${id_school}" "school_identifier_all_missing"
}

capture confirm variable ${event_time_var}
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "event_study_models" "${event_time_var}" "event_time_variable_missing"
}
else {
    quietly count if !missing(${event_time_var})
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "event_study_models" "${event_time_var}" "event_time_all_missing"
    }
}

* Retention outcomes unavailable or empty among incumbents.
foreach y of global outcomes_retention_main {
    capture confirm variable `y'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "retention_models" "`y'" "outcome_variable_missing"
    }
    else {
        quietly count if ${incumbent_var} == 1 & !missing(`y')
        if r(N) == 0 {
            do "replication/utils/record_unavailable_analysis.do" "13_tally" "retention_models" "`y'" "no_nonmissing_outcomes_in_incumbent_sample"
        }
    }
}

* Entrant sample and outcomes unavailable.
capture confirm variable ${entrant_var}
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "${entrant_var}" "entrant_flag_missing"
}
else {
    quietly count if ${entrant_var} == 1
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "${entrant_var}" "entrant_sample_has_zero_rows"
    }

    foreach y of global outcomes_entrant {
        capture confirm variable `y'
        if _rc {
            do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "`y'" "entrant_outcome_variable_missing"
        }
        else {
            quietly count if ${entrant_var} == 1 & !missing(`y')
            if r(N) == 0 {
                do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "`y'" "no_nonmissing_outcomes_in_entrant_sample"
            }
        }
    }
}
