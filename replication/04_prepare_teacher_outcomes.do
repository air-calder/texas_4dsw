/*
Description: Prepare teacher-year analysis file with t+1 transition outcomes.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local analysis_data "replication/output/intermediate/teacher_year_analysis.dta"
local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

use "`analysis_data'", clear

capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"

foreach v in id2 syear district campus firstyear ever4DSW post_adoption event_time fte exper is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `analysis_data'"
        exit 459
    }
}

keep if inrange(syear, 2017, 2024)

isid id2 syear
sort id2 syear
tsset id2 syear

quietly summarize syear, meanonly
local max_year = r(max)

gen observed_t1 = !missing(F.syear) if syear < `max_year'

gen stay_school_t1 = (observed_t1 == 1 & F.campus == campus) if syear < `max_year'
replace stay_school_t1 = 0 if syear < `max_year' & observed_t1 == 1 & F.campus != campus

gen stay_district_t1 = (observed_t1 == 1 & F.district == district) if syear < `max_year'
replace stay_district_t1 = 0 if syear < `max_year' & observed_t1 == 1 & F.district != district

gen switch_district_t1 = (observed_t1 == 1 & F.district != district) if syear < `max_year'
replace switch_district_t1 = 0 if syear < `max_year' & observed_t1 == 1 & F.district == district

gen exit_tx_public_t1 = (observed_t1 == 0) if syear < `max_year'

gen turnover_teacher_t1 = 1 - stay_school_t1 if !missing(stay_school_t1)

gen is_incumbent = !missing(stay_school_t1)

gen exp_le5 = (exper <= 5) if !missing(exper)
gen exp_gt5 = (exper > 5) if !missing(exper)
gen exp_gt9 = (exper > 9) if !missing(exper)
sort id2 syear
save "`prepared_data'", replace
