/*
Description: Main entrant/sorting models at teacher-year level.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "code/4DSW student teacher analysis/replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
capture mkdir "code/4DSW student teacher analysis/replication/output/tables"

foreach v in teachid syear district campus is_entrant post_adoption female certified exper totalpay fte incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

quietly count if is_entrant == 1
if r(N) == 0 {
    di as error "Entrant sample has zero rows"
    exit 459
}

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    quietly count if is_entrant == 1 & !missing(`y')
    if r(N) == 0 {
        di as error "Entrant outcome `y' is all missing in entrant sample"
        exit 459
    }
}

local tcontrols "female certified exper totalpay fte"

tempfile results
tempname posth
postfile `posth' str30 spec str40 outcome double coef se pvalue long N using "`results'", replace

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    noisily areg `y' post_adoption i.syear if is_entrant == 1 & !missing(`y'), absorb(campus) vce(cluster district)
    local b = _b[post_adoption]
    local s = _se[post_adoption]
    local z = `b' / `s'
    local p = 2 * normal(-abs(`z'))
    local n = e(N)
    post `posth' ("baseline") ("`y'") (`b') (`s') (`p') (`n')

    noisily areg `y' post_adoption `tcontrols' i.syear if is_entrant == 1 & !missing(`y'), absorb(campus) vce(cluster district)
    local b = _b[post_adoption]
    local s = _se[post_adoption]
    local z = `b' / `s'
    local p = 2 * normal(-abs(`z'))
    local n = e(N)
    post `posth' ("plus_teacher_ctrl") ("`y'") (`b') (`s') (`p') (`n')
}
postclose `posth'

use "`results'", clear
sort outcome spec
export delimited using "code/4DSW student teacher analysis/replication/output/tables/teacher_entrant_main.csv", replace
