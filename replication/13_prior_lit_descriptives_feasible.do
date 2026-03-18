/*
Description: Feasible descriptive replications for prior literature tables.
Run from project root.
Fail fast on missing required variables.
*/

version 17

local prepared_data "replication/output/intermediate/teacher_year_prepared.dta"

use "`prepared_data'", clear
capture mkdir "replication/output/descriptives"

foreach v in id2 syear district campus ever4DSW post_adoption event_time rural is_incumbent is_entrant female certified exper totalpay fte degree class_size class_frpl_share stay_school_t1 turnover_teacher_t1 exp_le5 exp_gt9 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable `v' in `prepared_data'"
        exit 459
    }
}

gen male = 1 - female if !missing(female)
gen adv_degree = inlist(degree, 2, 3) if !missing(degree)

* ==================== Lawson Table 1 (feasible subset) ====================
tempfile lawson_t1
tempname ph_law1
postfile `ph_law1' str30 group_id str50 metric double mean long N str120 note using "`lawson_t1'", replace

local g1 "all_teachers"
local g2 "all_movers"
local g3 "movers_entering_rural"
local g4 "movers_entering_4dsw"

foreach g in g1 g2 g3 g4 {
    local group = "``g''"
    local cond "1"

    if "`group'" == "all_movers" {
        local cond "incoming_from_tx == 1"
    }
    if "`group'" == "movers_entering_rural" {
        local cond "incoming_from_tx == 1 & rural == 1"
    }
    if "`group'" == "movers_entering_4dsw" {
        local cond "incoming_from_tx == 1 & post_adoption == 1"
    }

    foreach m in adv_degree totalpay exper female certified {
        quietly count if `cond' & !missing(`m')
        local n = r(N)
        local mean = .
        if `n' > 0 {
            quietly summarize `m' if `cond', meanonly
            local mean = r(mean)
        }
        post `ph_law1' ("`group'") ("`m'") (`mean') (`n') ("Mover groups use incoming_from_tx == 1")
    }
}
postclose `ph_law1'

use "`lawson_t1'", clear
sort metric group_id
export delimited using "replication/output/descriptives/lawson_table1_feasible.csv", replace

* ==================== Lawson Table 2 (feasible subset) ====================
use "`prepared_data'", clear

tempfile district_base district_turnover district_entrant lawson_t2

preserve
collapse (firstnm) ever4DSW post_adoption event_time, by(district syear)
save "`district_base'", replace
restore

preserve
keep if is_incumbent == 1
collapse (mean) turnover_teacher_t1, by(district syear)
save "`district_turnover'", replace
restore

preserve
keep if is_entrant == 1
collapse (mean) incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree, by(district syear)
save "`district_entrant'", replace
restore

use "`district_base'", clear
merge 1:1 district syear using "`district_turnover'"
drop if _merge == 2
drop _merge
merge 1:1 district syear using "`district_entrant'"
drop if _merge == 2
drop _merge

tempname ph_law2
postfile `ph_law2' str30 group_id str50 metric double mean long N str120 note using "`lawson_t2'", replace

local h1 "five_day"
local h2 "four_day_post"
local h3 "four_day_pre_adoption"
local h4 "four_day_first_year"

foreach h in h1 h2 h3 h4 {
    local group = "``h''"
    local cond "ever4DSW == 0"

    if "`group'" == "four_day_post" {
        local cond "ever4DSW == 1 & post_adoption == 1"
    }
    if "`group'" == "four_day_pre_adoption" {
        local cond "ever4DSW == 1 & event_time == -1"
    }
    if "`group'" == "four_day_first_year" {
        local cond "ever4DSW == 1 & event_time == 0"
    }

    foreach m in turnover_teacher_t1 incoming_from_tx incoming_first_time incoming_alt_path incoming_experience incoming_adv_degree incoming_no_degree {
        quietly count if `cond' & !missing(`m')
        local n = r(N)
        local mean = .
        if `n' > 0 {
            quietly summarize `m' if `cond', meanonly
            local mean = r(mean)
        }
        post `ph_law2' ("`group'") ("`m'") (`mean') (`n') ("District-year means; student-teacher ratio unavailable")
    }
}
postclose `ph_law2'

use "`lawson_t2'", clear
sort metric group_id
export delimited using "replication/output/descriptives/lawson_table2_feasible.csv", replace

* ==================== Khalid Table 1 (feasible subset) ====================
use "`prepared_data'", clear
gen male = 1 - female if !missing(female)

sort campus syear id2
by campus syear id2: gen __tag_teacher = (_n == 1)
collapse (sum) n_teachers = __tag_teacher (mean) female male certified class_size class_frpl_share, by(campus syear post_adoption)

tempfile khalid_t1
tempname ph_kh1
postfile `ph_kh1' str30 group_id str50 metric double mean long N str120 note using "`khalid_t1'", replace

foreach g in five_day four_day {
    local cond "post_adoption == 0"
    if "`g'" == "four_day" {
        local cond "post_adoption == 1"
    }

    foreach m in n_teachers class_size female male certified class_frpl_share {
        quietly count if `cond' & !missing(`m')
        local n = r(N)
        local mean = .
        if `n' > 0 {
            quietly summarize `m' if `cond', meanonly
            local mean = r(mean)
        }
        post `ph_kh1' ("`g'") ("`m'") (`mean') (`n') ("Campus-year means; race shares and student-teacher ratio unavailable")
    }
}
postclose `ph_kh1'

use "`khalid_t1'", clear
sort metric group_id
export delimited using "replication/output/descriptives/khalid_table1_feasible.csv", replace

* ==================== Khalid Table 2 (feasible subset) ====================
use "`prepared_data'", clear

sort campus syear id2
by campus syear id2: gen __tag_teacher = (_n == 1)
gen new_teacher_flag = (is_entrant == 1)

gen prop_retained = stay_school_t1 if is_incumbent == 1
gen prop_female_retained = stay_school_t1 if is_incumbent == 1 & female == 1
gen prop_exp_le5_retained = stay_school_t1 if is_incumbent == 1 & exp_le5 == 1
gen prop_exp_gt9_retained = stay_school_t1 if is_incumbent == 1 & exp_gt9 == 1
gen prop_certified_retained = stay_school_t1 if is_incumbent == 1 & certified == 1

collapse (mean) prop_retained prop_female_retained prop_exp_le5_retained prop_exp_gt9_retained prop_certified_retained prop_new_teachers = new_teacher_flag, by(campus syear post_adoption)

tempfile khalid_t2
tempname ph_kh2
postfile `ph_kh2' str30 group_id str50 metric double mean long N str120 note using "`khalid_t2'", replace

foreach g in five_day four_day {
    local cond "post_adoption == 0"
    if "`g'" == "four_day" {
        local cond "post_adoption == 1"
    }

    foreach m in prop_retained prop_female_retained prop_exp_le5_retained prop_exp_gt9_retained prop_certified_retained prop_new_teachers {
        quietly count if `cond' & !missing(`m')
        local n = r(N)
        local mean = .
        if `n' > 0 {
            quietly summarize `m' if `cond', meanonly
            local mean = r(mean)
        }
        post `ph_kh2' ("`g'") ("`m'") (`mean') (`n') ("Campus-year means without matching")
    }
}
postclose `ph_kh2'

use "`khalid_t2'", clear
sort metric group_id
export delimited using "replication/output/descriptives/khalid_table2_feasible.csv", replace

* ==================== Missing components log ====================
clear
input str30 table_id str60 missing_component str80 reason
"Lawson_Table2" "student_teacher_ratio" "No district-level student enrollment variable in cleaned inputs"
"Lawson_Table3_Fig2to4_Fig7" "PageRank outcomes" "Excluded by design in this replication pipeline"
"Lawson_Robustness" "adjacent_to_treated controls" "Adjacency source not present in cleaned pipeline"
"Khalid_Table1" "teacher race shares" "Teacher race variables not in prepared replication panel"
"Khalid_Table1" "student race shares" "Student race variables not in prepared replication panel"
"Khalid_Main_All" "matched sample (1:5 nearest-neighbor)" "Matching inputs and design matrix not implemented"
"Khalid_EventStudy" "time-varying school controls vector" "Controls from paper not all available in prepared panel"
end

export delimited using "replication/output/descriptives/prior_lit_descriptive_gaps.csv", replace
