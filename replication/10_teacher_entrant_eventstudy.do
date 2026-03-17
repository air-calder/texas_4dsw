/*
Description: Event-study estimates for entrant/sorting outcomes.
Run from project root.
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

capture confirm variable is_entrant
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "is_entrant" "entrant_flag_missing"
    file open fh using "replication/output/tables/teacher_entrant_eventstudy_note.txt", write replace
    file write fh "Entrant sample variable is_entrant is missing; entrant event studies skipped." _n
    file close fh
    exit
}

quietly count if is_entrant == 1
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "is_entrant" "entrant_sample_has_zero_rows"
    file open fh using "replication/output/tables/teacher_entrant_eventstudy_note.txt", write replace
    file write fh "Entrant sample variable is_entrant has zero entrant observations; entrant event studies skipped." _n
    file close fh
    exit
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
    capture confirm variable `y'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "`y'" "entrant_outcome_missing"
    }
    else {
        quietly count if is_entrant == 1 & !missing(`y')
        if r(N) == 0 {
            do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "`y'" "entrant_outcome_all_missing_in_sample"
            continue
        }

        capture noisily areg `y' `event_vars' i.syear if is_entrant == 1 & !missing(`y'), absorb(campus) vce(cluster district)
        if _rc == 0 {
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
    }
}
postclose `posth'

use "`es'", clear
sort outcome event_time
export delimited using "replication/output/tables/teacher_entrant_eventstudy.csv", replace
