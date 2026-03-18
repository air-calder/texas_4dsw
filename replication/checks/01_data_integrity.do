/*
Description: Basic integrity checks for teacher-year prepared data.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`prepared_data'"
if _rc {
    do "replication/04_prepare_teacher_outcomes.do"
}

use "`prepared_data'", clear
capture mkdir "replication/output/checks"

local required "id2 campus district syear post_adoption ever4DSW firstyear event_time is_incumbent is_entrant stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree"
foreach v of local required {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "01_integrity" "data_integrity_checks" "`v'" "missing_required_variable"
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

capture noisily isid id2 syear
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "01_integrity" "data_integrity_checks" "id2+syear" "teacher_year_key_not_unique"
    di as error "Teacher-year key id2 x syear is not unique"
    exit 459
}

* Required variable check export.
tempfile varcheck
tempname varpost
postfile `varpost' str40 variable byte exists using "`varcheck'", replace
foreach v of local required {
    post `varpost' ("`v'") (1)
}
postclose `varpost'
use "`varcheck'", clear
export delimited using "replication/output/checks/required_variable_check.csv", replace

* Key check export.
preserve
clear
set obs 1
gen unique_teacher_year = 1
export delimited using "replication/output/checks/key_check.csv", replace
restore

* Missingness summary.
tempfile miss
tempname misspost
postfile `misspost' str40 variable long n_missing double pct_missing using "`miss'", replace
quietly count
local n_all = r(N)
foreach v of local required {
    quietly count if missing(`v')
    local n_miss = r(N)
    local p_miss = `n_miss' / `n_all'
    post `misspost' ("`v'") (`n_miss') (`p_miss')
}
postclose `misspost'

use "`miss'", clear
sort -pct_missing
export delimited using "replication/output/checks/missingness_summary.csv", replace

* Transition identity checks.
use "`prepared_data'", clear
quietly count if is_incumbent == 1 & stay_school_t1 == 1 & stay_district_t1 != 1
local c_stay = r(N)
quietly count if is_incumbent == 1 & !missing(observed_t1) & !missing(stay_district_t1) & !missing(switch_district_t1) & observed_t1 != stay_district_t1 + switch_district_t1
local c_move_id = r(N)
quietly count if is_incumbent == 1 & !missing(observed_t1) & !missing(exit_tx_public_t1) & observed_t1 + exit_tx_public_t1 != 1
local c_exit_id = r(N)

preserve
clear
set obs 1
gen fail_stay_school_impl_stay_district = `c_stay'
gen fail_observed_equals_stayplusswitch = `c_move_id'
gen fail_observed_plus_exit_equals_one = `c_exit_id'
export delimited using "replication/output/checks/transition_identity_checks.csv", replace
restore

* Counts by year and treatment status.
use "`prepared_data'", clear
sort syear id2
by syear id2: gen __tag_teacher = (_n == 1)
by syear: egen n_teachers = total(__tag_teacher)
sort syear campus
by syear campus: gen __tag_school = (_n == 1)
by syear: egen n_schools = total(__tag_school)
sort syear district
by syear district: gen __tag_district = (_n == 1)
by syear: egen n_districts = total(__tag_district)
bys syear: egen n_treated = total(post_adoption)
keep syear n_teachers n_schools n_districts n_treated
duplicates drop
gen treated_share_teacher_rows = n_treated / n_teachers
sort syear
export delimited using "replication/output/checks/year_level_counts.csv", replace
