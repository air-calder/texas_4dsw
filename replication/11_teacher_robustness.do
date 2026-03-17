/*
Description: Robustness checks for teacher-level retention outcomes.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/tables"

local key_outcomes "${y_stay_school} ${y_stay_district}"
local specs "baseline cluster_school teacher_fe"

capture confirm variable ${rural_var}
if _rc == 0 {
    local specs "`specs' rural_only"
}

capture confirm variable ${hybrid_var}
if _rc == 0 {
    local specs "`specs' no_hybrid"
}

capture confirm variable ${adjacent_treated_var}
if _rc == 0 {
    local specs "`specs' nonadjacent_controls"
}

tempfile rb
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`rb'", replace

foreach sp of local specs {
    local if_cond "${incumbent_var} == 1"
    local cluster_var "${id_district}"

    if "`sp'" == "cluster_school" {
        local cluster_var "${id_school}"
    }
    if "`sp'" == "rural_only" {
        local if_cond "${incumbent_var} == 1 & ${rural_var} == 1"
    }
    if "`sp'" == "no_hybrid" {
        local if_cond "${incumbent_var} == 1 & (${hybrid_var} != 1 | missing(${hybrid_var}))"
    }
    if "`sp'" == "nonadjacent_controls" {
        local if_cond "${incumbent_var} == 1 & (${treat_var} == 1 | ${adjacent_treated_var} != 1 | missing(${adjacent_treated_var}))"
    }

    foreach y of local key_outcomes {
        capture confirm variable `y'
        if _rc == 0 {
            if "`sp'" == "teacher_fe" {
                capture noisily xtset ${id_teacher} ${year_var}
                capture noisily xtreg `y' ${treat_var} i.${year_var} if `if_cond' & !missing(`y'), fe vce(cluster ${id_district})
            }
            else {
                capture noisily areg `y' ${treat_var} i.${year_var} if `if_cond' & !missing(`y'), absorb(${id_school}) vce(cluster `cluster_var')
            }

            if _rc == 0 {
                local b = _b[${treat_var}]
                local s = _se[${treat_var}]
                local z = `b' / `s'
                local p = 2 * normal(-abs(`z'))
                local n = e(N)
                post `posth' ("`sp'") ("`y'") (`b') (`s') (`p') (`n')
            }
        }
    }
}
postclose `posth'

use "`rb'", clear
sort outcome spec
export delimited using "${rep_output}/tables/teacher_robustness.csv", replace
