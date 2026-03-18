/*
Description: Robustness checks for teacher-level retention outcomes.
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

foreach v in id2 syear district campus is_incumbent post_adoption rural hybrid_calendar stay_school_t1 stay_district_t1 {
    capture confirm variable `v'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "11_robustness" "robustness_models" "`v'" "missing_required_variable"
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

foreach y in stay_school_t1 stay_district_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
    if r(N) == 0 {
        do "replication/utils/record_unavailable_analysis.do" "11_robustness" "robustness_models" "`y'" "no_nonmissing_outcome_in_incumbent_sample"
        di as error "Outcome `y' has no nonmissing values in incumbent sample"
        exit 459
    }
}

local specs "baseline cluster_school teacher_fe rural_only no_hybrid"

tempfile rb
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`rb'", replace

foreach sp of local specs {
    local if_cond "is_incumbent == 1"
    local cluster_var "district"

    if "`sp'" == "cluster_school" {
        local cluster_var "campus"
    }
    if "`sp'" == "rural_only" {
        local if_cond "is_incumbent == 1 & rural == 1"
    }
    if "`sp'" == "no_hybrid" {
        local if_cond "is_incumbent == 1 & (hybrid_calendar != 1 | missing(hybrid_calendar))"
    }

    foreach y in stay_school_t1 stay_district_t1 {
        if "`sp'" == "teacher_fe" {
            noisily xtset id2 syear
            noisily xtreg `y' post_adoption i.syear if `if_cond' & !missing(`y'), fe vce(cluster district)
        }
        else {
            noisily areg `y' post_adoption i.syear if `if_cond' & !missing(`y'), absorb(campus) vce(cluster `cluster_var')
        }

        local b = _b[post_adoption]
        local s = _se[post_adoption]
        local z = `b' / `s'
        local p = 2 * normal(-abs(`z'))
        local n = e(N)
        post `posth' ("`sp'") ("`y'") (`b') (`s') (`p') (`n')
    }
}
postclose `posth'

use "`rb'", clear
sort outcome spec
export delimited using "replication/output/tables/teacher_robustness.csv", replace
