/*
Description: Merge all student and teacher data for each subject we want student-teacher match not to appear more than once - using Alejandra's code from Gates Math TX
Author: Jamie Klinenberg
Notes: 
*/

clear
set max_memory 200g

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

/**************************************************************************
Step 1: With subject constraints
****************************************************************************/
// Load student teacher links data
use "$clean/stu_tch_links", clear

	// Drop if id1 is missing
	drop if mi(id1)

	// Class size restrictions
	bys campus class_id teachid syear: gen num_students = _N
	su num_students, d
	drop if num_students < r(p1) | num_students > r(p99)
	drop id1_num
	destring id1, gen(id1_num)

	compress 

	replace subject = "22" if subject == "27" // Reading = 27 and ELA = 22. Replace reading code with ELA code

	// Consolidate courses
	// Consolidate student-teacher-subject links
	bys campus id1_num subject teachid syear (num_students): gen course2 = course_seq[1]
	bys campus id1_num subject teachid syear (num_students): gen service2 = service[1]
	bys campus id1_num subject teachid syear (num_students): gen servicex2 = servicex[1]
	bys campus id1_num subject teachid syear (num_students): gen class_id2 = class_id[1]

	replace course_seq = course2
	replace service = service2
	replace servicex = servicex2
	replace class_id = class_id2

	keep id1 campus subject teachid syear course_seq service servicex class_id teach_math teach_reading teach_science teach_socialstudies teach_other tch_grade_min tch_grade_max tch_grade_mode
	duplicates drop

	duplicates report campus id1 subject teachid syear
	assert r(unique_value) == r(N)

	// Flag student and teacher courses in each subject
	sort id1 syear teachid
	foreach sub in "10" "22" "98" { // grade level courses, math, ela
		by id1 syear: egen student_has_`sub' = max(cond(subject == "`sub'", 1, 0))
		by id1 syear teachid: egen teacher_has_`sub' = max(cond(subject == "`sub'", 1, 0))
		
	}

	// If student has teacher of record in each of the other core courses, then drop entirely
	count if subject == "98" & student_has_98 == 1 & student_has_22 == 1 & student_has_10 == 1
	drop if subject == "98" & student_has_98 == 1 & student_has_22 == 1 & student_has_10 == 1

	// Drop if student has multiple all-subject classes
	egen tag = tag(id1 syear campus class_id)
	bys id1 syear campus subject: egen num_classes = total(tag)
	tab num_classes subject
	drop if subject == "98" & num_classes > 1
	drop tag num_classes

	// If student only has single all-subject class, expand with one entry per missing subject
	foreach sub in 10 22 {
		expand 2 if subject == "98" & student_has_`sub' == 0, gen(_t)
		replace subject = "`sub'" if _t == 1
		drop _t
	}

	drop if subject == "98"
	drop student_has_* teacher_has_*

	// Drop student with more than 2 matches per subject
	egen tag_teacher = tag(id1 syear subject teachid)
	bys id1 syear subject: egen num_teachers = total(tag_teacher)
	tab num_teachers
	egen tag_student = tag(id1 syear subject)
	tab num_teachers if tag_student
	drop if num_teachers > 2

	gen teach_weight = 1 / num_teachers
	su teach_weight, d
	drop tag_student num_teachers tag_teacher

	duplicates report id1 syear subject // dups expected here (multiple teachers per subject)

	rename class_id section_id

	// Label all variables
	lab var teachid "Teacher ID"
	lab var campus "Campus code"
	lab var syear "School year"
	lab var id1 "Student ID"
	lab var service "Course code"
	lab var course_seq "Course sequence"
	lab var servicex "Course title"
	lab var subject "Subject code"
	lab var teach_weight "Teacher weight"
	lab var section_id "Section ID"

	compress
	memory

save "$clean/stu_tch_merged", replace		

// Add additional variables needed for VAMs from student data 
use "$clean/stu_tch_merged", clear
destring campus, replace
merge m:1 id1 syear using "$clean/student_merged"
drop if _merge==1
drop if _merge==2  
compress

// Create "test" variable that is the standardized math score if subject is math (10) and the standardized ela score if subject is ela (22)
gen test = m_ssc_std
replace test = r_ssc_std if subject == "22"

// Level or "lvl" is an indicator at the student level for whether their grade is 6 or higher
gen level = 1
replace level = 2 if inlist(grade, "6", "7", "8", "9", "10", "11", "12")

// Generate broken down race variables
drop amer_ind_alask asian black_african_amer hawaiian_pac_islander white hisp_latino
gen white = race == 5
gen black = race == 3
gen hispanic = race == 4
gen asian = race == 2
gen other = race == 1
compress

// Classroom menas, classx = classroom means
sort campus syear teachid section_id
foreach var of varlist lep speced gifted female frl white black hispanic asian other lag_r_ssc_std lag_m_ssc_std {
	by campus syear teachid section_id: egen classx_`var' = mean(`var')
	
}

// Destring teacher ID
destring teachid, replace
	
// Drop variables we don't need, most of these are empty.
drop id2 id1_num invalid_id1_flag state_assigned_flag sex ethnic ada_eligible lep_language lep_permission economic at_risk title1  bilingual esl  voced_stat immigrant dtupdate date_update migrant_ind over_report even_start attribution as_of_status pk_military bil_pgm esl_pgm pk_foster crisis_ind campus_accnt campus_accnt_rpt ethnic_old eth_race unsch_asyl_ref homeless_status unaccomp_youth early_reading tstem_ind echs_ind iep_continuer_ind fhsp_college_instr_ind dup_id student_lang_cd assoc_degree_ind star_of_tx_ind p_tech_ind interv_strategy_ind sect_504_ind alt_lang_pgm new_tech_ind foster_care military_connect parent_req_rtn_ind district_attend bil_esl_attend gifted_attend pep_attend preg_rl_attend se_attend ve_attend pct_attend att_mult_cmptype src_campus_acc disability_flag mult_disabled_flag discipline_flag title1_flag lep_attend ood_campus_accnt ood_district_accnt ood_mult_cmptype ood_src_campus_acc last_enroll_date fhsp_college_inst_ind dyslexia_risk_cd pk_elig_py_ind adult_prev_attend_ind gen_ed_homebnd_ind dyslexia_ind dyslexia_scr_exc_rsn r_ssc m_ssc a1_ssc a2_ssc ge_ssc prior_r_ssc prior_m_ssc id lag_pct_attend lag2_pct_attend lag3_pct_attend _merge

// Final save 
compress
destring grade, replace
count if grade == . // 0
save "$clean/vam_data", replace
stop 

// unable to save the unrestricted dataset below since it would be 130 million KB
// re-evalutate the code process below later
/*****************************************************************************
Step 2: Without subject constraints
******************************************************************************/
// Load student teacher links data
use "$clean/stu_tch_links_allsubjects", clear
egen total_ids = count(id1_num)
local group_size = total_ids / 4
list id1_num in `group_size'
list id1_num in `= 2 * `group_size''
list id1_num in `= 3 * `group_size''

gen group = ceil(_n / `group_size')

forvalues i = 1 / 4 {
	preserve
	keep if group == `i'
	save "$clean/stu_tch_linksall_idsgroup`i'", replace
	restore
}

use "$clean/stu_tch_links_allsubjects", clear
		keep if id1_num<=5694176
		save "$clean/stu_tch_linksall_idsgroup1", replace
use "$clean/stu_tch_links_allsubjects", clear
		keep if id1_num>5694176 & id1_num<=13697170
		save "$clean/stu_tch_linksall_idsgroup2", replace
use "$clean/stu_tch_links_allsubjects", clear
		keep if id1_num>13697170 & id1_num<=17100743 
		save "$clean/stu_tch_linksall_idsgroup3", replace
use "$clean/stu_tch_links_allsubjects", clear
		keep if id1_num>17100743
		save "$clean/stu_tch_linksall_idsgroup4", replace	
	
forval i = 1 / 4 {
    use "$clean/stu_tch_linksall_idsgroup`i'", clear
		//Drop if missing student ID
	drop if mi(id1)

	// Class size restrictions
	bys campus class_id teachid syear: gen num_students = _N
	su num_students, d
	drop if num_students < r(p1) | num_students > r(p99)
	drop id1_num
	destring id1, gen(id1_num)

	compress 

	replace subject = "22" if subject == "27" // Reading = 27 and ELA = 22. Replace reading code with ELA code

	// Consolidate courses
	// Consolidate student-teacher-subject links
	bys campus id1_num subject teachid syear (num_students): gen course2 = course_seq[1]
	bys campus id1_num subject teachid syear (num_students): gen service2 = service[1]
	bys campus id1_num subject teachid syear (num_students): gen servicex2 = servicex[1]
	bys campus id1_num subject teachid syear (num_students): gen class_id2 = class_id[1]

	replace course_seq = course2
	replace service = service2
	replace servicex = servicex2
	replace class_id = class_id2

	keep id1 campus subject teachid syear course_seq service servicex class_id teach_math teach_reading teach_science teach_socialstudies teach_other tch_grade_min tch_grade_max tch_grade_mode
	duplicates drop

	duplicates report campus id1 subject teachid syear
	assert r(unique_value) == r(N)

	// Flag student and teacher courses in each subject
	sort id1 syear teachid
	foreach sub in "10" "22" "98" { // grade level courses, math, ela
		by id1 syear: egen student_has_`sub' = max(cond(subject == "`sub'", 1, 0))
		by id1 syear teachid: egen teacher_has_`sub' = max(cond(subject == "`sub'", 1, 0))
		
	}

	// If student has teacher of record in each of the other core courses, then drop entirely
	count if subject == "98" & student_has_98 == 1 & student_has_22 == 1 & student_has_10 == 1
	drop if subject == "98" & student_has_98 == 1 & student_has_22 == 1 & student_has_10 == 1

	// Drop if student has multiple all-subject classes
	egen tag = tag(id1 syear campus class_id)
	bys id1 syear campus subject: egen num_classes = total(tag)
	tab num_classes subject
	drop if subject == "98" & num_classes > 1
	drop tag num_classes

	// If student only has single all-subject class, expand with one entry per missing subject
	foreach sub in 10 22 {
		expand 2 if subject == "98" & student_has_`sub' == 0, gen(_t)
		replace subject = "`sub'" if _t == 1
		drop _t
	}

	drop if subject == "98"
	drop student_has_* teacher_has_*

	// Drop student with more than 2 matches per subject
	egen tag_teacher = tag(id1 syear subject teachid)
	bys id1 syear subject: egen num_teachers = total(tag_teacher)
	tab num_teachers
	egen tag_student = tag(id1 syear subject)
	tab num_teachers if tag_student
	drop if num_teachers > 2

	gen teach_weight = 1 / num_teachers
	su teach_weight, d
	drop tag_student num_teachers tag_teacher

	duplicates report id1 syear subject // dups expected here (multiple teachers per subject)

	rename class_id section_id

	// Label all variables
	lab var teachid "Teacher ID"
	lab var campus "Campus code"
	lab var syear "School year"
	lab var id1 "Student ID"
	lab var service "Course code"
	lab var course_seq "Course sequence"
	lab var servicex "Course title"
	lab var subject "Subject code"
	lab var teach_weight "Teacher weight"
	lab var section_id "Section ID"

	compress
	memory

save "$clean/allstu_tch_merged_idsgroup`i'", replace
}		

// Add additional variables needed for VAMs.
// loop over the three datasets
forval i = 1 / 4 {
use "$clean/allstu_tch_merged_idsgroup`i'", clear
destring campus, replace
merge m:1 id1 syear using "$clean/student_merged_idsgroup`i'"
	drop if _merge==1
	drop if _merge==2  


// Create "test" variable that is the standardized math score if subject is math (10) and the standardized ela score if subject is ela (22)
gen test = m_ssc_std
replace test = r_ssc_std if subject == "22"

// Level or "lvl" is an indicator at the student level for whether their grade is 6 or higher
gen level = 1
replace level = 2 if inlist(grade, 6, 7, 8, 9, 10, 11, 12)

// Generate broken down race variables
drop amer_ind_alask asian black_african_amer hawaiian_pac_islander white hisp_latino
gen white = race == 5
gen black = race == 3
gen hispanic = race == 4
gen asian = race == 2
gen other = race == 1

compress
memory

// Classroom menas, classx = classroom means
sort campus syear teachid section_id
foreach var of varlist lep speced gifted female frl white black hispanic asian other lag_r_ssc_std lag_m_ssc_std {
	by campus syear teachid section_id: egen classx_`var' = mean(`var')
	
}

// Destring teacher ID
	destring teachid, replace

	save "$clean/vam_data_allsubj_idsgroup`i'", replace
	
// Drop variables we don't need, most of these are empty.
drop id2 id1_num invalid_id1_flag state_assigned_flag sex ethnic ada_eligible lep_language lep_permission economic at_risk title1  bilingual esl  voced_stat immigrant dtupdate date_update migrant_ind over_report even_start attribution as_of_status pk_military bil_pgm esl_pgm pk_foster crisis_ind campus_accnt campus_accnt_rpt ethnic_old eth_race unsch_asyl_ref homeless_status unaccomp_youth early_reading tstem_ind echs_ind iep_continuer_ind fhsp_college_instr_ind dup_id student_lang_cd assoc_degree_ind star_of_tx_ind p_tech_ind interv_strategy_ind sect_504_ind alt_lang_pgm new_tech_ind foster_care military_connect parent_req_rtn_ind district_attend bil_esl_attend gifted_attend pep_attend preg_rl_attend se_attend ve_attend pct_attend att_mult_cmptype src_campus_acc disability_flag mult_disabled_flag discipline_flag title1_flag lep_attend ood_campus_accnt ood_district_accnt ood_mult_cmptype ood_src_campus_acc last_enroll_date fhsp_college_inst_ind dyslexia_risk_cd pk_elig_py_ind adult_prev_attend_ind gen_ed_homebnd_ind dyslexia_ind dyslexia_scr_exc_rsn r_ssc m_ssc a1_ssc a2_ssc ge_ssc prior_r_ssc prior_m_ssc id lag_pct_attend lag2_pct_attend lag3_pct_attend _merge

}

/******************************Apppend groups 1-4 and save.*****************/
/// need to run this part only!!
use "$clean/vam_data_allsubj_idsgroup1", clear 
append using "$clean/vam_data_allsubj_idsgroup2" "$clean/vam_data_allsubj_idsgroup3" "$clean/vam_data_allsubj_idsgroup4"
save "$clean/vam_data_allsubjects", replace