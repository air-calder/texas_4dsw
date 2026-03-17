/*
Description: Consolidate teacher-level outputs into workbook and summary figures.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

capture mkdir "${rep_output}/tables"
capture mkdir "${rep_output}/figures"

local workbook "${rep_output}/tables/teacher_replication_results.xlsx"

capture confirm file "${rep_output}/tables/teacher_retention_main.csv"
if _rc == 0 {
    import delimited "${rep_output}/tables/teacher_retention_main.csv", clear
    export excel using "`workbook'", sheet("retention_main") firstrow(variables) sheetreplace
}

capture confirm file "${rep_output}/tables/teacher_retention_eventstudy.csv"
if _rc == 0 {
    import delimited "${rep_output}/tables/teacher_retention_eventstudy.csv", clear
    export excel using "`workbook'", sheet("retention_eventstudy") firstrow(variables) sheetreplace
}

capture confirm file "${rep_output}/tables/teacher_retention_heterogeneity.csv"
if _rc == 0 {
    import delimited "${rep_output}/tables/teacher_retention_heterogeneity.csv", clear
    export excel using "`workbook'", sheet("retention_heterogeneity") firstrow(variables) sheetreplace
}

capture confirm file "${rep_output}/tables/teacher_entrant_main.csv"
if _rc == 0 {
    import delimited "${rep_output}/tables/teacher_entrant_main.csv", clear
    export excel using "`workbook'", sheet("entrant_main") firstrow(variables) sheetreplace
}

capture confirm file "${rep_output}/tables/teacher_entrant_eventstudy.csv"
if _rc == 0 {
    import delimited "${rep_output}/tables/teacher_entrant_eventstudy.csv", clear
    export excel using "`workbook'", sheet("entrant_eventstudy") firstrow(variables) sheetreplace
}

capture confirm file "${rep_output}/tables/teacher_robustness.csv"
if _rc == 0 {
    import delimited "${rep_output}/tables/teacher_robustness.csv", clear
    export excel using "`workbook'", sheet("robustness") firstrow(variables) sheetreplace
}

* Final trend figures from descriptive outputs
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
            graph export "${rep_output}/figures/final_trend_`y'.png", replace width(1400) height(900)
        }
    }
}
