/*
Description: Master runner for teacher-year replication pipeline.
Run from project root.
*/

version 17
clear all
set more off

// Must redirect working directory from personal folder to project folder -potentially due to server settings.
cd "E:\projects\2403-Evidence\project"

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"
capture mkdir "replication/output/checks"
capture mkdir "replication/output/descriptives"
capture mkdir "replication/output/tables"
capture mkdir "replication/output/figures"
capture mkdir "replication/output/logs"
local codedirectory "E:/projects/2403-Evidence/project/code/4DSW student teacher analysis/replication"

local run_stamp = subinstr("`c(current_date)'", " ", "", .)
log using "code/4DSW student teacher analysis/replication/output/logs/master_`run_stamp'.log", text replace

// if there is no error commented then the code file ran successfully
foreach f in "01_build_classroom_controls_teacher_year.do" ///
			"02a_teacher_school_crosswalk.do" ///
			"02_build_teacher_year_prepared.do" ///
			"03_descriptives_teacher.do" /// 
			"04_teacher_retention_main.do" ///
			"05_teacher_retention_eventstudy.do" ///
			"06_teacher_retention_heterogeneity.do" ///
			"07_teacher_entrant_sorting_main.do" ///
			"08_teacher_entrant_eventstudy.do" ///
			"09_teacher_robustness.do" /// 
			"10_tables_figures_teacher.do" /// we don't have the data in lines 44-60. commented out for now
			"11_unavailable_analyses_tally.do" ///
			"12_teacher_csdid.do" /// error after line 94: Units always treated found. These will be excluded. panels are not nested within clusters. csdid failed for outcome stay_school_t1 with anticipation(0)
			"13_prior_lit_descriptives_feasible.do" /// we dont have any of the lawson or khalid dta's required in this code file 
			"14_teacher_retention_quartiles" ///
			"checks/01_data_integrity.do" /// 
			"checks/02_pretrend_checks.do" { 
    local fullpath "`codedirectory'/`f'"
	display "`codedirectory'"
    di as text "Running `fullpath' ..."
    capture noisily do `"`fullpath'"'
    if _rc {
        di as error "FAILED: `f' (return code `_rc')"
        log close
        exit _rc
    }
}

di as result "Replication pipeline completed successfully."
log close

// FERPA update all code files except after code file 10