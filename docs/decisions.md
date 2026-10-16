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
| — | Golden test platform | Decided 2026-10-16 |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Verified 2026-10-16 |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack | Verified 2026-10-16 |
| A | Scroll structure choice | Decided 2026-10-16; confirm at the decision gate |
| A | Horizontal insets that stay put when system bars hide | Decided 2026-10-16; check on device |
| B | CP437 vs Latin-1 heuristic against the real archive | Open |
| B | YAML front matter added to archive `.txt` files | Found 2026-10-16; handle in Stage B |
| C | Archive URL pattern, format, and metadata location | Partly verified 2026-10-16 (tarball contents beyond issue 1 still open) |
| E | Licence of each candidate font | Open (two verified for Stage A) |
| G | Flutter selection behaviour in lazily built lists | Open |
| I | Section header patterns across the archive | Open |

---|---|---|
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

## 2026-10-16: Stage A fonts

- **Checked:** licences from the primary sources (JetBrains Mono `OFL.txt` in the official repo; the int10h.org readme and the pack's own `LICENSE.TXT`). Also inspected both shipped binaries with fontTools.
- **Found:**
  - **JetBrains Mono 2.304** is SIL OFL 1.1. Its ligatures are in `calt` only; the compiled font has no `liga` table. Advance is 600/1000 = 0.6 and natural line height is 1.32 em. It covers all 128 box-drawing characters, all block elements and all of Latin-1. It is **missing 21 CP437 symbols** (☺☻♥♦♣♠◘◙♂♀♪♫☼▬↨∟₧⌐⌠⌡ⁿ), which fall back to a system font for now; Stage E's placeholder substitution has to handle them.
  - **PxPlus IBM VGA 8x16** from VileR's Ultimate Oldschool PC Font Pack v2.2 is CC BY-SA 4.0. VileR asks for credit as "VileR" with a link to int10h.org. Units per em is 1600 and advance is 800, so at 16px each glyph is exactly 8px wide and the line box is exactly 16px tall. It covers all of CP437 and all of Latin-1, and has no GSUB features.
  - The Px variant is right for us. Ac (aspect-corrected) variants use non-square pixels and break integer scaling. Mx variants add embedded bitmaps that Flutter does not use.
- **Changed:**
  - Both fonts are bundled unmodified, with their licence files and an `ATTRIBUTION.md`, under `assets/fonts/`.
  - JetBrains Mono uses `lineHeightRatio` 1.32, its natural height, so box-drawing verticals join. PxPlus uses 1.0, with `cellWidthPx` 8 and `nativeSizePx` 16.
  - **Open legal question:** whether bundling a CC BY-SA font in a store app counts as an adaptation. My reading is that it doesn't: the file is unmodified and only credit is required. Confirm before release (Stage K).

## 2026-10-16: Phrack archive source

- **Checked:** the live site, response headers, the issue 1 tarball listing, and `robots.txt`.
- **Found:**
  - The archive has moved to `https://archives.phrack.org/`. The old `phrack.org/archives/...` URLs redirect there with a 301.
  - Single philes are at `/issues/<n>/<m>.txt`, served as `text/plain` with no charset. Issue tarballs are at `/tgz/phrack<N>.tar.gz` for N = 1 to 72. They are really gzip, even though the server labels them `application/x-tar`. Issue 1's tarball has a flat layout (`./1.txt` … `./8.txt`).
  - **Every `.txt` file starts with a YAML front-matter block** (`title:`, `author:`) that is not part of the original phile. It is the best metadata source, but it has to be stripped from the text.
  - The latest issue is 72, released 2025-08-19. Phile counts in headers are not reliable: 72/1 says "of 0x12" but the issue has 19 files.
  - `robots.txt` allows everything. There is no stated policy on automated downloads. The site sits behind Cloudflare with ETags.
- **Changed:**
  - `tool/fetch_dev_philes.dart` fetches 7/3 (*The Conscience of a Hacker*) and 72/1 into `assets/dev/`, with an identifying user agent and a 1 s delay between requests.
  - Stage B must strip front matter before normalising, and Stage C should parse it for title and author.
  - Still open for Stage C: the contents of other tarballs (does 72 include the PDF?) and `archives.phrack.org/robots.txt`.

## 2026-10-16: Reader scroll structure

- **Checked:** `TwoDimensionalScrollView` against a horizontal `SingleChildScrollView` wrapping a fixed-width `ListView.builder` with `itemExtent`.
- **Found:**
  - Nested scroll views give everything the spec asks for with stock widgets. All lines scroll sideways as one block, and line index maps to offset by `index * itemExtent`. The chrome overlay just sits in a `Stack` above both.
  - Their one cost: a diagonal drag locks to one axis. For reading that is arguably a feature.
  - `TwoDimensionalScrollView` would need a custom viewport and delegate to get the same lazily built fixed-extent rows.
- **Changed:**
  - Using nested scroll views.
  - Restoring position means rebuilding the scroll controllers whenever the layout changes, with `initialScrollOffset` computed from the stored `ReadingPosition`, instead of calling `jumpTo` after layout. The first frame at the new metrics is then already correct, and scroll clamping during that frame cannot overwrite the saved position.
  - `ReadingPosition.fromOffsets` snaps fractions within 1e-6 of a line boundary. Floating point otherwise turns line 7 at a 29/3 line height into 6.999…, and a rotation lands one line early. This has regression tests.

## 2026-10-16: Insets that do not move text

- **Checked:** which insets change when the chrome shows or hides.
- **Found:** in Android landscape with 3-button navigation, the nav bar sits on a side edge and immersive mode removes it, so `viewPadding.left`/`right` change with the chrome. Display cutouts never hide. `DisplayFeature.bounds` are in logical pixels (unlike `FlutterView.padding`, which is physical). On iOS, the landscape safe areas don't change when the status bar hides.
- **Changed:** `stableHorizontalInsets` uses cutout bounds on Android and `viewPadding` on iOS. Top and bottom insets are ignored entirely: chrome and system bars overlay the text. Widget tests cover both cases (system bars appearing; a side cutout), and a mutation check confirmed the test catches a `viewPadding`-based implementation. **Still to check on physical devices**, especially Android phones with a side cutout and iPhones in landscape.

## 2026-10-16: Golden test platform

- **Checked:** Windows and Linux text rasterisation differ, and the newest `ghcr.io/cirruslabs/flutter` image is 3.44, three minor versions behind.
- **Found:** goldens have to be generated by one OS and one Flutter version.
- **Changed:**
  - Goldens are Linux-only and skip on other OSes.
  - CI pins Flutter 3.47.7. `tool/goldens/Dockerfile` builds the same version from a git tag, and `tool/goldens/update.ps1` regenerates (or `-Check`s) goldens from Windows.
  - The acceptance checks that must hold everywhere don't rely on goldens: 80-column widths measured from shaped glyph boxes, a pixel-equality ligature test with a `calt`-on control, and geometry checks for overflow and chrome.
