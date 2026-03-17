/*
Description: Append one row to running tally of unavailable analyses.
Usage:
do "replication/utils/record_unavailable_analysis.do" "module" "analysis" "missing_item" "reason"
*/

version 17

args module analysis missing_item reason

capture confirm global unavailable_tally
if _rc {
    do "replication/01_config.do"
}

if "`module'" == "" {
    local module "unknown_module"
}
if "`analysis'" == "" {
    local analysis "unspecified_analysis"
}
if "`missing_item'" == "" {
    local missing_item "unspecified_missing_item"
}
if "`reason'" == "" {
    local reason "missing_or_unavailable_data"
}

capture mkdir "${rep_output}"
capture mkdir "${rep_output}/checks"

local run_date = subinstr("`c(current_date)'", " ", "_", .)
local run_time = subinstr("`c(current_time)'", ":", "-", .)

local module = subinstr("`module'", ",", ";", .)
local analysis = subinstr("`analysis'", ",", ";", .)
local missing_item = subinstr("`missing_item'", ",", ";", .)
local reason = subinstr("`reason'", ",", ";", .)

capture confirm file "${unavailable_tally}"
if _rc {
    file open uf using "${unavailable_tally}", write replace text
    file write uf "run_date,run_time,module,analysis,missing_item,reason" _n
}
else {
    file open uf using "${unavailable_tally}", write append text
}

file write uf "`run_date',`run_time',`module',`analysis',`missing_item',`reason'" _n
file close uf
