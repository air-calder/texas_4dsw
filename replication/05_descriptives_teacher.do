/*
Description: Descriptive tables and trend files for teacher-year panel.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/descriptives"
capture mkdir "${rep_output}/figures"

* 1) Sample counts by year
preserve
sort ${year_var} ${id_teacher}
by ${year_var} ${id_teacher}: gen __tag_teacher = (_n == 1)
by ${year_var}: egen n_teachers = total(__tag_teacher)

sort ${year_var} ${id_school}
by ${year_var} ${id_school}: gen __tag_school = (_n == 1)
by ${year_var}: egen n_schools = total(__tag_school)

sort ${year_var} ${id_district}
by ${year_var} ${id_district}: gen __tag_district = (_n == 1)
by ${year_var}: egen n_districts = total(__tag_district)

bys ${year_var}: egen n_treated_rows = total(${treat_var})
keep ${year_var} n_teachers n_schools n_districts n_treated_rows
duplicates drop
gen treated_row_share = n_treated_rows / n_teachers
sort ${year_var}
export delimited using "${rep_output}/descriptives/sample_counts_by_year.csv", replace
restore

* 2) Adoption timing distribution at teacher-row level
preserve
keep if ${ever_treat_var} == 1
contract ${adopt_year_var}
rename _freq n_teacher_rows
export delimited using "${rep_output}/descriptives/adoption_timing_distribution.csv", replace
restore

* 3) Pre-period balance means by ever-treated status
preserve
keep if ${year_var} <= ${baseline_end_year}
collapse (mean) ${covars_balance} ${outcomes_retention_main}, by(${ever_treat_var})
export delimited using "${rep_output}/descriptives/preperiod_balance_means.csv", replace
restore

* 4) Retention trends among incumbents by ever-treated status
preserve
keep if ${incumbent_var} == 1
collapse (mean) ${outcomes_retention_trends}, by(${year_var} ${ever_treat_var})
save "${rep_output}/descriptives/retention_trends_by_group.dta", replace
export delimited using "${rep_output}/descriptives/retention_trends_by_group.csv", replace
restore

* 5) Entrant outcome trends by ever-treated status (if entrant flag exists)
capture confirm variable ${entrant_var}
if _rc == 0 {
    preserve
    keep if ${entrant_var} == 1
    collapse (mean) ${outcomes_entrant}, by(${year_var} ${ever_treat_var})
    save "${rep_output}/descriptives/entrant_trends_by_group.dta", replace
    export delimited using "${rep_output}/descriptives/entrant_trends_by_group.csv", replace
    restore
}

* 6) Trend figures for retention outcomes
capture confirm file "${rep_output}/descriptives/retention_trends_by_group.dta"
if _rc == 0 {
    use "${rep_output}/descriptives/retention_trends_by_group.dta", clear
    foreach y of global outcomes_retention_trends {
        capture confirm variable `y'
        if _rc == 0 {
            twoway ///
                (line `y' ${year_var} if ${ever_treat_var} == 0, sort lcolor(navy)) ///
                (line `y' ${year_var} if ${ever_treat_var} == 1, sort lcolor(maroon)), ///
                legend(order(1 "Never treated" 2 "Ever treated")) ///
                xtitle("School year") ytitle("Mean `y'")
            graph export "${rep_output}/figures/trend_`y'.png", replace width(1400) height(900)
        }
    }
}
