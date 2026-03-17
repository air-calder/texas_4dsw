## Teacher-Year Replication Pipeline (No PageRank)

This folder contains a teacher-year replication scaffold for the two prior-literature papers, using one pre-built analysis dataset and deriving transition outcomes defensively.

### Scope
- Uses one `teacher_id x school_year` panel as input.
- Starts at data checks + descriptives (no raw-data construction scripts).
- Computes `t+1` mobility/retention outcomes in-script even if precomputed versions exist.
- Includes main, event-study, heterogeneity, entrant, and robustness modules.
- Excludes all PageRank-related outcomes by design.

### Expected Input
- Default file: `data/clean/teacher_year_analysis.dta`
- Update paths and variable names in `replication/01_config.do`.
- Variable naming template is in `replication/specs/variable_map_template.csv`.

### Run Order
Run the master script from repo root:

```stata
do replication/00_master.do
```

Or run modules manually in this order:
1. `replication/01_config.do`
2. `replication/04_prepare_teacher_outcomes.do`
3. `replication/checks/01_data_integrity.do`
4. `replication/checks/02_pretrend_checks.do`
5. `replication/05_descriptives_teacher.do`
6. `replication/06_teacher_retention_main.do`
7. `replication/07_teacher_retention_eventstudy.do`
8. `replication/08_teacher_retention_heterogeneity.do`
9. `replication/09_teacher_entrant_sorting_main.do`
10. `replication/10_teacher_entrant_eventstudy.do`
11. `replication/11_teacher_robustness.do`
12. `replication/12_tables_figures_teacher.do`

### Outputs
- `replication/output/intermediate/`: prepared teacher-year file
- `replication/output/checks/`: integrity, duplicate handling, and pretrend diagnostics
- `replication/output/descriptives/`: sample tables and trend files
- `replication/output/tables/`: model result CSVs and combined workbook
- `replication/output/figures/`: trend and summary figures
- `replication/output/logs/`: master run logs

### Notes
- Primary retention outcome: `stay_school_t1`.
- Secondary retention checks include `stay_district_t1`, `switch_district_t1`, and `exit_tx_public_t1`.
- Main FE structure is school FE + year FE (`areg` with absorbed school FE).
- Default clustering is district-level; school and teacher-FE variants are included in robustness.
