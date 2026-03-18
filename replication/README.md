## Teacher-Year Replication Pipeline (No PageRank)

This folder contains a teacher-year replication pipeline for the two prior-literature papers. It builds the analysis panel directly from cleaned outputs produced by scripts in `Code/` and fails fast when required inputs are missing.

### Scope
- Builds one `id2 x syear` panel from cleaned files in `data/clean/`.
- Starts from cleaned outputs (no raw-data construction scripts).
- Computes teacher `t+1` mobility/retention outcomes in-script because precomputed teacher versions are not created in `Code/`.
- Includes main, event-study, heterogeneity, entrant, and robustness modules.
- Excludes all PageRank-related outcomes by design.

### Expected Input (from `Code/` cleaning pipeline)
- `data/clean/teacher_background.dta`
- `data/clean/yearly_tracker_merge.dta`
- `data/clean/vam_data_idsgroup1.dta` through `data/clean/vam_data_idsgroup4.dta`
- `data/raw/ccd_district.dta` (uses `year`, `StateAgencyID`, and `District_Urbanicity`)
- Scripts use `Code/` variable names directly (no replication config file).

### Run Order
Run the master script from repo root:

```stata
do replication/00_master.do
```

Or run modules manually in this order:
1. `replication/01_build_classroom_controls_teacher_year.do`
2. `replication/02_build_teacher_year_prepared.do`
3. `replication/checks/01_data_integrity.do`
4. `replication/checks/02_pretrend_checks.do`
5. `replication/03_descriptives_teacher.do`
6. `replication/04_teacher_retention_main.do`
7. `replication/05_teacher_retention_eventstudy.do`
8. `replication/06_teacher_retention_heterogeneity.do`
9. `replication/07_teacher_entrant_sorting_main.do`
10. `replication/08_teacher_entrant_eventstudy.do`
11. `replication/09_teacher_robustness.do`
12. `replication/10_tables_figures_teacher.do`
13. `replication/11_unavailable_analyses_tally.do`

### Outputs
- `replication/output/intermediate/`: prepared teacher-year file
- `replication/output/checks/`: integrity and pretrend diagnostics
- `replication/output/descriptives/`: sample tables and trend files
- `replication/output/tables/`: model result CSVs and combined workbook
- `replication/output/figures/`: trend and summary figures
- `replication/output/logs/`: master run logs

### Notes
- Primary retention outcome: `stay_school_t1`.
- Secondary retention checks include `stay_district_t1`, `switch_district_t1`, and `exit_tx_public_t1`.
- Main FE structure is school FE + year FE (`areg` with absorbed school FE).
- Default clustering is district-level; school and teacher-FE variants are included in robustness.

### Best-Guess Availability from `Code/`
| Input / Variable Group | Best Guess | Evidence in `Code/` | Notes |
|---|---|---|---|
| `data/clean/teacher_background.dta` | Available | `Code/teacher_background.do:135` | Explicitly saved by cleaning pipeline. |
| `id2`, `syear`, `exper`, `first_cert_year`, `tier1`, `tier2`, `tier3`, `cert_alt`, `degree` | Available | `Code/teacher_background.do:45`, `Code/teacher_background.do:86`, `Code/teacher_background.do:104`, `Code/teacher_background.do:121` | Explicitly generated/kept or expected in teacher file used by replication. |
| `district`, `campus`, `fte`, `totalpay`, `sex` | Available | `Code/teacher_background.do` employee records are carried through to final save | Present in the teacher file used by replication. |
| `certified` | Derivable | `first_cert_year` from `Code/teacher_background.do:104` | Replication defines `certified = (syear >= first_cert_year)`. |
| `data/clean/yearly_tracker_merge.dta` | Available | `Code/calendar_clean.do:190` | Core treatment timing file. |
| `firstyear`, `ever4DSW`, `post_adoption`, `pct_four` | Available | `Code/calendar_clean.do:155`, `Code/calendar_clean.do:179`, `Code/calendar_clean.do:182` | Used for treatment, event timing, and hybrid flag construction. |
| `data/raw/ccd_district.dta` | Available | `Code/calendar_clean.do:203`, `Code/calendar_clean.do:215` | Raw district CCD source used for urbanicity merge. |
| `District_Urbanicity` / `rural` source | Available | `District_Urbanicity` kept from `data/raw/ccd_district.dta` | Replication sets `rural` from urbanicity categories after merge on `district` + `year`. |
| `data/clean/vam_data_idsgroup1-4.dta` | Available | `Code/stu_tch_merge.do:183` | All four VAM slices are written in cleaning code. |
| Classroom-control sources (`teachid`, `section_id`, `num_students`, `classx_frl`, `classx_white`, `classx_lag_*`) | Available | `Code/stu_tch_merge.do:53`, `Code/stu_tch_merge.do:124`, `Code/stu_tch_merge.do:175` | Used to build `class_size`, `class_frpl_share`, `class_nonwhite_share`, `class_prior_ach`. |
| Entrant outcomes (`is_entrant`, `incoming_from_tx`, `incoming_first_time`, `incoming_experience`, `incoming_alt_path`) | Derived in replication | built in `replication/02_build_teacher_year_prepared.do` | Not explicitly produced as final vars in `Code/` outputs. |
| Degree-based entrant outcomes (`incoming_adv_degree`, `incoming_no_degree`) | Available (derived in replication) | `degree` is used in `replication/02_build_teacher_year_prepared.do` | Degree code mapping: 0 no degree, 1 bachelor's, 2 master's, 3 PhD; `incoming_adv_degree = inlist(degree,2,3)`, `incoming_no_degree = (degree==0)`. |
| `adjacent_to_treated` | Missing | no adjacency construction in `Code/` | Requires an external district adjacency source. |

This table is a code-based best guess from cleaning scripts and may differ from what is present in your local `.dta` files.
