/*
Description: Global config for teacher-year replication scripts.
Update this file first before running the pipeline.
*/

version 17

* Root paths
global project_root "`c(pwd)'"
global rep_root "${project_root}/replication"
global rep_output "${rep_root}/output"

* Cleaned inputs from Code/ pipeline
global clean_data_dir "${project_root}/data/clean"
global clean_teacher_file "${clean_data_dir}/teacher_background.dta"
global clean_calendar_file "${clean_data_dir}/yearly_tracker_merge.dta"
global clean_rural_file "${clean_data_dir}/ccd_district_weighted.dta"
global clean_vam_prefix "${clean_data_dir}/vam_data_idsgroup"

* Replication working files
global analysis_data "${rep_output}/intermediate/teacher_year_analysis.dta"
global prepared_data "${rep_output}/intermediate/teacher_year_prepared.dta"
global unavailable_tally "${rep_output}/checks/unavailable_analyses.csv"

* Output folders
capture mkdir "${rep_output}"
capture mkdir "${rep_output}/intermediate"
capture mkdir "${rep_output}/checks"
capture mkdir "${rep_output}/descriptives"
capture mkdir "${rep_output}/tables"
capture mkdir "${rep_output}/figures"
capture mkdir "${rep_output}/logs"

* Analysis windows
global analysis_start_year 2017
global analysis_end_year 2024
global baseline_end_year 2019
global pretrend_end_year 2019
global event_min -3
global event_max 4

* IDs and treatment timing variables (EDIT TO MATCH YOUR DATA)
global id_teacher "teacher_id"
global id_school "school_id"
global id_district "district_id"
global year_var "school_year"
global treat_var "treated"
global ever_treat_var "ever_treated"
global adopt_year_var "adopt_year"
global event_time_var "event_time"
global matched_var "matched_sample"

* Optional sample flags used in robustness (EDIT IF AVAILABLE)
global rural_var "rural"
global hybrid_var "hybrid_calendar"
global adjacent_treated_var "adjacent_to_treated"

* Inputs for defensive duplicate handling and derived bins
global fte_var "fte"
global experience_var "experience"
global entrant_var "is_entrant"
global incumbent_var "is_incumbent"

* Derived transition outcomes (computed in 04_prepare_teacher_outcomes.do)
global y_observed_t1 "observed_t1"
global y_stay_school "stay_school_t1"
global y_stay_district "stay_district_t1"
global y_switch_district "switch_district_t1"
global y_exit_public "exit_tx_public_t1"
global y_turnover_teacher "turnover_teacher_t1"

* Entrant/sorting outcomes (expected in analysis file)
global y_in_from_tx "incoming_from_tx"
global y_in_first "incoming_first_time"
global y_in_alt "incoming_alt_path"
global y_in_exp "incoming_experience"
global y_in_advdeg "incoming_adv_degree"
global y_in_nodeg "incoming_no_degree"

* Candidate control lists (script drops unavailable vars automatically)
global teacher_controls_candidates "female certified ${experience_var} salary ${fte_var}"
global classroom_controls_candidates "class_size class_frpl_share class_nonwhite_share class_prior_ach"

* Heterogeneity candidates
global heter_binary_candidates "female exp_le5 exp_gt5 exp_gt9 certified"
global heter_continuous_candidates "class_size class_frpl_share class_nonwhite_share class_prior_ach"

* Covariates for baseline balance descriptives
global covars_balance "female certified ${experience_var} salary ${fte_var} class_size class_frpl_share class_nonwhite_share class_prior_ach"

* Outcome bundles
global outcomes_retention_main "${y_stay_school} ${y_stay_district} ${y_switch_district} ${y_exit_public}"
global outcomes_retention_trends "${y_stay_school} ${y_stay_district} ${y_exit_public}"
global outcomes_entrant "${y_in_from_tx} ${y_in_first} ${y_in_alt} ${y_in_exp} ${y_in_advdeg} ${y_in_nodeg}"
