/*
Description: Event-study estimates for entrant/sorting outcomes.
Runs on entrant sample only.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/tables"

capture confirm variable ${entrant_var}
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "${entrant_var}" "entrant_flag_missing"
    file open fh using "${rep_output}/tables/teacher_entrant_eventstudy_note.txt", write replace
    file write fh "Entrant sample variable ${entrant_var} is missing; entrant event studies skipped." _n
    file close fh
    exit
}

quietly count if ${entrant_var} == 1
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "${entrant_var}" "entrant_sample_has_zero_rows"
    file open fh using "${rep_output}/tables/teacher_entrant_eventstudy_note.txt", write replace
    file write fh "Entrant sample variable ${entrant_var} has zero entrant observations; entrant event studies skipped." _n
    file close fh
    exit
}

local event_vars ""
forvalues k = ${event_min}/${event_max} {
    if `k' != -1 {
        if `k' < 0 {
            local kk = abs(`k')
            local vn = "et_m`kk'"
        }
        else {
            local vn = "et_p`k'"
        }
        capture drop `vn'
        gen `vn' = (${event_time_var} == `k')
        local event_vars "`event_vars' `vn'"
    }
}

tempfile es
tempname posth
postfile `posth' str40 outcome int event_time double coef se pvalue using "`es'", replace

foreach y of global outcomes_entrant {
    capture confirm variable `y'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "`y'" "entrant_outcome_missing"
    }
    else {
        quietly count if ${entrant_var} == 1 & !missing(`y')
        if r(N) == 0 {
            do "replication/utils/record_unavailable_analysis.do" "10_entrant_eventstudy" "entrant_eventstudy_models" "`y'" "entrant_outcome_all_missing_in_sample"
            continue
        }

        capture noisily areg `y' `event_vars' i.${year_var} if ${entrant_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
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
export delimited using "${rep_output}/tables/teacher_entrant_eventstudy.csv", replace
