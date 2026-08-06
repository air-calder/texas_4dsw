/*
Description: Create dataset with student testing data for 4DSW project - using Alejandra's code from Gates Math TX
Author: Jamie Klinenberg using Ben and Alejandra's Code


// Sources: (1) Annual academic calendars -> E:\master_data\ERC_TEA Documents\TEA Testing Dates
			(2) Data dictionary -> E:\master_data\Testing Documents\TAKS\TAKS Manuals
				* We can ignore anything that says pilot or retake
Score code information (251-251 1 READING/ELA)
A = Absent
X = Student is ARD exempt, do not score (exit level)
L = Student is LEP exempt, do not score (grades 3-10)
P = Previously Met Standard (Grades 3 and 5 and exit level retest administrations)
O = Other (e.g., illness, cheating)
Y = Student did not take the English-version reading test, do not score (Grades 4 and 6 April Grade 5 June)
Z = Student did not take the Spanish-version reading test, do not score (Grades 4 and 6 April Grade 5 June)
Q = Student did not take the TAKS reading tests, do not score (Grades 3 and 5 February and Grades 4, 6, 7, and 8 April)
S = Score
C = Student did not take the paper-version reading test and an online-version reading test for this student could not be matched to the student's paper-version record (Grade 8 and June exit level retest)
W = Parental Waiver: Parent or guardian requested that a student not participate in the third TAKS reading test opportunity (Grades 3 and 5 June administration)
R = ARD Committee has determined after the April test administration that TAKS reading is not appropriate for the student (Grades 3 and 5 June administration)
T = A state-approved alternate assessment was administered instead of TAKS reading (Grades 3 and 5 June administration)
D = No document processed for this subject (Grades 3, 4, 5, 7, 8, 9, 10, and exit level)
G = TAKS-ALT record
*/

set max_memory 100g

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

/* **************************************
/// 0. Create helper programs for repeated code throughout data stacking process/
************************************** */

// Helper cleaning program for TAKS data (2004 - 2011) for initial data cleaning
capture program drop taks_clean
program define taks_clean
	rename *, lower
	drop if id1 == ""
	
	// Keep necessary variables and the TAKS exam version (i.e., "K"), when applicable.
	capture replace m_ssc = . if m_testver != "K" // test var is not always present in the data/clean
	capture replace r_ssc = . if r_testver != "K" // test var is not always present in the data/clean
	keep id1 m_ssc r_ssc grade m_scode r_scode
	
	// Keep necessary scores
	qui replace m_ssc = . if m_scode != "S"
	qui replace r_ssc = . if r_scode != "S"
	
	// Data check
// 	tab m_scode
//	tab r_scode
end 

// Helper cleaning program for TAKS data (2004 - 2011) for final data cleaning.
capture program drop taks_final_clean
program define taks_final_clean
	// Keep necessary variables.
	keep id1 grade r_ssc m_ssc
	
	// Generate max score per student, test, and grade.
	qui bys id1 grade: egen max_m = max(m_ssc)
	qui replace m_ssc = max_m
	qui bys id1 grade: egen max_r = max(r_ssc)
	qui replace r_ssc = max_r
	drop max_m max_r
	drop if r_ssc == . & m_ssc == .
	duplicates drop
	
	// Generate subject specific grade variables.
	generate r_testgrade = grade if r_ssc != .
	generate m_testgrade = grade if m_ssc != .
	destring grade, replace
	destring r_testgrade, replace
	destring m_testgrade, replace
	drop grade
	
	// Make data unique on studid.
		* mismatched . values
		replace m_testgrade = r_testgrade if r_testgrade != . & m_testgrade == .
		replace r_testgrade = m_testgrade if m_testgrade !=. & r_testgrade == .
		* about 0.01% conflicting grades, keep highest test grades
		bysort id1: egen max_r_grade = max(r_testgrade)
		bysort id1: egen max_m_grade = max(m_testgrade)
		gen max_r_flag = (r_testgrade == max_r_grade)
		gen max_m_flag = (m_testgrade == max_m_grade)
		drop max_r_grade max_m_grade
		drop if max_r_flag == 0 & max_m_flag == 0
		drop max_r_flag max_m_flag
		duplicates drop
		
	// Quick data checks
		qui duplicates report id1 r_testgrade m_testgrade
		qui assert r(N) == r(unique_value)
		bys r_testgrade m_testgrade: sum *_ssc
		tab r_testgrade m_testgrade, m 
	//
	end

// Helper cleaning program for STAAR data (2012-2023).
	capture program drop staar_clean
	program define staar_clean
		rename *, lower
		drop if id1 == ""
		
		// Keep all necessary variables and scores.
		keep id1 m_ssc r_ssc grade m_scode r_scode
		qui replace m_ssc = . if m_scode != "S"
		qui replace r_ssc = . if r_scode != "S"
		
		// Data checks
		tab m_scode
		tab r_scode
end 

// Helper cleaning program for EOC in alg1, alg2, geo (2012-2023) for inital data cleaning.
		// #1 - Algebra 1 (a1)
		capture program drop clean_eoca1
		program define clean_eoca1
			rename *, lower
			drop if id1 == ""
			
			// Keep necessary variables and scores.
			keep id1 a1_ssc grade a1_scode
			qui replace a1_ssc = . if a1_scode != "S"
			
			// Data check
			tab a1_scode
	end
		// #2 - Algebra 2 (a2)
		capture program drop clean_eoca2
		program define clean_eoca2
			rename *, lower
			drop if id1 == ""
			
			// Keep necessary variables and scores.
			keep id1 a2_ssc grade a2_scode
			qui replace a2_ssc = . if a2_scode != "S"
			
			// Data check
			tab a2_scode
end		
		// #3 - Geometry (ge)
		capture program drop clean_eocge
		program define clean_eocge
			rename *, lower
			drop if id1 == ""
			
			// Keep necessary variables and scores.
			keep id1 ge_ssc grade ge_scode
			qui replace ge_ssc = . if ge_scode != "S"
			
			// Data check
			//tab ge_scode
end

// Helper cleaning program for STAAR data (2012-2023) for final data cleaning of all five subjects.
capture program drop staar_final_clean_all
program define staar_final_clean_all
	// Keep necessary variables
	keep id1 grade r_ssc m_ssc a1_ssc a2_ssc ge_ssc
	
	// Generate max score per student, test, and grade
	qui bys id1 grade: egen max_m = max(m_ssc)
	qui replace m_ssc = max_m
	qui bys id1 grade: egen max_r = max(r_ssc)
	qui replace r_ssc = max_r
	qui bys id1 grade: egen max_a1 = max(a1_ssc)
	qui replace a1_ssc = max_a1
	qui bys id1 grade: egen max_a2 = max(a2_ssc)
	qui replace a2_ssc = max_a2
	qui bys id1 grade: egen max_ge = max(ge_ssc)
	qui replace ge_ssc = max_ge

	drop max_m max_r max_a1 max_a2 max_ge
	drop if r_ssc == . & m_ssc == . & a1_ssc == . & a2_ssc == . & ge_ssc == .
	duplicates drop
	
	// Generate subject specific grades variables and destring
	gen r_testgrade = grade if r_ssc != .
	gen m_testgrade = grade if m_ssc != .
	gen a1_testgrade = grade if a1_ssc != .
	gen a2_testgrade = grade if a2_ssc != .
	gen ge_testgrade = grade if ge_ssc != .
	destring grade, replace
	destring r_testgrade, replace
	destring m_testgrade, replace
	destring a1_testgrade, replace
	destring a2_testgrade, replace
	destring ge_testgrade, replace
	drop grade
	
	// Make data unique on sstudid
		* mismatched . values for grades and scores for the same student
		* very small group of students that have different scores, keep the highest
		replace m_testgrade = r_testgrade if r_testgrade != . & m_testgrade == .
		replace r_testgrade = m_testgrade if m_testgrade != . & r_testgrade == .
		bys id1: egen max_m_ssc = max(m_ssc)
		bys id1: egen max_r_ssc = max(r_ssc)
		bys id1: egen max_a1_ssc = max(a1_ssc)
		bys id1: egen max_a2_ssc = max(a2_ssc)
		bys id1: egen max_ge_ssc = max(ge_ssc)
		replace m_ssc = max_m_ssc if max_m_ssc != . 
		replace r_ssc = max_r_ssc if max_r_ssc != .
		replace a1_ssc = max_a1_ssc if max_a1_ssc != .
		replace a2_ssc = max_a2_ssc if max_a2_ssc != .
		replace ge_ssc = max_ge_ssc if max_ge_ssc != .
		
		drop max_m_ssc max_r_ssc max_a1_ssc max_a2_ssc max_ge_ssc
		
		* about 1% conflicting grades, keep highest test grade
		bys id1: egen max_r_grade = max(r_testgrade)
		bys id1: egen max_m_grade = max(m_testgrade)
		bys id1: egen max_a1_grade = max(a1_testgrade)
		bys id1: egen max_a2_grade = max(a2_testgrade)
		bys id1: egen max_ge_grade = max(ge_testgrade)
		gen max_r_flag = (r_testgrade == max_r_grade)
		gen max_m_flag = (m_testgrade == max_m_grade) // here is the 1%
		gen max_a1_flag = (a1_testgrade == max_a1_grade) if a1_ssc != .
		gen max_a2_flag = (a2_testgrade == max_a2_grade) if a2_ssc != .
		gen max_ge_flag = (ge_testgrade == max_ge_grade) if ge_ssc != .
		
		replace a1_testgrade = max_a1_grade if max_a1_grade != .
		replace a2_testgrade = max_a2_grade if max_a2_grade != .
		replace ge_testgrade = max_ge_grade if max_ge_grade != .
		
		drop max_r_grade max_m_grade max_a1_grade max_a2_grade max_ge_grade 
		drop if max_r_flag == 0 & max_m_flag == 0
		drop max_r_flag max_m_flag max_a1_flag max_a2_flag max_ge_flag
		duplicates drop
		
		// Data checks
		qui duplicates report id1
		qui assert r(N) == r(unique_value)
		bys r_testgrade m_testgrade: sum *_ssc
		bys a1_testgrade: sum *_ssc
		bys a2_testgrade: sum *_ssc
		bys ge_testgrade: sum *_ssc
		
		tab r_testgrade m_testgrade, m
		tab a1_testgrade, m
		tab a2_testgrade, m
		tab ge_testgrade, m
end

// Helper cleaning program for STAAR Data (2012-2023) for final data cleaning when only reading, math, and algebra 1 are available
capture program drop staar_final_clean_three
program define staar_final_clean_three
	// 2022 contains non-numeric grade values
	capture confirm variable schoolyear 
		if _rc == 0 {
		    replace grade = "" if grade == "OS"
			destring grade, replace
		}
		
	// Keep necessary variables
	keep id1 grade r_ssc m_ssc a1_ssc
	
	// Generate max score per student, test, and grade
	qui bys id1 grade: egen max_m = max(m_ssc)
	qui replace m_ssc = max_m
	qui bys id1 grade: egen max_r = max(r_ssc)
	qui replace r_ssc = max_r
	qui bys id1 grade: egen max_a1 = max(a1_ssc)
	qui replace a1_ssc = max_a1
	
	drop max_m max_r max_a1
	drop if r_ssc == . & m_ssc == . & a1_ssc == .
	
	// Generate subject specific grades variables and destring
	gen r_testgrade = grade if r_ssc != .
	gen m_testgrade = grade if m_ssc != .
	gen a1_testgrade = grade if a1_ssc != .
	
	destring grade, replace
	destring r_testgrade, replace
	destring m_testgrade, replace
	destring a1_testgrade, replace
	drop grade
	
	// Make data unique on sstudid
		* mismatched . values for grades and scores for the same student
		* very small group of students that have different scores, keep the highest
		replace m_testgrade = r_testgrade if r_testgrade != . & m_testgrade == .
		replace r_testgrade = m_testgrade if m_testgrade != . & r_testgrade == .
		bys id1: egen max_m_ssc = max(m_ssc)
		bys id1: egen max_r_ssc = max(r_ssc)
		bys id1: egen max_a1_ssc = max(a1_ssc)
		replace m_ssc = max_m_ssc if max_m_ssc != . 
		replace r_ssc = max_r_ssc if max_r_ssc != .
		replace a1_ssc = max_a1_ssc if max_a1_ssc != .
		
		drop max_m_ssc max_r_ssc max_a1_ssc
		
		* about 1% conflicting grades, keep highest test grade
		bys id1: egen max_r_grade = max(r_testgrade)
		bys id1: egen max_m_grade = max(m_testgrade)
		bys id1: egen max_a1_grade = max(a1_testgrade)
		gen max_r_flag = (r_testgrade == max_r_grade)
		gen max_m_flag = (m_testgrade == max_m_grade) // here is the 1%
		gen max_a1_flag = (a1_testgrade == max_a1_grade) if a1_ssc != .
		
		replace a1_testgrade = max_a1_grade if max_a1_grade != .
		
		drop max_r_grade max_m_grade max_a1_grade
		drop if max_r_flag == 0 & max_m_flag == 0
		drop max_r_flag max_m_flag max_a1_flag
		duplicates drop
		
		// Data checks
		qui duplicates report id1
		qui assert r(N) == r(unique_value)
		bys r_testgrade m_testgrade: sum *_ssc
		bys a1_testgrade: sum *_ssc
		tab r_testgrade m_testgrade, m
		tab a1_testgrade, m
end

// Helper cleaning program for STAAR Data (2012-2023) for final data cleaning when only reading, math, alg1 and alg2 are available
capture program drop staar_final_clean_four
program define staar_final_clean_four

	// Keep necessary variables
	keep id1 grade r_ssc m_ssc a1_ssc a2_ssc
	
	// Generate max score per student, test, and grade
	qui bys id1 grade: egen max_m = max(m_ssc)
	qui replace m_ssc = max_m
	qui bys id1 grade: egen max_r = max(r_ssc)
	qui replace r_ssc = max_r
	qui bys id1 grade: egen max_a1 = max(a1_ssc)
	qui replace a1_ssc = max_a1
	qui bys id1 grade: egen max_a2 = max(a2_ssc)
	qui replace a2_ssc = max_a2
	
	drop max_m max_r max_a1 max_a2
	drop if r_ssc == . & m_ssc == . & a1_ssc == . & a2_ssc == .
	
	// Generate subject specific grades variables and destring
	gen r_testgrade = grade if r_ssc != .
	gen m_testgrade = grade if m_ssc != .
	gen a1_testgrade = grade if a1_ssc != .
	gen a2_testgrade = grade if a2_ssc != .
	
	destring grade, replace
	destring r_testgrade, replace
	destring m_testgrade, replace
	destring a1_testgrade, replace
	destring a2_testgrade, replace
	drop grade
	
	// Make data unique on sstudid
		* mismatched . values for grades and scores for the same student
		* very small group of students that have different scores, keep the highest
		replace m_testgrade = r_testgrade if r_testgrade != . & m_testgrade == .
		replace r_testgrade = m_testgrade if m_testgrade != . & r_testgrade == .
		bys id1: egen max_m_ssc = max(m_ssc)
		bys id1: egen max_r_ssc = max(r_ssc)
		bys id1: egen max_a1_ssc = max(a1_ssc)
		bys id1: egen max_a2_ssc = max(a2_ssc)
		replace m_ssc = max_m_ssc if max_m_ssc != . 
		replace r_ssc = max_r_ssc if max_r_ssc != .
		replace a1_ssc = max_a1_ssc if max_a1_ssc != .
		replace a2_ssc = max_a2_ssc if max_a2_ssc != .
		
		drop max_m_ssc max_r_ssc max_a1_ssc max_a2_ssc
		
		* about 1% conflicting grades, keep highest test grade
		bys id1: egen max_r_grade = max(r_testgrade)
		bys id1: egen max_m_grade = max(m_testgrade)
		bys id1: egen max_a1_grade = max(a1_testgrade)
		bys id1: egen max_a2_grade = max(a2_testgrade)
		gen max_r_flag = (r_testgrade == max_r_grade)
		gen max_m_flag = (m_testgrade == max_m_grade) // here is the 1%
		gen max_a1_flag = (a1_testgrade == max_a1_grade) if a1_ssc != .
		gen max_a2_flag = (a2_testgrade == max_a2_grade) if a2_ssc != .
		
		replace a1_testgrade = max_a1_grade if max_a1_grade != .
		replace a2_testgrade = max_a2_grade if max_a2_grade != .
		
		drop max_r_grade max_m_grade max_a1_grade max_a2_grade
		drop if max_r_flag == 0 & max_m_flag == 0
		drop max_r_flag max_m_flag max_a1_flag max_a2_flag
		duplicates drop
		
		// Data checks
		qui duplicates report id1
		qui assert r(N) == r(unique_value)
		bys r_testgrade m_testgrade: sum *_ssc
		bys a1_testgrade: sum *_ssc
		bys a2_testgrade: sum *_ssc
		tab r_testgrade m_testgrade, m
		tab a1_testgrade, m
		tab a2_testgrade, m
end

/* **************************************
/// 1. Read in test scores
		(a) TAKS (2004-2011) and clean EOG testing in math and reading for grades 3-8.
************************************** */ /*
** 2003 
		// grade 3
			* march 2003: grade 3 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2003/taks3_march.dta", clear
			taks_clean
			tempfile g3m
			save `g3m'
			
			* march 2003: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2003/taks3sp_march.dta", clear
			taks_clean
			tempfile g3ms
			save `g3ms'
			
			* april 2003: grade 3 math and reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2003/taks3_april.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2003: grade 3 math and reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2003/taks3sp_april.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			clear
			append using `g3m' `g3ms' `g3a' `g3as'
			tempfile g3
			save `g3'
			
		// grade 4-8
			forvalues g = 4 / 8 {
				* english version
				use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2003/taks`g'.dta", clear
				taks_clean
				tempfile eng
				save `eng'
				
				* spanish version: grade 6 and under only
				if `g' <= 6 {
					use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2003/taks`g'sp.dta", clear
					taks_clean
					append using `eng'
				}
				
				tempfile g`g'
				save `g`g''
			}
			
			clear
			forvalues g = 3 / 8 {
				append using `g`g''
			}
			
		// Final clean and save. 
			taks_final_clean
			save "$intermediate/stu_test_2003", replace
			
** 2004
		// grade 3
			* march 2004: grade 3 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2004/taks3_march_fy04.dta", clear
			taks_clean
			tempfile g3m
			save `g3m'
			
			* march 2004: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2004/taks3sp_march_fy04.dta", clear
			taks_clean
			tempfile g3ms
			save `g3ms'
			
			* april 2004: grade 3 math and reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2004/taks3_april_fy04.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2004: grade 3 math and reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2004/taks3sp_april_fy04.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			clear
			append using `g3m' `g3ms' `g3a' `g3as'
			tempfile g3
			save `g3'
			
		// grade 4-8
			forvalues g = 4 / 8 {
				* english version
				use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2004/taks`g'_fy04.dta", clear
				taks_clean
				tempfile eng
				save `eng'
				
				* spanish version: grade 6 and under only
				if `g' <= 6 {
					use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2004/taks`g'sp_fy04.dta", clear
					taks_clean
					append using `eng'
				}
				
				tempfile g`g'
				save `g`g''
			}
			
			clear
			forvalues g = 3 / 8 {
				append using `g`g''
			}
			
		// Final clean and save. 
			taks_final_clean
			save "$intermediate/stu_test_2004", replace
			
** 2005
		// grade 3
			* march 2005: grade 3 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks3_march_fy05.dta", clear
			taks_clean
			tempfile g3m
			save `g3m'
			
			* march 2005: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks3sp_march_fy05.dta", clear
			taks_clean
			tempfile g3ms
			save `g3ms'
			
			* april 2005: grade 3 math and reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks3_april_fy05.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2005: grade 3 math and reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks3sp_april_fy05.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			clear
			append using `g3m' `g3ms' `g3a' `g3as'
			tempfile g3
			save `g3'
			
		// grade 5
			* Missing math data for 5th graders. Should be in april datasets but does not exist in any other month. 
			* march 2005: grade 5 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks5_march_fy05.dta", clear
			taks_clean
			tempfile g3m
			save `g3m'
			
			* march 2005: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks5sp_march_fy05.dta", clear
			taks_clean
			tempfile g3ms
			save `g3ms'
			
			* april 2005: grade 3 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks5_april_fy05.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2005: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks5sp_april_fy05.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			clear
			append using `g3m' `g3ms' `g3a' `g3as'
			tempfile g5
			save `g5'		
	
		// grade 4-8
			forvalues g = 4 / 8 {
				* Grade 5 had monthly data sets, but the rest of the grades did not. 
				if `g' == 5 {
					use `g5'
				}
				
				else {
					* english version
					use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks`g'_fy05.dta", clear
					taks_clean
					tempfile eng
					save `eng'
				
					* spanish version: grade 6 and under only
					if `g' <= 6 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2005/taks`g'sp_fy05.dta", clear
						taks_clean
						append using `eng'
					}
				}
				
				tempfile g`g'
				save `g`g''
			}
			
			clear
			forvalues g = 3 / 8 {
				append using `g`g''
			}
			
		// Final clean and save. 
			taks_final_clean
			save "$intermediate/stu_test_2005", replace

** 2006
		// grade 3
			* feb 2006: grade 3 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks3eng_feb06.dta", clear
			taks_clean
			tempfile g3f
			save `g3f'
			
			* feb 2006: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks3sp_feb06.dta", clear
			taks_clean
			tempfile g3fs
			save `g3fs'
			
			* april 2006: grade 3 math and reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks3eng_apr06.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2005: grade 3 math and reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks3sp_apr06.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			clear
			append using `g3f' `g3fs' `g3a' `g3as'
			tempfile g3
			save `g3'
			
		// grade 5
			* feb 2006: grade 5 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks5eng_feb06.dta", clear
			taks_clean
			tempfile g3f
			save `g3f'
			
			* feb 2006: grade 5 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks5sp_feb06.dta", clear
			taks_clean
			tempfile g3fs
			save `g3fs'
			
			* april 2006: grade 5 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks5eng_apr06.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2006: grade 5 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks5sp_apr06.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			* april 2006: grade 5 math (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks5eng_mth_apr06.dta", clear
			taks_clean
			tempfile g3am
			save `g3am'
			
			* april 2006: grade 5 math (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks5sp_mth_apr06.dta", clear
			taks_clean
			tempfile g3ams
			save `g3ams'
			
			clear
			append using `g3f' `g3fs' `g3a' `g3as' `g3am' `g3ams'
			tempfile g5
			save `g5'		
	
		// grade 4-8
			forvalues g = 4 / 8 {
				* Grade 5 had monthly data sets, but the rest of the grades did not. 
				if `g' == 5 {
					use `g5'
				}
				
				else {
					if `g' <=6 {
						* english version
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks`g'eng_apr06.dta", clear
						taks_clean
						tempfile eng
						save `eng'
				
						* spanish version: grade 6 and under only
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks`g'sp_apr06.dta", clear
						taks_clean
						append using `eng'
				}
				else {
					use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2006/taks`g'_apr06.dta", clear
					taks_clean
					tempfile eng
					save `eng'
				}
				
				}	
				tempfile g`g'
				save `g`g''
			}
			
			clear
			forvalues g = 3 / 8 {
				append using `g`g''
			}
			
		// Final clean and save. 
			taks_final_clean
			save "$intermediate/stu_test_2006", replace			

** 2007
		// grade 3
			* feb 2007: grade 3 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks3eng_feb07.dta", clear
			taks_clean
			tempfile g3f
			save `g3f'
			
			* feb 2007: grade 3 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks3sp_feb07.dta", clear
			taks_clean
			tempfile g3fs
			save `g3fs'
			
			* april 2007: grade 3 math and reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks3eng_apr07.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2007: grade 3 math and reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks3sp_apr07.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			clear
			append using `g3f' `g3fs' `g3a' `g3as'
			tempfile g3
			save `g3'
		
		// grade 5
			* feb 2007: grade 5 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks5eng_feb07.dta", clear
			taks_clean
			tempfile g3f
			save `g3f'
			
			* feb 2007: grade 5 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks5sp_feb07.dta", clear
			taks_clean
			tempfile g3fs
			save `g3fs'
			
			* april 2007: grade 5 reading (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks5eng_apr07.dta", clear
			taks_clean
			tempfile g3a
			save `g3a'
			
			* april 2007: grade 5 reading (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks5sp_apr07.dta", clear
			taks_clean
			tempfile g3as
			save `g3as'
			
			* april 2007: grade 5 math (english version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks5eng_mth_apr07.dta", clear
			taks_clean
			tempfile g3am
			save `g3am'
			
			* april 2007: grade 5 math (spanish version)
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks5sp_mth_apr07.dta", clear
			taks_clean
			tempfile g3ams
			save `g3ams'
			
			clear
			append using `g3f' `g3fs' `g3a' `g3as' `g3am' `g3ams'
			tempfile g5
			save `g5'		
		
	// grade 4-8
			forvalues g = 4 / 8 {
				* Grade 5 had monthly data sets, but the rest of the grades did not. 
				if `g' == 5 {
					use `g5'
				}
				
				else {
					if `g' <=6 {
						* english version
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks`g'eng_apr07.dta", clear
						taks_clean
						tempfile eng
						save `eng'
				
						* spanish version: grade 6 and under only
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks`g'sp_apr07.dta", clear
						taks_clean
						append using `eng'
				}
				else {
					use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2007/taks`g'_apr07.dta", clear
					taks_clean
					tempfile eng
					save `eng'
				}
				
				}	
				tempfile g`g'
				save `g`g''
			}
			
			clear
			forvalues g = 3 / 8 {
				append using `g`g''
			}
			
		// Final clean and save. 
			taks_final_clean
			save "$intermediate/stu_test_2007", replace			
		
** 2008

	foreach g in 3 5 8 {
	    * g3, g5, g8 reading: march, eg taks3r_mar08
	use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2008/taks`g'r_mar08.dta", clear
		taks_clean
		tempfile f1
		save `f1'
		
		* g3, g5, g8 math: april, eg taks3rm_apr08 (this includes reading retakes which we don't want)
		if `g' == 3 use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2008/taks`g'rm_apr08.dta", clear
		if `g' != 3 use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2008/taks`g'm_apr08.dta", clear
		
		taks_clean
		* reading here are retakes. we don't want this because we want original scores
		replace r_ssc = .
		append using `f1'
		
		tempfile g`g'
		save `g`g''
		
	}
	
	* g 4, g6, g7 reading + math: april, eg taks4_apr08
	foreach g in 4 6 7 {
	    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2008/taks`g'_apr08.dta", clear
		taks_clean
		tempfile g`g'
		save `g`g''
	}
	
	clear
	forvalues g = 3 / 8 {
	    append using `g`g''
		
	}
	
	// Final clean and save
		taks_final_clean
		save "$intermediate/stu_test_2008", replace
		
** 2009
	foreach g in 3 5 8 {
	    * g3, g5, g8 reading: march, eg taks3r_mar09
	use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2009/taks`g'r_mar09.dta", clear
		taks_clean
		tempfile f1
		save `f1'
		
		* g3, g5, g8 math: april, eg taks3rm_apr09 (this includes reading retakes which we don't want)
		if `g' == 3 use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2009/taks`g'rm_apr09.dta", clear
		if `g' != 3 use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2009/taks`g'm_apr09.dta", clear
		
		taks_clean
		* reading here are retakes. we don't want this because we want original scores
		replace r_ssc = .
		append using `f1'
		
		tempfile g`g'
		save `g`g''
		
	}
	
	* g 4, g6, g7 reading + math: april, eg taks4_apr09
	foreach g in 4 6 7 {
	    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2009/taks`g'_apr09.dta", clear
		taks_clean
		tempfile g`g'
		save `g`g''
	}
	
	clear
	forvalues g = 3 / 8 {
	    append using `g`g''
		
	}
	
	// Final clean and save
		taks_final_clean
		save "$intermediate/stu_test_2009", replace
	
** 2010
		* for 5 and 8 use eg taks5rm_apr10 - the rest by themselves
	forvalues g = 3 / 8 {
	    if `g' == 5 {
				* english
				use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2010/taks`g'rm_apr10.dta", clear
				taks_clean
				tempfile g5
				save `g5'
				}
		else if `g' == 8 {
				use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2010/taks`g'rm_apr10.dta", clear
				taks_clean
				tempfile g8
				save `g8'
				}	
		else {
				use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2010/taks`g'_apr10.dta", clear
				taks_clean
				tempfile g`g'
				save `g`g''
			}	
		}
		
		clear
		forvalues g = 3 / 8 {
		    append using `g`g''
		}
	
	// Final clean and save
		taks_final_clean
		save "$intermediate/stu_test_2010", replace
		
** 2011
		* for 5 and 8 use eg taks5rm_apr11 - the rest by themselves
	forvalues g = 3 / 8 {
	    if `g' == 5 {
		    * english
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2011/taks`g'rm_apr11.dta", clear
			taks_clean
			tempfile g5
			save `g5'
			}
		else if `g' == 8 {
			use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2011/taks`g'rm_apr11.dta", clear
			taks_clean
			tempfile g8
			save `g8'
			}	
		else {
		    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2011/taks`g'_apr11.dta", clear
			taks_clean
			tempfile g`g'
			save `g`g''
		}	
	}
		clear
		forvalues g = 3 / 8 {
		    append using `g`g''
		}
	
	// Final clean and save
		taks_final_clean
		save "$intermediate/stu_test_2011", replace

/* **************************************
/// 1. Read in test scores
		(b) STAAR (2012-2023) and clean EOG, alg1, geo, and alg2 testing in math and reading for grades 3-8.
************************************** */	
// 2012:
		
		*g3-8 test scores
		forvalues g = 3 / 8 {
		    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2012/staar`g'_apr12.dta", clear
			staar_clean
			tempfile staar_g`g'
			save `staar_g`g''
		}
		
		* EOC alg1 and alg2 (include may and july)
		forvalues g = 1 / 2 {
		   use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2012/staareoca`g'_may12.dta", clear
		   clean_eoca`g'
		   tempfile eoc_a`g'_may
		   save `eoc_a`g'_may'
		   
		   use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2012/staareoca`g'_jul12.dta", clear
		   clean_eoca`g'
		   tempfile eoc_a`g'_jul
		   save `eoc_a`g'_jul'
		   
		   clear
		   append using `eoc_a`g'_may' `eoc_a`g'_jul'
		   tempfile eoc_a`g'
		   save `eoc_a`g''
		}
		
		* EOC geo (include may and july)
		   use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2012/staareocge`g'_may12.dta", clear
		   clean_eocge
		   tempfile eoc_ge_may
		   save `eoc_ge_may'
		   
		   use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2012/staareocge`g'_jul12.dta", clear
		   clean_eocge
		   tempfile eoc_ge_jul
		   save `eoc_ge_jul'
		   
		   clear
		   append using `eoc_ge_may' `eoc_ge_jul'
		   tempfile eoc_ge
		   save `eoc_ge'
	
			clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
				}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
				}
			append using `eoc_ge'
			
		// Final clean and save	
		staar_final_clean_all
		save "$intermediate/stu_test_2012", replace
		display "2012 done"

** 2013:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2013/g`g'_staar_apr13.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2013/g`g'_staar_apr13.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}
						else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2013/staar`g'_apr13.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''    
						}
				}		
		}
		
		* EOC alg1 and alg2 
		forvalues g = 1 / 2 {
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2013/staareoca`g'_spr13.dta", clear
				* additional files available for a1 in dec and july as well as a2 in dec
			clean_eoca`g'
			tempfile eoc_a`g'
			save `eoc_a`g''
		}
		
		* EOC geo
		   use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2013/staareocge_spr13.dta", clear
				* additional files available for ge in dec.
		   clean_eocge
		   tempfile eoc_ge
		   save `eoc_ge'

		 clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
				}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
				}
			append using `eoc_ge'
			  
		// Final clean and save	
		staar_final_clean_all
		save "$intermediate/stu_test_2013", replace
		display "2013 done"

** 2014:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2014/g`g'_staar_apr14.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2014/g`g'_staar_apr14.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2014/staar`g'_apr14.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''    
						}
				}		
		
		}
		
		* EOC alg1
		* No alg2 or geo datasets available
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2014/staareoca1_spr14.dta", clear
				* additional files available for a1 in dec and july
			clean_eoca1
			tempfile eoc_a1
			save `eoc_a1'
			
			clear
			forvalues g = 3 / 8 {
			    append using `staar_g`g''
			}
			append using `eoc_a1'
		// Final clean and save	
		staar_final_clean_three
		save "$intermediate/stu_test_2014", replace
		display "2014 done"
	

// 2015:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2015/g`g'_staar_mar15.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2015/g`g'_staar_mar15.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2015/staar`g'_apr15.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''    
					}
				}		
		}
		
		* EOC alg1
		* No alg2 or geo datasets available
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2015/staareoca1_spr15.dta", clear
				* additional files available for a1 in dec and july
			clean_eoca1
			tempfile eoc_a1
			save `eoc_a1'
	
				clear
				forvalues g = 3 / 8 {
					append using `staar_g`g''
					}	
				append using `eoc_a1'
				
		// Final clean and save	
		staar_final_clean_three
		save "$intermediate/stu_test_2015", replace
		display "2015 done"

** 2016:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2016/g`g'_staar_mar16.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2016/g`g'_staar_mar16.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2016/staar`g'_may16.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''	
					}
				}		
		}
		
		* EOC alg1
		* No alg2 or geo datasets available
		forvalues g = 1 / 2 {
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2016/staareoca`g'_spr16.dta", clear
				* additional files available for a1 in dec and july
			clean_eoca`g'
			tempfile eoc_a`g'
			save `eoc_a`g''		
		}
		
			clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
					}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
					}
		
		// Final clean and save	
		staar_final_clean_four
		save "$intermediate/stu_test_2016", replace
		display "2016 done"

** 2017:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2017/g`g'_staar_mar17.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2017/g`g'_staar_mar17.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2017/staar`g'_may17.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''	
					}
				}		
		}
		
	* EOC alg1
	* No alg2 or geo datasets available
		forvalues g = 1 / 2 {
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2017/staareoca`g'_spr17.dta", clear
				* additional files available for a1 in dec and july
			clean_eoca`g'
			tempfile eoc_a`g'
			save `eoc_a`g''		
		}
		
			clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
					}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
					}
		
		// Final clean and save	
		staar_final_clean_four
		save "$intermediate/stu_test_2017", replace
		display "2017 done"

** 2018:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2018/g`g'_staar_apr18.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2018/g`g'_staar_apr18.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2018/staar`g'_may18.dta", clear
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''	
					}
				}		
		}
		
	* EOC alg1
	* No alg2 or geo datasets available
		forvalues g = 1 / 2 {
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2018/staareoca`g'_spr18.dta", clear
				* additional files available for a1 in dec and july
			clean_eoca`g'
			tempfile eoc_a`g'
			save `eoc_a`g''		
		}
		
			clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
					}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
					}
		
		// Final clean and save	
		staar_final_clean_four
		save "$intermediate/stu_test_2018", replace
		display "2018 done"
		
** 2019:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2019/g`g'_staar_apr19.dta", clear
						rename STUDENT_ID1 ID1
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2019/g`g'_staar_apr19.dta", clear
						rename STUDENT_ID1 ID1
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2019/staar`g'_may19.dta", clear
						rename STUDENT_ID1 ID1
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''	
					}
				}		
		}
		
	* EOC alg1 and alg2
	* No geo datasets available
		forvalues g = 1 / 2 {
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2019/staareoca`g'_spr19.dta", clear
				* additional files available for a1 in dec and july
			rename STUDENT_ID1 ID1
			clean_eoca`g'
			tempfile eoc_a`g'
			save `eoc_a`g''		
		}
		
			clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
					}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
					}
		
		// Final clean and save	
		staar_final_clean_four
		save "$intermediate/stu_test_2019", replace
		display "2019 done"
		
**** Not including 2020 data due to the pandemic
		
** 2021:
		*g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
						if `g' == 5 {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2021/g`g'_staar_apr21.dta", clear
						rename STUDENT_ID1 ID1
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
						}	
				else {
				    if `g' == 8 {
					    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2021/g`g'_staar_apr21.dta", clear
						rename STUDENT_ID1 ID1
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''
					}
					else {
						use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2021/staar`g'_may21.dta", clear
						rename STUDENT_ID1 ID1
						staar_clean
						tempfile staar_g`g'
						save `staar_g`g''	
					}
				}		
		}
		
	* EOC alg1 and alg2
	* No geo datasets available
		forvalues g = 1 / 2 {
		     use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2021/staareoca`g'_spr21.dta", clear
				* additional files available for a1 in dec and july
			rename STUDENT_ID1 ID1
			clean_eoca`g'
			tempfile eoc_a`g'
			save `eoc_a`g''		
		}
		
			clear
			forvalues g = 3 / 8 {
					append using `staar_g`g''
					}
			forvalues g = 1 / 2 {
					append using `eoc_a`g''
					}
		
		// Final clean and save	
		staar_final_clean_four
		save "$intermediate/stu_test_2021", replace
		display "2021 done"		

** 2022:
		* g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
		    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2022/staar`g'_may22.dta", clear
			rename STUDENT_ID1 ID1
			staar_clean
			tempfile staar_g`g'
			save `staar_g`g''	
		}
		
		* EOC alg1 and alg2
		* No geo datasets available
		use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2022/staareoca1_spr22.dta", clear
				* additional files available for a1 in dec and june
		rename STUDENT_ID1 ID1
		clean_eoca1
		tempfile eoc_a1
		save `eoc_a1'
		
				clear
				forvalues g = 3 / 8 {
							append using `staar_g`g''
							}
				append using `eoc_a1'
				generate schoolyear = 2022
				
		// Final clean and save	
		staar_final_clean_three
		save "$intermediate/stu_test_2022", replace
		display "2022 done"			
*/				
** 2023:
		* g3-8 staar test scores
		* additional files available for g5 and g8 in may and june
		forvalues g = 3 / 8 {
		    use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2023/staar`g'_may23.dta", clear
			rename (RLA_SSC STUDENT_ID1 RLA_TESTVER RLA_SCODE) ///
				(R_SSC ID1 R_TESTVER R_SCODE) 
			staar_clean
			tempfile staar_g`g'
			save `staar_g`g''	
		}
		
		* EOC alg1 and alg2
		* No geo datasets available
		use "E:\projects\2403-Evidence\NewFilesReleased\TAASandTAKSandSTAAR/2023/staareoca1_spr23.dta", clear
				* additional files available for a1 in dec and june
		rename STUDENT_ID1 ID1
		clean_eoca1
		tempfile eoc_a1
		save `eoc_a1'
		
				clear
				forvalues g = 3 / 8 {
							append using `staar_g`g''
							}
				append using `eoc_a1'
				generate schoolyear = 2023
				
		// Final clean and save	
		staar_final_clean_three
		save "$intermediate/stu_test_2023", replace
		display "2023 done"
		
** 2024: 
	* g3-8 staar test scores
	* additional files available for g5 and g8 in may, and june.
	forvalues g = 3 / 8 {
		use "E:/projects/235-Math/NewFilesReleased/TAASandTAKSandSTAAR/2024/staar`g'_may24.dta", clear
		rename (RLA_SSC STUDENT_ID1 RLA_TESTVER RLA_SCODE) (R_SSC ID1 R_TESTVER R_SCODE)
		staar_clean
		tempfile staar_g`g'
		save `staar_g`g''
		}
		
	* EOC alg1 
	* No geo and alg2 datasets available
		use "E:/projects/235-Math/NewFilesReleased/TAASandTAKSandSTAAR/2024/staareoca1_spr24.dta", clear 
		replace A1_SSC = . if FTT_RT == "R"
		rename STUDENT_ID1 ID1
		clean_eoca1 
		tempfile eoc_a1
		save `eoc_a1'			
		** add a1 alt files
		use "E:/projects/235-Math/NewFilesReleased/TAASandTAKSandSTAAR/2024/staareoca1_alt2_apr24.dta", clear
		rename (STUDENT_ID1) (ID1)
		clean_eoca1 
		tempfile eoc_a1_alt
		save `eoc_a1_alt'	
		** add a1 jun files 
		use "E:/projects/235-Math/NewFilesReleased/TAASandTAKSandSTAAR/2024/staareoca1_jun24.dta", clear
		replace A1_SSC = . if FTT_RT == "R"
		rename STUDENT_ID1 id1
		clean_eoca1
		tempfile eoc_a1_jun
		save `eoc_a1_jun'	
		** add a1 dec files 
		use "E:/projects/235-Math/NewFilesReleased/TAASandTAKSandSTAAR/2024/staareoca1_dec23.dta", clear
		replace A1_SSC = . if FTT_RT == "R"
		rename STUDENT_ID1 id1
		clean_eoca1
		tempfile eoc_a1_dec
		save `eoc_a1_dec'
	
	// Append all together for the whole school year
		clear
		forvalues g = 3 / 8 {
			append using `staar_g`g''
			}
		append using `eoc_a1'
		append using `eoc_a1_alt'
		append using `eoc_a1_jun'
		append using `eoc_a1_dec'
		
	// Final cleaning and save
	generate schoolyear = 2024
	staar_final_clean_three
	save "$intermediate/stu_test_2024", replace
	display "2024 done"		
		