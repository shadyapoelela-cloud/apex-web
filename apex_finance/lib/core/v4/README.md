# core/v4 — Active V4→V5 Bridge

**Status:** This directory is NOT deprecated dead code. It contains
2 files (`v4_groups.dart` + `v4_groups_data.dart`) that are actively
imported by `lib/core/v5/`:

- `lib/core/v5/v5_data.dart:25` — `import '../v4/v4_groups.dart';`
- `lib/core/v5/v5_models.dart:20` — `import '../v4/v4_groups.dart';`

Until V5 absorbs the `V4Group` / `V4Groups` data model (tracked as
**G-A2.3** in `APEX_BLUEPRINT/09 § 4`), do **NOT** delete these files.

**History:**

- **Sprint 7 G-A2 (2026-04-30):** removed `v4_routes.dart` + added
  `@deprecated` headers to all V4 widgets. Closure note claimed
  "0 external users" for `v4_groups.dart` — that claim was incorrect
  at the time and went stale further when V5 added the imports.
- **Sprint 8 G-A2.1 (2026-05-01):** moved `apex_screen_host.dart` to
  `lib/widgets/` (clean code, wrong location) and deleted 8 orphan
  V4 files (`apex_anomaly_feed`, `apex_command_palette`,
  `apex_hijri_date`, `apex_launchpad`, `apex_numerals`,
  `apex_sub_module_shell`, `apex_tab_bar`, `apex_zatca_error_card`).
  The V5→V4 dependency on `v4_groups` was discovered via Verify-First
  mid-execution; this directory was kept rather than break V5.
- **Sprint 9 G-A2.3 (queued):** migrate `v4_groups*` → `v5_groups*`
  in `lib/core/v5/`, update the 2 V5 imports, sweep `V4Group` /
  `V4Groups` class refs, then delete this directory entirely.

See `APEX_BLUEPRINT/09 § 4` for the full migration narrative and
`G-DOCS-1` evidence #14 for the verify-first save that prevented a
broken delete.
