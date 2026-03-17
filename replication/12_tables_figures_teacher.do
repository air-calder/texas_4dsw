/*
Description: Consolidate teacher-level outputs into workbook and summary figures.
Run from project root.
*/

version 17

capture mkdir "replication/output/tables"
capture mkdir "replication/output/figures"

local workbook "replication/output/tables/teacher_replication_results.xlsx"

capture confirm file "replication/output/tables/teacher_retention_main.csv"
if _rc == 0 {
    import delimited "replication/output/tables/teacher_retention_main.csv", clear
    export excel using "`workbook'", sheet("retention_main") firstrow(variables) sheetreplace
}

capture confirm file "replication/output/tables/teacher_retention_eventstudy.csv"
if _rc == 0 {
    import delimited "replication/output/tables/teacher_retention_eventstudy.csv", clear
    export excel using "`workbook'", sheet("retention_eventstudy") firstrow(variables) sheetreplace
}

capture confirm file "replication/output/tables/teacher_retention_heterogeneity.csv"
if _rc == 0 {
    import delimited "replication/output/tables/teacher_retention_heterogeneity.csv", clear
    export excel using "`workbook'", sheet("retention_heterogeneity") firstrow(variables) sheetreplace
}

capture confirm file "replication/output/tables/teacher_entrant_main.csv"
if _rc == 0 {
    import delimited "replication/output/tables/teacher_entrant_main.csv", clear
    export excel using "`workbook'", sheet("entrant_main") firstrow(variables) sheetreplace
}

capture confirm file "replication/output/tables/teacher_entrant_eventstudy.csv"
if _rc == 0 {
    import delimited "replication/output/tables/teacher_entrant_eventstudy.csv", clear
    export excel using "`workbook'", sheet("entrant_eventstudy") firstrow(variables) sheetreplace
}

capture confirm file "replication/output/tables/teacher_robustness.csv"
if _rc == 0 {
    import delimited "replication/output/tables/teacher_robustness.csv", clear
    export excel using "`workbook'", sheet("robustness") firstrow(variables) sheetreplace
}

capture confirm file "replication/output/descriptives/retention_trends_by_group.dta"
if _rc == 0 {
    use "replication/output/descriptives/retention_trends_by_group.dta", clear
    foreach y in stay_school_t1 stay_district_t1 exit_tx_public_t1 {
        capture confirm variable `y'
        if _rc == 0 {
            twoway ///
                (line `y' syear if ever4DSW == 0, sort lcolor(navy)) ///
                (line `y' syear if ever4DSW == 1, sort lcolor(maroon)), ///
                legend(order(1 "Never treated" 2 "Ever treated")) ///
                xtitle("School year") ytitle("Mean `y'")
            graph export "replication/output/figures/final_trend_`y'.png", replace width(1400) height(900)
        }
    }
}
