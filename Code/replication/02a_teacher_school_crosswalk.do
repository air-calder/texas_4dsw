
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"


// 2015-2019 ran and saved individually.
forvalues y = 15 / 19 {
	
	di "Starting year 20`y'"
	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_teacher_class_assign`y'", clear
	rename *, lower
		
	qui keep id2 district campus
	so id2 district campus
	by id2 district campus: gen obs = _n
	gsort id2 -obs
	qui by id2: keep if _n == 1
	drop obs
	
	gen syear = 20`y'
	
	qui distinct id2
	di "year `y': `r(N)' teachers"
	assert r(N) > 250000
	
	qui save "$intermediate/tch_school_assign_`y'", replace
}

/* 
Step 2. 2020+
*/

// 2020 and 2021 has one file that has both stu and tch (p_class_roster_wntr`y') 
forvalues y = 20 / 21 {
	
	di "Starting year 20`y'"

	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_class_roster_wntr`y'", clear
	rename *, lower
	
	rename staff_id2 id2
	rename district_id district
	rename campus_id campus
	
	qui keep id2 district campus
	so id2 district campus
	by id2 district campus: gen obs = _n
	gsort id2 -obs
	qui by id2: keep if _n == 1
	drop obs
	
	gen syear = 20`y'
	
	qui distinct id2
	di "year `y': `r(N)' teachers"
	assert r(N) > 250000
		
	qui save "$intermediate/tch_school_assign_`y'", replace
}

// 2022 and 2023. we're back to separate files for teacher and student_id1
forvalues y = 22 / 23 {
	
	di "Starting year 20`y'"

	use "E:\projects\2403-Evidence\NewFilesReleased\TEA\p_class_roster_staff_wntr`y'", clear
	rename *, lower
	
	rename staff_id2 id2
	rename district_id district
	rename campus_id campus
	
	qui keep id2 district campus
	so id2 district campus
	by id2 district campus: gen obs = _n
	gsort id2 -obs
	qui by id2: keep if _n == 1
	drop obs
	
	gen syear = 20`y'
	
	qui distinct id2
	di "year `y': `r(N)' teachers"
	assert r(N) > 250000
		
	qui save "$intermediate/tch_school_assign_`y'", replace
	
	}
	
/* Step 3. Append everything together and make sure variables are consistent across years
*/
clear
forvalues y = 15 / 23 {
	append using "$intermediate/tch_school_assign_`y'"
}	

rename id2 teachid
drop if teachid == ""

tab syear

destring teachid, replace
destring district, replace

save "E:\projects\2403-Evidence\project\data\clean\teacher_school_assign.dta", replace

