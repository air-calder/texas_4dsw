/*
Description: Consolidate teacher-level outputs into workbook and summary figures.
Run from project root.
Fail fast if required module outputs are missing.
*/

version 17

capture mkdir "replication/output/tables"
capture mkdir "replication/output/figures"

foreach f in replication/output/tables/teacher_retention_main.csv replication/output/tables/teacher_retention_eventstudy.csv replication/output/tables/teacher_retention_heterogeneity.csv replication/output/tables/teacher_entrant_main.csv replication/output/tables/teacher_entrant_eventstudy.csv replication/output/tables/teacher_robustness.csv replication/output/descriptives/retention_trends_by_group.dta {
    capture confirm file "`f'"
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "12_tables_figures" "final_outputs" "`f'" "missing_required_input_file"
        di as error "Missing required file: `f'"
        exit 601
    }
}

local workbook "replication/output/tables/teacher_replication_results.xlsx"

import delimited "replication/output/tables/teacher_retention_main.csv", clear
export excel using "`workbook'", sheet("retention_main") firstrow(variables) sheetreplace

import delimited "replication/output/tables/teacher_retention_eventstudy.csv", clear
export excel using "`workbook'", sheet("retention_eventstudy") firstrow(variables) sheetreplace

import delimited "replication/output/tables/teacher_retention_heterogeneity.csv", clear
export excel using "`workbook'", sheet("retention_heterogeneity") firstrow(variables) sheetreplace

import delimited "replication/output/tables/teacher_entrant_main.csv", clear
export excel using "`workbook'", sheet("entrant_main") firstrow(variables) sheetreplace

import delimited "replication/output/tables/teacher_entrant_eventstudy.csv", clear
export excel using "`workbook'", sheet("entrant_eventstudy") firstrow(variables) sheetreplace

import delimited "replication/output/tables/teacher_robustness.csv", clear
export excel using "`workbook'", sheet("robustness") firstrow(variables) sheetreplace

use "replication/output/descriptives/retention_trends_by_group.dta", clear
foreach v in syear ever4DSW stay_school_t1 stay_district_t1 exit_tx_public_t1 {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "12_tables_figures" "final_outputs" "`v'" "missing_required_variable_in_trend_file"
        di as error "Missing required variable `v' in retention trends file"
        exit 459
    }
}

foreach y in stay_school_t1 stay_district_t1 exit_tx_public_t1 {
    twoway ///
        (line `y' syear if ever4DSW == 0, sort lcolor(navy)) ///
        (line `y' syear if ever4DSW == 1, sort lcolor(maroon)), ///
        legend(order(1 "Never treated" 2 "Ever treated")) ///
        xtitle("School year") ytitle("Mean `y'")
    graph export "replication/output/figures/final_trend_`y'.png", replace width(1400) height(900)
}
