# AGENTS.md

Instructions for coding agents working on ATDT. The authoritative product and build specification is [`docs/atdt-initial-spec.md`](docs/atdt-initial-spec.md). Read it before making changes. If this file and the spec disagree, the spec wins; flag the conflict.

## Project in one paragraph

ATDT is a Flutter (Dart) app for iOS and Android that reads the Phrack archive as the original fixed-width text. The reading experience is the product: exactly 80 columns at fit, monospace, no soft wrap, no reflow, and an exact reading position across rotation and font changes. Content is downloaded on-device and stored in SQLite (drift). State management uses Riverpod.

## Hard rules

1. **Never commit or bundle Phrack text.** The app downloads it on the device; no asset declaration may include it. Tests use synthetic fixtures in `test/fixtures/` that you write yourself; device tests generate text in code.
2. **Never reflow or rewrap text.** Every line renders on exactly one visual row. `softWrap: false`, `maxLines: 1`, `overflow: TextOverflow.visible`.
3. **Pure Dart cores.** Layout maths (`lib/layout/`), ingestion (`lib/ingest/`) and archive parsing and downloading (`lib/archive/`) must not import `package:flutter`. Keep them unit-testable with plain `dart test` semantics. Storage (`lib/storage/`) is pure drift except `database_file.dart`, which opens the file on a device.
4. **Position is a tuple, never pixels.** Reading position is `(topLineIndex, fractionIntoLine, columnOffset)`. Restore from it after every metrics change.
5. **Chrome is an overlay.** Showing or hiding chrome must never move a line of text.
6. **Ligatures off on every font:** `FontFeature.disable('liga')` and `FontFeature.disable('calt')`.
7. **Do not assume glyph advance.** Measure each font's `advanceRatio` with `TextPainter`; never hardcode 0.6.
8. **Pixel fonts render at integer scales** of their native cell size, with line heights on whole physical pixels.

## Staged workflow

- Work one stage at a time, in the order in the spec (A to K).
- Do not start a stage until the previous stage's acceptance criteria pass.
- At the end of each stage: update `README.md` (how to run the app and tests, plus the stage status table), then **stop for human review**.
- Stage A ends with `docs/spike-report.md`. Do not start Stage B until it has been reviewed.

## Verify items and decisions

Every item marked **Verify** in the spec gets a dated entry in [`docs/decisions.md`](docs/decisions.md) recording what was checked, what was found, and what changed as a result. Record significant design choices there too (for example, the scroll structure picked in Stage A). Do not write code that depends on an unverified assumption.

## Commands

```sh
flutter pub get
flutter analyze
dart format .
flutter test
flutter test --update-goldens
flutter test integration_test
dart run build_runner build --delete-conflicting-outputs   # drift codegen; *.g.dart is committed
```

Before calling any work done, run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test`. All three must be clean.

## Testing expectations

- Layout calculator: unit tests for fit size, integer scaling, the scale-below-one fallback, safe-area handling, and overflow content width.
- Rendering: golden tests at fixed viewport sizes. Goldens are platform-sensitive; generate and compare them on the same OS as CI.
- Ingestion: one test per synthetic fixture. Normalisation must be idempotent.
- Device behaviour (rotation, orientation, persistence): `integration_test`.
- Fixtures in `test/fixtures/` are byte-exact. `.gitattributes` marks them `-text`; never let an editor or tool rewrite their line endings or encoding.

## Code style

- Follow `flutter_lints` and `dart format` defaults.
- Prefer small, pure functions for maths and parsing; keep widgets thin.
- Use Riverpod consistently for state; don't mix in other state-management approaches.
- Comments explain *why*, not *what*.

## Git

- Branch off `main` for each stage or feature; open a PR for review.
- Commits are signed. Do not bypass signing.
- Keep commits focused, with messages that describe the change and why.

## Developer environment notes

- On Windows, run Python as `python`, not `python3`. Python helper scripts use PEP 723 inline metadata and run via `uv run`.
- On this project's Windows machine, signed `git commit` must run from PowerShell, not Git Bash.
