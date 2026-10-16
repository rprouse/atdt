# Decisions log

Dated record of every **Verify** item from the spec, plus significant design decisions. Newest entries at the bottom.

Each entry records:

- **Checked:** what was examined, and how
- **Found:** the result
- **Changed:** what was done as a result (or "nothing")

## Open Verify items

| Stage | Item | Status |
|---|---|---|
| — | FTS5 included in the bundled SQLite build, and whether `sqlite3_flutter_libs` or `sqlite3` v3 build hooks is the right way to bundle it | Open (Stage C) |
| — | Golden test platform: CI runs Linux, development is on Windows | Open (Stage A) |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Open |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack (believed CC BY-SA 4.0) | Open |
| A | Scroll structure choice (`TwoDimensionalScrollView` vs nested scroll views) | Open |
| B | CP437 vs Latin-1 heuristic against the real archive | Open |
| C | Archive URL pattern, format, and metadata location | Open |
| E | Licence of each candidate font | Open |
| G | Flutter selection behaviour in lazily built lists | Open |
| I | Section header patterns across the archive | Open |

---

## 2026-10-16: Repository housekeeping

- **Checked:** how to keep the byte-exact fixtures required by the spec (CRLF, lone CR, CP437 bytes) intact on a Windows dev machine.
- **Found:** Git's line-ending normalisation and editor settings would rewrite them.
- **Changed:** `.gitattributes` marks `test/fixtures/**` as `-text`; `.editorconfig` turns off its rules for that folder.

## 2026-10-16: Project scaffold

- **Checked:** the Flutter toolchain (3.47.7 stable, Dart 3.13.5) and what the scaffold needs before Stage A.
- **Found:** Stage A needs no storage. The `sqlite3` package v3 bundles SQLite through Dart build hooks, and `sqlite3_flutter_libs` (named in the spec) is being phased out because of that. Whether FTS5 is present depends on which route is used.
- **Changed:**
  - Generated with `flutter create --org org.prouse --project-name atdt --platforms android,ios`. Bundle ID and application ID are `org.prouse.atdt`.
  - Added only `flutter_riverpod` and `integration_test`. Drift and SQLite packages are deferred to Stage C, where the FTS5 Verify item decides how SQLite is bundled.
  - `analysis_options.yaml` turns on strict casts, inference and raw types, and treats `unawaited_futures` as an error.
  - `test/architecture_test.dart` fails the build if `lib/layout/`, `lib/ingest/` or `lib/archive/` imports Flutter, Riverpod or `dart:ui`. It was checked against a planted violation.
  - CI (GitHub Actions, Ubuntu) runs format, analyze and tests. Goldens rendered on Windows will not match Linux pixel for pixel. Stage A must decide where goldens are generated (likely CI-only or a Linux container) before committing any.
