/*
Description: Master runner for teacher-year replication pipeline.
Run from project root.
*/

version 17
clear all
set more off

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"
capture mkdir "replication/output/descriptives"
capture mkdir "replication/output/tables"
capture mkdir "replication/output/figures"
capture mkdir "replication/output/logs"

local run_stamp = subinstr("`c(current_date)'", " ", "", .)
log using "replication/output/logs/master_`run_stamp'.log", text replace

local script_list "replication/01_build_classroom_controls_teacher_year.do replication/02_build_teacher_year_prepared.do replication/checks/01_data_integrity.do replication/checks/02_pretrend_checks.do replication/03_descriptives_teacher.do replication/04_teacher_retention_main.do replication/05_teacher_retention_eventstudy.do replication/06_teacher_retention_heterogeneity.do replication/07_teacher_entrant_sorting_main.do replication/08_teacher_entrant_eventstudy.do replication/09_teacher_robustness.do replication/10_tables_figures_teacher.do replication/11_unavailable_analyses_tally.do"

foreach f of local script_list {
    di as text "Running `f' ..."
    capture noisily do "`f'"
    if _rc {
        di as error "FAILED: `f' (return code `_rc')"
        log close
        exit _rc
    }
}

di as result "Replication pipeline completed successfully."
log close
