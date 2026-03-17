/*
Description: Basic integrity checks for teacher-year prepared data.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/checks"

* 1) Required variable existence
tempfile varcheck
tempname varpost
postfile `varpost' str40 variable byte exists using "`varcheck'", replace

local required "${id_teacher} ${id_school} ${id_district} ${year_var} ${treat_var} ${ever_treat_var} ${adopt_year_var} ${event_time_var} ${incumbent_var} ${y_stay_school} ${y_stay_district} ${y_switch_district} ${y_exit_public}"
foreach v of local required {
    capture confirm variable `v'
    local ok = (_rc == 0)
    post `varpost' ("`v'") (`ok')
}
postclose `varpost'

use "`varcheck'", clear
export delimited using "${rep_output}/checks/required_variable_check.csv", replace

* 2) Unique teacher-year key
use "${prepared_data}", clear
capture noisily isid ${id_teacher} ${year_var}
local unique_ok = (_rc == 0)

preserve
clear
set obs 1
gen unique_teacher_year = `unique_ok'
export delimited using "${rep_output}/checks/key_check.csv", replace
restore

* 3) Missingness on key variables and outcomes
tempfile miss
tempname misspost
postfile `misspost' str40 variable long n_missing double pct_missing using "`miss'", replace

local miss_vars "${id_teacher} ${id_school} ${id_district} ${year_var} ${treat_var} ${ever_treat_var} ${adopt_year_var} ${event_time_var} ${incumbent_var} ${entrant_var} ${outcomes_retention_main} ${outcomes_entrant}"

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
export delimited using "${rep_output}/checks/missingness_summary.csv", replace

* 4) Transition identity checks
use "${prepared_data}", clear

quietly count if ${incumbent_var} == 1 & ${y_stay_school} == 1 & ${y_stay_district} != 1
local c_stay = r(N)

quietly count if ${incumbent_var} == 1 & !missing(${y_observed_t1}) & !missing(${y_stay_district}) & !missing(${y_switch_district}) & ${y_observed_t1} != ${y_stay_district} + ${y_switch_district}
local c_move_id = r(N)

quietly count if ${incumbent_var} == 1 & !missing(${y_observed_t1}) & !missing(${y_exit_public}) & ${y_observed_t1} + ${y_exit_public} != 1
local c_exit_id = r(N)

preserve
clear
set obs 1
gen fail_stay_school_impl_stay_district = `c_stay'
gen fail_observed_equals_stayplusswitch = `c_move_id'
gen fail_observed_plus_exit_equals_one = `c_exit_id'
export delimited using "${rep_output}/checks/transition_identity_checks.csv", replace
restore

* 5) Counts by year and treatment status
use "${prepared_data}", clear

sort ${year_var} ${id_teacher}
by ${year_var} ${id_teacher}: gen __tag_teacher = (_n == 1)
by ${year_var}: egen n_teachers = total(__tag_teacher)

sort ${year_var} ${id_school}
by ${year_var} ${id_school}: gen __tag_school = (_n == 1)
by ${year_var}: egen n_schools = total(__tag_school)

sort ${year_var} ${id_district}
by ${year_var} ${id_district}: gen __tag_district = (_n == 1)
by ${year_var}: egen n_districts = total(__tag_district)

bys ${year_var}: egen n_treated = total(${treat_var})
keep ${year_var} n_teachers n_schools n_districts n_treated
duplicates drop
gen treated_share_teacher_rows = n_treated / n_teachers
sort ${year_var}
export delimited using "${rep_output}/checks/year_level_counts.csv", replace
