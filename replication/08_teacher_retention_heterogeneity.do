/*
Description: Heterogeneity models for teacher-level retention outcomes.
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

tempfile het
tempname posth
postfile `posth' str12 var_type str40 heter_var str40 outcome double coef se pvalue long N using "`het'", replace

foreach y in stay_school_t1 stay_district_t1 {
    capture confirm variable `y'
    if _rc == 0 {
        foreach h in female exp_le5 exp_gt5 exp_gt9 certified {
            capture confirm variable `h'
            if _rc == 0 {
                capture noisily areg `y' c.post_adoption##i.`h' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
                if _rc == 0 {
                    local b = .
                    local s = .
                    local p = .
                    capture local b = _b[1.`h'#c.post_adoption]
                    capture local s = _se[1.`h'#c.post_adoption]
                    if missing(`b') {
                        capture local b = _b[c.post_adoption#1.`h']
                        capture local s = _se[c.post_adoption#1.`h']
                    }
                    if !missing(`b') & !missing(`s') {
                        local z = `b' / `s'
                        local p = 2 * normal(-abs(`z'))
                        local n = e(N)
                        post `posth' ("binary") ("`h'") ("`y'") (`b') (`s') (`p') (`n')
                    }
                }
            }
        }

        foreach h in class_size class_frpl_share class_nonwhite_share class_prior_ach {
            capture confirm variable `h'
            if _rc == 0 {
                capture noisily areg `y' c.post_adoption##c.`h' i.syear if is_incumbent == 1 & !missing(`y'), absorb(campus) vce(cluster district)
                if _rc == 0 {
                    local b = _b[c.post_adoption#c.`h']
                    local s = _se[c.post_adoption#c.`h']
                    local z = `b' / `s'
                    local p = 2 * normal(-abs(`z'))
                    local n = e(N)
                    post `posth' ("continuous") ("`h'") ("`y'") (`b') (`s') (`p') (`n')
                }
            }
        }
    }
}
postclose `posth'

use "`het'", clear
sort outcome var_type heter_var
export delimited using "replication/output/tables/teacher_retention_heterogeneity.csv", replace
