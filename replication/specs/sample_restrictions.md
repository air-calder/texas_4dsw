## Sample Restrictions (Teacher-Year Pipeline)

Use this file to document the exact sample restrictions applied before estimation.

Suggested fields to fill:
- Input file version/date
- Year window kept
- Teacher types included/excluded
- School/district types included/excluded (rural-only, etc.)
- Treatment definition details (full vs hybrid)
- Handling of missing treatment timing
- Handling of duplicate `id2 x syear` rows
- Incumbent sample definition (`is_incumbent`)
- Entrant sample definition (`is_entrant`)

Current scaffold defaults:
- Uses year window `2017-2024` in `replication/02_build_teacher_year_prepared.do`.
- Requires unique `id2 x syear` teacher-year rows (`isid`); duplicate rows fail the run.
- Main retention models run on `is_incumbent == 1`.
- Entrant/sorting models run on `is_entrant == 1`.
- Robustness includes optional rural-only and no-hybrid variants if those variables exist.
