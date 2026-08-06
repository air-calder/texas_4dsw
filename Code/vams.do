/*
Description: This .do file runs the value added models for the Gates Math project. 
Author: Alejandra Salazar
Reference code: Github - 3_analysis_longrun/code/estimate_vam.ado  
*/

// Must redirect working directory from personal folder to project folder -potentially due to server settings.
cd "E:\projects\2403-Evidence\project"

// Adjust memory 
clear all
set max_memory 200g

// Set global
global clean "E:/projects/2403-Evidence/project/data/clean"

// Establish a program to estimate vams 
// cap prog drop estimate_vam
// prog def estimate_vam
	
	local stu_var ///
		c.lag_m_ssc_std##c.lag_m_ssc_std##c.lag_m_ssc_std ///
		c.lag_r_ssc_std##c.lag_r_ssc_std##c.lag_r_ssc_std ///
		lep speced gifted female race frl
		
	local class_var ///
		classx_lep classx_speced classx_gifted classx_female classx_frl ///
		classx_white classx_black classx_hispanic classx_asian classx_other ///
		classx_lag_r_ssc_std classx_lag_m_ssc_std 
	
	di "controls `stu_var' `class_var'"
	
// Load data
use "$clean/vam_data", clear
compress
memory
keep if inrange(grade, 4, 9)
sort teachid subject grade syear
	
	foreach y of varlist test {
		local abs "tfx_resid(teachid)"
		// VAMs
		vam `y', teacher(teachid) year(syear) class(section_id) ///
			by(subject level) /// 
			controls(`stu_var' `class_var' i.grade#i.syear) ///
			`abs' /// 
			driftlimit(5) ///
			data(merge tv score_r) /// // tv = teacher value added, also called tfx
			output("E:\projects\2403-Evidence\project\output\vams_`prefix'_`y'")
		}
// end

foreach var in teachid subject grade syear section_id level {
	bys syear: egen miss_`var' = total(missing(`var'))
	tab miss_`var'
}
// Save teacher-year dataset with one column for math value-added and one for ELA.
keep teachid subject syear level tv 
duplicates drop
collapse (mean) tv, by(teachid syear subject)
reshape wide tv, i(teachid syear) j(subject, string)
duplicates report teachid syear // Passed! 
rename teachid teacher_id1
save "$clean/vams_tv", replace