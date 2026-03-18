/*
Description: Descriptive tables and trend files for teacher-year panel.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
capture mkdir "replication/output/descriptives"
capture mkdir "replication/output/figures"

foreach v in id2 syear district campus post_adoption ever4DSW is_incumbent is_entrant female certified exper salary fte class_size class_frpl_share class_nonwhite_share class_prior_ach stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

* 1) Sample counts by year.
preserve
sort syear id2
by syear id2: gen __tag_teacher = (_n == 1)
by syear: egen n_teachers = total(__tag_teacher)

sort syear campus
by syear campus: gen __tag_school = (_n == 1)
by syear: egen n_schools = total(__tag_school)

sort syear district
by syear district: gen __tag_district = (_n == 1)
by syear: egen n_districts = total(__tag_district)

bys syear: egen n_treated_rows = total(post_adoption)
keep syear n_teachers n_schools n_districts n_treated_rows
duplicates drop
gen treated_row_share = n_treated_rows / n_teachers
sort syear
export delimited using "replication/output/descriptives/sample_counts_by_year.csv", replace
restore

* 2) Adoption timing distribution at teacher-row level.
preserve
keep if ever4DSW == 1
contract firstyear
gen n_teacher_rows = _freq
keep firstyear n_teacher_rows
export delimited using "replication/output/descriptives/adoption_timing_distribution.csv", replace
restore

* 3) Pre-period balance means by ever-treated status.
preserve
keep if syear <= 2019
collapse (mean) female certified exper salary fte class_size class_frpl_share class_nonwhite_share class_prior_ach stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1, by(ever4DSW)
export delimited using "replication/output/descriptives/preperiod_balance_means.csv", replace
restore

* 4) Retention trends among incumbents by ever-treated status.
preserve
keep if is_incumbent == 1
collapse (mean) stay_school_t1 stay_district_t1 exit_tx_public_t1, by(syear ever4DSW)
save "replication/output/descriptives/retention_trends_by_group.dta", replace
export delimited using "replication/output/descriptives/retention_trends_by_group.csv", replace
restore

* 5) Entrant outcome trends by ever-treated status.
preserve
keep if is_entrant == 1
collapse (mean) incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree, by(syear ever4DSW)
save "replication/output/descriptives/entrant_trends_by_group.dta", replace
export delimited using "replication/output/descriptives/entrant_trends_by_group.csv", replace
restore

* 6) Trend figures for retention outcomes.
use "replication/output/descriptives/retention_trends_by_group.dta", clear
foreach y in stay_school_t1 stay_district_t1 exit_tx_public_t1 {
    twoway ///
        (line `y' syear if ever4DSW == 0, sort lcolor(navy)) ///
        (line `y' syear if ever4DSW == 1, sort lcolor(maroon)), ///
        legend(order(1 "Never treated" 2 "Ever treated")) ///
        xtitle("School year") ytitle("Mean `y'")
    graph export "replication/output/figures/trend_`y'.png", replace width(1400) height(900)
}
