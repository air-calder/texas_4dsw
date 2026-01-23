/*
Description: Clean daily calendar data to create dataset of four-day school week schools in TX. 
Author: Jamie Klinenberg
*/
set max_memory 100g

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"
global raw "E:/projects/2403-Evidence/project/data/raw"
global output "E:\projects\2403-Evidence\project\output"

/*****************1. Calendar files to create full dataset************/
forvalues y = 2017 / 2024 {
	
	local f = substr("`y'", 3, 4) // for adapting filename
	use "E:\projects\2403-Evidence\NewFilesReleased\UTA-CDP 24-03-TEA\p_campus_calendar`f'", clear
	drop if year(CALENDAR_DT) == 2010
	drop if CALENDAR_DT < SIXWEEK_BEG_DT | CALENDAR_DT > SIXWEEK_END_DT
	gen week_id = CALENDAR_DT - mod(dow(CALENDAR_DT) + 6, 7)
	bys campus district track week_id SCHOOL_DAY_EVENT: gen days_in_week_event = _N
	gen school_year = `y'
	bys campus district track: egen first_day_of_year = min(CALENDAR_DT)
	bys campus district track: egen last_day_of_year = max(CALENDAR_DT)
	save "$intermediate/calendar_`y'", replace
}

/***** 2. Append together
///////////////////// */

	clear
	forvalues y = 2017 / 2024 {
		append using "$intermediate/calendar_`y'"
	}
	duplicates drop
	format week_id %td
	format first_day_of_year %td
	format last_day_of_year %td
	gen year = year(CALENDAR_DT)
	save "$intermediate/calendar", replace 

/***** 3. Clean full data set
///////////////////// */
	use "$intermediate/calendar", clear
	
 	// Fill in calendar
	preserve
	local start_year = year(r(min))
	local end_year = year(r(max))

	keep campus school_year
	duplicates drop
	tempfile schools
	save `schools'
	restore

	clear 
	local total_years = `end_year' - `start_year' + 1
	local obs_per_year = 365
	
	local total_obs = `total_years' * 366 // to handle leap years
	set obs `total_obs'
	
	gen temp_id =  _n
	gen year = `start_year' + floor((temp_id - 1) / 366)
	gen day_of_year = mod(temp_id - 1, 366) + 1
	
	gen calendar_date = mdy(1, 1, year) + day_of_year - 1
	drop if mi(calendar_date)
	drop if year > `end_year'
	
	drop temp_id day_of_year
	format calendar_date %td
	
	cross using `schools'
	sort district campus track calendar_date
	duplicates drop district campus track calendar_date, force
	
	tempfile full_calendar
	save `full_calendar'
	use `full_calendar', clear
	
	use "$intermediate/calendar", clear
	rename CALENDAR_DT calendar_date
	merge m:1 district campus track calendar_date using `full_calendar'
	
	* _merge == 1 shouldn't happen
	* _merge == 2 non-school days (weekend + breaks)
	* _merge == 3 school days from original data
	
	drop _merge
	gen weekend = inlist(dow(calendar_date), 0, 6)
	gen calendar_day = dow(calendar_date) // 1 is Monday
	gen calendar_week = week(calendar_date)
	gen calendar_month = month(calendar_date)
	gen calendar_year = year(calendar_date)
	duplicates drop district campus track calendar_date, force
	save "$intermediate/calendar_full", replace
	
	use "$intermediate/calendar_full", clear	
	merge m:1 campus district track school_year using "$clean/track_data"
	keep if _merge==3
	drop _merge 
	duplicates tag campus district calendar_date, gen(dup) // no duplicates!
	
	format week_id %td
	rename week_id school_week_id
	gen instructional_days = days_in_week_event if SCHOOL_DAY_EVENT == "01"
	gen waiver_days = days_in_week_event if SCHOOL_DAY_EVENT == "02"
	gen covid_days = days_in_week_event if SCHOOL_DAY_EVENT == "03" | SCHOOL_DAY_EVENT == "04"

	// Count the number of Mondays since the first Monday of the year
	bys district campus school_year: egen first_monday_of_year = min(school_week_id)
	format first_monday_of_year %td

// Assign each observation a value for week type 
	gen less_than_four_day = (instructional_days < 4 & !mi(instructional_days))
	gen four_day_week = (instructional_days == 4 & !mi(instructional_days))
	gen five_day_week = (instructional_days == 5 & !mi(instructional_days))
	gen more_than_five_day = (instructional_days > 5 & !mi(instructional_days))
	bys district campus school_year: egen unique_school_weeks = nvals(school_week_id)
	format school_week_id %td
	
	gen is_monday = (calendar_day == 1)
	gen is_friday = (calendar_day == 5)
	
	bys district campus school_week_id: egen monday_count = total(is_monday)
	bys district campus school_week_id: egen friday_count = total(is_friday)
	
	gen monday_off = (monday_count == 0)
	gen friday_off = (friday_count == 0)

	gen binary_school_week = 1 if !mi(school_week_id)
	replace binary_school_week = 0 if mi(school_week_id)
	
	foreach var in unique_school_weeks instructional_days waiver_days covid_days less_than_four_day four_day_week five_day_week more_than_five_day monday_off friday_off {
	bys district campus school_week_id: egen max_`var' = max(`var')
	}
	save "$clean/calendar_full", replace

// Weekly Calendar
	use "$clean/calendar_full", clear
	keep if binary_school_week == 1
	collapse (first) max_instructional_days max_less_than_four_day max_four_day_week max_five_day_week max_more_than_five_day max_unique_school_weeks max_monday_off max_friday_off first_day_of_year last_day_of_year calendar_week calendar_month, by(campus district school_week_id school_year) fast
	gen no_week_type = 1 if max_less_than_four_day==0 & max_four_day_week==0 & max_five_day_week==0 & max_more_than_five_day==0
	save "$clean/weekly_calendar", replace
	
	use "$clean/weekly_calendar", clear
	collapse (first) max_unique_school_weeks first_day_of_year last_day_of_year (sum) max_instructional_days max_less_than_four_day max_four_day_week max_five_day_week max_more_than_five_day no_week_type max_monday_off max_friday_off, by(campus district school_year)
	gen pct_lt4 = max_less_than_four_day / max_unique_school_weeks
	gen pct_four = max_four_day_week / max_unique_school_weeks
	gen pct_five = max_five_day_week / max_unique_school_weeks
	gen pct_mt5 = max_more_than_five_day / max_unique_school_weeks
	gen pct_no_week = no_week_type / max_unique_school_weeks
	
// Create ranges for 4dsw	
	gen four_day_range = 0 if pct_four == 0
	replace four_day_range = 1 if pct_four >= 0 & pct_four <= .25
	replace four_day_range = 2 if pct_four > .25 & pct_four <= .5
	replace four_day_range = 3 if pct_four > .5 & pct_four <= .75
	replace four_day_range = 4 if pct_four > .75
	save "$clean/yearly_calendar", replace

// Bring in tracker data
	use "E:\projects\2403-Evidence\NewFilesReleased\4DSW_all", clear
	gen district = substr(StateAgencyID, 4, .)
	gen firstyear = substr(FirstYear, 6, .)
	replace firstyear = "2018" if firstyear == "2021 / 2017-2018"
	replace firstyear = "2021" if firstyear == "2021 / 2022-2023"
	replace firstyear = "2021" if firstyear == "2021 / 2023-2024"
	replace firstyear = "2021" if firstyear == "2022 / 2020-2021"
	replace firstyear = "2021" if firstyear == "2024 / 2021-2022"
	replace firstyear = "2024" if firstyear == "2025 / 2023-2024"
	destring firstyear, replace
	gen ever4DSW = (UH == 1 | Jamie == 1 | Cade == 1)
	merge 1:m district using "$clean/yearly_calendar"
	gen pre_adoption = (school_year < firstyear & !mi(firstyear))
	gen post_adoption = (school_year >= firstyear & !mi(firstyear))
	rename NCESAgencyID AgencyNCES
	keep if _merge == 3
	drop _merge
	tab firstyear
	foreach var in ever4DSW Jamie Cade UH MDR {
		replace `var' = 0 if firstyear==2025
	}
	save "$clean/yearly_tracker_merge", replace
	4813380
// Bring in CCD Data - create one school-level CCD data set and one district-level
	** School
	use "$raw\ccd_school", clear
	rename year school_year
	rename StateSchoolID campus
	destring AgencyNCES, replace
	duplicates drop campus school_year, force
	merge 1:m campus school_year using "$clean/yearly_tracker_merge"
	save "$clean/yearly_ccd_school_tracker", replace
	
	** District
	use "$raw\ccd_district", clear
	rename year school_year
	destring AgencyNCES, replace
	merge 1:m AgencyNCES school_year using "$clean/yearly_tracker_merge"
	save "$clean/yearly_ccd_district_tracker", replace

// Generate a dataset that collapses to the district-level by weighting schools by school enrollment.
	use "$clean/yearly_ccd_school_tracker", clear
	collapse (first) ever4DSW Jamie Cade UH MDR firstyear (mean) max_unique_school_weeks first_day_of_year last_day_of_year max_instructional_days max_less_than_four_day max_four_day_week max_five_day_week max_more_than_five_day no_week_type max_monday_off max_friday_off pct_lt4 pct_four pct_five pct_mt5 [aweight=sch_TotalEnrollment], by(AgencyNCES AgencyName school_year)
	rename school_year year
	tostring AgencyNCES, replace
	duplicates drop AgencyNCES year, force
	merge 1:1 AgencyNCES year using "$raw/ccd_district"
	rename year school_year
	save "$clean/ccd_district_weighted", replace 

// PCT of districts, schools, and students in 4DSW over time
	** Districts
	use "E:\projects\2403-Evidence\NewFilesReleased\4DSW_all", clear
	rename NCESAgencyID AgencyNCES
	gen firstyear = substr(FirstYear, 6, .)
	replace firstyear = "2018" if firstyear == "2021 / 2017-2018"
	replace firstyear = "2021" if firstyear == "2021 / 2022-2023"
	replace firstyear = "2021" if firstyear == "2021 / 2023-2024"
	replace firstyear = "2021" if firstyear == "2022 / 2020-2021"
	replace firstyear = "2021" if firstyear == "2024 / 2021-2022"
	replace firstyear = "2024" if firstyear == "2025 / 2023-2024"
	destring firstyear, replace
	tostring AgencyNCES, replace
	merge 1:m AgencyNCES using "$raw/ccd_district"
	gen ever4DSW = (UH == 1 | Jamie == 1 | Cade == 1)
	gen current_4DSW = (year >= firstyear & ever4DSW == 1)
	bys year: gen num_districts = _n
	collapse (sum) current_4DSW (last) num_districts, by(year)
	gen pct_cur_4DSW_dist = current_4DSW / num_districts
	save "$clean/pct_data", replace
	
	** Schools
	use "E:\projects\2403-Evidence\NewFilesReleased\4DSW_all", clear
	rename NCESAgencyID AgencyNCES
	gen firstyear = substr(FirstYear, 6, .)
	replace firstyear = "2018" if firstyear == "2021 / 2017-2018"
	replace firstyear = "2021" if firstyear == "2021 / 2022-2023"
	replace firstyear = "2021" if firstyear == "2021 / 2023-2024"
	replace firstyear = "2021" if firstyear == "2022 / 2020-2021"
	replace firstyear = "2021" if firstyear == "2024 / 2021-2022"
	replace firstyear = "2024" if firstyear == "2025 / 2023-2024"
	destring firstyear, replace
	tostring AgencyNCES, replace
	merge 1:m AgencyNCES using "$raw/ccd_school"
	gen ever4DSW = (UH == 1 | Jamie == 1 | Cade == 1)
	gen current_4DSW = (year >= firstyear & ever4DSW == 1)
	bys year: gen num_schools = _n
	bys year: gen num_4DSW_students = sch_TotalEnrollment if current_4DSW == 1
	collapse (sum) current_4DSW num_4DSW_students sch_TotalEnrollment (last) num_schools, by(year)
	gen pct_cur_4DSW_stu = num_4DSW_students / sch_TotalEnrollment
	gen pct_cur_4DSW_sch = current_4DSW / num_schools
	merge 1:1 year using "$clean/pct_data"
	keep if _merge == 3
	save "$clean/pct_data", replace
	
// Case Studies
	 use "$clean/ccd_district_weighted", clear
	gen four_day_range = 0 if pct_four == 0
	replace four_day_range = 1 if pct_four >= 0 & pct_four <= .25
	replace four_day_range = 2 if pct_four > .25 & pct_four <= .5
	replace four_day_range = 3 if pct_four > .5 & pct_four <= .75
	replace four_day_range = 4 if pct_four > .75
	
	browse if four_day_range == 4 & ever4DSW == 0 & school_year == 2024