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
  orientation), a debug overlay and an About dialog with font credits and
  licences.
- Three fonts, all drawn as outlines at fit size:
  - JetBrains Mono 2.304 (modern, OFL, ships ligatures);
  - BigBlue TerminalPlus 1.0 (IBM 8x14 EGA/VGA look, CC BY-SA);
  - C64 Pro Mono 1.2.1 (Commodore 64 look, Style's freeware licence).
- Two themes: green phosphor and paper.
- Synthetic fixtures (`tool/gen_fixtures.dart`) and a fetcher for two real
  philes (`tool/fetch_dev_philes.dart`).

## Retro fonts: outline at fit size instead of integer-scaled pixels

The first version of the spike used PxPlus IBM VGA 8x16 with integer
scaling. On phones in portrait, an 8-pixel cell only reaches **1x**: 8
physical pixels per glyph and 38–43% of the width unused. That was crisp
but too small to read. Landscape reached 3x and looked right.

Following review, the retro look now comes from BigBlue TerminalPlus and
C64 Pro Mono, rendered like any vector font at fit size. They fill all 80
columns in every orientation. At fractional scales the pixel edges are
anti-aliased, a little soft at small sizes, but readable. The integer-scale
path stays in the layout calculator (the spec keeps it as a core rule, and
Stage E's manifest has the flag), but no bundled font uses it.

## Acceptance criteria

| Criterion | Evidence | Result |
|---|---|---|
| Exactly 80 columns at fit, portrait and landscape, every font | Widget tests measure the shaped glyph boxes of an 80-character line for all three fonts; goldens at 390x844 and 844x390 | Pass (tests, emulator). Physical device: **Pending** |
| A 132-column line scrolls horizontally; all lines move with it; chrome does not | Widget test: every line shifts by the same amount; chrome is a separate overlay | Pass |
| Rotation in a 10,000-line file keeps the top line (±1) and column | Widget tests (exact line, 3 rotations, each font); integration test on the Android emulator (6 rotations, each font) | Pass (exact, not just ±1) |
| Switching fonts mid-file keeps the top line | Widget test and integration test | Pass |
| Pixel font renders at an integer scale | Covered by calculator unit tests; no bundled font uses integer scaling after review (see above) | Superseded by the font decision |
| `->`, `!=`, `==`, `<=`, `www` render as separate characters | Pixel-equality test against glyphs drawn one by one, plus a control showing `calt` on *does* form a ligature; golden | Pass |
| Chrome hides on scroll down, shows on scroll up, toggles on tap; no line moves | Widget tests, including status/nav bar insets appearing and a side cutout; emulator screenshots match pixel for pixel | Pass |
| 60 fps scrolling a 10,000-line file in profile mode, mid-range Android | `integration_test/scroll_perf_test.dart` harness works (checked in debug on an emulator) | **Pending**: needs a physical device |
| Layout calculator unit tests | `test/layout/` | Pass |

## Legibility at 80 columns

At fit, every font has the same glyph width, because the 80 columns fill
the same space. What changes between fonts is line height:

| Device | Glyph width | JetBrains Mono line | BigBlue line | C64 line |
|---|---|---|---|---|
| Small Android (360 pt) | 4.30 pt (12.9 px) | 9.5 pt | 6.5 pt | 4.3 pt |
| iPhone 15 (393 pt) | 4.71 pt (14.1 px) | 10.4 pt | 7.1 pt | 4.7 pt |
| Pixel 7 (412 pt) | 4.95 pt (13.0 px) | 10.9 pt | 7.4 pt | 5.0 pt |
| Pixel 7 landscape (915 pt) | 11.24 pt (29.5 px) | 24.7 pt | 16.9 pt | 11.2 pt |
| iPhone 15 landscape (852 pt) | 10.45 pt (31.3 px) | 23.0 pt | 15.7 pt | 10.4 pt |
| iPad mini portrait (744 pt) | 9.10 pt (18.2 px) | 20.0 pt | 13.7 pt | 9.1 pt |

Emulator observations (Pixel 7 image, 2.625x):

- **JetBrains Mono, portrait:** clean and readable for good eyesight, as
  the spec expects.
- **BigBlue Terminal, portrait:** fills the width with a clear DOS look.
  Slightly soft at this size, but readable. Its 8x14-derived proportions
  give tighter lines than JetBrains Mono, so more text fits per screen.
- **C64 Pro Mono, portrait:** very dense. Its cells are square, so each
  line is only as tall as a glyph is wide (about 13 px). The C64 was a
  40-column machine, and this font is at its best in landscape or on
  tablets.

Subjective verdict on a physical phone, with screenshots: **Pending**.

## Coverage gaps (for Stage E)

- **JetBrains Mono:** missing 21 CP437 symbols (☺♥♦… ⌠⌡ⁿ).
- **BigBlue TerminalPlus:** complete for CP437 and Latin-1.
- **C64 Pro Mono:** ASCII and PETSCII only. It covers 29 of 128
  box-drawing characters, has no double-line box drawing, and is missing
  most Latin-1 accented letters and many CP437 symbols.

Until Stage E's same-width placeholder, missing glyphs fall back to a
system font, and alignment after them is not guaranteed. The C64
box-drawing golden shows this.

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

## iOS vs Android

**Pending**: no iOS build yet (needs a Mac). Things to compare:

- Anti-aliasing of the blocky retro fonts at fractional sizes.
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

- With the chrome showing, the top lines of a phile sit under it, because
  chrome is an overlay. That's per spec, but opening a phile with the
  chrome hidden, or starting with a top margin, may read better. Revisit in
  Stage D.
- Archive `.txt` files now start with YAML front matter. The spike shows it
  as text; Stage B must strip it.
- Column counting uses UTF-16 code units, which is fine for CP437 and
  Latin-1. Stage B should count code points.
- **C64 Pro Mono's licence only allows it in software that is free to end
  users.** A paid build or in-app purchase needs a separate licence from
  Style, or the font must be dropped from that build.
