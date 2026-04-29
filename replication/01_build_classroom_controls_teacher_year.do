/*
Description: Build teacher-year classroom controls from VAM files.
Run from project root.
*/

version 17

capture mkdir "replication/output"
capture mkdir "replication/output/intermediate"

local first_vam = 1
tempfile class_controls

forvalues i = 1/4 {
    use "data/clean/vam_data_idsgroup`i'.dta" if syear >= 2017, clear

    gen class_frpl_share = classx_frl
    gen class_nonwhite_share = 1 - classx_white
    egen class_prior_ach = rowmean(classx_lag_r_ssc_std classx_lag_m_ssc_std)
    sort teachid syear section_id
    by teachid syear section_id: egen class_size = count(id1)

    keep teachid syear class_size class_frpl_share class_nonwhite_share class_prior_ach
    drop if missing(teachid) | missing(syear)
    collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(teachid syear)

    gen id2 = teachid
    drop teachid

    if `first_vam' {
        save "`class_controls'", replace
        local first_vam = 0
    }
    else {
        append using "`class_controls'"
        save "`class_controls'", replace
    }
}

use "`class_controls'", clear
collapse (mean) class_size class_frpl_share class_nonwhite_share class_prior_ach, by(id2 syear)
sort id2 syear
save "replication/output/intermediate/classroom_controls_teacher_year.dta", replace
