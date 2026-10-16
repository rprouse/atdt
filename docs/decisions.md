# Decisions log

Dated record of every **Verify** item from the spec, plus significant design decisions. Newest entries at the bottom.

Each entry records:

- **Checked:** what was examined, and how
- **Found:** the result
- **Changed:** what was done as a result (or "nothing")

## Open Verify items

| Stage | Item | Status |
|---|---|---|
| — | FTS5 included in the bundled SQLite build, and whether `sqlite3_flutter_libs` or `sqlite3` v3 build hooks is the right way to bundle it | Verified 2026-10-16 (build hooks; FTS5 present; pinned by a test) |
| — | Golden test platform | Decided 2026-10-16 |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Verified 2026-10-16 |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack | Verified 2026-10-16 |
| A | Scroll structure choice | Decided 2026-10-16; confirm at the decision gate |
| A | Horizontal insets that stay put when system bars hide | Decided 2026-10-16; check on device |
| B | CP437 vs Latin-1 heuristic against the real archive | Verified 2026-10-16 (archive is all UTF-8; heuristic kept as fallback) |
| B | YAML front matter added to archive `.txt` files | Handled 2026-10-16 |
| C | Archive URL pattern, format, and metadata location | Verified 2026-10-16 (all 72 tarballs; dates from the issue picker) |
| E | Licence of each candidate font | Open (JetBrains Mono, BigBlue TerminalPlus and C64 Pro Mono verified) |
| G | Flutter selection behaviour in lazily built lists | Open |
| I | Section header patterns across the archive | Open |

---|---|---|
| — | FTS5 included in the bundled SQLite build, and whether `sqlite3_flutter_libs` or `sqlite3` v3 build hooks is the right way to bundle it | Open (Stage C) |
| — | Golden test platform: CI runs Linux, development is on Windows | Open (Stage A) |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Open |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack (believed CC BY-SA 4.0) | Open |
| A | Scroll structure choice (`TwoDimensionalScrollView` vs nested scroll views) | Open |
| B | CP437 vs Latin-1 heuristic against the real archive | Verified 2026-10-16 (archive is all UTF-8; heuristic kept as fallback) |
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

## 2026-10-16: Retro fonts as outlines, not integer-scaled pixels

- **Checked:** PxPlus IBM VGA 8x16 with integer scaling, on the emulator and in the calculator for common phone widths. Also the licences and binaries of BigBlue TerminalPlus and C64 Pro Mono, from their primary sources.
- **Found:**
  - With integer scaling, an 8-pixel cell reaches only **1x on every phone in portrait**: 8 physical pixels per glyph, with 38–43% of the width unused. Review judged the pixel font "not great".
  - **BigBlue TerminalPlus 1.0** (VileR, int10h.org) is CC BY-SA 4.0. Advance is 800/1200 = 0.667 and line height is 1.0 em. It has full CP437 and Latin-1 coverage and no GSUB features. The original `BigBlue_TerminalPlus.TTF` is better for us than the Nerd Font patch: the patch adds thousands of icon glyphs we don't need and is an adaptation.
  - **C64 Pro Mono 1.2.1** (Style, style64.org) is under Style's own licence. It may be included in a software package **only unmodified, under its original file name, and only if the software is free to end users**. It may not be sold, put in a font collection, or offered for direct download. Advance is 1.0 (square cells) and line height is 1.0 em. Coverage is ASCII and PETSCII: 29/128 box-drawing characters, no double-line boxes, and most accented Latin-1 letters missing.
- **Changed:**
  - Dropped PxPlus IBM VGA 8x16. BigBlue TerminalPlus and C64 Pro Mono now render as outlines at fit size, like JetBrains Mono, so all three fill 80 columns in every orientation.
  - `C64_Pro_Mono-STYLE.ttf` keeps its original file name. `.gitattributes` gains `*.TTF binary` for BigBlue's upper-case extension.
  - Added an About dialog (chrome info button) with each font's credit. Each font's shipped licence file is registered with Flutter's `LicenseRegistry`, so "View licenses" shows the full texts. Tests check both.
  - The integer-scale code path and its unit tests stay in the layout calculator. The spec keeps it as a core rule and Stage E's manifest has the flag; no bundled font sets it today.
  - **Release constraint:** C64 Pro Mono can only ship while ATDT is free. Any paid tier needs a licence from Style, or the font must be removed from that build.

## 2026-10-16: Stage B ingestion against the real archive

- **Checked:** ran `tool/ingest_archive.dart` over all 72 issue tarballs (1,026 philes). Then scanned the raw files for conversion damage (U+FFFD, UTF-8-read-as-Latin-1 mojibake) and for every control character, with its context.
- **Found:**
  - **Every phile is valid UTF-8.** The maintainers have converted the archive: box drawing appears as real Unicode (1,899 box characters), and there is no U+FFFD or mojibake. The CP437 / Latin-1 heuristic never fires on the live source.
  - **Every phile has front matter** with a title and an author (1,026/1,026).
  - **C0 bytes survived the conversion as raw bytes** in 26 philes (305 characters), and they look like DOS display glyphs:
    - ESC in 22/4 and 22/5 is border art: `/|←/|←…` and `←|/`, probably backslashes mangled long ago, but aligned as one column each.
    - 0x03 ♥ appears in 6 philes, 0x14 ¶ in 3, and 0x18/0x19 ↑↓ in diagrams.
    - 0x1F appears in 46/19, 46/20, 46/23 and 48/3 as WordStar soft hyphens at line ends (`dif
ferent`).
  - **No real ANSI escape sequences exist.** The 4 "sequences" my first version stripped were false positives: `ESC _` and `ESC O` in art. Stripping them deleted the following art character and shifted the art by two columns.
  - **^Z:** 26 philes end with a single ^Z (trailing padding), and 6 have a ^Z at a line end where concatenated parts meet (46/15, 46/16, 46/18, 46/25, 46/26 and 55/3).
  - Form feeds: 5, all in 50/6.
  - **Size:** median 474 lines and 79 columns. 15% of philes exceed 80 columns, and the widest is 559 (62/6). **71/7 is 16.4 million characters (265,732 lines)**; ingesting it takes 1.9 s on a desktop JIT.
- **Changed:**
  - **The spec says "other C0 controls become a visible placeholder". C0 bytes and DEL now show as their CP437 glyphs in every encoding instead.** That is how DOS displayed them, and it keeps art and symbols intact. The `∙` placeholder (U+2219, present in every bundled font) is kept for NUL (blank in CP437) and C1 controls. Soft hyphens therefore show as `▼` at line ends, faithful to DOS if not to WordStar.
  - ANSI stripping is limited to full CSI sequences (`ESC [ … final`). A bare ESC is a `←` glyph.
  - A ^Z immediately before a line break is dropped (DOS stopped reading there), as well as trailing ^Z/NUL padding.
  - The decoding heuristic (CP437 when box-drawing bytes appear outside words; Latin-1 when accented letters sit inside them; Windows-1252 when bytes 0x80–0x9F are prose punctuation) stays as the fallback for non-UTF-8 sources. It is covered by fixtures. Ambiguous decisions are flagged on `PhileText.encodingAmbiguous` and in the CSV; none occur in the archive.
  - **For Stage C:** import must run off the UI isolate (71/7 alone takes seconds on a phone). Line-offset storage must cope with philes over 16 MB.

## 2026-10-16: SQLite bundling and FTS5

- **Checked:** pub.dev, the changelogs and READMEs of `drift`, `drift_flutter`, `sqlite3` and `sqlite3_flutter_libs`, and the drift docs. Ran FTS5 under `flutter test` on Windows and in the Linux CI container.
- **Found:**
  - `sqlite3` 3.x bundles SQLite (3.54 in 3.7.x) through Dart build hooks on Android, iOS, Windows and Linux. The prebuilt binaries are compiled with `SQLITE_ENABLE_FTS5`, and iOS uses the bundled copy, not the system SQLite.
  - **`sqlite3_flutter_libs` is end-of-life** (0.6.0+eol does nothing). Its README says to remove it after moving to `sqlite3` 3.x. `drift_flutter` 0.3.x pulls in the empty eol stub on purpose.
  - The `sqlite3` Dart API has no incremental blob I/O (`sqlite3_blob_open`).
  - The hook downloads the SQLite binary (sha256-checked), so CI needs network access, which GitHub Actions has.
- **Changed:**
  - Using `drift` 2.35 + `drift_flutter` 0.3 + `path_provider`; `sqlite3_flutter_libs` is not a direct dependency, unlike the spec.
  - `build.yaml` tells `drift_dev` about the fts5 module, ready for Stage H.
  - `test/storage/archive_database_test.dart` creates an FTS5 table and runs a `MATCH` query, so losing FTS5 fails CI.

## 2026-10-16: Archive format and metadata (Stage C)

- **Checked:** all 72 cached tarballs with Python's `tarfile`; phrack.org issue pages; `archives.phrack.org/robots.txt`.
- **Found:**
  - Every tarball has the same flat layout: a `./` entry plus `./N.txt` files only. There are no PDFs, nested paths, symlinks or unsafe paths. The archive is 31.1 MB compressed and 61 MB once stored.
  - Tar timestamps are all 1985-11-17 00:00 (normalised), so they are **not release dates**.
  - Release dates for all 72 issues are in the issue-jump `<select>` on every issue page (`Issue N (YYYY-MM-DD)`). `/issues/1/1` is a meta-refresh stub to the slugged page, so two requests fetch every date.
  - `archives.phrack.org/robots.txt` only *defines* Cloudflare content signals (search, ai-input, ai-train) and sets none, so under its own clause (c) it neither grants nor restricts. An offline reader on the user's device is none of those uses anyway.
- **Changed:**
  - Issues are discovered from the `tgz/` directory index, so "check for new issues" finds issue 73 when it appears.
  - Release dates are fetched best effort; a failure leaves them null ("if known").
  - Title and author come from front matter, falling back to "Phile N" and no author. Nothing is guessed.

## 2026-10-16: Text storage in line-aligned chunks

- **Checked:** how to read one line without loading a 16 MB phile, given no incremental blob I/O. Measured on the emulator.
- **Found:**
  - SQLite's `substr()` on a BLOB materialises the whole value, so the spec's "single blob with line-start offsets" would read 16 MB per line for 71/7. The offsets alone would be 1 MB.
  - With line-aligned chunks, `readLine` (debug build, x86 emulator, after warm-up) has p50 2.4–3.9 ms and p95 4.1–7.7 ms. **The median equals the empty-query round trip to drift's database isolate** (2.5–3.1 ms), so the lookup itself is negligible. Chunk size barely matters: 64 KiB gave p95 4.55 ms, 16 KiB 4.22 ms, and 4 KiB 3.78 ms in one run.
- **Changed:**
  - The `phile_text` table holds ~16 KiB chunks of whole lines, each tagged with `first_line` and `line_count` and indexed by `(phile_id, first_line)`. Any line is one indexed lookup of one chunk. That meets the spec's purpose ("read a line without splitting the whole file"), but not its literal design.
  - `readLine` uses a raw prepared query; the query builder cost more than the lookup in debug.
  - `integration_test/storage_perf_test.dart` asserts p95 < 5 ms only in profile and release builds. **Pending:** run it on a mid-range physical phone in profile mode.

## 2026-10-16: Download robustness and backup exclusion

- **Checked:** a fresh emulator install downloading the real archive, killed mid-download, then airplane mode mid-download.
- **Found and fixed during testing:**
  - Dart's gzip decoder accepts a truncated stream silently, which would have stored a half-downloaded issue as empty. There are now three guards: the gzip ISIZE trailer, the tar end-of-archive marker, and rejection of an issue with no philes.
  - On device, a kill after 9 issues relaunched straight into a resumed run of the 63 remaining issues, without a tap. Airplane mode showed "Can't reach the Phrack archive…" with Retry, keeping the 25 issues done; Retry stored the other 47. Final state: 72 issues, 1,026 philes, all release dates, SQLite integrity ok.
- **Changed:**
  - Each issue is saved in one transaction. A persisted `archive.download` flag ("requested" or "settled") drives the auto-resume at launch.
  - The database is `<application support>/atdt/archive.sqlite`. Android excludes `files/atdt/` with `fullBackupContent` (API ≤ 30) and `dataExtractionRules` (API 31+, cloud backup and device transfer). iOS sets `isExcludedFromBackup` on the folder through a method channel in `AppDelegate`. **Not yet built or verified on iOS: needs a Mac.**
  - Reading positions share the database, so they are excluded from backup too. They are per-device state, and the archive can be fetched again; a separate backed-up store can be added in Stage G if wanted.
