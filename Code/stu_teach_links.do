/*
Description: Create dataset with student teacher links for 4DSW project - using Alejandra's code from Gates Math TX
Author: Jamie Klinenberg
Notes: need to clear out space on the disk in order to run all of this code
*/

clear
set max_memory 100g
// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

/*
Years 2012-2019, we need info from 3 separate files. Doing this year by year and save the yearly version.

Classroom Role
1	Teacher of Record
2	Assistant Teacher
3	Support Teacher
4	Substitute Teacher
5	PK Classroom Aide
*/

// 2012-2019 ran and saved individually.
forvalues y = 12 / 19 {
	
	// 1A. Students
	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_stud_class_enroll`y'", clear
	rename *, lower
	
	keep id1 campus service course_seq class_id
	duplicates drop
	tempfile stu
	save `stu', replace
	
	// 1B. 
	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_teacher_class_assign`y'", clear
	rename *, lower
	
	* keep teacher of record
	tab class_role
	keep if class_role == "01"
	
	* keep teachers (not subs)
	tab role
	keep if role == "087"
	
	keep id1 campus service course_seq class_id
	rename id1 teachid
	
	duplicates drop
	tempfile tch
	save `tch', replace
	
	// 1C. Course info
	use  "E:\master_data\ERC_TEA Documents\Stata_TEA_Key_Files\p_service`y'.dta", clear
	rename *, lower
	keep service servicex servgrp1 subject subjarea subj_subcat grade_level adv_course elig_hs_credit
	
	tempfile course
	save `course', replace


	// 1D. Join
	use `stu', clear
	joinby campus service course_seq class_id using `tch'
	merge m:1 service using `course'
	assert _merge!=1 // confirming all students and teachers merged with course data
	drop if _merge==2 // drop any courses that didn't have students or teachers
	drop _merge
	gen syear = 20`y'
	
	save "$intermediate/links_20`y'", replace
}

/* 
Step 2. 2020+
*/

// 2020 and 2021 has one file that has both stu and tch (p_class_roster_wntr`y') 
forvalues y = 20 / 21 {
	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_class_roster_wntr`y'", clear
	rename *, lower
	
	keep if role == "087"
	keep if classroom_position == "Teacher of Record"
	
	* variable names need to be consistent with older data
	rename student_id1 id1
	rename campus_id campus
	rename class_id_number class_id
	rename staff_id1 teachid
	rename service_id service
	rename course_sequence course_seq
	
	keep id1 campus service course_seq class_id teachid
	duplicates drop
	tempfile links
	save `links', replace
	
	* course
	use "E:\master_data\ERC_TEA Documents\Stata_TEA_Key_Files\p_service`y'.dta", clear
	rename *, lower
	keep service servicex servgrp1 subject subjarea subj_subcat grade_level adv_course elig_hs_credit
	
	tempfile course
	save `course', replace
	
	use `links', clear
	merge m:1 service using `course'
	assert _merge!=1 // confirming all students and teachers merged with course data
	drop if _merge==2 // drop any courses that didn't have students or teachers 
	drop _merge
	gen syear = 20`y'
	
	save "$intermediate/links_20`y'", replace
}

// 2022 and 2023. we're back to separate files for teacher and student_id1
forvalues y = 22 / 23 {
	* student
	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_class_roster_student_wntr`y'", clear
	rename *, lower
	
	* variable names need to be consistent with older data
	rename student_id1 id1
	rename campus_id campus
	rename class_id_number class_id
	rename service_id service
	rename course_sequence course_seq
	
	keep id1 campus service course_seq class_id
	duplicates drop
	save "$intermediate/stu_`y'", replace
	
	* teacher
	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_class_roster_staff_wntr`y'", clear
	rename *, lower
	
	* keep teacher of record
	tab classroom_position
	keep if classroom_position == "Teacher of Record"
	
	* keep teachers (not subs)
	tab role_id
	keep if role_id == "087"
	
	rename staff_id1 teachid
	rename campus_id campus
	rename class_id_number class_id
	rename course_sequence_code course_seq
	rename service_id service
	
	keep teachid campus service course_seq class_id
	
	duplicates drop
	tempfile tch
	save "$intermediate/tch_`y'", replace
	
	* course
	use "E:\master_data\ERC_TEA Documents\Stata_TEA_Key_Files\p_service`y'.dta", clear
	rename *, lower
	drop servicex_long course_abbrev dtupdate
	
	tempfile course
	save "$intermediate/course_`y'", replace
	
	* Join
	use "$intermediate/stu_`y'", clear
	joinby campus service course_seq class_id using "$intermediate/tch_`y'"
	merge m:1 service using "$intermediate/course_`y'"
	assert _merge!=1 // confirming all students and teachers merged with course data
	drop if _merge==2 // drop any courses that didn't have students or teachers 
	drop _merge
	gen syear = 20`y'

	save "$intermediate/links_20`y'", replace
	
	}
	
/* Step 3. Append everything together and make sure variables are consistent across years
*/
clear
forvalues y = 12 / 23 {
	append using "E:\projects\2403-Evidence\project\data\intermediate\links_20`y'"
}	

// Final clean
drop subj_subcat

// Final save
compress
destring id1, gen(id1_num)
save "$clean/stu_tch_links", replace
