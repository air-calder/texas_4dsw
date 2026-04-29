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
forvalues y = 22 / 25 { 
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
	keep if classroom_position == "Teacher of Record" | classroom_position == "Teacher Of Record"
	
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
	
Step 3. Append everything together and make sure variables are consistent across years
*/
clear
forvalues y = 15 / 25 { // unable to include 2012-2025 due to memory
	append using "E:\projects\2403-Evidence\project\data\intermediate\links_20`y'"
}	
memory
compress
memory 

// Final clean
drop subj_subcat

*E:\master_data\ERC_TEA Documents\p_subject_2008-2015
// Generate variables for subjects taught. 
gen teach_math = subject == "10"
gen teach_reading = inlist(subject, "22", "27")
gen teach_science = subject == "9"
gen teach_socialstudies = subject == "38"
gen teach_other = !inlist(subject, "10", "22", "27", "9", "38") 

// Generate variables for grades taught.
// Note: grade_level is wonky and these odd values occur within the same year across most years i.e. "40" "45" "04". In Gates, we didn't resolve or even destring this variable because we drop it in stu_tch_merge. 
// ideally we want to find codebook for this to understand what these 30+ codes mean. potentially secondary classes. as long as we know what they mean we can keep them. potentially keep KG but not PK. 
//tab grade_level, m
// GRADE_LEVEL |      Freq.     Percent        Cum.
// ------------+-----------------------------------
//          01 | 31,393,123        5.28        5.28
//          02 | 33,260,210        5.60       10.88
//          03 | 33,955,056        5.72       16.60
//          04 | 34,107,408        5.74       22.34
//          05 | 33,372,889        5.62       27.96
//          06 | 29,001,188        4.88       32.84
//          07 | 24,603,507        4.14       36.98
//          08 | 22,244,814        3.74       40.72
//          30 | 73,793,925       12.42       53.14
//          40 | 56,373,239        9.49       62.63
//          45 |188,465,275       31.72       94.36
//          50 |     62,358        0.01       94.37
//          60 |     21,586        0.00       94.37
//          70 | 23,570,449        3.97       98.34
//          KG |  8,093,567        1.36       99.70
//          PK |  1,786,017        0.30      100.00
// ------------+-----------------------------------
//       Total |594,104,611      100.00
replace grade_level = "00" if grade_level == "KG"
replace grade_level = "-01" if grade_level == "PK"
destring grade_level, replace

// By teacher id and school year get the maximum of the subject variables and grades taught.
foreach var in teach_math teach_reading teach_science teach_socialstudies teach_other {
	bys teachid syear: egen max_`var' = max(`var') 
} 
drop teach_math teach_reading teach_science teach_socialstudies teach_other
rename (max_teach_math max_teach_reading max_teach_science max_teach_socialstudies max_teach_other) (teach_math teach_reading teach_science teach_socialstudies teach_other)
bys teachid syear: egen tch_grade_min = min(grade_level)
bys teachid syear: egen tch_grade_max = max(grade_level)
bys teachid syear: egen tch_grade_mode = mode(grade_level), minmode

// Save all subjects. 
destring id1, gen(id1_num)
save "$clean/stu_tch_links_allsubjects", replace

// Keep math and ELA/reading
keep if inlist(subject, ///
	"98", ///		// Elementary
	"10", /// 		// Math
	"22", ///		// ELA
	"27")			// Reading
		
// Save only subjects in code block above. 
save "$clean/stu_tch_links", replace