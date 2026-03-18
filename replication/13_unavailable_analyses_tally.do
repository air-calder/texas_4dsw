/*
Description: Verify required analysis inputs exist and append diagnostics.
Run from project root.
Fail fast when required inputs are unavailable.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`prepared_data'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_modules" "`prepared_data'" "prepared_data_missing"
    di as error "Missing prepared data file: `prepared_data'"
    exit 601
}

use "`prepared_data'", clear

foreach v in post_adoption campus event_time is_incumbent is_entrant stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_modules" "`v'" "missing_required_variable"
        di as error "Missing required variable `v' in prepared data"
        exit 459
    }
}

quietly count if !missing(post_adoption)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_regressions" "post_adoption" "treatment_variable_all_missing"
    di as error "post_adoption is all missing"
    exit 459
}

quietly summarize post_adoption, meanonly
if r(min) == r(max) {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "all_regressions" "post_adoption" "treatment_has_no_variation"
    di as error "post_adoption has no variation"
    exit 459
}

quietly count if !missing(campus)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "school_fe_models" "campus" "school_identifier_all_missing"
    di as error "campus is all missing"
    exit 459
}

quietly count if !missing(event_time)
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "event_study_models" "event_time" "event_time_all_missing"
    di as error "event_time is all missing"
    exit 459
}

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "retention_models" "`y'" "no_nonmissing_outcomes_in_incumbent_sample"
        di as error "`y' has no nonmissing values in incumbent sample"
        exit 459
    }
}

quietly count if is_entrant == 1
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "is_entrant" "entrant_sample_has_zero_rows"
    di as error "Entrant sample has zero rows"
    exit 459
}

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    quietly count if is_entrant == 1 & !missing(`y')
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "13_tally" "entrant_models" "`y'" "no_nonmissing_outcomes_in_entrant_sample"
        di as error "`y' has no nonmissing values in entrant sample"
        exit 459
    }
}
