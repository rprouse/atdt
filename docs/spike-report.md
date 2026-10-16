# Stage A spike report

Status: **automated checks complete; device checks pending.** Items marked
**Pending** need a physical phone and a human eye, and must be filled in
before the Stage A decision gate.

Date: 2026-10-16. Flutter 3.47.7 (Dart 3.13.5).

## What was built

- `lib/layout/`: a pure-Dart layout calculator and the `(topLineIndex,
  fraction, columnOffset)` reading position. Unit-tested: fit size, integer
  scaling, the scale-below-one fallback, safe areas, overflow width, and
  line-boundary round trips.
- `lib/reader/`: the reader (horizontal scroll view around a fixed-extent
  `ListView`), overlay chrome with debug menus (file, font, theme,
  orientation) and a debug overlay.
- Two fonts: JetBrains Mono 2.304 (vector, OFL) and PxPlus IBM VGA 8x16
  (pixel, CC BY-SA). Two themes: green phosphor and paper.
- Synthetic fixtures (`tool/gen_fixtures.dart`) and a fetcher for two real
  philes (`tool/fetch_dev_philes.dart`).

## Acceptance criteria

| Criterion | Evidence | Result |
|---|---|---|
| Exactly 80 columns at fit, portrait and landscape, both fonts | Widget tests measure the shaped glyph boxes of an 80-character line; goldens at 390x844 and 844x390 | Pass (tests). Physical device: **Pending** |
| A 132-column line scrolls horizontally; all lines move with it; chrome does not | Widget test: every line shifts by the same amount; chrome is a separate overlay | Pass |
| Rotation in a 10,000-line file keeps the top line (±1) and column | Widget test (exact line, 3 rotations, both fonts); integration test on the Android emulator (6 rotations, both fonts) | Pass (exact, not just ±1) |
| Switching fonts mid-file keeps the top line | Widget test and integration test | Pass |
| Pixel font renders at an integer scale, shown in the debug overlay | Widget tests check whole-multiple glyph widths and a pixel-aligned left edge; overlay shows `scale` | Pass. Crispness on a device: **Pending** |
| `->`, `!=`, `==`, `<=`, `www` render as separate characters | Pixel-equality test against glyphs drawn one by one, plus a control showing `calt` on *does* form a ligature; golden | Pass |
| Chrome hides on scroll down, shows on scroll up, toggles on tap; no line moves | Widget tests, including status/nav bar insets appearing and a side cutout | Pass |
| 60 fps scrolling a 10,000-line file in profile mode, mid-range Android | `integration_test/scroll_perf_test.dart` harness works (checked in debug on an emulator) | **Pending**: needs a physical device |
| Layout calculator unit tests | `test/layout/` | Pass |

## Legibility at 80 columns in portrait

Sizes the calculator produces (16 pt total horizontal padding):

| Device | JetBrains Mono size | JBM glyph width (px) | VGA scale | VGA glyph (px) | Width used by VGA |
|---|---|---|---|---|---|
| Small Android (360 pt @3x) | 7.17 pt | 12.9 | 1x | 8x16 | 62% |
| iPhone 15 (393 pt @3x) | 7.85 pt | 14.1 | 1x | 8x16 | 57% |
| Pixel 7 (412 pt @2.625x) | 8.25 pt | 13.0 | 1x | 8x16 | 62% |
| Pixel 7 landscape (915 pt) | 18.73 pt | 29.5 | 3x | 24x48 | 81% |
| iPhone 15 landscape (852 pt) | 17.42 pt | 31.4 | 3x | 24x48 | 77% |
| iPad mini portrait (744 pt @2x) | 15.17 pt | 18.2 | 2x | 16x32 | 88% |

- **JetBrains Mono in portrait:** about 7–8 pt, roughly 13–14 physical
  pixels per glyph. Small, but each glyph has enough pixels to render
  cleanly. Expect "good eyesight required", as the spec anticipates.
  Subjective verdict with screenshots: **Pending**.
- **VGA 8x16 in portrait:** always 1x on phones, so glyphs are 8 physical
  pixels wide and 38–43% of the screen width is empty margin. It is crisp
  but very small. Subjective verdict: **Pending**, but I expect it to be
  unreadable for most people.
- **VGA in landscape:** 3x on both phones, with 19–23% margin. This is the
  font's natural home.

### Options for pixel fonts on 1x screens (for the gate)

1. Accept it: pixel fonts are a landscape and tablet feature, and the
   settings could say so.
2. Fall back to fit size (non-integer, slightly soft) when the scale would
   be 1, which trades crispness for size. The calculator already has this
   code path; it would only need a different trigger.
3. Ship a narrower-cell pixel font as well (any font with an 8-pixel cell
   hits the same 1x limit), so this only helps with a 6- or 7-pixel cell.

## Frame timing

**Pending.** Run on a mid-range Android phone (profile mode is not
available on emulators):

```sh
flutter drive --profile --no-dds \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/scroll_perf_test.dart -d <device>
```

Each font writes `build/scroll_perf_<font>.timeline_summary.json`. Record
`average_frame_build_time_millis`, `90th_percentile_frame_build_time_millis`,
`average_frame_rasterizer_time_millis` and the missed-budget counts here.

(Harness check only, debug mode on an x86 emulator, not representative:
JetBrains Mono 261 frames, 11.6 ms average build; VGA 269 frames, 8.7 ms
average build.)

## iOS vs Android

**Pending**: no iOS build yet (needs a Mac). Things to compare:

- Glyph rasterisation of the pixel font at integer scales (any smoothing).
- Landscape safe areas around the notch or Dynamic Island. The reader uses
  `viewPadding` left/right on iOS and display cutouts on Android.
- `SystemUiMode.immersiveSticky` has no iOS equivalent. On iOS it only hides
  the status bar.

## Scroll structure: keep it?

**Recommendation: keep** the horizontal scroll view around a fixed-extent
`ListView`.

- It met every functional criterion with stock widgets.
- Position maths is plain arithmetic.
- Restoring by rebuilding the controllers with `initialScrollOffset`
  avoids a one-frame flash.

The one known cost is that diagonal drags lock to one axis. Revisit only
if profiling shows `Text` per line is too slow (then use a custom painter
inside the same structure) or if Stage G's zoom needs a single 2D
viewport.

## Notes for later stages

- JetBrains Mono lacks 21 CP437 symbols (☺♥♦… ⌠⌡ⁿ). Until Stage E adds
  placeholder substitution, they fall back to a system font. The forced
  strut keeps row heights fixed, but column alignment after such a glyph
  is not guaranteed.
- Archive `.txt` files now start with YAML front matter. The spike shows it
  as text; Stage B must strip it.
- Column counting uses UTF-16 code units, which is fine for CP437 and
  Latin-1. Stage B should count code points.
