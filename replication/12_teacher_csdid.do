/*
Description: Callaway-Sant'Anna estimates for retention and entrant outcomes.
Run from project root.
Fail fast on missing required variables and missing csdid package.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"
local event_min = -3
local event_max = 4

capture mkdir "replication/output/tables"

capture which csdid
if _rc {
    di as error "Required command csdid is not installed. Install in target environment with: ssc install csdid"
    exit 499
}

capture program drop _post_rtable
program define _post_rtable
    syntax name(name=ph) , DOMAIN(string) OUTCOME(string) SAMPLE(string) SPEC(string) NOBS(integer)

    tempname t
    matrix `t' = r(table)
    local k = colsof(`t')
    if `k' == 0 {
        di as error "Post-estimation table has zero columns for outcome `outcome' spec `spec'"
        exit 459
    }

    local cnames : colnames `t'
    forvalues j = 1/`k' {
        local term : word `j' of `cnames'
        local b = el(`t', 1, `j')
        local s = el(`t', 2, `j')
        local p = .
        if !missing(`s') & `s' > 0 {
            local z = `b' / `s'
            local p = 2 * normal(-abs(`z'))
        }
        post `ph' ("`domain'") ("`outcome'") ("`sample'") ("`spec'") ("`term'") (`b') (`s') (`p') (`nobs')
    }
end

tempfile ret_main ret_event ent_main ent_event cohort
tempname ph_ret_main ph_ret_event ph_ent_main ph_ent_event ph_cohort

postfile `ph_ret_main' str20 domain str40 outcome str20 sample str30 spec str40 term double coef se pvalue long N using "`ret_main'", replace
postfile `ph_ret_event' str20 domain str40 outcome str20 sample str30 spec str40 term double coef se pvalue long N using "`ret_event'", replace
postfile `ph_ent_main' str20 domain str40 outcome str20 sample str30 spec str40 term double coef se pvalue long N using "`ent_main'", replace
postfile `ph_ent_event' str20 domain str40 outcome str20 sample str30 spec str40 term double coef se pvalue long N using "`ent_event'", replace
postfile `ph_cohort' str20 domain str40 outcome str20 sample str30 spec str40 term double coef se pvalue long N using "`cohort'", replace

* ==================== Teacher-level retention C&S ====================
use "`prepared_data'", clear

foreach v in id2 syear district firstyear ever4DSW post_adoption is_incumbent stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

sort id2 syear
by id2: egen g_first_treat = min(cond(post_adoption == 1, syear, .))
replace g_first_treat = 0 if missing(g_first_treat)

gen __post_reversal = (g_first_treat > 0 & syear >= g_first_treat & post_adoption == 0)
quietly count if is_incumbent == 1 & __post_reversal == 1
if r(N) > 0 {
    di as text "WARNING: dropping " r(N) " incumbent rows with post-treatment reversals for csdid retention"
}
drop if __post_reversal == 1
drop __post_reversal

foreach y in stay_school_t1 stay_district_t1 switch_district_t1 exit_tx_public_t1 {
    quietly count if is_incumbent == 1 & !missing(`y')
    if r(N) == 0 {
        di as error "Outcome `y' has no nonmissing values in incumbent sample"
        exit 459
    }

    forvalues a = 0/1 {
        capture noisily csdid `y' if is_incumbent == 1 & !missing(`y'), ivar(id2) time(syear) gvar(g_first_treat) notyet cluster(district) anticipation(`a')
        if _rc {
            di as error "csdid failed for outcome `y' with anticipation(`a')"
            exit _rc
        }
        local n = e(N)

        capture noisily estat simple
        if _rc {
            di as error "estat simple failed for outcome `y' with anticipation(`a')"
            exit _rc
        }
        _post_rtable `ph_ret_main', domain("retention") outcome("`y'") sample("teacher") spec("ant`a'_simple") nobs(`n')

        capture noisily estat event, window(`event_min' `event_max')
        if _rc {
            di as error "estat event failed for outcome `y' with anticipation(`a')"
            exit _rc
        }
        _post_rtable `ph_ret_event', domain("retention") outcome("`y'") sample("teacher") spec("ant`a'_event") nobs(`n')

        capture noisily estat group
        if _rc {
            di as error "estat group failed for outcome `y' with anticipation(`a')"
            exit _rc
        }
        _post_rtable `ph_cohort', domain("retention") outcome("`y'") sample("teacher") spec("ant`a'_group") nobs(`n')
    }
}

* ==================== District-level entrant C&S ====================
use "`prepared_data'", clear

foreach v in district syear firstyear ever4DSW post_adoption is_entrant incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

tempfile district_panel entrant_panel

preserve
collapse (firstnm) firstyear ever4DSW post_adoption, by(district syear)
save "`district_panel'", replace
restore

preserve
keep if is_entrant == 1
collapse (mean) incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree, by(district syear)
save "`entrant_panel'", replace
restore

use "`district_panel'", clear
merge 1:1 district syear using "`entrant_panel'"
drop if _merge == 2
drop _merge

gen g_first_treat = firstyear if ever4DSW == 1 & !missing(firstyear)
replace g_first_treat = 0 if missing(g_first_treat)

foreach y in incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    quietly count if !missing(`y')
    if r(N) == 0 {
        di as error "District-level entrant outcome `y' has no nonmissing values"
        exit 459
    }

    capture noisily csdid `y' if !missing(`y'), ivar(district) time(syear) gvar(g_first_treat) notyet cluster(district) anticipation(0)
    if _rc {
        di as error "csdid failed for district-level entrant outcome `y'"
        exit _rc
    }
    local n = e(N)

    capture noisily estat simple
    if _rc {
        di as error "estat simple failed for district-level entrant outcome `y'"
        exit _rc
    }
    _post_rtable `ph_ent_main', domain("entrant") outcome("`y'") sample("district") spec("ant0_simple") nobs(`n')

    capture noisily estat event, window(`event_min' `event_max')
    if _rc {
        di as error "estat event failed for district-level entrant outcome `y'"
        exit _rc
    }
    _post_rtable `ph_ent_event', domain("entrant") outcome("`y'") sample("district") spec("ant0_event") nobs(`n')

    capture noisily estat group
    if _rc {
        di as error "estat group failed for district-level entrant outcome `y'"
        exit _rc
    }
    _post_rtable `ph_cohort', domain("entrant") outcome("`y'") sample("district") spec("ant0_group") nobs(`n')
}

postclose `ph_ret_main'
postclose `ph_ret_event'
postclose `ph_ent_main'
postclose `ph_ent_event'
postclose `ph_cohort'

use "`ret_main'", clear
keep outcome sample spec term coef se pvalue N
sort outcome spec term
export delimited using "replication/output/tables/teacher_retention_csdid_main.csv", replace

use "`ret_event'", clear
keep outcome sample spec term coef se pvalue N
sort outcome spec term
export delimited using "replication/output/tables/teacher_retention_csdid_eventstudy.csv", replace

use "`ent_main'", clear
keep outcome sample spec term coef se pvalue N
sort outcome spec term
export delimited using "replication/output/tables/teacher_entrant_csdid_main.csv", replace

use "`ent_event'", clear
keep outcome sample spec term coef se pvalue N
sort outcome spec term
export delimited using "replication/output/tables/teacher_entrant_csdid_eventstudy.csv", replace

use "`cohort'", clear
keep domain outcome sample spec term coef se pvalue N
sort domain outcome spec term
export delimited using "replication/output/tables/teacher_csdid_cohort_effects.csv", replace
