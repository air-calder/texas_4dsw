/*
Description: Event-study estimates for teacher-level retention outcomes.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/tables"

* Build event-time dummies, omitting t = -1 as reference.
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

foreach y of global outcomes_retention_main {
    capture confirm variable `y'
    if _rc == 0 {
        capture noisily areg `y' `event_vars' i.${year_var} if ${incumbent_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
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
export delimited using "${rep_output}/tables/teacher_retention_eventstudy.csv", replace
