/*
Description: Event-study estimates for entrant/sorting outcomes.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"
local event_min = -3
local event_max = 4

capture confirm file "`prepared_data'"
if _rc {
    do "replication/04_prepare_teacher_outcomes.do"
}

use "`prepared_data'", clear
capture mkdir "replication/output/tables"

foreach v in id2 syear district campus is_entrant event_time incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "`v'" "missing_required_variable"
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

quietly count if is_entrant == 1
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "is_entrant" "entrant_sample_has_zero_rows"
    di as error "Entrant sample has zero rows"
    exit 459
}

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    quietly count if is_entrant == 1 & !missing(`y')
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "`y'" "entrant_outcome_all_missing_in_sample"
        di as error "Entrant outcome `y' is all missing in entrant sample"
        exit 459
    }
}

local event_vars ""
forvalues k = `event_min'/`event_max' {
    if `k' != -1 {
        if `k' < 0 {
            local kk = abs(`k')
            local vn = "et_m`kk'"
        }
        else {
            local vn = "et_p`k'"
        }
        capture drop `vn'
        gen `vn' = (event_time == `k')
        local event_vars "`event_vars' `vn'"
    }
}

tempfile es
tempname posth
postfile `posth' str40 outcome int event_time double coef se pvalue using "`es'", replace

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    noisily areg `y' `event_vars' i.syear if is_entrant == 1 & !missing(`y'), absorb(campus) vce(cluster district)
    foreach ev of local event_vars {
        if strpos("`ev'", "et_m") == 1 {
            local et = -real(substr("`ev'", 5, .))
        }
        else {
            local et = real(substr("`ev'", 5, .))
        }
        local b = _b[`ev']
        local s = _se[`ev']
        local z = `b' / `s'
        local p = 2 * normal(-abs(`z'))
        post `posth' ("`y'") (`et') (`b') (`s') (`p')
    }
}
postclose `posth'

use "`es'", clear
sort outcome event_time
export delimited using "replication/output/tables/teacher_entrant_eventstudy.csv", replace
