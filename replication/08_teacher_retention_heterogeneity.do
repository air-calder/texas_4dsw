/*
Description: Heterogeneity models for teacher-level retention outcomes.
Includes binary and continuous interaction terms.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/tables"

local outcomes "${y_stay_school} ${y_stay_district}"

tempfile het
tempname posth
postfile `posth' str12 var_type str40 heter_var str40 outcome double coef se pvalue long N using "`het'", replace

foreach y of local outcomes {
    capture confirm variable `y'
    if _rc == 0 {
        * Binary heterogeneity
        foreach h of global heter_binary_candidates {
            capture confirm variable `h'
            if _rc == 0 {
                capture noisily areg `y' c.${treat_var}##i.`h' i.${year_var} if ${incumbent_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
                if _rc == 0 {
                    local b = .
                    local s = .
                    local p = .
                    capture local b = _b[1.`h'#c.${treat_var}]
                    capture local s = _se[1.`h'#c.${treat_var}]
                    if missing(`b') {
                        capture local b = _b[c.${treat_var}#1.`h']
                        capture local s = _se[c.${treat_var}#1.`h']
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

        * Continuous heterogeneity
        foreach h of global heter_continuous_candidates {
            capture confirm variable `h'
            if _rc == 0 {
                capture noisily areg `y' c.${treat_var}##c.`h' i.${year_var} if ${incumbent_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
                if _rc == 0 {
                    local b = _b[c.${treat_var}#c.`h']
                    local s = _se[c.${treat_var}#c.`h']
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
export delimited using "${rep_output}/tables/teacher_retention_heterogeneity.csv", replace
