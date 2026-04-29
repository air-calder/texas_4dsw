/*
Description: Merge the student-teacher links with the teacher data we've created (Experience, license, value added) to prepare the analysis dataset.
Author: Alejandra Salazar
*/

// Must redirect working directory from personal folder to project folder -potentially due to server settings.
cd "E:\projects\2403-Evidence\project\data"

// Adjust memory 
clear all
set max_memory 100g

// Clean two datasets from calendar_clean.do to later merge.  
	// (1) 4DSW all
	use "E:\projects\2403-Evidence\NewFilesReleased\4DSW_all", clear
	gen district = substr(StateAgencyID, 4, .)
	destring district, replace
	gen firstyear_4dsw = substr(FirstYear, 6, .)
	replace firstyear_4dsw = "2018" if firstyear == "2021 / 2017-2018"
	replace firstyear_4dsw = "2021" if firstyear == "2021 / 2022-2023"
	replace firstyear_4dsw = "2021" if firstyear == "2021 / 2023-2024"
	replace firstyear_4dsw = "2021" if firstyear == "2022 / 2020-2021"
	replace firstyear_4dsw = "2021" if firstyear == "2024 / 2021-2022"
	replace firstyear_4dsw = "2024" if firstyear == "2025 / 2023-2024"
	destring firstyear_4dsw, replace
	gen status4DSW = (UH == 1 | Jamie == 1 | Cade == 1)
	save "E:\projects\2403-Evidence\project\data\clean\4DSW_all.dta", replace
	// (2) CCD school
	use "E:\projects\2403-Evidence\project\data\raw\ccd_school", clear
	rename year syear
	rename StateSchoolID campus
	destring AgencyNCES, replace
	duplicates drop campus syear, force
	save "E:\projects\2403-Evidence\project\data\clean\ccd_school.dta", replace
	
// Load in teacher value added data which includes student data of taken and passed courses. 
use "clean/vam_data_all", clear
destring sept1_age, replace

// Merge in teacher data (experience and license)
merge m:1 teachid syear using "clean/teacher_background", nogen   
	//     Result                      Number of obs
	//     -----------------------------------------
	//     Not matched                   130,700,264
	//         from master               121,902,088  
	//         from using                  8,798,176  
	//
	//     Matched                         1,399,718 <---- this seems too low?
	//     -----------------------------------------

// Merge the VAM data.
merge m:1 teachid syear using "clean/vams_tv", nogen
	//     Result                      Number of obs
	//     -----------------------------------------
	//     Not matched                     8,798,176
	//         from master                 8,798,176  
	//         from using                          0  
	//
	//     Matched                       123,301,806  
	//     -----------------------------------------

// Merge dataset from line 221 in calendar_clean.do  
merge m:1 district using "E:\projects\2403-Evidence\project\data\clean\4DSW_all.dta", nogen
	//     Result                      Number of obs
	//     -----------------------------------------
	//     Not matched                     4,671,970
	//         from master                 4,671,953  (_merge==1)
	//         from using                         17  (_merge==2)
	//
	//     Matched                       127,428,029  (_merge==3)
	//     -----------------------------------------

// Merge dataset from line 194 in calendar_clean.do  
merge m:1 campus syear using "E:\projects\2403-Evidence\project\data\clean\ccd_school.dta" //, nogen
	//     Result                      Number of obs
	//     -----------------------------------------
	//     Not matched                    56,814,812
	//         from master                56,799,161  (_merge==1) <----- higher than i expected? 
	//         from using                     15,651  (_merge==2)
	//
	//     Matched                        75,300,838  (_merge==3)
	//     -----------------------------------------

// Save
save "E:\projects\2403-Evidence\project\data\clean\analysis.dta", replace	

// List of variables we want in this dataset:
browse teachid syear campus sex sept1_age subject tch_grade_max tch_grade_min tch_grade_mode fte degree exper tv10 tv22 basepay classx_asian classx_black classx_female classx_frl classx_gifted classx_hispanic classx_lag_m_ssc_std classx_lag_r_ssc_std classx_lep classx_other classx_speced classx_white max_tier1 max_tier2 max_tier3

browse firstyear_4dsw status4DSW
// Create these variables: use ccd_school (only has the last bulletpoint) and for the rest maybe yearly_calendar/calendar_full 
	// - school-level total instructional days
	// - school-level total school weeks 
	// - school-level # of 4-day weeks
	// - CCD school and district demographics
		// ^im assuming: sch_FRL sch_AIAN sch_AAPI sch_Hispanic sch_Black sch_White sch_NHOPI sch_Two sch_TotalRaceEthnicityPublicSc special_ed_school cte_school alternative_school sch_pct_FRL sch_pct_AIAN sch_pct_AAPI sch_pct_Hispanic sch_pct_Black sch_pct_White sch_pct_NHOPI sch_pct_Two sch_pct_non_white sch_pct_FRL_quartile sch_pct_non_white_quartile School_Urbanicity TitleI TitleIEligible TitleIStatus
		// but we also have: SchoolNCES school_id StateAgencyID seasch SchoolName AgencyNCES School_Type Agency_Type Charter SchoolLevel sch_TotalEnrollment syear traditional_school campus
	