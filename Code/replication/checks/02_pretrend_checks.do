/*
Description: Pretrend diagnostic outputs for teacher-year event-study setup.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
capture mkdir "code/4DSW student teacher analysis/replication/output/checks"

foreach v in is_incumbent ever4DSW event_time syear stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

preserve
keep if is_incumbent == 1
keep if ever4DSW == 1
keep if inrange(event_time, -3, -1)
collapse (mean) stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1, by(event_time)
export delimited using "code/4DSW student teacher analysis/replication/output/checks/pretrend_event_time_means.csv", replace
restore

preserve
keep if is_incumbent == 1
keep if syear <= 2019
collapse (mean) stay_school_t1 stay_district_t1 exit_tx_public_t1, by(syear ever4DSW)
export delimited using "code/4DSW student teacher analysis/replication/output/checks/pretrend_year_means_by_group.csv", replace
restore
