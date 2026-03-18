# AGENTS

## Purpose
This repository is for replicating **two existing papers** using the cleaned data pipeline we already have.

The goal is to make `replication/` produce the analysis outputs from cleaned inputs, not to redesign the original cleaning system.

## Scope and Boundaries
- Work in `replication/`.
- Do **not** modify anything in `Code/`.
- Treat `Code/` as the source of truth for available cleaned variables and file structure.

## Environment Notes
- Final execution happens in a **Windows** environment.
- Do not assume Stata runs are possible in this local Linux environment.
- Do not claim scripts were executed unless they were actually run in the target environment.

## Practical Guidance
- Keep replication scripts strict and explicit about required inputs.
- Prefer direct use of known variable names from cleaned files.
- Keep numbering and run order in `replication/` consistent with `replication/00_master.do`.
- Update `replication/README.md` when assumptions or required variables change.
