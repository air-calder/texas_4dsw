/*
Description: Main retention models at teacher-year level.
Primary outcome is stay_school_t1.
*/

version 17

capture confirm file "${prepared_data}"
if _rc {
    do "replication/01_config.do"
    do "replication/04_prepare_teacher_outcomes.do"
}

use "${prepared_data}", clear
capture mkdir "${rep_output}/tables"

* Build available controls dynamically.
local tcontrols ""
foreach x of global teacher_controls_candidates {
    capture confirm variable `x'
    if _rc == 0 {
        local tcontrols "`tcontrols' `x'"
    }
}

local ccontrols ""
foreach x of global classroom_controls_candidates {
    capture confirm variable `x'
    if _rc == 0 {
        local ccontrols "`ccontrols' `x'"
    }
}

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y of global outcomes_retention_main {
    capture confirm variable `y'
    if _rc == 0 {
        * Baseline: school FE + year FE
        capture noisily areg `y' ${treat_var} i.${year_var} if ${incumbent_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
        if _rc == 0 {
            local b = _b[${treat_var}]
            local s = _se[${treat_var}]
            local z = `b' / `s'
            local p = 2 * normal(-abs(`z'))
            local n = e(N)
            post `posth' ("baseline") ("`y'") (`b') (`s') (`p') (`n')
        }

        * + Teacher controls
        if "`tcontrols'" != "" {
            capture noisily areg `y' ${treat_var} `tcontrols' i.${year_var} if ${incumbent_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
            if _rc == 0 {
                local b = _b[${treat_var}]
                local s = _se[${treat_var}]
                local z = `b' / `s'
                local p = 2 * normal(-abs(`z'))
                local n = e(N)
                post `posth' ("plus_teacher_ctrl") ("`y'") (`b') (`s') (`p') (`n')
            }
        }

        * + Teacher and classroom controls
        if "`tcontrols'" != "" | "`ccontrols'" != "" {
            local full_controls "`tcontrols' `ccontrols'"
            capture noisily areg `y' ${treat_var} `full_controls' i.${year_var} if ${incumbent_var} == 1 & !missing(`y'), absorb(${id_school}) vce(cluster ${id_district})
            if _rc == 0 {
                local b = _b[${treat_var}]
                local s = _se[${treat_var}]
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
export delimited using "${rep_output}/tables/teacher_retention_main.csv", replace
