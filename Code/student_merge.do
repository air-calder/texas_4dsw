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

// Split files up into four
foreach x in enroll_demog attend_demog tests {
	use "$clean/stu_`x'", clear
	preserve
		keep if id1_num<=5694176
		save "$clean/stu_`x'_idsgroup1", replace
	restore
	preserve
		keep if id1_num>5694176 & id1_num<=13697170
		save "$clean/stu_`x'_idsgroup2", replace
	restore
	preserve
		keep if id1_num>13697170 & id1_num<=17100743 
		save "$clean/stu_`x'_idsgroup3", replace
	restore
		preserve
		keep if id1_num>17100743
		save "$clean/stu_`x'_idsgroup4", replace
	restore
}
	
	// Use student enrollment & attendance data as the base file and merge with test data. Drop test data that do not merge with enrollment.
forval i = 1 / 4 {	
		// Load enrollment data/clean
		use "$clean/stu_enroll_demog_idsgroup`i'", clear
		
		// Merge in absences data
		merge 1:1 id1_num syear using "$clean/stu_attend_demog_idsgroup`i'", force
		drop _merge
		// Merge in test score data/clean
		merge 1:1 id1_num syear using "$clean/stu_tests_idsgroup`i'", force
		tab _merge if syear>=2004 & syear!=2020 & syear!=2024 & ((grade>=3 & grade<=8) | (r_testgrade>=3 & r_testgrade<=8)), mi // check how much of grades 3-8 in years with test data merged; ~90% merged, 8.5% had only demographics, 1.5% had only test data; seems okay
		keep if _merge==1  | _merge==3 // keep all students in enrollment file regardless of match with test date; drop tests that don't merge with enrollment
		drop _merge
		
		// Remove 2021 from attendance data (except for days_member) because of COVID / virtual instruction and unreliable data
		foreach j in days_absent days_present pct_attend {
			replace `j' = . if syear == 2021  
		}
		
		// Save 
		compress
		save "$clean/stu_tests_and_demog_idsgroup`i'", replace
		
	
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
			
	/*	// Impute the lagged test data for 2021 (i.e., test data from 2020) because missing from COVID 
		foreach var in r_ssc_std m_ssc_std {
			reg lag_`var' i.grade##c.lag2_r_ssc_std##c.lag2_r_ssc_std##c.lag2_r_ssc_std ///
			i.grade##c.lag2_m_ssc_std##c.lag2_m_ssc_std##c.lag2_m_ssc_std ///
			predict lag_imp if syear == 2021
			replace lag_`var' = lag_imp if syear == 2021
			drop lag_imp
		} */

		
	// Final save 
	compress
	save "$clean/student_merged_idsgroup`i'", replace
	}
