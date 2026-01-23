/*
Description: Create dataset with student enrollment data for 4DSW project
Author: Jamie Klinenberg
*/

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

/*****************1. Student Enrollment Demographic files to create full dataset************/
forvalues y = 2000 / $last_year {
	
		local f = substr("`y'", 3, 4) // for adapting filename
		di "loading enrollment year `y' (file p_enroll_demog`f')"
		use "E:/projects/2403-Evidence/NewFilesReleased/TEA/p_enroll_demog`f'f.dta", clear
		rename *, lower
		replace id1 = trim(id1)
		destring id1, gen(id1_num)
		
		// Resolve duplicates.
		if `y' == 2017 {
		    duplicates drop
			drop if id1_num == XXX & grade == "PK" // 2016 grade for this student was 02.
			drop if id1_num == XXX & ethnic  == "W" // Student is not in previous or following dataset and duplicate has more information
			duplicates tag id1_num district, gen(dup_id)
			assert dup_id < 1 // should be no more duplicates
		}
		
		if `y' == 2022 {
		    drop if id1_num == XXX & grade == "07" // 2021 grade was 05 so this is dropped
			drop if id1_num == XXX & grade == "10" // 2021 grade was 07 so this is dropped
			drop if id1_num == XXX & lep == "5" // 2023 LEP = 5 & 2021/2020 LEP = 3
			drop if id1_num == XXX & sex == "M" // F in 2021 and 2020
			drop if id1_num == XXX & speced == "1" // Speced is 0 in 2023 and 2021.
			duplicates drop
			duplicates tag id1_num district, gen(dup_id)
			browse if dup_id == 1 // should be no more duplicates
		}
		if `y' == 2023 {
			drop if id1_num == XXX & grade == "PK" // 2022 grade for this student was 01.
			drop if id1_num == XXX & sex == "M" // F in 2021 and 2020
			drop if id1_num == XXX & grade == "PK" // Keeping grade 01 observation with more info
			duplicates drop
			duplicates tag id1_num district, gen(dup_id)
			assert dup_id < 1 // should be no more duplicates
		}
		
		if `y' == 2024 {
		 duplicates drop	
			drop if id1_num == XXX & sex == "M" // F in 2021 and 2020
			drop if id1_num == XXX & speced == "1" // Speced is 0 in 2023 and 2021.
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & grade == "KG" // 1st grade in 2023i 
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & grade == "05" // KG in 2023
			drop if id1_num == XXX & sex == "F" // M in 2023
			drop if id1_num == XXX & grade == "09" // 6th grade in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & grade == "01" // 1st grade in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & sex == "F" // M in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & sex == "F" // M in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & grade == "11" // 9th grade in 2023
			drop if id1_num == XXX & grade == "08" // 5th grade in 2022
			drop if id1_num == XXX & grade == "06" // 6th grade in 2023
			drop if id1_num == XXX & sex == "M" // F in 2023
			drop if id1_num == XXX & grade == "PK" // grade 0 in 2023
			drop if id1_num == XXX & sex == "F" // M in previous years
			drop if id1_num == XXX & grade == "09" // 6th grade in 2022
			drop if id1_num == XXX & grade == "07" // 7th grade in 2022
			drop if id1_num == XXX & grade == "11" // 9th grade in 2023g
			drop if id1_num == XXX & grade == "KG" // check 2023
			drop if id1_num == XXX & grade == "05" // 5th grade in 2023
			drop if id1_num == XXX & grade == "KG" // 1st in 2022
			drop if id1_num == XXX & lep == "0" // 1 in 2022 check 2023
			drop if id1_num == XXX & sex == "M" // F in 2022
			drop if id1_num == XXX & sex == "M" // F in 2022
			drop if id1_num == XXX & eth_race == 48 // eth_race 33 in 2022
			drop if id1_num == XXX & grade == "12" // grade 8 in 2022
			
			// for unresolved dups, keep a random obs
			gen tag = runiform()
			gen drop_flag = 0
			bys id1_num district (tag): replace drop_flag = 1 if inlist(id1_num, XXX, XXX, XXX, XXX, XXX, XXX, XXX, XXX, XXX, XXX, XXX) & _n == 1 
			drop if drop_flag==1
			drop drop_flag tag
			duplicates tag id1_num district, gen(dup_id)
			assert dup_id < 1 // should be no more duplicates
			drop id1_num
			
		}
	
	// Make sure unique at correct level.
		duplicates drop
		qui duplicates report id1 district
		assert r(N) == r(unique_value)

	// Clean	
		// Gender
			tab sex, m
			gen female = sex == "F"
			tab female
			
		// Race/ethnicity
			tab ethnic
			capture drop race
			gen race = 1 if inlist(ethnic, "1", "I", "P", "T")
			replace race = 2 if inlist(ethnic, "2", "A")
			replace race = 3 if inlist(ethnic, "3", "B")
			replace race = 4 if inlist(ethnic, "4", "H")
			replace race = 5 if inlist(ethnic, "5", "W")
			
			lab def racelbl /// 
				1 "Other" ///
				2 "Asian" ///
				3 "Black" ///
				4 "Hispanic" ///
				5 "White", add
				
			lab values race racelbl
			tab race
			
			/// Economic
				tab economic
				gen frl = inlist(economic, "01", "02", "99")
				tab economic frl
				
			// Grade
				tab grade
				drop if inlist(grade, "EE", "PK")
				replace grade = "0" if grade == "KG"
				destring grade, replace
				
			// LEP
				tab lep, m
				replace lep = "1" if lep != "0"
				destring lep, replace
			
			// Speced
				tab speced, m
				replace speced = "1" if speced != "0"
				destring speced, replace
			
			// Gifted
				tab gifted, m
				destring gifted, replace
				
 			// save
			gen syear = `y'
			compress
			save "$intermediate/enroll_`y'", replace
	}
			
/***** 2. Append together
///////////////////// */

	clear
	forvalues y = 2000 / $last_year {
		append using "$intermediate/enroll_`y'"
	}
	save "$intermediate/stu_enroll_demog", replace 
	
/**** 3. Clean
/////////// */
use "$intermediate/stu_enroll_demog", clear
replace district = trim(district) 
ren district district_enroll
tostring grade, replace
merge m:1 id1 syear using "$clean/stu_attend_demog", keepusing(district)
ren district district_attend
tab _merge

/*  _merge==1 -> in enrollment data but missing attendance data (0.3% of obs)
_merge==2 -> in attendance data but missing enrollment (can drop from this file)
Using this merge to keep the district with most days in membership (from attendance file), so not keeping any other attendance variables
*/

unique id1 syear // check unique student-year count
drop if _merge == 2 

unique id1 syear // check unique student-year count (should be less than last check)
	// drop obs that are duplicate because the student is associated with two (or more) districts in the enrollment data, each of which merged on to the one district they are associated with in the attendance data. We want to keep the district that matches the district we kept in the attendance data (where they had the most days of membership) 
	duplicates tag id1 syear, gen(dup)
	drop if dup>=1 & district_attend!=district_enroll & _merge==3
	drop dup _merge
	ren district_enroll district
	drop id1_num
	destring id1, gen(id1_num)
	duplicates report id1_num syear
	duplicates drop id1_num syear, force // drops 136 duplicates to run tsset
unique id1_num syear // check unique student-year count (should be same as last check)
isid id1_num syear // confirm unique by student id and year

	// Retained: in same grade in following year
		destring grade, replace
		tsset id1_num syear
		gen retained = F.grade <= grade & F.grade != .
		qui sum syear
		replace retained = . if syear == r(max) //for the most recent year, we don't know retained or not
		tab syear retained
		lab var retained "Was retained in grade after this year"
		
	// Same school in current year compared to prior year - consider middle school discrepancy
		destring campus, replace
		gen same_prior_school = F.campus <= campus & F.campus != .
		replace same_prior_school = . if syear == r(max)
		tab syear same_prior_school
		lab var same_prior_school "Same school in current year compared to prior year"
		
	// Same school district in current year compared to prior year.
		destring district, replace
		gen same_prior_district = F.district <= district & F.district != .
		replace same_prior_district = . if syear == r(max)
		tab syear same_prior_district
		lab var same_prior_district "Same school district in current year compared to prior year" 
		
/* ///////////
/// Clean up and save 
///////////// */
		* make sure everything looks consistent across years (# obs and values)
		tab syear race
		tab syear grade
		bys syear: sum female grade frl lep speced retained
		
		compress
	save "$clean/stu_enroll_demog", replace

