/*
Description: Master runner for teacher-year replication pipeline.
*/

version 17
clear all
set more off

do "replication/01_config.do"

capture mkdir "${rep_output}"
capture mkdir "${rep_output}/logs"

local run_stamp = subinstr("`c(current_date)'", " ", "", .)
log using "${rep_output}/logs/master_`run_stamp'.log", text replace

local script_list "replication/04_prepare_teacher_outcomes.do replication/checks/01_data_integrity.do replication/checks/02_pretrend_checks.do replication/05_descriptives_teacher.do replication/06_teacher_retention_main.do replication/07_teacher_retention_eventstudy.do replication/08_teacher_retention_heterogeneity.do replication/09_teacher_entrant_sorting_main.do replication/10_teacher_entrant_eventstudy.do replication/11_teacher_robustness.do replication/12_tables_figures_teacher.do"

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
