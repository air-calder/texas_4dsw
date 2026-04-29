/*
Description: Build teacher-year classroom controls from VAM files.
Run from project root.
*/

clear
set max_memory 200g

// Must redirect working directory from personal folder to project folder
cd "E:\projects\2403-Evidence\project"

// Set global
global last_year 2024
global intermediate "E:/projects/2403-Evidence/project/data/intermediate"
global clean "E:/projects/2403-Evidence/project/data/clean"

local first_vam = 1
tempfile class_controls

    use "$clean/vam_data_all" if syear >= 2017, clear

    gen class_frpl_share = classx_frl
    gen class_nonwhite_share = 1 - classx_white
    egen class_prior_ach = rowmean(classx_lag_r_ssc_std classx_lag_m_ssc_std)
    sort teachid syear section_id
    by teachid syear section_id: egen class_size = count(id1)

    keep teachid syear class_size class_frpl_share class_nonwhite_share class_prior_ach
    drop if missing(teachid) | missing(syear)
    collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear)

    if `first_vam' {
        save "`class_controls'", replace
        local first_vam = 0
    }
    else {
        append using "`class_controls'"
        save "`class_controls'", replace
    }

use "`class_controls'", clear
collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear)

rename teachid teacher_id1 
save "code/4DSW student teacher analysis/replication/output/intermediate/classroom_controls_teacher_year.dta", replace
