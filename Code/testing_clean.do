/*
Description: This file aims to clean test scores from stu_test_stack.do - using Alejandra's code from Gates Math TX
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

// Cleaning goals: (1) We want one observation per student per year with test scores in math, reading, alg1, geo, alg2.
//							(2) We want standardized test scores in reading, math, and alg1.
//							(3) Create new variables for prior test scores in math and reading. 	

	forvalues g = 2003 / 2019 {
	    use "$intermediate/stu_test_`g'", replace
		
		// Data check
		qui duplicates report id1
		qui assert r(N) == r(unique_value)
		
		// Generate SY and desired standardized scores
		generate schoolyear = `g'
		sort r_testgrade
		by r_testgrade: egen r_ssc_std = std(r_ssc) // could not use center bc could not install egenmore package.
		sort m_testgrade
		by m_testgrade: egen m_ssc_std = std(m_ssc)
		if `g' > 2011 {
		    egen a1_ssc_std = std(a1_ssc)
			capture egen ge_ssc_std = std(ge_ssc) // not always available
			capture egen a2_ssc_std = std(a2_ssc) // not always available
		}
		
		// Save
		count if m_testgrade == .
		count if r_testgrade == .
		display "`g' done"
		save "$intermediate/stu_test_`g'_clean", replace
		}
		
	forvalues g = 2021 / 2024 {
	    use "$intermediate/stu_test_`g'", clear
			
			// Data check
			qui duplicates report id1
			qui assert r(N) == r(unique_value)
			
			// Generate SY and desired standardized scores
			gen schoolyear = `g'
			egen r_ssc_std = std(r_ssc)
			egen m_ssc_std = std(m_ssc)
			egen a1_ssc_std = std(a1_ssc)
			capture egen ge_ssc_std = std(ge_ssc) // not always available 
			capture egen a2_ssc_std = std(a2_ssc) // not always available
			
			// Save
			count if m_testgrade == .
			count if r_testgrade == .
			display "`g' done"
			save "$intermediate/stu_test_`g'_clean", replace
		}
		
	// Append all years together and make sure we have one observation per student per year.
			clear
			forvalues g = 2003 / 2019 {
			    append using "$intermediate/stu_test_`g'_clean"
				}
			forvalues g = 2021 / 2024 {
			    append using "$intermediate/stu_test_`g'_clean"
				}	
				
	// Generate prior year test score in math and reading.
		destring id1, gen(id1_num)
		tsset id1_num schoolyear
		gen prior_r_ssc = L.r_ssc_std
		gen prior_m_ssc = L.m_ssc_std
		
	// Rename school year to syear for consistency
	rename schoolyear syear
	
	// Save cleaned data.
	save "$clean/stu_tests", replace
	
	// Data check
	duplicates report id1 syear 