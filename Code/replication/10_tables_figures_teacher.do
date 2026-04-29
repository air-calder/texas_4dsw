/*
Description: Consolidate teacher-level outputs into workbook and summary figures.
Run from project root.
Fail fast if required module outputs are missing.
*/

version 17

capture mkdir "code/4DSW student teacher analysis/replication/output/tables"
capture mkdir "code/4DSW student teacher analysis/replication/output/figures"

local workbook "code/4DSW student teacher analysis/replication/output/tables/teacher_replication_results.xlsx"

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_main.csv", clear
export excel using "`workbook'", sheet("retention_main") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_eventstudy.csv", clear
export excel using "`workbook'", sheet("retention_eventstudy") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_heterogeneity.csv", clear
export excel using "`workbook'", sheet("retention_heterogeneity") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_entrant_main.csv", clear
export excel using "`workbook'", sheet("entrant_main") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_entrant_eventstudy.csv", clear
export excel using "`workbook'", sheet("entrant_eventstudy") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_robustness.csv", clear
export excel using "`workbook'", sheet("robustness") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_main.csv", clear
export excel using "`workbook'", sheet("csdid_ret_main") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_retention_eventstudy.csv", clear
export excel using "`workbook'", sheet("csdid_ret_event") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_entrant_main.csv", clear
export excel using "`workbook'", sheet("csdid_ent_main") firstrow(variables) sheetreplace

import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_entrant_eventstudy.csv", clear
export excel using "`workbook'", sheet("csdid_ent_event") firstrow(variables) sheetreplace

// import delimited "code/4DSW student teacher analysis/replication/output/tables/teacher_csdid_cohort_effects.csv", clear
// export excel using "`workbook'", sheet("csdid_cohorts") firstrow(variables) sheetreplace
//
// import delimited "code/4DSW student teacher analysis/replication/output/descriptives/lawson_table1_feasible.csv", clear
// export excel using "`workbook'", sheet("lawson_t1_feasible") firstrow(variables) sheetreplace
//
// import delimited "code/4DSW student teacher analysis/replication/output/descriptives/lawson_table2_feasible.csv", clear
// export excel using "`workbook'", sheet("lawson_t2_feasible") firstrow(variables) sheetreplace
//
// import delimited "code/4DSW student teacher analysis/replication/output/descriptives/khalid_table1_feasible.csv", clear
// export excel using "`workbook'", sheet("khalid_t1_feasible") firstrow(variables) sheetreplace
//
// import delimited "code/4DSW student teacher analysis/replication/output/descriptives/khalid_table2_feasible.csv", clear
// export excel using "`workbook'", sheet("khalid_t2_feasible") firstrow(variables) sheetreplace
//
// import delimited "code/4DSW student teacher analysis/replication/output/descriptives/prior_lit_descriptive_gaps.csv", clear
// export excel using "`workbook'", sheet("prior_lit_gaps") firstrow(variables) sheetreplace

use "code/4DSW student teacher analysis/replication/output/descriptives/retention_trends_by_group.dta", clear
foreach v in syear ever4DSW stay_school_t1 stay_district_t1 exit_tx_public_t1 {
    capture confirm variable `v'
    if _rc {
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
    graph export "code/4DSW student teacher analysis/replication/output/figures/final_trend_`y'.png", replace width(1400) height(900)
}
