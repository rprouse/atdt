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
| A | Rendering spike | Not started |
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

- [Flutter](https://docs.flutter.dev/get-started/install) 3.47 or newer (stable channel), which includes Dart 3.13
- JDK 17, available to `flutter doctor`, for Android builds
- Android Studio or the Android SDK, for Android builds
- Xcode on macOS, for iOS builds

## Getting started

```sh
flutter pub get
flutter run
```

### Real philes for manual testing

Phrack text is never committed to this repository. To test with real philes, download a couple into the git-ignored `assets/dev/` folder:

```sh
dart run tool/fetch_dev_philes.dart
```

If `assets/dev/` is empty, the app falls back to the synthetic fixtures in `test/fixtures/`.

## Testing

```sh
flutter test                         # unit, widget and golden tests
flutter test --update-goldens        # regenerate golden images after an intended change
flutter test integration_test        # device behaviour (needs a device or emulator)
```

Performance checks use profile mode on a physical device:

```sh
flutter run --profile
```

## Project layout

```
lib/
  layout/      Pure Dart layout maths (no Flutter imports)
  ingest/      Pure Dart decoding and normalisation (no Flutter imports)
  archive/     Pure Dart archive parsing (no Flutter imports)
  reader/      The reader widget and its scroll structure
test/
  fixtures/    Synthetic, byte-exact text fixtures
  architecture_test.dart   Fails if a pure-Dart folder imports Flutter
integration_test/
tool/          Developer scripts
docs/          Spec, decisions log, spike report
```

## Documentation

- [`docs/atdt-initial-spec.md`](docs/atdt-initial-spec.md): the product and staged build specification
- [`docs/decisions.md`](docs/decisions.md): dated record of every verified assumption and design decision
- [`AGENTS.md`](AGENTS.md): instructions for coding agents working in this repository

## Licence

The source code is released under the [MIT License](LICENSE).

Bundled fonts keep their own licences (for example SIL OFL 1.1 and CC BY-SA 4.0). They are listed with attribution on the in-app credits screen and alongside each font in `assets/fonts/`.

Phrack and all Phrack content belong to their respective authors and the Phrack staff. This project is not affiliated with Phrack.
