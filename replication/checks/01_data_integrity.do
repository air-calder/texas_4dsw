/*
Description: Basic integrity checks for teacher-year prepared data.
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

* 1) Required variable existence.
tempfile varcheck
tempname varpost
postfile `varpost' str40 variable byte exists using "`varcheck'", replace

local required "id2 campus district syear post_adoption ever4DSW firstyear event_time is_incumbent stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1"
foreach v of local required {
    capture confirm variable `v'
    local ok = (_rc == 0)
    post `varpost' ("`v'") (`ok')
}
postclose `varpost'

use "`varcheck'", clear
export delimited using "replication/output/checks/required_variable_check.csv", replace

* 2) Unique teacher-year key.
use "`prepared_data'", clear
capture noisily isid id2 syear
local unique_ok = (_rc == 0)

preserve
clear
set obs 1
gen unique_teacher_year = `unique_ok'
export delimited using "replication/output/checks/key_check.csv", replace
restore

* 3) Missingness on key variables and outcomes.
tempfile miss
tempname misspost
postfile `misspost' str40 variable long n_missing double pct_missing using "`miss'", replace

local miss_vars "id2 campus district syear post_adoption ever4DSW firstyear event_time is_incumbent is_entrant stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree"

quietly count
local n_all = r(N)

foreach v of local miss_vars {
    capture confirm variable `v'
    if _rc == 0 {
        quietly count if missing(`v')
        local n_miss = r(N)
        local p_miss = `n_miss' / `n_all'
        post `misspost' ("`v'") (`n_miss') (`p_miss')
    }
}
postclose `misspost'

use "`miss'", clear
sort -pct_missing
export delimited using "replication/output/checks/missingness_summary.csv", replace

* 4) Transition identity checks.
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

* 5) Counts by year and treatment status.
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
