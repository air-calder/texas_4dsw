/*
Description: Create dataset with student attendance data for 4DSW project - using Alejandra's code from Gates Math TX
Author: Jamie Klinenberg
*/

set max_memory 100g

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

/*****************1. Employee demographic files merge with employee data (2003-2009) ************/
	
forvalues y = 2000 / $last_year {

		local f = substr("`y'", 3, 4) // for adapting filename
		di "loading employee demographic year `y' (file p_employ`f'f)"
		use "E:/projects/2403-Evidence/NewFilesReleased/TEA/p_employ`f'f.dta", clear
		
		/* EMPLOY_TYPE is a TEA-assigned grouping that indicates employee type.
		01 - professional - at least one classroom or non-classroom assignment record with a ROLEGRP1 value of 01
		02 - paraprofessional - persons who only have classroom assignment records with ROLEGRP1==02
		03 - auxiliary - persons who do not have a classroom or a non-classroom assignment 
		*/ 
		tab EMPLOY_TYPE, m
		keep if EMPLOY_TYPE == "01"
		tab EMPLOY_TYPE, m
		
		/* STAFFGRP1 identifies the location of staff responsibility.
		01 - Classroom - no non-classroom assignments and at least one classroom assignments
		02 - Non-Classroom - no classroom assignments and at least one non-classroom assignments
		03 - Both Classroom/Non-Classroom assignments
		04 - Non-Professional classroom - assignments with ROLEGRP1 == 02
		05 - Auxiliary - no classroom or non-classroom assignments 
		*/ 
		keep if STAFFGRP1 == "01" | STAFFGRP1 == "03"
		tab STAFFGRP1, m
		
		rename *, lower
	
		gen syear = `y'
		save "$intermediate/teacher_`y'", replace
	}

/***** 2. Append together employee files only and demographic files ///////////////////// */

	clear
	forvalues y = 2000 / $last_year {
		append using "$intermediate/teacher_`y'"
	}
	
	// One odd duplicate observation causing id1 necessary for uniqueness
	drop if id2 == "XXX" & id1 == ""
	unique syear id2 exper
	
	// Figure out experience variable
	// Resolve duplicates in terms of id2 syear by taking the observation with more experiences
	gsort syear id2 -exper // -exper sorts in descending order
	gen keep_exper_obs = (syear != syear[_n-1] | id2 != id2[_n-1]) // flag observations with the most experience
	keep if keep_exper_obs // keep only these observations
	drop keep_exper_obs 
	
	// Confirm data is unique on id2 syear
	duplicates report syear id2 // approx 8 million
	drop id1 // id2 is the correct teachid and has 0 missing observations compared to id1
	destring id2, replace
	unique id2 // 991,086
	
	// Save
	save "$intermediate/all_teacher", replace 

	
/*****************Clean certification data (most recent year only needed) ************/
use "E:/projects/2403-Evidence/NewFilesReleased/StBrdEdCert/2023/sbec_final20231031", clear
drop if id2 == ""
gen cert_year = year(cert_effective_dt)

// Generate indicator variables if a teacher received standard, alternative, or other certifications
tab cert_pgm
tab cert_pgm if cert_year >= 2015
gen cert_standard = cert_pgm == "Standard Program"
gen cert_alt = cert_pgm == "Alternative Program"
gen cert_other = cert_standard == 0 & cert_alt == 0

lab var cert_standard "Standard program"
lab var cert_alt "Alternate program"
lab var cert_other "Other program (mostly post-bacc & permit)"

// Generate certification tiers
gen tier1 = (cert_type == "Provisional" | cert_type == "Standard")
gen tier2 =  (cert_type == "Intern" | cert_type == "One Year" | cert_type == "One Year Extension" | cert_type == "Probationary" | cert_type == "Probationary Extension" | cert_type == "Probationary Second Extension" | cert_type == "Temporary Exemption" | cert_type == "Visiting International Teacher" | cert_type == "Vocational" | cert_type == "Temporary Teaching Certificate")
gen tier3 = (cert_type == "Emergency" | cert_type == "Emergency Certified" | cert_type == "Emergency Non-Certified" | cert_type == "Emergency Teaching" | cert_type == "Temporary Classroom" | cert_type == "Non-renewable")	
gen non_teacher = (cert_type == "Educational Aide" | cert_type == "Paraprofessional" | cert_type == "Professional" | cert_type == "Standard Professional" | cert_type == "Standard Paraprofessional")
drop if non_teacher==1

// Flag if a teacher was certified
bys id2: egen ever_cert = max(cond(cert_standard == 1 | cert_alt == 1 | cert_other == 1), 1, 0)

// Generate a variable for the first year a teacher became certified
bys id2: egen first_cert_year = min(cond(ever_cert == 1, cert_year, 0))
bys id2: egen first_issdate = min(cert_effective_dt)

bys id2: egen cert_tier1 = max(cond(cert_effective_dt == first_issdate & tier1==1, 1, 0))
bys id2: egen cert_tier2 = max(cond(cert_effective_dt == first_issdate & tier2==1, 1, 0))
bys id2: egen cert_tier3 = max(cond(cert_effective_dt == first_issdate & tier3==1, 1, 0))

replace cert_tier2 = 0 if cert_tier1 == 1
replace cert_tier3 = 0 if cert_tier1 == 1 | cert_tier2 == 1
// Rename for consistency when merging
rename cert_year syear
destring id2, replace

// After this drop, 18,362 teachers not in one of the tiers. 65% with unknown permit, 34% with special assignment, .5% with unknown. Mostly from 1987-1992.

duplicates drop

keep id2 first_cert_year first_issdate tier1 tier2 tier3 

save "$intermediate/certification_2023", replace


/***** 3. Clean employee files ///////////////////// */
use "$intermediate/all_teacher", clear
merge m:1 id2 using "$intermediate/certification_2023"
	
// Confirm data is unique on id2 syear
	duplicates tag syear id2, gen(dups)
	tab dups, m
	drop dups

save "$clean/teacher_background", replace	

/***** 4. Descriptives ///////////////////// */
// Generate categories for experience and pay - SHOULD EDIT CATEGORY RESTRICTIONS
gen exper_cat = 1 if (exper <=3) // Novice
replace exper_cat = 2 if (exper > 3 & exper <=5) // Early Career
replace exper_cat = 3 if (exper > 5 & exper <=10) // Mid-Career
replace exper_cat = 4 if (exper > 10) // Experienced

