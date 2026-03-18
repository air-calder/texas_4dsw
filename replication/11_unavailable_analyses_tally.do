/*
Description: Verify required analysis inputs exist and append diagnostics.
Run from project root.
Fail fast when required inputs are unavailable.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear

foreach v in post_adoption campus event_time is_incumbent is_entrant stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in prepared data"
        exit 459
    }
}

quietly count if !missing(post_adoption)
if r(N) == 0 {
    di as error "post_adoption is all missing"
    exit 459
}

quietly summarize post_adoption, meanonly
if r(min) == r(max) {
    di as error "post_adoption has no variation"
    exit 459
}

quietly count if !missing(campus)
if r(N) == 0 {
    di as error "campus is all missing"
    exit 459
}

quietly count if !missing(event_time)
if r(N) == 0 {
    di as error "event_time is all missing"
    exit 459
}

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
    if r(N) == 0 {
        di as error "`y' has no nonmissing values in incumbent sample"
        exit 459
    }
}

quietly count if is_entrant == 1
if r(N) == 0 {
    di as error "Entrant sample has zero rows"
    exit 459
}

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    quietly count if is_entrant == 1 & !missing(`y')
    if r(N) == 0 {
        di as error "`y' has no nonmissing values in entrant sample"
        exit 459
    }
}
