/*
Description: Merge all student enrollment and outcomes data for 4DSW project
Author: Jamie Klinenberg
*/
clear
set max_memory 100g
// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"
		
// Merge all student-level data 
	// Load enrollment data/clean
	use "$clean/stu_enroll_demog", clear
	count if grade == . //0
	tostring district, replace
	tostring grade, replace
	
	// Merge in absences data
	merge 1:1 id1_num syear using "$clean/stu_attend_demog", ///
		keep(match master) generate(enrollattend_merge)
	count if grade == "" //0
	
	// Merge in test score data/clean
	merge 1:1 id1_num syear using "$clean/stu_tests", keep(match master) ///
		generate(enrollattendtest_merge)
	count if grade == "" // 0
	foreach j in days_absent days_present pct_attend {
		replace `j' = . if syear == 2021 // COVID impacted 
	}	
	compress
	save "$clean/stu_tests_and_demog", replace	
			
// Create lags of outcome variables i.e. on prior EOC scores
		// math, ela - already have prior scores
		// a1, a2, geo - if no math scores we can replace with a1,
		// if missing both replace with geo,
		// and if missing all three replace with a2
	duplicates report id1 syear
	egen id = group(id1)
	sort id syear
	tsset id syear
	replace m_ssc_std = a1_ssc_std if m_ssc_std == .
	replace m_ssc_std = ge_ssc_std if m_ssc_std == .
	replace m_ssc_std = a2_ssc_std if m_ssc_std == .
	foreach var of varlist r_ssc_std m_ssc_std {
		gen lag_`var' = L.`var'
		gen lag2_`var' = L2.`var'
		lab var lag_`var' "Lag `var'"
		lab var lag2_`var' "2X Lag `var'"
	}
			
	// Non-test variables
	foreach var of varlist pct_attend {
		gen lag_`var' = L.`var'
		gen lag2_`var' = L2.`var'
		gen lag3_`var' = L3.`var'
		lab var lag_`var' "Lag `var'"
		lab var lag2_`var' "2X Lag `var'"
		lab var lag3_`var' "3X Lag `var'"
	}
		
// Final save 
compress
count if grade == "" // 0
save "$clean/student_merged", replace