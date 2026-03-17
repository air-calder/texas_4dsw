/*
Description: Prepare teacher-year analysis file with t+1 transition outcomes.
Run from project root.
*/

version 17

local analysis_data "replication/output/intermediate/teacher_year_analysis.dta"
local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`analysis_data'"
if _rc {
    do "replication/02_build_teacher_year_analysis.do"
}

capture confirm file "`analysis_data'"
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "04_prepare" "teacher_outcome_prep" "`analysis_data'" "analysis_data_missing_after_build"
    di as error "Missing analysis dataset: `analysis_data'"
    exit 601
}

use "`analysis_data'", clear

capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"

keep if inrange(syear, 2017, 2024)

quietly count
local n_before = r(N)

capture noisily isid id2 syear
if _rc {
    gen __orig_order = _n
    capture confirm variable fte
    if _rc == 0 {
        gsort id2 syear -fte __orig_order
    }
    else {
        sort id2 syear __orig_order
    }
    by id2 syear: keep if _n == 1
    drop __orig_order
}

quietly count
local n_after = r(N)

preserve
clear
set obs 1
gen rows_before = `n_before'
gen rows_after = `n_after'
gen rows_dropped = rows_before - rows_after
export delimited using "replication/output/checks/duplicate_resolution.csv", replace
restore

local trans_vars "observed_t1 stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1"
foreach v of local trans_vars {
    capture confirm variable `v'
    if _rc == 0 {
        capture drop old_`v'
        clonevar old_`v' = `v'
    }
}

capture confirm variable ever4DSW
if _rc {
    gen ever4DSW = !missing(firstyear)
}

capture confirm variable post_adoption
if _rc {
    gen post_adoption = (syear >= firstyear) if !missing(firstyear)
    replace post_adoption = 0 if missing(post_adoption)
}

capture confirm variable event_time
if _rc {
    gen event_time = syear - firstyear if !missing(firstyear)
}

sort id2 syear
by id2: gen __next_year = syear[_n+1]
by id2: gen __next_school = campus[_n+1]
by id2: gen __next_district = district[_n+1]

quietly summarize syear, meanonly
local max_year = r(max)

capture drop observed_t1
gen observed_t1 = (__next_year == syear + 1) if syear < `max_year'

capture drop stay_school_t1
gen stay_school_t1 = (observed_t1 == 1 & __next_school == campus) if syear < `max_year'
replace stay_school_t1 = 0 if syear < `max_year' & observed_t1 == 1 & __next_school != campus

capture drop stay_district_t1
gen stay_district_t1 = (observed_t1 == 1 & __next_district == district) if syear < `max_year'
replace stay_district_t1 = 0 if syear < `max_year' & observed_t1 == 1 & __next_district != district

capture drop switch_district_t1
gen switch_district_t1 = (observed_t1 == 1 & __next_district != district) if syear < `max_year'
replace switch_district_t1 = 0 if syear < `max_year' & observed_t1 == 1 & __next_district == district

capture drop exit_tx_public_t1
gen exit_tx_public_t1 = (observed_t1 == 0) if syear < `max_year'

capture drop turnover_teacher_t1
gen turnover_teacher_t1 = 1 - stay_school_t1 if !missing(stay_school_t1)

capture drop is_incumbent
gen is_incumbent = !missing(stay_school_t1)

capture confirm variable is_entrant
if _rc {
    by id2: egen __first_obs_year = min(syear)
    gen is_entrant = (syear == __first_obs_year) if !missing(__first_obs_year)
    drop __first_obs_year

    local incoming_avail ""
    foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
        capture confirm variable `y'
        if _rc == 0 {
            local incoming_avail "`incoming_avail' `y'"
        }
    }
    if "`incoming_avail'" != "" {
        egen __incoming_nonmiss = rownonmiss(`incoming_avail')
        replace is_entrant = 1 if __incoming_nonmiss > 0
        drop __incoming_nonmiss
    }
}

capture confirm variable exper
if _rc == 0 {
    capture confirm variable exp_le5
    if _rc {
        gen exp_le5 = (exper <= 5) if !missing(exper)
    }
    capture confirm variable exp_gt5
    if _rc {
        gen exp_gt5 = (exper > 5) if !missing(exper)
    }
    capture confirm variable exp_gt9
    if _rc {
        gen exp_gt9 = (exper > 9) if !missing(exper)
    }
}

tempfile mm
tempname mmpost
postfile `mmpost' str40 variable long n_compared long n_mismatch double mismatch_share using "`mm'", replace

foreach v of local trans_vars {
    capture confirm variable old_`v'
    if _rc == 0 {
        quietly count if !missing(old_`v') & !missing(`v')
        local n_comp = r(N)
        quietly count if !missing(old_`v') & !missing(`v') & old_`v' != `v'
        local n_diff = r(N)
        local s_diff = .
        if `n_comp' > 0 {
            local s_diff = `n_diff' / `n_comp'
        }
        post `mmpost' ("`v'") (`n_comp') (`n_diff') (`s_diff')
        drop old_`v'
    }
}
postclose `mmpost'

preserve
use "`mm'", clear
export delimited using "replication/output/checks/transition_mismatch_audit.csv", replace
restore

drop __next_year __next_school __next_district
sort id2 syear
save "`prepared_data'", replace
