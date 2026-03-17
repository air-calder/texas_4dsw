/*
Description: Main entrant/sorting models at teacher-year level.
Runs on entrant sample only.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/tables"

capture confirm variable ${entrant_var}
if _rc {
    file open fh using "${rep_output}/tables/teacher_entrant_note.txt", write replace
    file write fh "Entrant sample variable ${entrant_var} is missing; entrant models skipped." _n
    file close fh
    exit
}

local tcontrols ""
foreach x of global teacher_controls_candidates {
    capture confirm variable `x'
    if _rc == 0 {
        local tcontrols "`tcontrols' `x'"
    }
}

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y of global outcomes_entrant {
    capture confirm variable `y'
    if _rc == 0 {
        capture noisily areg `y' ${treat_var} i.${year_var} if ${entrant_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
        if _rc == 0 {
            local b = _b[${treat_var}]
            local s = _se[${treat_var}]
            local z = `b' / `s'
            local p = 2 * normal(-abs(`z'))
            local n = e(N)
            post `posth' ("baseline") ("`y'") (`b') (`s') (`p') (`n')
        }

        if "`tcontrols'" != "" {
            capture noisily areg `y' ${treat_var} `tcontrols' i.${year_var} if ${entrant_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
            if _rc == 0 {
                local b = _b[${treat_var}]
                local s = _se[${treat_var}]
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
export delimited using "${rep_output}/tables/teacher_entrant_main.csv", replace
