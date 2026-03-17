/*
Description: Pretrend diagnostic outputs for teacher-year event-study setup.
Run from project root.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`prepared_data'"
if _rc {
    do "replication/04_prepare_teacher_outcomes.do"
}

use "`prepared_data'", clear
capture mkdir "replication/output/checks"

* Event-time means among ever-treated incumbents (pre-period only).
capture confirm variable event_time
local has_event = (_rc == 0)
capture confirm variable ever4DSW
local has_ever = (_rc == 0)

if `has_event' & `has_ever' {
    preserve
    keep if is_incumbent == 1
    keep if ever4DSW == 1
    keep if inrange(event_time, -3, -1)
    collapse (mean) stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1, by(event_time)
    export delimited using "replication/output/checks/pretrend_event_time_means.csv", replace
    restore
}

* Yearly pre-period means by ever-treated status.
preserve
keep if is_incumbent == 1
keep if syear <= 2019
collapse (mean) stay_school_t1 stay_district_t1 exit_tx_public_t1, by(syear ever4DSW)
export delimited using "replication/output/checks/pretrend_year_means_by_group.csv", replace
restore
