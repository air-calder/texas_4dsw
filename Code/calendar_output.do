/*
Description: Create tables and figures of calendar data for TX four-day school week brief. 
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
global descriptives "E:\projects\2403-Evidence\project\output\descriptives"

// Main Paper Tables
** Table 1: 4DSW Ranges + Calendar Structures Across Indicators in 2024 - Use District-Level in Paper
	// School-Level
use "$clean/yearly_tracker_merge", clear
gen all_schools = 1
gen never4DSW = (ever4DSW != 1)
	// Four-Day Ranges by Indicator
	keep if school_year == 2024
	gen four_day_range = 1 if pct_four >= 0 & pct_four <= .25
	replace four_day_range = 2 if pct_four > .25 & pct_four <= .5
	replace four_day_range = 3 if pct_four > .5 & pct_four <= .75
	replace four_day_range = 4 if pct_four > .75
	foreach var in all_schools ever4DSW never4DSW Jamie Cade UH MDR {
		tabout four_day_range `var' using "$output/descriptives/sch_4dsw_range_`var'.xls", replace
	}
	
	// Average Calendar Structure by Indicator
	foreach x in all_schools ever4DSW never4DSW Jamie Cade UH MDR {
	preserve	
	keep if `x' == 1
	foreach var in max_instructional_days max_unique_school_weeks pct_four pct_five pct_lt4 first_day_of_year last_day_of_year max_monday_off max_friday_off {
	egen mean_`var' = mean(`var')
	egen sd_`var' = sd(`var')
	}
	format mean_first_day_of_year mean_last_day_of_year %td
	gen school_obs = _n
	collapse (first) mean_max_instructional_days sd_max_instructional_days mean_max_unique_school_weeks sd_max_unique_school_weeks mean_pct_four sd_pct_four mean_pct_five sd_pct_five mean_pct_lt4 sd_pct_lt4 mean_first_day_of_year sd_first_day_of_year mean_last_day_of_year sd_last_day_of_year mean_max_monday_off sd_max_monday_off mean_max_friday_off sd_max_friday_off (last) school_obs 
	export excel using "$output/descriptives/sch_cldr_avgs_`x'_24", sheetreplace firstrow(variables)
	restore
 	}
	// First-Year of Adoption
	use "$clean/yearly_tracker_merge", clear
	collapse (first) firstyear, by(campus ever4DSW Jamie Cade UH MDR)
	foreach var in ever4DSW Jamie Cade UH MDR {
	tabout firstyear if `var' == 1 using "$output/descriptives/sch_firstyr_`var'.xls", replace
	}	
	
	// # Districts 
	use "E:\projects\2403-Evidence\NewFilesReleased\4DSW_all", clear
	gen firstyear = substr(FirstYear, 6, .)
	gen ever4DSW = (UH == 1 | Jamie == 1 | Cade == 1)
	replace firstyear = "2018" if firstyear == "2021 / 2017-2018"
	replace firstyear = "2021" if firstyear == "2021 / 2022-2023"
	replace firstyear = "2021" if firstyear == "2021 / 2023-2024"
	replace firstyear = "2021" if firstyear == "2022 / 2020-2021"
	replace firstyear = "2021" if firstyear == "2024 / 2021-2022"
	replace firstyear = "2024" if firstyear == "2025 / 2023-2024"
	destring firstyear, replace
	foreach var in ever4DSW Jamie Cade UH MDR {
		replace `var' = 0 if firstyear==2025
	}
	foreach var in ever4DSW Jamie Cade UH MDR {
	tabout firstyear if `var' == 1 using "$output/descriptives/dist_firstyr_`var'.xls", replace
	}
	
	// District-Level Weighted
use "$clean/ccd_district_weighted", clear
gen all_districts = 1
gen never4DSW = (ever4DSW != 1)
	// Four-Day Ranges by Indicator
	keep if school_year == 2024
	gen four_day_range = 1 if pct_four >= 0 & pct_four <= .25
	replace four_day_range = 2 if pct_four > .25 & pct_four <= .5
	replace four_day_range = 3 if pct_four > .5 & pct_four <= .75
	replace four_day_range = 4 if pct_four > .75
	foreach var in all_districts ever4DSW never4DSW Jamie Cade UH MDR {
		tabout four_day_range `var' using "$output/descriptives/dist_4dsw_range_`var'.xls", replace
	}
	
	// Average Calendar Structure by Indicator
	foreach x in all_districts ever4DSW never4DSW Jamie Cade UH MDR {
	preserve	
	keep if `x' == 1
	foreach var in max_instructional_days max_unique_school_weeks pct_four pct_five pct_lt4 first_day_of_year last_day_of_year max_monday_off max_friday_off {
	egen mean_`var' = mean(`var')
	egen sd_`var' = sd(`var')
	}
	format mean_first_day_of_year mean_last_day_of_year %td
	gen district_obs = _n
	collapse (first) mean_max_instructional_days sd_max_instructional_days mean_max_unique_school_weeks sd_max_unique_school_weeks mean_pct_four sd_pct_four mean_pct_five sd_pct_five mean_pct_lt4 sd_pct_lt4 mean_first_day_of_year sd_first_day_of_year mean_last_day_of_year sd_last_day_of_year mean_max_monday_off sd_max_monday_off mean_max_friday_off sd_max_friday_off (last) district_obs 
	export excel using "$output/descriptives/dist_cldr_avgs_`x'_24", sheetreplace firstrow(variables)
	restore
 	}
	// First-Year of Adoption
	use "$clean/ccd_district_weighted", clear
	collapse (first) firstyear, by(AgencyNCES ever4DSW Jamie Cade UH MDR)
	foreach var in ever4DSW Jamie Cade UH MDR {
	    tabout firstyear if `var' == 1 using "$output/descriptives/dist_firstyear_`var'.xls", replace
	}
	
** Table 2: Calendar Structure Comparison in 2017 and 2024 - Use School-Level in Paper	
	use "$clean/yearly_tracker_merge", clear
	foreach x in 2017 2024 {
		foreach y in 0 1 {
	preserve		
	keep if school_year == `x' & ever4DSW == `y' 
	foreach var in max_instructional_days max_unique_school_weeks pct_four pct_five pct_lt4 first_day_of_year last_day_of_year  max_monday_off max_friday_off {
	egen mean_`var' = mean(`var')
	egen sd_`var' = sd(`var')
	}
	format mean_first_day_of_year mean_last_day_of_year %td	
	gen dist_obs = _n
	collapse (first) mean_max_instructional_days sd_max_instructional_days mean_max_unique_school_weeks sd_max_unique_school_weeks mean_pct_four sd_pct_four mean_pct_five sd_pct_five mean_pct_lt4 sd_pct_lt4 mean_first_day_of_year sd_first_day_of_year mean_last_day_of_year sd_last_day_of_year mean_max_monday_off sd_max_monday_off mean_max_friday_off sd_max_friday_off (last) dist_obs 
	export excel using "$output/descriptives/sch_cldr_avgs_`x'`y'", sheetreplace firstrow(variables)
	restore
		}
	}
	
	use "$clean/ccd_district_weighted", clear
	foreach x in 2017 2024 {
			foreach y in 0 1 {
		preserve		
		keep if school_year == `x' & ever4DSW == `y' 
		foreach var in max_instructional_days max_unique_school_weeks pct_four pct_five pct_lt4 first_day_of_year last_day_of_year  max_monday_off max_friday_off {
		egen mean_`var' = mean(`var')
		egen sd_`var' = sd(`var')
		}
		format mean_first_day_of_year mean_last_day_of_year %td	
		gen dist_obs = _n
		collapse (first) mean_max_instructional_days sd_max_instructional_days mean_max_unique_school_weeks sd_max_unique_school_weeks mean_pct_four sd_pct_four mean_pct_five sd_pct_five mean_pct_lt4 sd_pct_lt4 mean_first_day_of_year sd_first_day_of_year mean_last_day_of_year sd_last_day_of_year mean_max_monday_off sd_max_monday_off mean_max_friday_off sd_max_friday_off (last) dist_obs 
		export excel using "$output/descriptives/dis_cldr_avgs_`x'`y'", sheetreplace firstrow(variables)
		restore
			}
		}
	
// Appendix	Tables
** Table 1A: Calendar structure Over Time Across All Schools
	use "$clean/yearly_calendar", clear
	forval y = 2017 / 2024 {
	preserve
	keep if school_year == `y'
	foreach var in max_instructional_days max_unique_school_weeks pct_four pct_five pct_lt4 first_day_of_year last_day_of_year max_monday_off max_friday_off {
	egen mean_`var' = mean(`var')
	egen sd_`var' = sd(`var')
	}
	format mean_first_day_of_year mean_last_day_of_year %td
	gen school_obs = _n
	collapse (first) mean_max_instructional_days sd_max_instructional_days mean_max_unique_school_weeks sd_max_unique_school_weeks mean_pct_four sd_pct_four mean_pct_five sd_pct_five mean_pct_lt4 sd_pct_lt4 mean_first_day_of_year sd_first_day_of_year mean_last_day_of_year sd_last_day_of_year mean_max_monday_off sd_max_monday_off mean_max_friday_off sd_max_friday_off (last) school_obs 
	export excel using "$output/descriptives/sch_cldr_avgs_`y'", sheetreplace firstrow(variables)
	restore
 	}
	

** Table 2A: District Characteristics of Ever 4DSW Schools in 2024
	use "$clean/yearly_ccd_tracker", clear
	keep if school_year == 2024 & ever4DSW == 1
	gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
	gen nonrural = (rural == 0)
	gen lowFRL = (dis_pct_FRL_quartile == 1)
	gen midFRL = (dis_pct_FRL_quartile == 2 | dis_pct_FRL_quartile == 3)
	gen highFRL = (dis_pct_FRL_quartile == 4)
	gen lowNW = (dis_pct_non_white_quartile == 1)
	gen midNW = (dis_pct_non_white_quartile == 2 | dis_pct_non_white_quartile == 3)
	gen highNW = (dis_pct_non_white_quartile == 4)
	gen lowenroll = (dis_TotalEnrollment <= 1000)
	gen midenroll = (dis_TotalEnrollment > 1000 & dis_TotalEnrollment <= 10000)
	gen highenroll = (dis_TotalEnrollment > 10000)
	
	foreach x in rural nonrural lowFRL midFRL highFRL lowNW midNW highNW lowenroll midenroll highenroll {
	preserve	
	keep if `x' ==  1
	foreach var in max_instructional_days max_unique_school_weeks pct_four pct_five pct_lt4 first_day_of_year last_day_of_year  max_monday_off max_friday_off {
	egen mean_`var' = mean(`var')
	egen sd_`var' = sd(`var')
	}
	format mean_first_day_of_year mean_last_day_of_year %td
	gen school_obs = _n
	collapse (first) mean_max_instructional_days sd_max_instructional_days mean_max_unique_school_weeks sd_max_unique_school_weeks mean_pct_four sd_pct_four mean_pct_five sd_pct_five mean_pct_lt4 sd_pct_lt4 mean_first_day_of_year sd_first_day_of_year mean_last_day_of_year sd_last_day_of_year mean_max_monday_off sd_max_monday_off mean_max_friday_off sd_max_friday_off (last) school_obs 
	export excel using "$output/descriptives/cldr_avgs_`x'_24", sheetreplace firstrow(variables)
	restore
 	}
	
	
** Table 3A: District Characteristics Comparisons in 2017 and 2024 	
	use "$clean/ccd_district_weighted", clear
	gen rural = (District_Urbanicity == "Rural, distant" | District_Urbanicity == "Rural, fringe" | District_Urbanicity == "Rural, remote")
	gen town = (District_Urbanicity == "Town, distant" | District_Urbanicity == "Town, fringe" | District_Urbanicity == "Town, remote")
	gen suburb = (District_Urbanicity == "Suburb, large" | District_Urbanicity == "Suburb, midsize" | District_Urbanicity == "Suburb, small")
	gen city = (District_Urbanicity == "City, large" | District_Urbanicity == "City, midsize" | District_Urbanicity == "City, small")
	
	foreach x in 2017 2024 {
		foreach y in 0 1 {
	preserve		
	keep if school_year == `x' & ever4DSW == `y' 
	foreach var in dis_TotalEnrollment dis_pct_FRL dis_pct_White dis_pct_Black dis_pct_Hispanic {
	egen mean_`var' = mean(`var')
	egen sd_`var' = sd(`var')	
	}
	gen dist_obs = _n
	collapse (first) mean_dis_TotalEnrollment sd_dis_TotalEnrollment mean_dis_pct_FRL sd_dis_pct_FRL mean_dis_pct_White sd_dis_pct_White mean_dis_pct_Black sd_dis_pct_Black mean_dis_pct_Hispanic sd_dis_pct_Hispanic (sum) rural town suburb city	(last) dist_obs
	export excel using "$output/descriptives/dist_char_`x'`y'", sheetreplace firstrow(variables)
	restore
		}
	}

	
/// Figures for brief
** PCT Weeks Histogram - 4dsw vs. 5dsw
	use "$clean/yearly_tracker_merge", clear
	keep if school_year == 2024 & ever4DSW == 0
	foreach var in pct_lt4 pct_four pct_five {
	    replace `var' = `var' * 100
	}
	twoway /// 
	(hist pct_lt4, width(5) freq color(red%40)) ///
	(hist pct_four, width(5) freq color(blue%40)) ///
	(hist pct_five, width(5) freq color(green%40)), ///
	legend(order(1 "Less than Four Days" 2 "Four Days" 3 "Five Days")) ///
	xtitle("Percent of School Weeks") ytitle("Number of Schools") ///
	name(hist1, replace)
//	graph export "$descriptives/pct_5DSW_2024_hist.png", replace width(1200) height(800)
	
	use "$clean/yearly_tracker_merge", clear
	keep if school_year == 2024 & ever4DSW == 1
	foreach var in pct_lt4 pct_four pct_five {
	    replace `var' = `var' * 100
	}
	twoway /// 
	(hist pct_lt4, width(5) freq color(red%40)) ///
	(hist pct_four, width(5) freq color(blue%40)) ///
	(hist pct_five, width(5) freq color(green%40)), ///
	legend(order(1 "Less than Four Days" 2 "Four Days" 3 "Five Days")) ///
	xtitle("Percent of School Weeks") ytitle("Number of Schools") ///
	name(hist2, replace)
//	graph export "$descriptives/pct_4dsw_2024_hist.png", replace width(1200) height(800)
	
	graph combine hist1 hist2, rows(1) cols(2) ycommon xcommon
	
// PCT of districts, schools, and students in 4DSW over time
	use "$clean/pct_data", clear
	foreach var in pct_cur_4DSW_dist pct_cur_4DSW_sch pct_cur_4DSW_stu {
	    replace `var' = `var' * 100
	}
	
	tostring year, replace
	gen label_dist = ""
	replace label_dist = string(pct_cur_4DSW_dist, "%9.2f") + "%" if year == "2024"
	gen label_sch = ""
	replace label_sch = string(pct_cur_4DSW_sch, "%9.2f") + "%" if year == "2024"
	gen label_stu = ""
	replace label_stu = string(pct_cur_4DSW_stu, "%9.2f") + "%" if year == "2024"
	destring year, replace

	twoway /// 
		(connected pct_cur_4DSW_dist year, msymbol(none) mlabel(label_dist) mlabcolor(black) sort lcolor(blue)) ///
		(connected pct_cur_4DSW_sch year, msymbol(none) mlabel(label_sch) mlabcolor(black) sort lcolor(red)) ///
		(connected pct_cur_4DSW_stu year, msymbol(none) mlabel(label_stu) mlabcolor(black) sort lcolor(green)), ///
		legend(order(1 "Districts" 2 "Schools" 3 "Students")) ///
		xtitle("School Year") ///
		xscale(range(2017 2025)) ///
		ytitle("Percent of All Districts, Schools, and Students")
		graph export "$descriptives/dist_stu_sch_4DSW.png", replace width(1200) height(800)
	
	
/// Looking into case studies 
	use "$clean/yearly_tracker_merge", clear
	browse if mi(Jamie) & mi(UH) & mi(Cade) & mi(MDR) & pct_four > .5 & !mi(pct_four)