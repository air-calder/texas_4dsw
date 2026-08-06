/*
Description: Create dataset with student attendance data for 4DSW project - using Alejandra's code from Gates Math TX
Author: Jamie Klinenberg
*/

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

/*****************1. Student Attendance Demographic files to create full dataset************/
forvalues y = 2000 / $last_year {
	
		local f = substr("`y'", 3, 4) // for adapting filename
		di "loading attendance year `y' (file p_attend_demog`f')"
		use "E:/projects/2403-Evidence/NewFilesReleased/TEA/p_attend_demog`f'.dta", clear
		rename *, lower
		
			// Resolve duplicates. - taken from Alejandra's code
			if `y' == 2021 {
				drop if id1 == "XXX" & sex == "M"
				duplicates drop
				duplicates tag id1 district, gen(dup_id)
				browse if dup_id==1
			}
			if 	`y' == 2022 {
				drop if id1 == "XXX" & sex == "M"
				drop if id1 == "XXX" & grade == "10"
				drop if id1 == "XXX" & grade =="PK" 
				drop if id1 == "XXX" & grade == "07"
				drop if id1 == "XXX" & discipline_flag == "0"
				drop if id1 == "XXX" & tot_days_absent == 6
				drop if id1 == "XXX" & se_attend == "0"
				drop if id1 == "XXX" & se_attend == "0"
				drop if id1 == "XXX" & grade == "10"
				drop if id1 == "XXX" & se_attend == "1"
				duplicates drop
				duplicates tag id1 district, gen(dup_id)
				browse if dup_id==1
			}
			if `y' == 2023 {
				duplicates drop 
				drop if id1 == "XXX" & grade == "PK"
				drop if id1 == "XXX" & grade == "PK"
				drop if id1 == "XXX" & sex == "M"
				drop if id1 == "XXX" & state_assigned_flag == "0" & district == "101912"
				drop if id1 == "XXX" & tot_days_absent == 6
				duplicates tag id1 district, gen(dup_id)
				browse if dup_id == 1
			}
			if `y' == 2024 {
				duplicates drop
				drop if id1 == "XXX" & sex == "M"
				drop if id1 == "XXX" & grade == "KG"
				drop if id1 == "XXX" & grade == "KG"
				drop if id1 == "XXX" & sex == "M"
				drop if id1 == "XXX" & grade == "05"

			}
			
			/// Make sure unique at district level
			qui duplicates report id1 district
			assert r(N) == r(unique_value)
			
			// save
			gen syear = `y'
			compress
			save "$intermediate/attend_`y'", replace
	}
			
/***** 2. Append together
///////////////////// */

	clear
	forvalues y = 2000 / $last_year {
		append using "$intermediate/attend_`y'"
	}
	save "$intermediate/stu_attend_demog", replace 
	
/***** 3. Clean full data set
///////////////////// */
	
	use "$intermediate/stu_attend_demog", clear
	foreach x in absent present member {
	bys id1 syear: egen days_`x' = sum(tot_days_`x')
	}
	
	replace pct_attend = days_present/days_member
	
	// For students with > 180 days absent or > 365 days present or member, replace with missing
	foreach x in absent present member {
		replace days_`x' = . if days_absent > 180 | days_present > 365 | days_member > 365
	}
	
	* keep district with most days in membership 
	tab syear
	gsort id1 syear -tot_days_member
	by id1 syear: keep if _n == 1
	tab syear
	
	duplicates report id1 syear
	assert r(N) == r(unique_value) // passed!
	replace id1 = trim(id1)
	replace district = trim(district)
	
	* drop attendance variables associated with a single district for a student who was enrolled in multiple districts within a year, as these are no longer valid at the student-level (across districts) 
	drop tot_days*
	
	*create numeric id1 var for later merge
	destring id1, gen(id1_num)
	
	compress
	save "$clean/stu_attend_demog", replace
