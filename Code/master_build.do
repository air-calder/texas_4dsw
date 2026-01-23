/*
Description: This .do file runs a handful of files for the 4DSW project in Texas.
Author: Jamie Klinenberg
*/
clear
set max_memory 100g
// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global clean "E:/projects/2403-Evidence/project/code"

// Load in cleaned student demographics (from TEA)
		include "$code/stu_attend_demog"
		include "$code/stu_enroll_demog"
		
// Cleaning student test
		include "$code/testing_stack"
		include "$code/testing_clean"
		
// Cleaning teacher data
		include "$code/stu_teach_links"
		include "$code/teacher_background"
		
// Merging
		include "$code/student_merge"
		include "$code/stu_tch_merge"
		