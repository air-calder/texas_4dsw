/*
Description: Create dataset with # students per track for 4DSW project
Author: Jamie Klinenberg
*/

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"


/*****************1. Student Attendance files to create track dataset************/
forvalues y = 2017 / $last_year {
	
		local f = substr("`y'", 3, 4) // for adapting filename
		di "loading attendance year `y' (file p_attend_student`f')"
		use "E:/projects/2403-Evidence/NewFilesReleased/TEA/p_attend_student`f'.dta", clear
		rename *, lower
		
/*			if `y' == 2021 {
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
*/			
			// save
			gen syear = `y'
			compress
			save "$intermediate/stu_attend_`y'", replace
	}
			
/***** 2. Append together
///////////////////// */

	clear
	forvalues y = 2017 / $last_year {
		append using "$intermediate/stu_attend_`y'"
	}
	save "$intermediate/stu_attend", replace 
	
/***** 3. Clean full data set
///////////////////// */
	
	use "$intermediate/stu_attend", clear
	duplicates drop id2 campus district track syear, force
	gen count = 1 
	collapse (count) students_per_track = count, by(district campus track syear)
	
	egen students_per_campus = total(students_per_track), by(district campus syear)
	gen pct_students_per_track = students_per_track / students_per_campus
	rename syear school_year
	
	save "$intermediate/students_per_track", replace

/* Select track with highest % of students */
	use "$intermediate/students_per_track", clear
	egen max_pct = max(pct_students_per_track), by(district campus school_year)
	keep if pct_students_per_track == max_pct 
	
	duplicates list campus district school_year, gen(dup) // 24 duplicates
	egen track_dups = count(track), by(district campus school_year pct_students_per_track)
	gen rand = runiform() if track_dups > 1
	gen dummy_sort = cond(track_dups > 1, rand, 0)
	gsort district campus -dummy_sort
	bys district campus school_year (dummy_sort): keep if _n == 1
	
	duplicates tag campus district school_year, gen(dup2) // no duplicates!
	drop dup dup2 track_dups rand dummy_sort max_pct
	save "$clean/track_data", replace