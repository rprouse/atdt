# ATDT

A native iOS and Android reader for the [Phrack](http://phrack.org) archive, shown exactly as published: 80 columns, monospace, no reflow.

```
ATDT — the Hayes command to dial a number. Pick up the line, start reading.
```

## What it does

- Downloads the full Phrack archive to the device once, then reads it offline.
- Shows every phile as its original fixed-width text. At fit, exactly 80 columns fill the screen. Longer lines scroll sideways as one block.
- Keeps your exact reading position when you rotate the device or change fonts.
- Ships bundled fonts, including crisp, integer-scaled retro pixel fonts, plus several colour themes.
- Immersive reading: the chrome hides while you scroll and comes back with a gesture.

The app does **not** bundle any Phrack content. Text is fetched on-device from the Phrack site.

## Status

Early development. The work is staged; see [`docs/atdt-initial-spec.md`](docs/atdt-initial-spec.md).

| Stage | Name | Status |
|---|---|---|
| A | Rendering spike | In review: automated checks pass; device checks pending ([report](docs/spike-report.md)) |
| B | Ingestion and normalisation | Not started |
| C | Archive download and storage | Not started |
| D | Library navigation | Not started |
| E | Font system | Not started |
| F | Themes | Not started |
| G | Reader polish | Not started |
| H | Search | Not started |
| I | Section navigation | Not started |
| J | CRT effect | Not started |
| K | Release hardening | Not started |

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.47.7 (stable channel), which includes Dart 3.13. CI and the golden-image tooling pin this exact version.
- JDK 17, available to `flutter doctor`, for Android builds
- Android Studio or the Android SDK, for Android builds
- Xcode on macOS, for iOS builds
- Docker, only for regenerating golden images on Windows or macOS

## Getting started

```sh
flutter pub get
flutter run
```

The Stage A app is a single reader screen. Tap the text to show or hide the chrome. The chrome's menus switch the file, font (JetBrains Mono or IBM VGA 8x16), theme and orientation (Auto, Portrait, Landscape). The bug icon shows a debug overlay with the computed font size, integer scale, line height, top line, column offset, device pixel ratio and available width.

### Real philes for manual testing

Phrack text is never committed to this repository. To test with real philes, download two into the git-ignored `assets/dev/` folder (Phrack 7/3 from 1986 and 72/1 from 2025), then rebuild:

```sh
dart run tool/fetch_dev_philes.dart
```

If `assets/dev/` has no philes, the app opens the 10,000-line synthetic fixture. Every fixture in `test/fixtures/` is in the file menu.

## Testing

```sh
flutter test                         # unit and widget tests (goldens skip on Windows/macOS)
dart run tool/gen_fixtures.dart      # regenerate the synthetic fixtures (deterministic)
```

### Golden images

Goldens are rendered on Linux only, because text rasterisation differs between operating systems. CI checks them. To regenerate them from Windows, with Docker running:

```powershell
pwsh tool/goldens/update.ps1          # rewrite test/reader/goldens/*.png
pwsh tool/goldens/update.ps1 -Check   # compare only, as CI does
```

On Linux, `flutter test --update-goldens` works directly.

### Device tests

Run each integration test file on its own; device runs do not handle several files at once.

```sh
flutter test integration_test/app_test.dart -d <device>
flutter test integration_test/reader_rotation_test.dart -d <device>
```

### Scrolling performance

This needs a physical device, because profile mode is not available on emulators:

```sh
flutter drive --profile --no-dds   --driver=test_driver/perf_driver.dart   --target=integration_test/scroll_perf_test.dart -d <device>
```

Timeline summaries are written to `build/scroll_perf_<font>.timeline_summary.json`.

## Project layout

```
lib/
  layout/      Pure Dart layout maths (no Flutter imports)
  ingest/      Pure Dart decoding and normalisation (no Flutter imports)
  archive/     Pure Dart archive parsing (no Flutter imports)
  reader/      The reader widget, its scroll structure, chrome and debug overlay
assets/
  fonts/       Bundled fonts with their licences and attribution
  dev/         Real philes for manual testing (git-ignored)
test/
  fixtures/    Synthetic, byte-exact text fixtures
  reader/goldens/   Golden images (Linux-rendered)
  architecture_test.dart   Fails if a pure-Dart folder imports Flutter
integration_test/
test_driver/   Driver for the performance test
tool/          Developer scripts (fixtures, dev philes, goldens)
docs/          Spec, decisions log, spike report
```

## Documentation

- [`docs/atdt-initial-spec.md`](docs/atdt-initial-spec.md): the product and staged build specification
- [`docs/decisions.md`](docs/decisions.md): dated record of every verified assumption and design decision
- [`docs/spike-report.md`](docs/spike-report.md): Stage A findings for the decision gate
- [`AGENTS.md`](AGENTS.md): instructions for coding agents working in this repository

## Licence

The source code is released under the [MIT License](LICENSE).

Bundled fonts keep their own licences (for example SIL OFL 1.1 and CC BY-SA 4.0). They are listed with attribution on the in-app credits screen and alongside each font in `assets/fonts/`.

Phrack and all Phrack content belong to their respective authors and the Phrack staff. This project is not affiliated with Phrack.
