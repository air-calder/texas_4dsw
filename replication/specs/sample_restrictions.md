## Sample Restrictions (Teacher-Year Pipeline)

Use this file to document the exact sample restrictions applied before estimation.

Suggested fields to fill:
- Input file version/date
- Year window kept
- Teacher types included/excluded
- School/district types included/excluded (rural-only, etc.)
- Treatment definition details (full vs hybrid)
- Handling of missing treatment timing
- Handling of duplicate `teacher_id x school_year` rows
- Incumbent sample definition (`is_incumbent`)
- Entrant sample definition (`is_entrant`)

Current scaffold defaults:
- Uses configured year window in `replication/01_config.do`.
- Resolves duplicate teacher-year rows by keeping max `fte` row when `fte` exists; otherwise keeps first deterministic row.
- Main retention models run on `is_incumbent == 1`.
- Entrant/sorting models run on `is_entrant == 1`.
- Robustness includes optional rural-only, no-hybrid, and non-adjacent-control variants if those variables exist.
