/*
Description: Event-study estimates for teacher-level retention outcomes.
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

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `y'
    if _rc == 0 {
        capture noisily areg `y' `event_vars' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
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
export delimited using "replication/output/tables/teacher_retention_eventstudy.csv", replace
