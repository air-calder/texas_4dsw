/*
Description: Main retention models at teacher-year level.
Run from project root.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`prepared_data'"
if _rc {
    do "replication/04_prepare_teacher_outcomes.do"
}

use "`prepared_data'", clear
capture mkdir "replication/output/tables"

local tcontrols ""
foreach x in female certified exper salary fte {
    capture confirm variable `x'
    if _rc == 0 {
        local tcontrols "`tcontrols' `x'"
    }
}

local ccontrols ""
foreach x in class_size class_frpl_share class_nonwhite_share class_prior_ach {
    capture confirm variable `x'
    if _rc == 0 {
        local ccontrols "`ccontrols' `x'"
    }
}

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `y'
    if _rc == 0 {
        capture noisily areg `y' post_adoption i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
        if _rc == 0 {
            local b = _b[post_adoption]
            local s = _se[post_adoption]
            local z = `b' / `s'
            local p = 2 * normal(-abs(`z'))
            local n = e(N)
            post `posth' ("baseline") ("`y'") (`b') (`s') (`p') (`n')
        }

        if "`tcontrols'" != "" {
            capture noisily areg `y' post_adoption `tcontrols' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
            if _rc == 0 {
                local b = _b[post_adoption]
                local s = _se[post_adoption]
                local z = `b' / `s'
                local p = 2 * normal(-abs(`z'))
                local n = e(N)
                post `posth' ("plus_teacher_ctrl") ("`y'") (`b') (`s') (`p') (`n')
            }
        }

        if "`tcontrols'" != "" | "`ccontrols'" != "" {
            local full_controls "`tcontrols' `ccontrols'"
            capture noisily areg `y' post_adoption `full_controls' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
            if _rc == 0 {
                local b = _b[post_adoption]
                local s = _se[post_adoption]
                local z = `b' / `s'
                local p = 2 * normal(-abs(`z'))
                local n = e(N)
                post `posth' ("plus_teacher_class_ctrl") ("`y'") (`b') (`s') (`p') (`n')
            }
        }
    }
}
postclose `posth'

use "`results'", clear
sort outcome spec
export delimited using "replication/output/tables/teacher_retention_main.csv", replace
