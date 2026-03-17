/*
Description: Main entrant/sorting models at teacher-year level.
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

capture confirm variable is_entrant
if _rc {
    do "replication/utils/record_unavailable_analysis.do" "09_entrant_main" "entrant_main_models" "is_entrant" "entrant_flag_missing"
    file open fh using "replication/output/tables/teacher_entrant_note.txt", write replace
    file write fh "Entrant sample variable is_entrant is missing; entrant models skipped." _n
    file close fh
    exit
}

quietly count if is_entrant == 1
if r(N) == 0 {
    do "replication/utils/record_unavailable_analysis.do" "09_entrant_main" "entrant_main_models" "is_entrant" "entrant_sample_has_zero_rows"
    file open fh using "replication/output/tables/teacher_entrant_note.txt", write replace
    file write fh "Entrant sample variable is_entrant has zero entrant observations; entrant models skipped." _n
    file close fh
    exit
}

local tcontrols ""
foreach x in female certified exper salary fte {
    capture confirm variable `x'
    if _rc == 0 {
        local tcontrols "`tcontrols' `x'"
    }
}

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `y'
    if _rc {
        do "replication/utils/record_unavailable_analysis.do" "09_entrant_main" "entrant_main_models" "`y'" "entrant_outcome_missing"
    }
    else {
        quietly count if is_entrant == 1 & !missing(`y')
        if r(N) == 0 {
            do "replication/utils/record_unavailable_analysis.do" "09_entrant_main" "entrant_main_models" "`y'" "entrant_outcome_all_missing_in_sample"
            continue
        }

        capture noisily areg `y' post_adoption i.syear if is_entrant == 1 & !missing(`y'), absorb(campus) vce(cluster district)
        if _rc == 0 {
            local b = _b[post_adoption]
            local s = _se[post_adoption]
            local z = `b' / `s'
            local p = 2 * normal(-abs(`z'))
            local n = e(N)
            post `posth' ("baseline") ("`y'") (`b') (`s') (`p') (`n')
        }

        if "`tcontrols'" != "" {
            capture noisily areg `y' post_adoption `tcontrols' i.syear if is_entrant == 1 & !missing(`y'), absorb(campus) vce(cluster district)
            if _rc == 0 {
                local b = _b[post_adoption]
                local s = _se[post_adoption]
                local z = `b' / `s'
                local p = 2 * normal(-abs(`z'))
                local n = e(N)
                post `posth' ("plus_teacher_ctrl") ("`y'") (`b') (`s') (`p') (`n')
            }
        }
    }
}
postclose `posth'

use "`results'", clear
sort outcome spec
export delimited using "replication/output/tables/teacher_entrant_main.csv", replace
