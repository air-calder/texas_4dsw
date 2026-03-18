/*
Description: Main retention models at teacher-year level.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

capture confirm file "`prepared_data'"
if _rc {
    do "replication/04_prepare_teacher_outcomes.do"
}

use "`prepared_data'", clear
capture mkdir "replication/output/tables"

foreach v in id2 syear district campus is_incumbent post_adoption female certified exper salary fte class_size class_frpl_share class_nonwhite_share class_prior_ach stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
    if r(N) == 0 {
        di as error "Outcome `y' has no nonmissing values in incumbent sample"
        exit 459
    }
}

local tcontrols "female certified exper salary fte"
local ccontrols "class_size class_frpl_share class_nonwhite_share class_prior_ach"
local full_controls "`tcontrols' `ccontrols'"

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    noisily areg `y' post_adoption i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
    local b = _b[post_adoption]
    local s = _se[post_adoption]
    local z = `b' / `s'
    local p = 2 * normal(-abs(`z'))
    local n = e(N)
    post `posth' ("baseline") ("`y'") (`b') (`s') (`p') (`n')

    noisily areg `y' post_adoption `tcontrols' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
    local b = _b[post_adoption]
    local s = _se[post_adoption]
    local z = `b' / `s'
    local p = 2 * normal(-abs(`z'))
    local n = e(N)
    post `posth' ("plus_teacher_ctrl") ("`y'") (`b') (`s') (`p') (`n')

    noisily areg `y' post_adoption `full_controls' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
    local b = _b[post_adoption]
    local s = _se[post_adoption]
    local z = `b' / `s'
    local p = 2 * normal(-abs(`z'))
    local n = e(N)
    post `posth' ("plus_teacher_class_ctrl") ("`y'") (`b') (`s') (`p') (`n')
}
postclose `posth'

use "`results'", clear
sort outcome spec
export delimited using "replication/output/tables/teacher_retention_main.csv", replace
