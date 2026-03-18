/*
Description: Heterogeneity models for teacher-level retention outcomes.
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

foreach v in syear district campus is_incumbent post_adoption stay_school_t1 stay_district_t1 female exp_le5 exp_gt5 exp_gt9 certified class_size class_frpl_share class_nonwhite_share class_prior_ach {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

tempfile het
tempname posth
postfile `posth' str12 var_type str40 heter_var str40 outcome double coef se pvalue long N using "`het'", replace

foreach y in stay_school_t1 stay_district_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
    if r(N) == 0 {
        di as error "Outcome `y' has no nonmissing values in incumbent sample"
        exit 459
    }

    foreach h in female exp_le5 exp_gt5 exp_gt9 certified {
        noisily areg `y' c.post_adoption##i.`h' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
        local b = .
        local s = .
        capture local b = _b[1.`h'#c.post_adoption]
        capture local s = _se[1.`h'#c.post_adoption]
        if missing(`b') {
            capture local b = _b[c.post_adoption#1.`h']
            capture local s = _se[c.post_adoption#1.`h']
        }
        local z = `b' / `s'
        local p = 2 * normal(-abs(`z'))
        local n = e(N)
        post `posth' ("binary") ("`h'") ("`y'") (`b') (`s') (`p') (`n')
    }

    foreach h in class_size class_frpl_share class_nonwhite_share class_prior_ach {
        noisily areg `y' c.post_adoption##c.`h' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
        local b = _b[c.post_adoption#c.`h']
        local s = _se[c.post_adoption#c.`h']
        local z = `b' / `s'
        local p = 2 * normal(-abs(`z'))
        local n = e(N)
        post `posth' ("continuous") ("`h'") ("`y'") (`b') (`s') (`p') (`n')
    }
}
postclose `posth'

use "`het'", clear
sort outcome var_type heter_var
export delimited using "replication/output/tables/teacher_retention_heterogeneity.csv", replace
