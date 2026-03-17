/*
Description: Pretrend diagnostic outputs for teacher-year event-study setup.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/checks"

* Event-time means among ever-treated incumbents (pre-period only)
capture confirm variable ${event_time_var}
local has_event = (_rc == 0)
capture confirm variable ${ever_treat_var}
local has_ever = (_rc == 0)

if `has_event' & `has_ever' {
    preserve
    keep if ${incumbent_var} == 1
    keep if ${ever_treat_var} == 1
    keep if inrange(${event_time_var}, ${event_min}, -1)
    collapse (mean) ${outcomes_retention_main}, by(${event_time_var})
    export delimited using "${rep_output}/checks/pretrend_event_time_means.csv", replace
    restore
}

* Yearly pre-period means by ever-treated status
preserve
keep if ${incumbent_var} == 1
keep if ${year_var} <= ${pretrend_end_year}
collapse (mean) ${outcomes_retention_trends}, by(${year_var} ${ever_treat_var})
export delimited using "${rep_output}/checks/pretrend_year_means_by_group.csv", replace
restore
